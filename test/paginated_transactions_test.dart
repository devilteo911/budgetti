import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/models/transaction.dart' as model;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart' as sqlite3open;

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

/// The history screen shows a snapshot of a query. Before, only callers that
/// remembered `ref.invalidate(paginatedTransactionsProvider)` refreshed it, so
/// a QIF import, a sync pull or a bank-capture write left it stale.
void main() {
  setUpAll(_ensureSqlite);

  late AppDatabase db;
  late FinanceService service;
  late ProviderContainer container;

  TransactionsCompanion row(String id, DateTime date, {String desc = 'x'}) =>
      TransactionsCompanion.insert(
        id: id,
        userId: const Value('user-a'),
        accountId: const Value('a1'),
        amount: -1,
        description: desc,
        category: 'Food',
        date: date,
      );

  PaginatedTransactionsState read() =>
      container.read(paginatedTransactionsProvider);

  /// Poll until [until] holds and nothing is in flight; the notifier refetches
  /// on a short debounce, so there is no single future to await.
  Future<PaginatedTransactionsState> settled(
    bool Function(PaginatedTransactionsState s) until,
  ) async {
    for (var i = 0; i < 300; i++) {
      final s = read();
      if (!s.isLoading && until(s)) return s;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('list never settled: ${read().transactions.length} rows loaded');
  }

  setUp(() {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    service = FinanceService(db, 'user-a');
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      financeServiceProvider.overrideWithValue(service),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('a row written after the first load shows up with no invalidate',
      () async {
    await settled((s) => s.transactions.isEmpty);

    await db.into(db.transactions).insert(row('t1', DateTime(2026, 8, 1)));

    final s = await settled((s) => s.transactions.length == 1);
    expect(s.transactions.single.id, 't1');
  });

  test('an edit and a delete reach the list too', () async {
    await db
        .into(db.transactions)
        .insert(row('t1', DateTime(2026, 8, 1), desc: 'before'));
    await settled((s) => s.transactions.length == 1);

    await service.updateTransaction(model.Transaction(
      id: 't1',
      accountId: 'a1',
      amount: -1,
      date: DateTime(2026, 8, 1),
      description: 'after',
      category: 'Food',
    ));
    await settled((s) => s.transactions.single.description == 'after');

    await service.deleteTransactions(['t1']);
    await settled((s) => s.transactions.isEmpty);
  });

  test('a write from another isolate is heard once tables are re-marked',
      () async {
    await settled((s) => s.transactions.isEmpty);

    // The workmanager isolate writes SQLite without notifying this isolate's
    // streams; main() re-marks every table on resume. A raw statement is the
    // same thing seen from here: the row lands, no notification fires.
    await db.customStatement(
      'INSERT INTO transactions (id, user_id, account_id, amount, description, '
      "category, type, date, is_deleted, last_updated) VALUES ('bg', 'user-a', "
      "'a1', -1, 'captured', 'Food', 'expense', 1788000000, 0, 1788000000)",
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(read().transactions, isEmpty);

    db.markTablesUpdated(db.allTables);

    await settled((s) => s.transactions.length == 1);
  });

  test('a write while scrolled keeps every loaded page and hasMore right',
      () async {
    await db.batch((b) => b.insertAll(db.transactions, [
          for (var i = 0; i < 250; i++)
            row('t$i', DateTime(2026, 1, 1).add(Duration(hours: i))),
        ]));
    await settled((s) => s.transactions.length == 100 && s.hasMore);
    final notifier = container.read(paginatedTransactionsProvider.notifier);
    await notifier.loadMore();
    await notifier.loadMore();
    expect(read().transactions.length, 250);
    expect(read().hasMore, isFalse);

    await db.into(db.transactions).insert(row('newest', DateTime(2026, 12, 1)));

    // Refetches the 250 already on screen, not just page one — and knows one
    // more row is waiting.
    final s = await settled((s) => s.transactions.first.id == 'newest');
    expect(s.transactions.length, 250);
    expect(s.hasMore, isTrue);

    await notifier.loadMore();
    expect(read().transactions.length, 251);
    expect(read().hasMore, isFalse);
  });
}
