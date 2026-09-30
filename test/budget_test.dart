import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/models/budget.dart' as model;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
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

void main() {
  setUpAll(_ensureSqlite);

  late AppDatabase db;
  late FinanceService service;

  Future<void> seed(String id, String category, double limit) =>
      db.into(db.budgets).insert(BudgetsCompanion.insert(
            id: id,
            userId: const Value('user-a'),
            category: category,
            limitAmount: limit,
            period: 'monthly',
            lastUpdated: Value(DateTime(2026, 1, 1)),
          ));

  setUp(() {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    service = FinanceService(db, 'user-a');
  });
  tearDown(() => db.close());

  // "Clear" used to save a limit of 0 and the row stayed: the overview card
  // counted it as a budget, and the web app could sync zero rows in too.
  test('a zero limit is not a budget', () async {
    await seed('b-food', 'Food', 200);
    await seed('b-zero', 'Fuel', 0);

    expect((await service.getBudgets()).map((b) => b.category), ['Food']);
    expect(
      (await service.watchBudgets().first).map((b) => b.category),
      ['Food'],
    );
  });

  test('clearing a budget deletes the row and stamps it for sync', () async {
    await seed('b-food', 'Food', 200);
    await service.deleteBudget('b-food');

    expect(await service.getBudgets(), isEmpty);
    final row = await db.select(db.budgets).getSingle();
    expect(row.isDeleted, isTrue);
    expect(row.lastUpdated!.isAfter(DateTime(2026, 1, 1)), isTrue,
        reason: 'lastUpdated is what makes the delete reach PocketBase');
  });

  test('setting a limit again after clearing makes a live budget', () async {
    await seed('b-food', 'Food', 200);
    await service.deleteBudget('b-food');

    await service.upsertBudget(
        model.Budget(id: '', userId: '', category: 'Food', limit: 150));

    final live = await service.getBudgets();
    expect(live.single.category, 'Food');
    expect(live.single.limit, 150);
  });
}
