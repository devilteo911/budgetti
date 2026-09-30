import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/finance_service.dart';
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

/// The Storico summary (hero, ENTRATA, SPESA, MOVIMENTI). With a filter that
/// matched nothing, `SUM()` over no rows is NULL: the unwrapped count threw,
/// the stream errored, and the StreamProvider kept the previous data, so the
/// summary showed the last non-empty numbers under an empty list.
void main() {
  setUpAll(_ensureSqlite);

  late AppDatabase db;
  late FinanceService service;

  Future<void> insert(String id, String account, double amount, String type) =>
      db.into(db.transactions).insert(TransactionsCompanion.insert(
            id: id,
            userId: const Value('user-a'),
            accountId: Value(account),
            amount: amount,
            description: id,
            category: 'x',
            type: Value(type),
            date: DateTime(2026, 8, 1),
          ));

  setUp(() {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    service = FinanceService(db, 'user-a');
  });
  tearDown(() => db.close());

  test('an empty ledger totals to zero, not an error', () async {
    expect(await service.watchTotals().first, (0.0, 0.0, 0));
  });

  test('deleting every row brings the totals back to zero', () async {
    await insert('in', 'a1', 100, 'income');
    await insert('out', 'a1', -30, 'expense');
    await insert('move', 'a1', 500, 'transfer');
    expect(await service.watchTotals().first, (100.0, 30.0, 2));

    await service.deleteTransactions(['in', 'out', 'move']);

    expect(await service.watchTotals().first, (0.0, 0.0, 0));
  });

  test('a wallet with no rows, or only deleted ones, totals to zero', () async {
    await insert('in', 'a1', 100, 'income');
    await insert('gone', 'a2', -20, 'expense');
    await service.deleteTransactions(['gone']);

    expect(await service.watchTotals(accountId: 'a1').first, (100.0, 0.0, 1));
    expect(await service.watchTotals(accountId: 'a2').first, (0.0, 0.0, 0));
    expect(await service.watchTotals(accountId: 'nobody').first, (0.0, 0.0, 0));
  });

  test('the hero provider follows the ledger down to zero', () async {
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      financeServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);
    container.listen(filteredTotalsProvider, (_, __) {});

    Future<AsyncValue<FilteredTotals>> until(
      bool Function(AsyncValue<FilteredTotals> v) ok,
    ) async {
      for (var i = 0; i < 300; i++) {
        final v = container.read(filteredTotalsProvider);
        if (ok(v)) return v;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      fail('never settled: ${container.read(filteredTotalsProvider)}');
    }

    await insert('out', 'a1', -30, 'expense');
    await until((v) => v.value?.count == 1);

    await service.deleteTransactions(['out']);

    final v = await until((v) => v.hasError || v.value?.count == 0);
    expect(v.hasError, isFalse, reason: 'an errored stream keeps old data');
    expect(v.value!.expense, 0);
    expect(v.value!.count, 0);
  });
}
