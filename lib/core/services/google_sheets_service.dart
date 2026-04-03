import 'package:budgetti/models/transaction.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;

import 'google_auth_service.dart';
import 'sheets_row_mapper.dart';

class GoogleSheetsService {
  final GoogleAuthService _authService;

  GoogleSheetsService(this._authService);

  Future<sheets.SheetsApi?> _getSheetsApi() async {
    try {
      final httpClient = await _authService.authenticatedClient();
      if (httpClient == null) {
        debugPrint('No authenticated HTTP client available for Sheets');
        return null;
      }
      return sheets.SheetsApi(httpClient);
    } catch (e, s) {
      debugPrint('Error getting Sheets API client: $e\n$s');
      return null;
    }
  }

  /// Read all raw rows from the given sheet (A2:M to include hash column).
  Future<List<List<Object?>>> readRawRows(
    String spreadsheetId,
    String sheetName,
  ) async {
    final sheetsApi = await _getSheetsApi();
    if (sheetsApi == null) {
      throw Exception('Not signed in to Google. Please sign in first.');
    }

    final response = await sheetsApi.spreadsheets.values.get(
      spreadsheetId,
      '$sheetName!A2:M',
    );

    return (response.values ?? []).cast<List<Object?>>();
  }

  /// Import transactions from the sheet.
  Future<List<Transaction>> importTransactions({
    required String spreadsheetId,
    required String sheetName,
    required Map<String, String> accountNameToId,
    int? year,
  }) async {
    final effectiveYear = year ?? DateTime.now().year;

    debugPrint('Importing transactions from $sheetName (year: $effectiveYear)');
    final rows = await readRawRows(spreadsheetId, sheetName);
    debugPrint('Read ${rows.length} raw rows from sheet');

    final transactions = SheetsRowMapper.parseAllRows(
      rows,
      accountNameToId,
      effectiveYear,
    );
    debugPrint('Parsed ${transactions.length} transactions');

    return transactions;
  }

  /// Export transactions to the sheet, appending only new rows.
  /// Dedup uses the hash in column M.
  Future<int> exportTransactions({
    required String spreadsheetId,
    required String sheetName,
    required List<Transaction> transactions,
    required Map<String, String> accountIdToName,
  }) async {
    final sheetsApi = await _getSheetsApi();
    if (sheetsApi == null) {
      throw Exception('Not signed in to Google. Please sign in first.');
    }

    // Collect existing hashes from column M
    final existingHashes = await _getExistingHashes(spreadsheetId, sheetName);
    debugPrint('Found ${existingHashes.length} existing hashes for dedup');

    // Sort transactions by date ASC
    final sorted = List<Transaction>.from(transactions)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Convert and filter duplicates
    final newRows = <List<Object>>[];
    for (final tx in sorted) {
      final rows = SheetsRowMapper.transactionToSheetRows(tx, accountIdToName);
      for (final row in rows) {
        final hash = row.last.toString(); // hash is the last element (col M)
        if (!existingHashes.contains(hash)) {
          newRows.add(row);
          existingHashes.add(hash); // prevent intra-batch duplicates
        }
      }
    }

    if (newRows.isEmpty) {
      debugPrint('No new rows to export');
      return 0;
    }

    // Find the first empty row by scanning column A
    final firstEmptyRow = await _findFirstEmptyRow(sheetsApi, spreadsheetId, sheetName);
    debugPrint('Writing ${newRows.length} rows starting at row $firstEmptyRow');

    final range = '$sheetName!A$firstEmptyRow:M${firstEmptyRow + newRows.length - 1}';
    final valueRange = sheets.ValueRange(values: newRows);

    await sheetsApi.spreadsheets.values.update(
      valueRange,
      spreadsheetId,
      range,
      valueInputOption: 'USER_ENTERED',
    );

    debugPrint('Export completed: ${newRows.length} rows at $range');
    return newRows.length;
  }

  /// Find the first empty row by looking at column A (date column).
  /// Skips header row 1, returns the row number to write at.
  Future<int> _findFirstEmptyRow(
    sheets.SheetsApi sheetsApi,
    String spreadsheetId,
    String sheetName,
  ) async {
    final response = await sheetsApi.spreadsheets.values.get(
      spreadsheetId,
      '$sheetName!A:A',
    );

    final rows = response.values ?? [];
    // Find last row with data in column A, then write after it
    int lastDataRow = 1; // at minimum, row 1 is the header
    for (var i = 0; i < rows.length; i++) {
      final cell = rows[i].isNotEmpty ? rows[i][0].toString().trim() : '';
      if (cell.isNotEmpty) {
        lastDataRow = i + 1; // 1-indexed
      }
    }
    return lastDataRow + 1;
  }

  /// Read existing hashes from column M.
  Future<Set<String>> _getExistingHashes(
    String spreadsheetId,
    String sheetName,
  ) async {
    try {
      final rows = await readRawRows(spreadsheetId, sheetName);
      final hashes = <String>{};
      for (final row in rows) {
        final hash = SheetsRowMapper.extractRowHash(row);
        if (hash != null) {
          hashes.add(hash);
        }
      }
      return hashes;
    } catch (e) {
      debugPrint('Error reading existing hashes: $e');
      return {};
    }
  }
}
