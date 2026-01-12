import 'dart:ui';

import 'package:budgetti/core/services/persistence_service.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mobile_ocr/mobile_ocr_plugin.dart';

class ReceiptOcrResult {
  final String? merchant;
  final double? amount;
  final DateTime? date;

  ReceiptOcrResult({this.merchant, this.amount, this.date});

  @override
  String toString() => 'Merchant: \$merchant, Amount: \$amount, Date: \$date';
}

/// Helper class to abstract differences between MLKit and MobileOCR
class _OcrLine {
  final String text;
  final Rect boundingBox;

  _OcrLine(this.text, this.boundingBox);
}

class OcrService {
  final PersistenceService _persistenceService;
  final _mlKitRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _mobileOcr = MobileOcr();

  OcrService(this._persistenceService);

  Future<ReceiptOcrResult> recognizeReceipt(String imagePath) async {
    final engine = _persistenceService.getOcrEngine();

    if (engine == 'mobile_ocr') {
      return _recognizeWithMobileOcr(imagePath);
    } else {
      return _recognizeWithMlKit(imagePath);
    }
  }

  Future<ReceiptOcrResult> _recognizeWithMlKit(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final RecognizedText recognizedText = await _mlKitRecognizer.processImage(
      inputImage,
    );

    final List<_OcrLine> allLines = [];
    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        allLines.add(_OcrLine(line.text, line.boundingBox));
      }
    }

    if (allLines.isEmpty) return ReceiptOcrResult();

    return _processLines(allLines);
  }

  Future<ReceiptOcrResult> _recognizeWithMobileOcr(String imagePath) async {
    try {
      // Ensure models are ready (downloads on first run on Android)
      await _mobileOcr.prepareModels();

      final textBlocks = await _mobileOcr.detectText(imagePath: imagePath);

      final List<_OcrLine> allLines = textBlocks.map((block) {
        return _OcrLine(block.text, block.boundingBox);
      }).toList();

      if (allLines.isEmpty) return ReceiptOcrResult();

      return _processLines(allLines);
    } catch (e) {
      // Fallback or error handling
      print('MobileOCR failed: \$e');
      return ReceiptOcrResult();
    }
  }

  ReceiptOcrResult _processLines(List<_OcrLine> allLines) {
    String? merchant;
    double? totalAmount;
    DateTime? date;

    final List<String> lineTexts = allLines.map((l) => l.text.trim()).toList();

    // 1. Try to find Merchant (Often the first line with real text)
    for (var line in lineTexts) {
      if (line.length > 3 &&
          !RegExp(r'^\d+\$', multiLine: true).hasMatch(line)) {
        merchant = line;
        break;
      }
    }

    // 2. Try to find Amount
    totalAmount = _extractAmount(allLines);

    // 3. Try to find Date
    date = _extractDate(lineTexts);

    return ReceiptOcrResult(
      merchant: merchant,
      amount: totalAmount,
      date: date,
    );
  }

  double? _extractAmount(List<_OcrLine> lines) {
    // Look for bingo keywords
    final bingoKeywords = RegExp(
      r'(TOTALE COMPLESSIVO|TOTALE EURO|TOTALE DOVUTO|TOTAL DUE)',
      caseSensitive: false,
    );
    final otherTotalKeywords = RegExp(
      r'(TOTAL|SUM|AMOUNT|PAGARE|TOTALE|EUR|€)',
      caseSensitive: false,
    );

    double? bestAmount;
    double maxFontHeight = 0;

    // 1. Bingo Logic: Find keyword and look for number on same horizontal line
    for (var line in lines) {
      final text = line.text.trim();
      if (bingoKeywords.hasMatch(text)) {
        final bbox = line.boundingBox;

        for (var otherLine in lines) {
          if (otherLine == line) continue;

          final otherBbox = otherLine.boundingBox;
          final bool sameLine =
              (otherBbox.top - bbox.top).abs() < (bbox.height * 0.5);

          if (sameLine) {
            final amount = _parseDecimal(otherLine.text);
            if (amount != null && amount > 0 && amount < 10000) {
              return amount; // Absolute priority for Bingo!
            }
          }
        }
      }
    }

    // 2. Visual Weight & Proximity fallback
    for (int i = 0; i < lines.length; i++) {
      final text = lines[i].text.trim();
      final isTotalKeyword = otherTotalKeywords.hasMatch(text);

      // If we find a total keyword, check nearby or track visual weight
      for (int j = i; j <= i + 2 && j < lines.length; j++) {
        final amount = _parseDecimal(lines[j].text);
        if (amount != null && amount > 0 && amount < 10000) {
          final height = lines[j].boundingBox.height;

          // Heuristic: If it's near a keyword, give it a "boost" in height comparison
          final adjustedHeight = isTotalKeyword && j <= i + 2
              ? height * 1.5
              : height;

          if (adjustedHeight > maxFontHeight) {
            maxFontHeight = adjustedHeight;
            bestAmount = amount;
          } else if (adjustedHeight == maxFontHeight) {
            // If same font size, pick the larger amount (usually Total vs Subtotal)
            if (bestAmount == null || amount > bestAmount) {
              bestAmount = amount;
            }
          }
        }
      }
    }

    // 3. Absolute fallback
    if (bestAmount == null) {
      for (var line in lines) {
        final amount = _parseDecimal(line.text);
        if (amount != null && amount > 0 && amount < 10000) {
          final height = line.boundingBox.height;
          if (height > maxFontHeight) {
            maxFontHeight = height;
            bestAmount = amount;
          }
        }
      }
    }

    return bestAmount;
  }

  double? _parseDecimal(String text) {
    // Match something like 1.234,56 or 1234.56 or 12,34
    // First, standardize separators
    final cleaned = text.replaceAll(',', '.').replaceAll(RegExp(r'[^\d.]'), '');
    final match = RegExp(r'(\d+\.\d{2})|(\d+\.\d{1})|(\d+)').firstMatch(cleaned);
    if (match != null) {
      return double.tryParse(match.group(0)!);
    }
    return null;
  }

  DateTime? _extractDate(List<String> lines) {
    // Look for DD/MM/YY, YYYY-MM-DD, etc.
    final dateRegex = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})');

    for (var line in lines) {
      final match = dateRegex.firstMatch(line);
      if (match != null) {
        final d = int.tryParse(match.group(1)!) ?? 1;
        final m = int.tryParse(match.group(2)!) ?? 1;
        var y = int.tryParse(match.group(3)!) ?? DateTime.now().year;
        if (y < 100) y += 2000;

        try {
          return DateTime(y, m, d);
        } catch (_) {}
      }
    }
    return null;
  }

  void dispose() {
    _mlKitRecognizer.close();
  }
}
