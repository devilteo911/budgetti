import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
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

/// A 100 € expense with 75 owed by the others, and the 50 € that came back,
/// both this month: every provider that feeds an analytic must read the
/// owner's 25 € and no income, while the rows the dashboard lists stay raw.
void main() {
  setUpAll(_ensureSqlite);

  late AppDatabase db;
  late ProviderContainer container;

  Future<void> insert(
    String id,
    double amount,
    String type, {
    double othersShare = 0,
    String? reimbursesId,
  }) => db.into(db.transactions).insert(TransactionsCompanion.insert(
        id: id,
        userId: const Value('user-a'),
        accountId: const Value('a1'),
        amount: amount,
        description: id,
        category: 'Eating out',
        type: Value(type),
        date: DateTime.now(),
        othersShare: Value(othersShare),
        reimbursesId: Value(reimbursesId),
      ));

  /// Listens to [p] and waits for its first value (the pattern of
  /// watch_totals_test.dart: a stream provider is only fed while listened to).
  Future<T> settled<T>(ProviderListenable<AsyncValue<T>> p) async {
    container.listen(p, (_, __) {});
    for (var i = 0; i < 300; i++) {
      final v = container.read(p);
      if (v.hasValue) return v.requireValue;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('never settled: ${container.read(p)}');
  }

  setUp(() async {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      financeServiceProvider.overrideWithValue(FinanceService(db, 'user-a')),
    ]);
    await insert('dinner', -100, 'expense', othersShare: 75);
    await insert('back', 50, 'income', reimbursesId: 'dinner');
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('the budget spend of the category is the own 25', () async {
    expect(await settled(budgetStatsProvider), {'Eating out': 25.0});
  });

  test('the summary sparkline nets the own share, not the reimbursement',
      () async {
    await settled(transactionsProvider(null));

    expect(container.read(monthlyNetFlowHistoryProvider).last, -25.0);
  });

  test('the dashboard totals are own, its recent rows raw', () async {
    await settled(accountsProvider);

    final stats = await settled(dashboardStatsProvider);
    expect(stats.monthlyExpenses, 25.0);
    expect(stats.monthlyIncome, 0.0);
    expect(stats.netFlow, -25.0);
    expect(
      [for (final t in stats.recentTransactions) t.amount],
      unorderedEquals([-100.0, 50.0]),
    );
  });

  test('the stats and the chart count the own share', () async {
    final period = container.read(selectedStatsPeriodProvider);

    final stats = await settled(statsDataProvider(period));
    expect(stats.categoryTotals, {'Eating out': 25.0});
    expect(stats.totalExpenses, 25.0);

    final series = await settled(chartsDataProvider);
    expect([for (final p in series.expenses) p.amount], [25.0]);
    expect(series.income, isEmpty, reason: 'a reimbursement is not income');
  });
}
