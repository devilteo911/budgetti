import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/models/category.dart' as model;
import 'package:budgetti/models/tag.dart' as model_tag;
import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart' as sqlite3open;

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

/// A database upgraded from before v12 keeps its seeded twins live, and the lists
/// show one of each. The row the owner sees stands for all of them: deleting it
/// must not let a hidden twin pop up in its place, and renaming it must not leave
/// the twin behind under the old name.
void main() {
  setUpAll(_ensureSqlite);

  Future<AppDatabase> twinned() async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    await seedOwner(db, beforeTheBatch: true); // Groceries ×3, Gift ×4 … all live
    await db.into(db.accounts).insert(AccountsCompanion.insert(
        id: 'acc', name: 'Wallet', userId: const Value(owner)));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: 't1',
          userId: const Value(owner),
          accountId: const Value('acc'),
          amount: -10,
          description: 'lunch',
          category: 'Groceries',
          date: DateTime(2026, 9, 1),
        ));
    return db;
  }

  Future<List<String>> liveNames(AppDatabase db, String table) async => [
        for (final r in await db
            .customSelect('SELECT name FROM $table WHERE is_deleted = 0')
            .get())
          r.read<String>('name')
      ];

  group('categories', () {
    test('deleting the visible row retires its twins too', () async {
      final db = await twinned();
      final service = FinanceService(db, owner);
      final visible =
          (await service.getCategories()).firstWhere((c) => c.name == 'Groceries');

      await service.deleteCategory(visible.id);

      expect((await service.getCategories()).map((c) => c.name),
          isNot(contains('Groceries')));
      expect(await liveNames(db, 'categories'), isNot(contains('Groceries')));
      // A same-named category of the other type is another category: untouched.
      expect(await liveNames(db, 'categories'), contains('Salary'));
    });

    test('renaming the visible row renames its twins too', () async {
      final db = await twinned();
      final service = FinanceService(db, owner);
      final visible =
          (await service.getCategories()).firstWhere((c) => c.name == 'Groceries');

      await service.updateCategory(model.Category(
        id: visible.id,
        userId: visible.userId,
        name: 'Food',
        iconCode: visible.iconCode,
        colorHex: visible.colorHex,
        type: visible.type,
      ));

      final names = (await service.getCategories()).map((c) => c.name).toList();
      expect(names, contains('Food'));
      expect(names, isNot(contains('Groceries')));
      expect(await liveNames(db, 'categories'), isNot(contains('Groceries')));
      // History follows the rename, as it always did.
      final tx = await db.select(db.transactions).getSingle();
      expect(tx.category, 'Food');
    });

    test('a type change reaches the twins as well', () async {
      final db = await twinned();
      final service = FinanceService(db, owner);
      final visible =
          (await service.getCategories()).firstWhere((c) => c.name == 'Groceries');

      await service.updateCategory(model.Category(
        id: visible.id,
        userId: visible.userId,
        name: visible.name,
        iconCode: visible.iconCode,
        colorHex: visible.colorHex,
        type: 'income',
      ));

      final rows = await (db.select(db.categories)
            ..where((t) => t.name.equals('Groceries') & t.isDeleted.equals(false)))
          .get();
      expect(rows.map((r) => r.type).toSet(), {'income'});
    });
  });

  group('tags', () {
    test('deleting the visible tag retires its twins too', () async {
      final db = await twinned();
      final service = FinanceService(db, owner);
      final visible = (await service.getTags()).firstWhere((t) => t.name == 'Gift');

      await service.deleteTag(visible.id);

      expect((await service.getTags()).map((t) => t.name), isNot(contains('Gift')));
      expect(await liveNames(db, 'tags'), isNot(contains('Gift')));
    });

    test('renaming the visible tag renames its twins too', () async {
      final db = await twinned();
      final service = FinanceService(db, owner);
      final visible = (await service.getTags()).firstWhere((t) => t.name == 'Gift');

      await service.updateTag(model_tag.Tag(
        id: visible.id,
        userId: visible.userId,
        name: 'Present',
        colorHex: visible.colorHex,
      ));

      final names = (await service.getTags()).map((t) => t.name).toList();
      expect(names, contains('Present'));
      expect(names, isNot(contains('Gift')));
      expect(await liveNames(db, 'tags'), isNot(contains('Gift')));
    });
  });
}
