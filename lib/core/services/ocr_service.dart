import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptOcrResult {
  final String? merchant;
  final double? amount;
  final DateTime? date;

  ReceiptOcrResult({this.merchant, this.amount, this.date});

  @override
  String toString() => 'Merchant: $merchant, Amount: $amount, Date: $date';
}

class OcrService {
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<ReceiptOcrResult> recognizeReceipt(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

    String? merchant;
    double? totalAmount;
    DateTime? date;

    final List<TextLine> allLines = [];
    for (TextBlock block in recognizedText.blocks) {
      allLines.addAll(block.lines);
    }

    if (allLines.isEmpty) return ReceiptOcrResult();

    final List<String> lineTexts = allLines.map((l) => l.text.trim()).toList();

    // 1. Try to find Merchant (Often the first line with real text)
    for (var line in lineTexts) {
      if (line.length > 3 &&
          !RegExp(r'^\d+$', multiLine: true).hasMatch(line)) {
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

  double? _extractAmount(List<TextLine> lines) {
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

    // 3. Absolute fallback: if no keyword proximity was strong enough,
    // we already tracked the maxFontHeight across the receipt in step 2.
    // If we still found nothing, check all lines as a safety.
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
          // ML Kit often messes up order depending on locale, we'll try to be smart or default to DMY
          return DateTime(y, m, d);
        } catch (_) {}
      }
    }
    return null;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
