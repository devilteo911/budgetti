import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/models/transaction.dart' as model;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart' as sqlite3open;

// `flutter test` runs in the VM without sqlite3_flutter_libs' bundled native,
// so point the FFI loader at the system library (.so.0 — no -dev symlink here).
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

  test('seeds defaults into an empty database', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    await FinanceService(db, 'user-a').getAccounts();

    expect(await db.select(db.categories).get(), isNotEmpty);
    expect(await db.select(db.tags).get(), isNotEmpty);
    expect(await db.select(db.accounts).get(), hasLength(1));
  });

  // The tag-pagination bug: the filter ran in memory *after* SQL LIMIT/OFFSET,
  // so a tag-filtered page came back short, hasMore flipped false, and rows
  // past the first page went missing. The filter must run in SQL.
  test('tag filter pages through every matching row', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final service = FinanceService(db, 'user-a');
    await service.getAccounts(); // seeds the default account

    final base = DateTime(2026, 1, 1);
    for (var i = 0; i < 250; i++) {
      await service.addTransaction(model.Transaction(
        id: 't$i',
        accountId: 'user-a_main',
        amount: -10,
        date: base.add(Duration(days: i)),
        description: 'tx $i',
        category: 'Bills',
        tags: i.isEven ? ['Gift'] : ['Other'],
      ));
    }

    final page1 =
        await service.getTransactions(tags: const ['Gift'], limit: 100);
    final page2 = await service.getTransactions(
        tags: const ['Gift'], limit: 100, offset: page1.length);

    expect(page1, hasLength(100)); // a short first page used to end paging
    expect(page2, hasLength(25)); // 125 tagged rows in total
    expect(page1.every((t) => t.tags.contains('Gift')), isTrue);
  });

  test('tag filter matches whole elements, not substrings', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final service = FinanceService(db, 'user-a');
    await service.getAccounts();

    Future<void> add(String id, List<String> tags, int day) =>
        service.addTransaction(model.Transaction(
          id: id,
          accountId: 'user-a_main',
          amount: -10,
          date: DateTime(2026, 1, day),
          description: id,
          category: 'Bills',
          tags: tags,
        ));

    await add('t0', ['Gift'], 1);
    await add('t1', ['Gifts'], 2);

    final matches =
        await service.getTransactions(tags: const ['Gift'], limit: 10);
    expect(matches, hasLength(1));
    expect(matches.single.id, 't0');
  });

  // The duplicate-defaults bug: rows existed, but under a different (or absent)
  // userId, so a per-user emptiness check seeded a second copy of every default.
  test('does not re-seed when data exists under another userId', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    await FinanceService(db, 'user-a').getAccounts();
    final before = (await db.select(db.categories).get()).length;

    await FinanceService(db, 'user-b').getAccounts();

    expect(await db.select(db.categories).get(), hasLength(before));
    expect(await db.select(db.accounts).get(), hasLength(1));
  });

  test('does not re-seed from a userId-less legacy row', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    // What the old AppDatabase seeder wrote: no userId, timestamp-based id.
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: '1751000000Bills',
          name: 'Bills',
          iconCode: 59469,
          colorHex: 0xFF607D8B,
          type: 'expense',
        ));

    await FinanceService(db, 'user-a').getAccounts();

    expect(await db.select(db.categories).get(), hasLength(1));
    expect(await db.select(db.accounts).get(), isEmpty);
  });

  _migrationTests();

  test('does not resurrect deliberately deleted defaults', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    await FinanceService(db, 'user-a').getAccounts();
    await db.update(db.categories).write(
          const CategoriesCompanion(isDeleted: Value(true)),
        );
    final deleted = (await db.select(db.categories).get()).length;

    await FinanceService(db, 'user-a').getAccounts();

    expect(await db.select(db.categories).get(), hasLength(deleted));
  });
}

// --- v12 migration: de-duplicate what the two seeders left behind ----------

Future<void> _insertTag(AppDatabase db, String id, String name) =>
    db.into(db.tags).insert(
        TagsCompanion.insert(id: id, name: name, colorHex: 0xFF00FF00));

Future<void> _insertCat(AppDatabase db, String id, String name, String type) =>
    db.into(db.categories).insert(CategoriesCompanion.insert(
        id: id, name: name, iconCode: 1, colorHex: 2, type: type));

void _migrationTests() {
  test('dedupe keeps the oldest copy and soft-deletes newer ones', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    await _insertTag(db, '1751000000Work', 'Work');   // old seeder, inserted 1st
    await _insertTag(db, 'user-a_tag_Work', 'Work');  // FinanceService, newer
    await _insertTag(db, 'sciclub-uuid', 'Sciclub');

    await db.dedupeForTest();

    final live = await (db.select(db.tags)
          ..where((t) => t.isDeleted.equals(false)))
        .get();
    expect(live.map((t) => t.id),
        containsAll(['1751000000Work', 'sciclub-uuid']));
    expect(live.map((t) => t.id), isNot(contains('user-a_tag_Work')));
    // Soft, not hard: the row must survive for the sync layer to propagate it.
    expect(await db.select(db.tags).get(), hasLength(3));
  });

  test('dedupe keeps same-named categories of different types', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    await _insertCat(db, 'a', 'Gift', 'expense');
    await _insertCat(db, 'b', 'Gift', 'income');
    await _insertCat(db, 'c', 'Gift', 'expense'); // the only real duplicate

    await db.dedupeForTest();

    final live = await (db.select(db.categories)
          ..where((t) => t.isDeleted.equals(false)))
        .get();
    expect(live.map((c) => c.id), unorderedEquals(['a', 'b']));
  });

  test('dedupe does not revive or re-delete on a second run', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    await _insertTag(db, 'old', 'Work');
    await _insertTag(db, 'new', 'Work');

    await db.dedupeForTest();
    await db.dedupeForTest();

    final live = await (db.select(db.tags)
          ..where((t) => t.isDeleted.equals(false)))
        .get();
    expect(live.map((t) => t.id), ['old']);
  });

  // The SQL totals aggregate replaced an in-memory re-filter of the whole
  // ledger — it must classify exactly like the model does: income/expense =
  // non-transfer by sign, transfers and their exclusion counted the same way.
  test('watchTotals matches the in-memory filter over the same rows', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final service = FinanceService(db, 'user-a');
    await service.getAccounts(); // seeds the default account

    final base = DateTime(2026, 3, 1);
    final rows = [
      (id: 't1', amount: 100.0, type: 'income', date: base, category: 'Salary', tags: <String>[]),
      (id: 't2', amount: -40.0, type: 'expense', date: base.add(const Duration(days: 1)), category: 'Food', tags: <String>['Groceries']),
      (id: 't3', amount: -60.0, type: 'expense', date: base.add(const Duration(days: 2)), category: 'Food', tags: <String>[]),
      (id: 't4', amount: 50.0, type: 'transfer', date: base.add(const Duration(days: 3)), category: '', tags: <String>[]),
      (id: 't5', amount: -10.0, type: 'expense', date: DateTime(2025, 1, 1), category: 'Food', tags: <String>[]), // outside range
      (id: 't6', amount: -20.0, type: 'expense', date: base.add(const Duration(days: 4)), category: 'Bills', tags: <String>['Groceries']),
    ];
    for (final r in rows) {
      await service.addTransaction(model.Transaction(
        id: r.id,
        accountId: 'user-a_main',
        amount: r.amount,
        date: r.date,
        description: r.id,
        category: r.category,
        type: r.type,
        tags: r.tags,
      ));
    }

    Future<(double, double, int)> totals() async {
      final list = await service
          .watchTotals(
            startDate: DateTime(2026, 1, 1),
            endDate: DateTime(2026, 12, 31, 23, 59, 59, 999),
            categories: ['Food', 'Bills'],
            tags: ['Groceries'],
          )
          .first;
      return list;
    }

    final (income, expense, count) = await totals();
    // Only t2 and t6 match (in-range, category, tag); the transfer never counts.
    expect(income, 0.0);
    expect(expense, 60.0);
    expect(count, 2);

    // Unfiltered totals: t1+t2+t3+t6 count, t5 is out of range, transfer t4
    // excluded from income/expense but… transfers are skipped entirely by the
    // old in-memory loop, so count must skip them too.
    final (allIncome, allExpense, allCount) =
        await service.watchTotals(startDate: DateTime(2026, 1, 1)).first;
    expect(allIncome, 100.0);
    expect(allExpense, 120.0);
    expect(allCount, 4);
  });

  test('watchInstallmentRelevant returns linked rows and unlinked expenses',
      () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final service = FinanceService(db, 'user-a');
    await service.getAccounts();

    final base = DateTime(2026, 3, 1);
    await service.addTransaction(model.Transaction(
      id: 'linked',
      accountId: 'user-a_main',
      amount: -100,
      date: base,
      description: 'rate',
      category: 'Shopping',
      installmentId: 'plan1',
    ));
    await service.addTransaction(model.Transaction(
      id: 'unlinked-expense',
      accountId: 'user-a_main',
      amount: -10,
      date: base,
      description: 'coffee',
      category: 'Food',
    ));
    await service.addTransaction(model.Transaction(
      id: 'income',
      accountId: 'user-a_main',
      amount: 50,
      date: base,
      description: 'salary',
      category: 'Salary',
      type: 'income',
    ));

    final rows = await service.watchInstallmentRelevant().first;
    expect(rows.map((t) => t.id),
        unorderedEquals(['linked', 'unlinked-expense']));
  });
}
