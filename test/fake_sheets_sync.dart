import 'package:budgetti/core/services/sheets_sync_service.dart';
import 'package:budgetti/models/transaction.dart';

/// The Sheets sync: counts its runs and, like the real one, hands the ledger
/// the rows the sheet added ([imports]) and the ids it deleted ([deletes]).
/// [onStart] runs as a sync starts, to look at what it finds; [fail] makes it
/// throw as an unreachable sheet does.
class FakeSheetsSync implements SheetsSyncService {
  FakeSheetsSync({this.onStart});

  final Future<void> Function()? onStart;
  int runs = 0;
  bool fail = false;
  var imports = <Transaction>[];
  var deletes = <String>[];

  @override
  bool get isSyncing => false;

  @override
  Future<SyncResult> sync({
    required List<Transaction> appTransactions,
    required Map<String, String> accountNameToId,
    required Map<String, String> accountIdToName,
    required Future<void> Function(List<String> ids) onDeleteFromApp,
    required Future<void> Function(List<Transaction> txs) onImportToApp,
  }) async {
    runs++;
    await onStart?.call();
    if (fail) throw StateError('sheet unreachable');
    await onImportToApp(imports);
    await onDeleteFromApp(deletes);
    return SyncResult(imported: imports.length, deletedFromApp: deletes.length);
  }
}
