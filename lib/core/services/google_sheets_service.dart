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

  /// Read all raw rows from the given sheet (skipping header row 1).
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
      '$sheetName!A2:L',
    );

    return (response.values ?? []).cast<List<Object?>>();
  }

  /// Import transactions from the sheet, parsing rows and merging transfer pairs.
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

  /// Export transactions to the sheet, appending new rows.
  /// Returns the number of rows actually written (after duplicate filtering).
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

    // Get existing row hashes for duplicate detection
    final existingHashes = await getExistingRowHashes(spreadsheetId, sheetName);
    debugPrint('Found ${existingHashes.length} existing rows for dedup');

    // Convert transactions to sheet rows, filtering duplicates
    final newRows = <List<Object>>[];
    for (final tx in transactions) {
      final rows = SheetsRowMapper.transactionToSheetRows(tx, accountIdToName);
      for (final row in rows) {
        final hash = '${row[0]}|${row[1]}|${row[2]}|${row[6]}';
        if (!existingHashes.contains(hash)) {
          newRows.add(row);
        }
      }
    }

    if (newRows.isEmpty) {
      debugPrint('No new rows to export');
      return 0;
    }

    debugPrint('Appending ${newRows.length} new rows to sheet');

    final valueRange = sheets.ValueRange(
      values: newRows,
    );

    await sheetsApi.spreadsheets.values.append(
      valueRange,
      spreadsheetId,
      '$sheetName!A:G',
      valueInputOption: 'USER_ENTERED',
    );

    debugPrint('Export completed: ${newRows.length} rows written');
    return newRows.length;
  }

  /// Get hashes of existing rows for duplicate detection.
  Future<Set<String>> getExistingRowHashes(
    String spreadsheetId,
    String sheetName,
  ) async {
    try {
      final rows = await readRawRows(spreadsheetId, sheetName);
      final hashes = <String>{};
      for (final row in rows) {
        if (SheetsRowMapper.isDataRow(row) && !SheetsRowMapper.isMonthSummaryRow(row)) {
          hashes.add(SheetsRowMapper.rowHash(row));
        }
      }
      return hashes;
    } catch (e) {
      debugPrint('Error reading existing rows for dedup: $e');
      return {};
    }
  }
}
