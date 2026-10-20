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

/// The data #38's "To receive" card and row badge consume: what the others owe
/// per shared expense, from the raw, unwindowed rows — the dinner is 14 months
/// old, outside the 12-month window of `transactionsProvider`.
void main() {
  setUpAll(_ensureSqlite);

  late AppDatabase db;
  late FinanceService service;
  late ProviderContainer container;

  final now = DateTime.now();
  DateTime ago(int months) => DateTime(now.year, now.month - months, 10);

  Future<void> insert(
    String id,
    double amount,
    String type,
    DateTime date, {
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
        date: date,
        othersShare: Value(othersShare),
        reimbursesId: Value(reimbursesId),
      ));

  /// Listens to [p] and waits for a value [ok] accepts (the pattern of
  /// watch_totals_test.dart: a stream provider is only fed while listened to).
  Future<T> until<T>(
    ProviderListenable<AsyncValue<T>> p,
    bool Function(T v) ok,
  ) async {
    container.listen(p, (_, __) {});
    for (var i = 0; i < 300; i++) {
      final v = container.read(p);
      if (v.hasValue && ok(v.requireValue)) return v.requireValue;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('never settled: ${container.read(p)}');
  }

  /// `dinner` owes 75 and got 50 back, `trip` owes 20 and got 30 (over-paid),
  /// `lunch` owes 10 and got 10 (settled).
  Future<void> seedFixture() async {
    await insert('dinner', -100, 'expense', ago(14), othersShare: 75);
    await insert('trip', -50, 'expense', ago(2), othersShare: 20);
    await insert('lunch', -20, 'expense', ago(1), othersShare: 10);
    await insert('back1', 30, 'income', ago(0), reimbursesId: 'dinner');
    await insert('back2', 20, 'income', ago(0), reimbursesId: 'dinner');
    await insert('back3', 30, 'income', ago(0), reimbursesId: 'trip');
    await insert('back4', 10, 'income', ago(0), reimbursesId: 'lunch');
    // Neither shared nor a reimbursement: not part of any of it.
    await insert('plain', -15, 'expense', ago(0));
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

  test('receivablesProvider holds every shared expense, over-paid ones too',
      () async {
    await seedFixture();

    final byId = await until(receivablesProvider, (m) => m.length == 3);

    expect(byId, {
      'dinner': (owed: 75.0, received: 50.0, outstanding: 25.0),
      'trip': (owed: 20.0, received: 30.0, outstanding: -10.0),
      'lunch': (owed: 10.0, received: 10.0, outstanding: 0.0),
    });
  });

  test('toReceiveProvider lists only what is still outstanding', () async {
    await seedFixture();

    final v = await until(toReceiveProvider, (v) => v.expenses.isNotEmpty);

    expect([for (final t in v.expenses) t.id], ['dinner']);
    expect(v.total, 25.0, reason: 'the over-paid trip never lowers it');
  });

  test('linking a reimbursement empties the list, with no invalidation',
      () async {
    await seedFixture();
    await insert('back5', 25, 'income', ago(0));
    await until(toReceiveProvider, (v) => v.total == 25.0);

    await service.linkReimbursement('back5', 'dinner');

    final v = await until(toReceiveProvider, (v) => v.expenses.isEmpty);
    expect(v.total, 0.0);
    final byId = await until(receivablesProvider, (m) => m.length == 3);
    expect(byId['dinner']!.outstanding, 0.0);
    expect(byId['dinner']!.received, 75.0);
  });

  test('toReceiveProvider is newest first and sums to the cent', () async {
    await insert('old', -10, 'expense', ago(3), othersShare: 0.1);
    await insert('new', -10, 'expense', ago(1), othersShare: 0.2);

    final v = await until(toReceiveProvider, (v) => v.expenses.length == 2);

    expect([for (final t in v.expenses) t.id], ['new', 'old']);
    expect(v.total, 0.3, reason: '0.1 + 0.2 in floats is 0.30000000000000004');
  });
}
