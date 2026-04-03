import 'package:budgetti/models/transaction.dart';
import 'package:uuid/uuid.dart';

class SheetsRowMapper {
  static const _monthToNum = {
    'gen': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'mag': 5, 'giu': 6,
    'lug': 7, 'ago': 8, 'set': 9, 'ott': 10, 'nov': 11, 'dic': 12,
  };

  static const _numToMonth = {
    1: 'gen', 2: 'feb', 3: 'mar', 4: 'apr', 5: 'mag', 6: 'giu',
    7: 'lug', 8: 'ago', 9: 'set', 10: 'ott', 11: 'nov', 12: 'dic',
  };

  static const _italianMonthNames = {
    'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno',
    'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre',
  };

  /// Parse Italian date format "1-gen" into DateTime using the given year.
  static DateTime? parseItalianDate(String raw, int year) {
    final trimmed = raw.trim().toLowerCase();
    final parts = trimmed.split('-');
    if (parts.length != 2) return null;

    final day = int.tryParse(parts[0]);
    final month = _monthToNum[parts[1]];
    if (day == null || month == null) return null;

    return DateTime(year, month, day);
  }

  /// Format DateTime as Italian short date "1-gen".
  static String formatItalianDate(DateTime date) {
    return '${date.day}-${_numToMonth[date.month]}';
  }

  /// Parse Italian currency format " € -100,00 " into double.
  static double? parseItalianAmount(String raw) {
    var cleaned = raw.trim();
    // Remove euro sign and surrounding spaces
    cleaned = cleaned.replaceAll('€', '').trim();
    // Remove thousands separator (dots)
    cleaned = cleaned.replaceAll('.', '');
    // Replace decimal comma with dot
    cleaned = cleaned.replaceAll(',', '.');
    // Remove any remaining spaces
    cleaned = cleaned.replaceAll(' ', '');
    return double.tryParse(cleaned);
  }

  /// Format double as Italian currency " € -100,00 ".
  static String formatItalianAmount(double amount) {
    final isNegative = amount < 0;
    final abs = amount.abs();
    final intPart = abs.truncate();
    final decPart = ((abs - intPart) * 100).round().toString().padLeft(2, '0');

    // Format with thousands separator
    final intStr = intPart.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < intStr.length; i++) {
      if (i > 0 && (intStr.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(intStr[i]);
    }

    final sign = isNegative ? '-' : '';
    return ' € $sign${buffer.toString()},$decPart ';
  }

  /// Check if a row is a monthly summary row (col H contains an Italian month name).
  static bool isMonthSummaryRow(List<Object?> row) {
    if (row.length < 8) return false;
    final colH = (row[7] ?? '').toString().trim().toLowerCase();
    return _italianMonthNames.contains(colH);
  }

  /// Check if a row has transaction data (col A has date, col C has amount).
  static bool isDataRow(List<Object?> row) {
    if (row.length < 3) return false;
    final colA = (row[0] ?? '').toString().trim();
    final colC = (row[2] ?? '').toString().trim();
    return colA.isNotEmpty && colC.isNotEmpty;
  }

  /// Check if a row is a transfer row (has data but empty Transizione col D).
  static bool isTransferRow(List<Object?> row) {
    if (!isDataRow(row)) return false;
    final colD = row.length > 3 ? (row[3] ?? '').toString().trim() : '';
    return colD.isEmpty;
  }

  /// Generate a hash key for duplicate detection.
  static String rowHash(List<Object?> row) {
    final date = (row[0] ?? '').toString().trim();
    final desc = (row[1] ?? '').toString().trim();
    final amount = (row[2] ?? '').toString().trim();
    final account = row.length > 6 ? (row[6] ?? '').toString().trim() : '';
    return '$date|$desc|$amount|$account';
  }

  /// Generate a hash key from a Transaction for duplicate detection.
  static String transactionHash(Transaction tx, Map<String, String> accountIdToName) {
    final date = formatItalianDate(tx.date);
    final accountName = accountIdToName[tx.accountId] ?? '';
    final amount = formatItalianAmount(tx.amount);
    return '$date|${tx.description}|$amount|$accountName';
  }

  /// Parse a single sheet row into a Transaction.
  static Transaction? sheetRowToTransaction(
    List<Object?> row,
    Map<String, String> accountNameToId,
    int year,
  ) {
    if (!isDataRow(row)) return null;

    final date = parseItalianDate((row[0] ?? '').toString(), year);
    if (date == null) return null;

    final description = (row[1] ?? '').toString().trim();
    final amount = parseItalianAmount((row[2] ?? '').toString());
    if (amount == null) return null;

    final transizione = row.length > 3 ? (row[3] ?? '').toString().trim().toLowerCase() : '';
    final categoria = row.length > 4 ? (row[4] ?? '').toString().trim() : '';
    final conti = row.length > 6 ? (row[6] ?? '').toString().trim() : '';

    String type;
    if (transizione == 'debit') {
      type = 'expense';
    } else if (transizione == 'credit') {
      type = 'income';
    } else {
      // Empty transizione = part of a transfer (handled separately)
      type = 'transfer';
    }

    final accountId = accountNameToId[conti] ?? '1';

    return Transaction(
      id: const Uuid().v4(),
      accountId: accountId,
      amount: amount,
      date: date,
      description: description,
      category: categoria,
      type: type,
    );
  }

  /// Merge two transfer rows into a single transfer Transaction.
  /// The row with negative amount is the source, positive is the destination.
  static Transaction? mergeTransferPair(
    Transaction source,
    Transaction destination,
  ) {
    final Transaction from;
    final Transaction to;

    if (source.amount < 0) {
      from = source;
      to = destination;
    } else {
      from = destination;
      to = source;
    }

    return Transaction(
      id: const Uuid().v4(),
      accountId: from.accountId,
      toAccountId: to.accountId,
      amount: to.amount.abs(), // Transfer amount is positive
      date: from.date,
      description: from.description.isNotEmpty ? from.description : to.description,
      category: from.category.isNotEmpty ? from.category : to.category,
      type: 'transfer',
    );
  }

  /// Parse all rows, merging transfer pairs.
  static List<Transaction> parseAllRows(
    List<List<Object?>> rows,
    Map<String, String> accountNameToId,
    int year,
  ) {
    final transactions = <Transaction>[];
    var i = 0;

    while (i < rows.length) {
      final row = rows[i];

      // Skip summary and empty rows
      if (isMonthSummaryRow(row) || !isDataRow(row)) {
        i++;
        continue;
      }

      if (isTransferRow(row)) {
        // Look for the next transfer row to form a pair
        final tx1 = sheetRowToTransaction(row, accountNameToId, year);
        Transaction? tx2;

        if (i + 1 < rows.length && isTransferRow(rows[i + 1])) {
          tx2 = sheetRowToTransaction(rows[i + 1], accountNameToId, year);
          i += 2;
        } else {
          // Orphan transfer row — import as-is
          if (tx1 != null) transactions.add(tx1);
          i++;
          continue;
        }

        if (tx1 != null && tx2 != null) {
          final merged = mergeTransferPair(tx1, tx2);
          if (merged != null) transactions.add(merged);
        }
      } else {
        final tx = sheetRowToTransaction(row, accountNameToId, year);
        if (tx != null) transactions.add(tx);
        i++;
      }
    }

    return transactions;
  }

  /// Convert a Transaction to sheet row(s).
  /// Returns 1 row for income/expense, 2 rows for transfers.
  static List<List<Object>> transactionToSheetRows(
    Transaction tx,
    Map<String, String> accountIdToName,
  ) {
    final dateStr = formatItalianDate(tx.date);
    final accountName = accountIdToName[tx.accountId] ?? '';

    if (tx.type == 'transfer') {
      final toAccountName = accountIdToName[tx.toAccountId ?? ''] ?? '';
      final amount = tx.amount.abs();
      return [
        // Source account: negative amount, no transizione
        [dateStr, tx.description, formatItalianAmount(-amount), '', tx.category, '', accountName],
        // Destination account: positive amount, no transizione
        [dateStr, tx.description, formatItalianAmount(amount), '', tx.category, '', toAccountName],
      ];
    }

    final transizione = tx.type == 'expense' ? 'debit' : 'credit';
    return [
      [dateStr, tx.description, formatItalianAmount(tx.amount), transizione, tx.category, '', accountName],
    ];
  }
}
