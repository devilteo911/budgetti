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
}
