import 'dart:convert';
import 'package:crypto/crypto.dart';
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

  /// Compute a deterministic hash from date, description, and amount.
  /// This is the single source of truth for dedup across all entry points.
  static String computeHash(DateTime date, String description, double amount) {
    final normalized = '${date.year}-${date.month}-${date.day}'
        '|${description.trim().toLowerCase()}'
        '|${amount.toStringAsFixed(2)}';
    return md5.convert(utf8.encode(normalized)).toString().substring(0, 12);
  }

  /// Compute hash from a Transaction.
  static String transactionHash(Transaction tx) {
    return computeHash(tx.date, tx.description, tx.amount);
  }

  /// Extract hash from a sheet row (column M = index 12).
  static String? extractRowHash(List<Object?> row) {
    if (row.length < 13) return null;
    final h = (row[12] ?? '').toString().trim();
    return h.isEmpty ? null : h;
  }

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
    cleaned = cleaned.replaceAll('€', '').trim();
    cleaned = cleaned.replaceAll('.', '');
    cleaned = cleaned.replaceAll(',', '.');
    cleaned = cleaned.replaceAll(' ', '');
    return double.tryParse(cleaned);
  }

  /// Format double as Italian currency " € -100,00 ".
  static String formatItalianAmount(double amount) {
    final isNegative = amount < 0;
    final abs = amount.abs();
    final intPart = abs.truncate();
    final decPart = ((abs - intPart) * 100).round().toString().padLeft(2, '0');

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
    final metaCategoria = row.length > 5 ? (row[5] ?? '').toString().trim() : '';
    final conti = row.length > 6 ? (row[6] ?? '').toString().trim() : '';

    String type;
    if (transizione == 'debit') {
      type = 'expense';
    } else if (transizione == 'credit') {
      type = 'income';
    } else {
      type = 'transfer';
    }

    final accountId = accountNameToId[conti] ?? '1';

    // Meta Categoria (col F) maps to tags
    final tags = metaCategoria.isNotEmpty
        ? metaCategoria.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
        : <String>[];

    return Transaction(
      id: const Uuid().v4(),
      accountId: accountId,
      amount: amount,
      date: date,
      description: description,
      category: categoria,
      type: type,
      tags: tags,
    );
  }

  /// Merge two transfer rows into a single transfer Transaction.
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
      amount: to.amount.abs(),
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

      if (isMonthSummaryRow(row) || !isDataRow(row)) {
        i++;
        continue;
      }

      if (isTransferRow(row)) {
        final tx1 = sheetRowToTransaction(row, accountNameToId, year);
        Transaction? tx2;

        if (i + 1 < rows.length && isTransferRow(rows[i + 1])) {
          tx2 = sheetRowToTransaction(rows[i + 1], accountNameToId, year);
          i += 2;
        } else {
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

  /// Title case a string: "hello world" → "Hello World".
  static String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Convert a Transaction to sheet row(s) with hash in column M.
  /// Columns: A-G = data, H-L = empty (formulas/notes), M = hash (hidden).
  static List<List<Object>> transactionToSheetRows(
    Transaction tx,
    Map<String, String> accountIdToName,
  ) {
    final dateStr = formatItalianDate(tx.date);
    final desc = _titleCase(tx.description);
    final accountName = accountIdToName[tx.accountId] ?? '';
    final tagsStr = tx.tags.join(', '); // Meta Categoria = tags

    if (tx.type == 'transfer') {
      final toAccountName = accountIdToName[tx.toAccountId ?? ''] ?? '';
      final amount = tx.amount.abs();

      final hash1 = computeHash(tx.date, tx.description, -amount);
      final hash2 = computeHash(tx.date, tx.description, amount);

      return [
        [dateStr, desc, formatItalianAmount(-amount), '', tx.category, tagsStr, accountName, '', '', '', '', '', hash1],
        [dateStr, desc, formatItalianAmount(amount), '', tx.category, tagsStr, toAccountName, '', '', '', '', '', hash2],
      ];
    }

    final transizione = tx.type == 'expense' ? 'debit' : 'credit';
    final hash = computeHash(tx.date, tx.description, tx.amount);

    return [
      [dateStr, desc, formatItalianAmount(tx.amount), transizione, tx.category, tagsStr, accountName, '', '', '', '', '', hash],
    ];
  }
}
