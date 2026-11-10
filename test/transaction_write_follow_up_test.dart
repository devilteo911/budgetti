import 'dart:async';
import 'dart:ffi';

import 'package:budgetti/core/database/database.dart' show AppDatabase;
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/core/services/notification_logic.dart';
import 'package:budgetti/core/services/notification_service.dart';
import 'package:budgetti/core/services/persistence_service.dart';
import 'package:budgetti/models/budget.dart';
import 'package:budgetti/models/transaction.dart' as model;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart' as sqlite3open;

import 'fake_sheets_sync.dart';

// See finance_service_seed_test.dart for why the FFI loader is overridden.
void _ensureSqlite() {
  try {
    sqlite3open.open.overrideFor(
      sqlite3open.OperatingSystem.linux,
      () => DynamicLibrary.open('/lib/x86_64-linux-gnu/libsqlite3.so.0'),
    );
  } catch (_) {
    // Already overridden or not on Linux — ignore.
  }
}

/// The notifier: records the budget alerts shown; [fail] makes it throw as the
/// plugin does when the OS refuses.
class _Notifier extends NotificationService {
  final alerts = <String>[];
  bool fail = false;

  @override
  Future<void> showBudgetAlert({
    required int id,
    required String category,
    required double percentage,
  }) async {
    if (fail) throw StateError('notifications refused');
    alerts.add(category);
  }
}

/// What follows a transaction write: the budget check of its category and one
/// Google Sheets sync, asserted through the write itself.
void main() {
  setUpAll(_ensureSqlite);

  late AppDatabase db;
  late _Notifier notifier;
  late FakeSheetsSync sheets;
  late FinanceService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    notifier = _Notifier();
    sheets = FakeSheetsSync();
    final logic = NotificationLogic(
      notifier,
      FinanceService(db, 'user-a'),
      PersistenceService(await SharedPreferences.getInstance()),
    );
    service = FinanceService(
      db,
      'user-a',
      checkBudget: logic.checkBudgetAlerts,
      sheets: sheets,
    );
    // Any Dining spend this month is over the limit.
    await service.upsertBudget(
        Budget(id: 'b1', userId: 'user-a', category: 'Dining', limit: 10));
  });
  tearDown(() => db.close());

  model.Transaction tx({
    String id = 't1',
    String type = 'expense',
    double amount = -50,
    String category = 'Dining',
    String? toAccountId,
  }) =>
      model.Transaction(
        id: id,
        accountId: 'a1',
        toAccountId: toAccountId,
        amount: amount,
        date: DateTime.now(),
        description: 'Amazon',
        category: category,
        type: type,
      );

  /// The follow-up is started, not awaited, by the write: let it finish.
  Future<void> settle() => service.followUpsDone;

  Future<List<String>> ledger() async =>
      [for (final t in await service.getTransactions()) t.id];

  test('adding an expense checks its budget and starts one Sheets sync',
      () async {
    await service.addTransaction(tx());
    await settle();

    expect(notifier.alerts, ['Dining']);
    expect(sheets.runs, 1);
  });

  test('updating an expense checks its budget and starts one Sheets sync',
      () async {
    await service.addTransaction(tx(amount: -5), followUp: false);

    await service.updateTransaction(tx(amount: -50));
    await settle();

    expect(notifier.alerts, ['Dining']);
    expect(sheets.runs, 1);
  });

  test('a transfer starts the Sheets sync and checks no budget', () async {
    // A budget on the category every transfer carries: still not a spend.
    await service.upsertBudget(
        Budget(id: 'b2', userId: 'user-a', category: 'Transfer', limit: 10));

    await service.addTransaction(tx(
        type: 'transfer', amount: 50, category: 'Transfer', toAccountId: 'a2'));
    await settle();

    expect(notifier.alerts, isEmpty);
    expect(sheets.runs, 1);
  });

  test('a bulk delete starts one Sheets sync and raises no budget alert',
      () async {
    await service.addTransaction(tx(id: 't1'), followUp: false);
    await service.addTransaction(tx(id: 't2'), followUp: false);
    await service.addTransaction(tx(id: 't3'), followUp: false);

    await service.deleteTransactions(['t1', 't2']);
    await settle();

    expect(await ledger(), ['t3']);
    expect(notifier.alerts, isEmpty);
    expect(sheets.runs, 1);
  });

  test('a delete of nothing starts no Sheets sync', () async {
    await service.deleteTransactions([]);
    await settle();

    expect(sheets.runs, 0);
  });

  group('a batch of adds', () {
    // Counts the checks themselves: an alert is raised once per category and
    // month whatever the number of checks, so the alerts cannot tell K from N.
    late List<String> checked;
    late FinanceService batch;

    setUp(() {
      checked = [];
      batch = FinanceService(
        db,
        'user-a',
        checkBudget: (t) async => checked.add(t.category),
        sheets: sheets,
      );
    });

    test('checks each category once and starts one Sheets sync', () async {
      await batch.addTransactions([
        tx(id: 't1', category: 'Dining'),
        tx(id: 't2', category: 'Groceries'),
        tx(id: 't3', category: 'Dining'),
        tx(id: 't4', category: 'Dining'),
        tx(id: 't5', type: 'income', amount: 900, category: 'Salary'),
      ]);
      await batch.followUpsDone;

      expect(await ledger(), unorderedEquals(['t1', 't2', 't3', 't4', 't5']));
      expect(checked, unorderedEquals(['Dining', 'Groceries', 'Salary']));
      expect(sheets.runs, 1);
    });

    test('checks no budget for its transfers', () async {
      await batch.addTransactions([
        tx(id: 't1', category: 'Dining'),
        tx(
            id: 't2',
            type: 'transfer',
            amount: 50,
            category: 'Transfer',
            toAccountId: 'a2'),
      ]);
      await batch.followUpsDone;

      expect(checked, ['Dining']);
      expect(sheets.runs, 1);
    });

    test('with a row that is refused writes nothing and runs no follow-up',
        () async {
      // The same id twice: the second insert is refused.
      await expectLater(
        batch.addTransactions([tx(id: 't1'), tx(id: 't1')]),
        throwsA(anything),
      );
      await batch.followUpsDone;

      expect(await ledger(), isEmpty);
      expect(checked, isEmpty);
      expect(sheets.runs, 0);
    });

    test('of nothing runs no follow-up', () async {
      await batch.addTransactions([]);
      await batch.followUpsDone;

      expect(sheets.runs, 0);
    });

    test('over a budget raises its alert', () async {
      await service.addTransactions([tx(id: 't1'), tx(id: 't2')]);
      await settle();

      expect(notifier.alerts, ['Dining']);
    });
  });

  // The screen that saved must not wait on two ledger reads, the notification
  // plugin and the network.
  test('a write returns once the row is saved, before its follow-up ends',
      () async {
    final check = Completer<void>();
    final slow = FinanceService(
      db,
      'user-a',
      checkBudget: (_) => check.future,
      sheets: sheets,
    );

    await slow.addTransaction(tx()).timeout(const Duration(seconds: 5));

    expect(await ledger(), ['t1']);
    expect(sheets.runs, 0, reason: 'the sync comes after the budget check');

    check.complete();
    await slow.followUpsDone;
    expect(sheets.runs, 1);
  });

  test('a write that fails runs no follow-up', () async {
    await service.addTransaction(tx(), followUp: false);

    // The same id again: the insert is refused.
    await expectLater(service.addTransaction(tx()), throwsA(anything));
    await settle();

    expect(notifier.alerts, isEmpty);
    expect(sheets.runs, 0);
  });

  test('an alert and a Sheets sync that throw leave the row saved', () async {
    notifier.fail = true;
    sheets.fail = true;

    await service.addTransaction(tx());
    await settle();

    expect(sheets.runs, 1);
    expect(await ledger(), ['t1']);
  });

  test('what the Sheets sync imports and deletes starts no further sync',
      () async {
    await service.addTransaction(tx(id: 'gone', amount: -1), followUp: false);
    sheets.imports = [tx(id: 'from-sheet')];
    sheets.deletes = ['gone'];

    await service.addTransaction(tx(id: 'mine', category: 'Groceries'));
    await settle();

    expect(await ledger(), unorderedEquals(['mine', 'from-sheet']));
    expect(sheets.runs, 1);
    expect(notifier.alerts, isEmpty);
  });

  test('the Sheets sync runs on its own, with no write and no widget',
      () async {
    sheets.imports = [tx(id: 'from-sheet')];

    final result = await service.syncSheets();

    expect(result.imported, 1);
    expect(await ledger(), ['from-sheet']);
    expect(sheets.runs, 1);
  });

  test('a transfer to its own wallet is refused by the write', () async {
    final toItself = tx(
        type: 'transfer', amount: 50, category: 'Transfer', toAccountId: 'a1');

    await expectLater(service.addTransaction(toItself), throwsArgumentError);
    await service.addTransaction(tx(), followUp: false);
    await expectLater(
        service.updateTransaction(toItself), throwsArgumentError);
    await settle();

    final rows = await service.getTransactions();
    expect([for (final t in rows) t.type], ['expense']);
    expect(sheets.runs, 0);
  });

  // The budget check reads the ledger through the write's own service: wired
  // through each other's providers the two would be a cycle, and the check
  // would fail on every save.
  test('the write the app hands to its screens carries the follow-up',
      () async {
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider
          .overrideWithValue(await SharedPreferences.getInstance()),
      databaseProvider.overrideWithValue(db),
      currentUserIdProvider.overrideWithValue('user-a'),
      notificationServiceProvider.overrideWithValue(notifier),
      sheetsSyncServiceProvider.overrideWithValue(sheets),
    ]);
    addTearDown(container.dispose);

    final wired = container.read(financeServiceProvider);
    await wired.addTransaction(tx());
    await wired.followUpsDone;

    expect(notifier.alerts, ['Dining']);
    expect(sheets.runs, 1);
  });
}
