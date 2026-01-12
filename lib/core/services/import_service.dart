import 'dart:io';
import 'package:budgetti/models/transaction.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class ImportService {
  Future<List<Transaction>> parseQifFile(File file) async {
    final lines = await file.readAsLines();
    final List<Transaction> transactions = [];

    DateTime? date;
    double? amount;
    String? payee;
    String? memo;
    String? category;
    
    // QIF format usually starts with !Type:Bank, etc.
    // We'll iterate through lines looking for transaction records ending with ^

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line == '^') {
        // End of record
        if (date != null && amount != null) {
          transactions.add(Transaction(
            id: const Uuid().v4(),
            accountId: '', // To be filled by user selection
            amount: amount,
            date: date,
            description: (memo != null && memo.isNotEmpty) ? memo : (payee ?? 'Imported Transaction'),
            category: category ?? 'Uncategorized',
            tags: [],
          ));
        }

        // Reset fields
        date = null;
        amount = null;
        payee = null;
        memo = null;
        category = null;
        continue;
      }

      if (line.startsWith('!')) {
        // Header line, ignore for now (or use to validate type)
        continue;
      }

      final code = line[0];
      final value = line.substring(1);

      switch (code) {
        case 'D': // Date
           try {
             // QIF dates can be tricky. Common formats: M/D/Y, M/D/YYYY, D/M/Y depending on locale.
             // We'll try a few common patterns.
             date = _parseDate(value);
           } catch (e) {
             print('Error parsing date: $value - $e');
           }
          break;
        case 'T': // Amount
          try {
             // Remove commas for thousands, keeping dot/comma for decimal?
             // Usually QIF uses English format (dot for decimal), but let's be safe.
             // Standard QIF is typically -1,234.50
             amount = double.tryParse(value.replaceAll(',', ''));
          } catch (e) {
             print('Error parsing amount: $value - $e');
          }
          break;
        case 'P': // Payee
          payee = value;
          break;
        case 'M': // Memo
          memo = value;
          break;
        case 'L': // Category
          category = value;
          break;
      }
    }

    return transactions;
  }

  DateTime? _parseDate(String dateStr) {
    // Attempt standard formats
    // M/d/yyyy
    // M/d/yy
    // d/M/yyyy' instead? 
    // QIF spec is ambiguous without knowing the source system's locale. 
    // Usually it matches the system generating it. 
    // Let's try flexible parsing.
    
    // Replace ' with / as some older QIFs use ' (e.g. 1/12'99)
    dateStr = dateStr.replaceAll("'", "/");

    final formats = [
      // Prioritize dd/MM/yyyy as requested
      DateFormat('d/M/yyyy'),
      DateFormat('dd/MM/yyyy'),
      DateFormat('d/M/yy'),
      DateFormat('dd/MM/yy'),
      // Fallbacks
      DateFormat('M/d/yyyy'),
      DateFormat('yyyy-MM-dd'), 
    ];

    for (final fmt in formats) {
      try {
        final d = fmt.parse(dateStr);
        // DateFormat loose parsing can result in valid dates for swapped day/month
        // e.g. 05/04/2023 -> May 4 or April 5. 
        // If we strictly want dd/mm, we should probably stick to that order first.
        // The loop order defines priority.
        return d;
      } catch (_) {}
    }
    
    // Manual fallback for yy vs yyyy ambiguity if DateFormat fails or assumes 1900s for short years sometimes
    return null;
  }
}
