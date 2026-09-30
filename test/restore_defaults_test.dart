import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart' as sqlite3open;

import 'fixtures/owner_defaults_fixture.dart';
import 'fixtures/seed_owner.dart';

// `flutter test` runs in the VM without sqlite3_flutter_libs' bundled native,
// so point the FFI loader at the system library (.so.0 — no -dev symlink here).
void _ensureSqlite() {
  try {
    sqlite3open.open.overrideFor(
      sqlite3open.OperatingSystem.linux,
      () => DynamicLibrary.open('/lib/x86_64-linux-gnu/libsqlite3.so.0'),
    );
  } catch (_) {}
}

Future<void> seedAsExported(AppDatabase db) => seedOwner(db, beforeTheBatch: false);

/// (id, name, icon, colour, is_deleted, last_updated) per row, in rowid order.
Future<List<String>> _categoryRows(AppDatabase db) async => [
      for (final r in await db
          .customSelect('SELECT id, name, icon_code, color_hex, is_deleted, '
              'last_updated FROM categories ORDER BY rowid')
          .get())
        '${r.read<String>('id')}|${r.read<String>('name')}|${r.read<int>('icon_code')}|'
            '${r.read<int>('color_hex')}|${r.read<int>('is_deleted')}|'
            '${r.read<int?>('last_updated')}'
    ];

Future<List<String>> _tagRows(AppDatabase db) async => [
      for (final r in await db
          .customSelect(
              'SELECT id, name, is_deleted, last_updated FROM tags ORDER BY rowid')
          .get())
        '${r.read<String>('id')}|${r.read<String>('name')}|${r.read<int>('is_deleted')}|'
            '${r.read<int?>('last_updated')}'
    ];

void main() {
  setUpAll(_ensureSqlite);

  // Restore defaults used to upsert `<userId>_cat_<Name>` for every default. For
  // this owner that meant ten brand-new rows next to the live ones (Dining beside
  // "Eating out", a second Transport…) and never the rows that had disappeared.
  // Now it only revives: the soft-deleted row of a default that has no live copy.
  group('restore default categories', () {
    test('brings back exactly the five that vanished, in place', () async {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      await seedAsExported(db);
      final before = await _categoryRows(db);

      final revived = await FinanceService(db, owner).restoreDefaultCategories();

      expect(revived, 5);
      final after = await _categoryRows(db);
      expect(after, hasLength(before.length), reason: 'no new rows, no duplicates');

      final live = {
        for (final r in await (db.select(db.categories)
              ..where((t) => t.isDeleted.equals(false)))
            .get())
          r.id: r
      };
      for (final id in vanishedOwnIds) {
        final row = live[id];
        expect(row, isNotNull, reason: '$id is live again');
        // Same id, icon and colour as the export.
        final was = exportedCategories.firstWhere((c) => c.$1 == id);
        expect((row!.iconCode, row.colorHex), (was.$4, was.$5));
        // Stamped now, so last-write-wins carries it to the server.
        expect(row.lastUpdated!.millisecondsSinceEpoch ~/ 1000,
            greaterThan(theBatchSecond));
      }

      // One live row per name+type, and the five are back in the owner's list.
      final names = [
        for (final c in await FinanceService(db, owner).getCategories())
          '${c.name}/${c.type}'
      ];
      expect(names.toSet(), hasLength(names.length));
      for (final name in vanishedDefaults) {
        expect(names, contains('$name/expense'));
      }

      // Everything else is byte-for-byte what it was.
      bool five(String row) => vanishedOwnIds.contains(row.split('|').first);
      expect(after.where((r) => !five(r)), before.where((r) => !five(r)));
    });

    test('leaves a renamed default alone: Dining lives on as "Eating out"',
        () async {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      await seedAsExported(db);

      await FinanceService(db, owner).restoreDefaultCategories();

      final live = [
        for (final r in await (db.select(db.categories)
              ..where((t) => t.isDeleted.equals(false)))
            .get())
          r.name
      ];
      expect(live, contains('Eating out'));
      expect(live, isNot(contains('Dining')));
      // Transport / Salary / Freelance / Investments each have a live copy
      // (renamed or legacy): none may gain a second one.
      for (final name in ['Transport', 'Salary', 'Freelance', 'Investments']) {
        expect(live.where((n) => n == name).length, lessThanOrEqualTo(1));
      }
    });

    test('a second tap changes nothing', () async {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      await seedAsExported(db);
      final service = FinanceService(db, owner);
      await service.restoreDefaultCategories();
      final once = await _categoryRows(db);

      expect(await service.restoreDefaultCategories(), 0);

      expect(await _categoryRows(db), once);
    });

    test('prefers the owner\'s own seeded copy over legacy and later seeds',
        () async {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      await seedAsExported(db);

      await FinanceService(db, owner).restoreDefaultCategories();

      final live = await (db.select(db.categories)
            ..where((t) => t.isDeleted.equals(false) & t.name.equals('Groceries')))
          .get();
      expect(live.map((r) => r.id), ['uidA_cat_Groceries']);
    });
  });

  // Which copy of a default comes back: the owner's own seeded `<uid>_cat_<Name>`,
  // even when another seeded copy sits earlier in rowid order.
  test('prefers the owner\'s own copy even when another seed comes first',
      () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    for (final id in ['other_cat_Groceries', 'owner_cat_Groceries']) {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
            id: id,
            name: 'Groceries',
            iconCode: 1,
            colorHex: 2,
            type: 'expense',
            userId: const Value(owner),
            isDeleted: const Value(true),
          ));
    }

    await FinanceService(db, owner).restoreDefaultCategories();

    final live = await (db.select(db.categories)
          ..where((t) => t.isDeleted.equals(false)))
        .get();
    expect(live.map((r) => r.id), ['owner_cat_Groceries']);
  });

  group('restore default tags', () {
    // Every default tag still has a live copy, so there is nothing to bring back.
    test('revives nothing and adds no duplicates', () async {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      await seedAsExported(db);
      final before = await _tagRows(db);

      final revived = await FinanceService(db, owner).restoreDefaultTags();

      expect(revived, 0);
      expect(await _tagRows(db), before);
    });

    test('prefers the owner\'s own tag even when another seed comes first',
        () async {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      for (final id in ['other_tag_Gift', 'owner_tag_Gift']) {
        await db.into(db.tags).insert(TagsCompanion.insert(
              id: id,
              name: 'Gift',
              colorHex: 1,
              userId: const Value(owner),
              isDeleted: const Value(true),
            ));
      }

      await FinanceService(db, owner).restoreDefaultTags();

      final live = await (db.select(db.tags)
            ..where((t) => t.isDeleted.equals(false)))
          .get();
      expect(live.map((r) => r.id), ['owner_tag_Gift']);
    });

    test('revives a default tag that has no live copy', () async {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      await seedAsExported(db);
      await (db.update(db.tags)..where((t) => t.name.equals('Gift')))
          .write(const TagsCompanion(isDeleted: Value(true)));

      final revived = await FinanceService(db, owner).restoreDefaultTags();

      expect(revived, 1);
      final gift = await (db.select(db.tags)
            ..where((t) => t.isDeleted.equals(false) & t.name.equals('Gift')))
          .get();
      expect(gift.map((t) => t.id), ['uidA_tag_Gift']); // the owner's seeded copy
    });
  });
}
