import 'dart:convert';

import 'package:budgetti/core/services/google_auth_service.dart';
import 'package:budgetti/core/services/google_sheets_service.dart';
import 'package:budgetti/core/services/persistence_service.dart';
import 'package:budgetti/core/services/sheets_row_mapper.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;

class SyncResult {
  final int imported;
  final int exported;
  final int deletedFromSheet;
  final int deletedFromApp;

  SyncResult({
    this.imported = 0,
    this.exported = 0,
    this.deletedFromSheet = 0,
    this.deletedFromApp = 0,
  });

  bool get hasChanges => imported + exported + deletedFromSheet + deletedFromApp > 0;

  @override
  String toString() {
    final parts = <String>[];
    if (imported > 0) parts.add('+$imported imported');
    if (exported > 0) parts.add('+$exported exported');
    if (deletedFromSheet > 0) parts.add('-$deletedFromSheet from sheet');
    if (deletedFromApp > 0) parts.add('-$deletedFromApp from app');
    return parts.isEmpty ? 'Already in sync' : parts.join(', ');
  }
}

/// Bidirectional 3-way sync between app and Google Sheets.
///
/// Uses a "last known hashes" set to distinguish new entries from deletions:
/// - In sheet, no hash in col M → new manual entry → import
/// - In sheet + last sync, not in app → deleted in app → remove from sheet
/// - In app + last sync, not in sheet → deleted in sheet → remove from app
/// - In app, not in sheet, not in last sync → new app entry → export
class SheetsSyncService {
  final GoogleSheetsService _sheetsService;
  final GoogleAuthService _authService;
  final PersistenceService _persistence;

  // Prevent concurrent syncs
  bool _isSyncing = false;

  SheetsSyncService(this._sheetsService, this._authService, this._persistence);

  bool get isSyncing => _isSyncing;

  /// Perform a full bidirectional sync.
  ///
  /// [appTransactions] - all current transactions from the app
  /// [accountNameToId] - map account names to IDs (for import)
  /// [accountIdToName] - map account IDs to names (for export)
  /// [onDeleteFromApp] - callback to delete transactions from app by ID
  /// [onImportToApp] - callback to add transactions to app
  Future<SyncResult> sync({
    required List<Transaction> appTransactions,
    required Map<String, String> accountNameToId,
    required Map<String, String> accountIdToName,
    required Future<void> Function(List<String> ids) onDeleteFromApp,
    required Future<void> Function(List<Transaction> txs) onImportToApp,
  }) async {
    if (_isSyncing) return SyncResult();
    if (_authService.currentUser == null) return SyncResult();

    _isSyncing = true;
    try {
      final spreadsheetId = _persistence.getSheetsSpreadsheetId();
      final sheetName = _persistence.getSheetsSheetName();
      final lastSyncHashes = _loadLastSyncHashes();

      // 1. Read sheet rows
      List<List<Object?>> sheetRows;
      try {
        sheetRows = await _sheetsService.readRawRows(spreadsheetId, sheetName);
      } catch (e) {
        debugPrint('Sync: failed to read sheet: $e');
        return SyncResult();
      }

      // 2. Build hash sets
      // App hashes: hash → transaction
      final appHashMap = <String, Transaction>{};
      for (final tx in appTransactions) {
        appHashMap[SheetsRowMapper.transactionHash(tx)] = tx;
      }
      // For transfers, each transfer produces 2 rows with 2 different hashes
      // We need to also track the "row-level" hashes for transfers
      final appRowHashes = <String>{};
      for (final tx in appTransactions) {
        final rows = SheetsRowMapper.transactionToSheetRows(tx, accountIdToName);
        for (final row in rows) {
          appRowHashes.add(row.last.toString());
        }
      }

      // Sheet hashes from column M (existing tracked rows)
      // Also collect rows without hash (manual entries without formula)
      final sheetHashes = <String>{};
      final sheetRowsByHash = <String, int>{}; // hash → row number (0-indexed from row 2)
      final newFromSheetRows = <List<Object?>>[];  // rows with hash but not in app or lastSync

      for (var i = 0; i < sheetRows.length; i++) {
        final row = sheetRows[i];
        if (!SheetsRowMapper.isDataRow(row) || SheetsRowMapper.isMonthSummaryRow(row)) {
          continue;
        }

        final hash = SheetsRowMapper.extractRowHash(row);
        if (hash != null && hash.isNotEmpty) {
          sheetHashes.add(hash);
          sheetRowsByHash[hash] = i;
        } else {
          // No hash at all → manual entry without formula
          newFromSheetRows.add(row);
        }
      }

      int imported = 0;
      int exported = 0;
      int deletedFromSheet = 0;
      int deletedFromApp = 0;

      // 3. Detect new entries from sheet:
      //    - Rows without hash (no formula) → manual entry
      //    - Rows with hash but NOT in app AND NOT in lastSync → new from sheet (has formula)
      final year = DateTime.now().year;
      final newTxs = <Transaction>[];

      // 3a. Rows without hash
      for (final row in newFromSheetRows) {
        final tx = SheetsRowMapper.sheetRowToTransaction(row, accountNameToId, year);
        if (tx != null) newTxs.add(tx);
      }

      // 3b. Rows with hash but unknown to app (new manual entry with sheet formula)
      for (final hash in sheetHashes) {
        if (!appRowHashes.contains(hash) && !lastSyncHashes.contains(hash)) {
          final rowIdx = sheetRowsByHash[hash];
          if (rowIdx != null && rowIdx < sheetRows.length) {
            final tx = SheetsRowMapper.sheetRowToTransaction(
              sheetRows[rowIdx], accountNameToId, year,
            );
            if (tx != null) newTxs.add(tx);
          }
        }
      }

      if (newTxs.isNotEmpty) {
        await onImportToApp(newTxs);
        imported = newTxs.length;
      }

      // 4. Detect deletions from app (hash in sheet + lastSync but not in app)
      final rowsToDeleteFromSheet = <int>[]; // sheet row indices to delete
      for (final hash in sheetHashes) {
        if (lastSyncHashes.contains(hash) && !appRowHashes.contains(hash)) {
          final rowIdx = sheetRowsByHash[hash];
          if (rowIdx != null) {
            rowsToDeleteFromSheet.add(rowIdx);
          }
        }
      }

      // 5. Detect deletions from sheet (hash in app + lastSync but not in sheet)
      final idsToDeleteFromApp = <String>[];
      for (final tx in appTransactions) {
        final hash = SheetsRowMapper.transactionHash(tx);
        if (lastSyncHashes.contains(hash) && !sheetHashes.contains(hash)) {
          idsToDeleteFromApp.add(tx.id);
        }
      }

      if (idsToDeleteFromApp.isNotEmpty) {
        await onDeleteFromApp(idsToDeleteFromApp);
        deletedFromApp = idsToDeleteFromApp.length;
      }

      // 6. Export new app entries (in app, not in sheet, not in lastSync)
      final newExportRows = <List<Object>>[];
      for (final tx in appTransactions) {
        if (idsToDeleteFromApp.contains(tx.id)) continue;
        final rows = SheetsRowMapper.transactionToSheetRows(tx, accountIdToName);
        for (final row in rows) {
          final hash = row.last.toString();
          if (!sheetHashes.contains(hash) && !lastSyncHashes.contains(hash)) {
            newExportRows.add(row);
          }
        }
      }

      // 7. Execute sheet mutations
      final sheetsApi = await _getSheetsApi();
      if (sheetsApi != null) {
        // Delete rows from sheet (in reverse order to preserve indices)
        if (rowsToDeleteFromSheet.isNotEmpty) {
          rowsToDeleteFromSheet.sort((a, b) => b.compareTo(a)); // reverse
          await _deleteSheetRows(sheetsApi, spreadsheetId, sheetName, rowsToDeleteFromSheet);
          deletedFromSheet = rowsToDeleteFromSheet.length;
        }

        // Write new exports + write hashes for imported entries
        if (newExportRows.isNotEmpty || newTxs.isNotEmpty) {
          // Rewrite ALL data: ensures everything is sorted and has hashes
          await _fullRewrite(sheetsApi, spreadsheetId, sheetName, appTransactions,
              accountIdToName, idsToDeleteFromApp);
          exported = newExportRows.length;
        }
      }

      // 8. Save current state as last sync hashes
      final newSyncHashes = <String>{};
      for (final tx in appTransactions) {
        if (idsToDeleteFromApp.contains(tx.id)) continue;
        final rows = SheetsRowMapper.transactionToSheetRows(tx, accountIdToName);
        for (final row in rows) {
          newSyncHashes.add(row.last.toString());
        }
      }
      // Also include imported manual entries
      // (they are now in app, will get hashed on next sync)
      _saveLastSyncHashes(newSyncHashes);

      await _persistence.setSheetsLastSyncTimestamp(
        DateTime.now().millisecondsSinceEpoch,
      );

      final result = SyncResult(
        imported: imported,
        exported: exported,
        deletedFromSheet: deletedFromSheet,
        deletedFromApp: deletedFromApp,
      );
      debugPrint('Sync completed: $result');
      return result;
    } finally {
      _isSyncing = false;
    }
  }

  /// Full rewrite: clear data rows and write all app transactions sorted ASC.
  Future<void> _fullRewrite(
    sheets.SheetsApi sheetsApi,
    String spreadsheetId,
    String sheetName,
    List<Transaction> appTransactions,
    Map<String, String> accountIdToName,
    List<String> excludeIds,
  ) async {
    // Sort ASC by date
    final sorted = appTransactions
        .where((tx) => !excludeIds.contains(tx.id))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final allRows = <List<Object>>[];
    for (final tx in sorted) {
      allRows.addAll(SheetsRowMapper.transactionToSheetRows(tx, accountIdToName));
    }

    if (allRows.isEmpty) return;

    // Clear existing data rows (A2:M onwards)
    await sheetsApi.spreadsheets.values.clear(
      sheets.ClearValuesRequest(),
      spreadsheetId,
      '$sheetName!A2:M',
    );

    // Write all rows starting at A2
    final range = '$sheetName!A2:M${allRows.length + 1}';
    await sheetsApi.spreadsheets.values.update(
      sheets.ValueRange(values: allRows),
      spreadsheetId,
      range,
      valueInputOption: 'USER_ENTERED',
    );

    debugPrint('Full rewrite: ${allRows.length} rows written');
  }

  /// Delete specific rows from the sheet by their 0-based data index.
  Future<void> _deleteSheetRows(
    sheets.SheetsApi sheetsApi,
    String spreadsheetId,
    String sheetName,
    List<int> rowIndices,
  ) async {
    // Get sheetId for the named sheet
    final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
    final sheet = spreadsheet.sheets?.firstWhere(
      (s) => s.properties?.title == sheetName,
      orElse: () => throw Exception('Sheet "$sheetName" not found'),
    );
    final sheetId = sheet?.properties?.sheetId ?? 0;

    // Build delete requests (indices are 0-based from row 2, so actual row = index + 1)
    // Must be sorted in reverse to preserve indices
    final requests = rowIndices.map((idx) {
      final actualRow = idx + 1; // +1 because header is row 0
      return sheets.Request(
        deleteDimension: sheets.DeleteDimensionRequest(
          range: sheets.DimensionRange(
            sheetId: sheetId,
            dimension: 'ROWS',
            startIndex: actualRow,
            endIndex: actualRow + 1,
          ),
        ),
      );
    }).toList();

    if (requests.isNotEmpty) {
      await sheetsApi.spreadsheets.batchUpdate(
        sheets.BatchUpdateSpreadsheetRequest(requests: requests),
        spreadsheetId,
      );
    }
  }

  Future<sheets.SheetsApi?> _getSheetsApi() async {
    final httpClient = await _authService.authenticatedClient();
    if (httpClient == null) return null;
    return sheets.SheetsApi(httpClient);
  }

  Set<String> _loadLastSyncHashes() {
    final json = _persistence.getLastSyncHashesJson();
    if (json == null) return {};
    try {
      return Set<String>.from(jsonDecode(json) as List);
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveLastSyncHashes(Set<String> hashes) async {
    await _persistence.setLastSyncHashesJson(jsonEncode(hashes.toList()));
  }
}
