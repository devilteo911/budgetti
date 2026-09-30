import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/color_slots.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/core/theme/ledger_style.dart';
import 'package:budgetti/models/category.dart' as model;
import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:flutter/material.dart' show Brightness;
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

/// A category is given a palette slot when it is created and keeps it: the colour
/// is stored, not recomputed from its neighbours. NULL (not assigned or synced
/// yet) renders through the id hash, so the owner sees no change until a slot lands.
void main() {
  setUpAll(_ensureSqlite);

  Future<AppDatabase> memory() async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    await db.select(db.accounts).get();
    return db;
  }

  Future<void> cat(AppDatabase db, String id, String name,
      {String type = 'expense', int? slot, bool deleted = false, DateTime? at}) =>
      db.into(db.categories).insert(CategoriesCompanion.insert(
            id: id,
            name: name,
            iconCode: 1,
            colorHex: 2,
            type: type,
            userId: const Value(owner),
            colorSlot: Value(slot),
            isDeleted: Value(deleted),
            lastUpdated: Value(at),
          ));

  Future<void> spend(AppDatabase db, String category, double amount,
      {String type = 'expense', bool deleted = false}) async {
    final n = (await db.select(db.transactions).get()).length;
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: 'tx$n',
          userId: const Value(owner),
          amount: amount,
          description: 'spend',
          category: category,
          type: Value(type),
          isDeleted: Value(deleted),
          date: DateTime(2026, 9, 1),
        ));
  }

  Future<Map<String, int?>> slots(AppDatabase db) async => {
        for (final c in await (db.select(db.categories)
              ..where((t) => t.isDeleted.equals(false)))
            .get())
          c.name: c.colorSlot
      };

  group('leastUsedSlot', () {
    test('an empty palette starts at 0', () => expect(leastUsedSlot([]), 0));

    test('takes the slot nobody uses, lowest first', () {
      expect(leastUsedSlot([0, 1, 3]), 2);
      expect(leastUsedSlot([1, 2]), 0);
    });

    test('once every slot is used it takes the least used, ties to the lowest',
        () {
      expect(leastUsedSlot([0, 1, 2, 3, 4, 5, 6, 7]), 0);
      expect(leastUsedSlot([0, 0, 1, 2, 3, 4, 5, 6, 7]), 1);
      expect(leastUsedSlot([0, 0, 1, 1, 2, 3, 4, 5, 6, 7, 7]), 2);
    });
  });

  group('a new expense category', () {
    test('takes the least-used slot, counting what is on screen today',
        () async {
      final db = await memory();
      // Hash-coloured rows (NULL slot): 'a' → 0, 'uidA_cat_Groceries' → 1,
      // 'uidA_cat_Bills' → 4 (the shared test vectors).
      await cat(db, 'a', 'A');
      await cat(db, 'uidA_cat_Groceries', 'Groceries');
      await cat(db, 'uidA_cat_Bills', 'Bills', slot: 4);
      final service = FinanceService(db, owner);

      await service.addCategory(model.Category(
          id: 'new-1', userId: owner, name: 'New', iconCode: 1, colorHex: 2, type: 'expense'));

      expect((await slots(db))['New'], 2, reason: '0, 1 and 4 are taken');
    });

    test('each one after that takes the next', () async {
      final db = await memory();
      final service = FinanceService(db, owner);
      for (var i = 0; i < 9; i++) {
        await service.addCategory(model.Category(
            id: 'n$i', userId: owner, name: 'N$i', iconCode: 1, colorHex: 2, type: 'expense'));
      }
      expect([for (var i = 0; i < 9; i++) (await slots(db))['N$i']],
          [0, 1, 2, 3, 4, 5, 6, 7, 0]);
    });

    test('an income category gets none', () async {
      final db = await memory();
      await FinanceService(db, owner).addCategory(model.Category(
          id: 'i1', userId: owner, name: 'Pay', iconCode: 1, colorHex: 2, type: 'income'));
      expect((await slots(db))['Pay'], isNull);
    });

    test('deleted and income rows do not count', () async {
      final db = await memory();
      await cat(db, 'x', 'Old', slot: 0, deleted: true);
      await cat(db, 'y', 'Pay', type: 'income', slot: 1);
      await FinanceService(db, owner).addCategory(model.Category(
          id: 'n', userId: owner, name: 'New', iconCode: 1, colorHex: 2, type: 'expense'));
      expect((await slots(db))['New'], 0);
    });

    test('a slot the caller already chose is kept', () async {
      final db = await memory();
      await FinanceService(db, owner).addCategory(model.Category(
          id: 'n', userId: owner, name: 'New', iconCode: 1, colorHex: 2,
          type: 'expense', colorSlot: 5));
      expect((await slots(db))['New'], 5);
    });
  });

  group('changing a category\'s type', () {
    Future<void> flip(FinanceService s, AppDatabase db, String id, String type) async {
      final row = await (db.select(db.categories)..where((t) => t.id.equals(id))).getSingle();
      await s.updateCategory(model.Category(
          id: id, userId: owner, name: row.name, iconCode: row.iconCode,
          colorHex: row.colorHex, type: type));
    }

    test('income → expense assigns a slot on the spot', () async {
      final db = await memory();
      await cat(db, 'a', 'A', slot: 0);
      await cat(db, 'p', 'Pay', type: 'income');
      await flip(FinanceService(db, owner), db, 'p', 'expense');
      expect((await slots(db))['Pay'], 1);
    });

    test('expense → income keeps the slot, and it comes back on the way back',
        () async {
      final db = await memory();
      await cat(db, 'e', 'Eats', slot: 6);
      final s = FinanceService(db, owner);
      await flip(s, db, 'e', 'income');
      expect((await slots(db))['Eats'], 6, reason: 'kept while income');
      await cat(db, 'z', 'Z', slot: 0);
      await flip(s, db, 'e', 'expense');
      expect((await slots(db))['Eats'], 6, reason: 'not re-assigned');
    });
  });

  group('backfill', () {
    test('gives the biggest categories distinct slots, by spend', () async {
      final db = await memory();
      for (final n in ['Bills', 'Health', 'Eating out', 'Groceries', 'Other']) {
        await cat(db, 'id-$n', n);
      }
      await spend(db, 'Eating out', -400);
      await spend(db, 'Groceries', -300);
      await spend(db, 'Other', -200);
      await spend(db, 'Bills', -50);
      await spend(db, 'Health', -40);

      final n = (await backfillColorSlots(db, owner)).length;

      expect(n, 5);
      expect(await slots(db),
          {'Eating out': 0, 'Groceries': 1, 'Other': 2, 'Bills': 3, 'Health': 4});
    });

    test('spend is money out: income, transfers, refunds and deleted rows do not count',
        () async {
      final db = await memory();
      await cat(db, 'a', 'Aa');
      await cat(db, 'b', 'Bb');
      await spend(db, 'Aa', -10);
      await spend(db, 'Aa', 500); // a refund
      await spend(db, 'Aa', -999, deleted: true);
      await spend(db, 'Aa', -999, type: 'transfer');
      await spend(db, 'Bb', -20);

      await backfillColorSlots(db, owner);

      expect(await slots(db), {'Bb': 0, 'Aa': 1}, reason: 'Bb spent 20, Aa 10');
    });

    test('ties go to the id, so two devices order them alike', () async {
      final db = await memory();
      await cat(db, 'zz', 'Zed');
      await cat(db, 'aa', 'Ay');
      await backfillColorSlots(db, owner);
      expect(await slots(db), {'Ay': 0, 'Zed': 1});
    });

    test('touches only live expense rows with no slot, and stamps them together',
        () async {
      final db = await memory();
      await cat(db, 'set', 'Set', slot: 3, at: DateTime(2026, 6, 1));
      await cat(db, 'open', 'Open');
      await cat(db, 'pay', 'Pay', type: 'income');
      await cat(db, 'dead', 'Dead', deleted: true);
      final now = DateTime(2026, 10, 1, 9, 30);

      final n = (await backfillColorSlots(db, owner, now: now)).length;

      expect(n, 1);
      final rows = {
        for (final r in await db.select(db.categories).get()) r.id: r
      };
      expect(rows['open']!.colorSlot, 0);
      expect(rows['open']!.lastUpdated, now);
      expect(rows['set']!.colorSlot, 3);
      expect(rows['set']!.lastUpdated, DateTime(2026, 6, 1), reason: 'untouched');
      expect(rows['pay']!.colorSlot, isNull);
      expect(rows['dead']!.colorSlot, isNull);
    });

    test('counts the slots already set when it picks', () async {
      final db = await memory();
      await cat(db, 'set', 'Set', slot: 0);
      await cat(db, 'open', 'Open');
      await backfillColorSlots(db, owner);
      expect((await slots(db))['Open'], 1);
    });

    test('is idempotent: a second run writes nothing', () async {
      final db = await memory();
      await cat(db, 'a', 'Aa');
      await cat(db, 'b', 'Bb');
      await backfillColorSlots(db, owner, now: DateTime(2026, 10, 1));
      final before = await (db.select(db.categories)).get();

      final n = (await backfillColorSlots(db, owner, now: DateTime(2026, 10, 2))).length;

      expect(n, 0);
      final after = await (db.select(db.categories)).get();
      expect([for (final r in after) (r.id, r.colorSlot, r.lastUpdated)],
          [for (final r in before) (r.id, r.colorSlot, r.lastUpdated)]);
    });

    test('a hidden twin is not given a slot of its own', () async {
      final db = await memory();
      await cat(db, 'first', 'Groceries');
      await cat(db, 'twin', 'Groceries');
      await backfillColorSlots(db, owner);
      final rows = {for (final r in await db.select(db.categories).get()) r.id: r};
      expect(rows['first']!.colorSlot, 0);
      expect(rows['twin']!.colorSlot, isNull);
    });
  });

  group('on the owner\'s real categories', () {
    // The state the phone exported, the five restored, plus what they spend.
    Future<AppDatabase> owners() async {
      final db = await memory();
      await seedOwner(db, beforeTheBatch: false);
      await FinanceService(db, owner).restoreDefaultCategories();
      const spent = {
        'Eating out': 4321.93, 'Car': 3854.98, 'Groceries': 2373.11,
        'Shopping': 1710.07, 'Transport': 60.80, 'Bills': 618.05,
        'Health': 355.06, 'Entertainment': 24.0,
      };
      for (final e in spent.entries) {
        await spend(db, e.key, -e.value);
      }
      return db;
    }

    test('the biggest eight all get different colours', () async {
      final db = await owners();
      await backfillColorSlots(db, owner);
      final s = await slots(db);
      final expense = [
        for (final e in s.entries)
          if (!['Refunds', 'Client A', 'Client B', 'Salary', 'Freelance', 'Investments']
              .contains(e.key))
            e.key
      ];
      expect(expense.toSet(), hasLength(8));
      expect({for (final n in expense) s[n]}, hasLength(8),
          reason: 'eight categories, eight slots: $s');
    });

    test('two devices with the same ledger compute the same slots', () async {
      final a = await owners();
      final b = await owners();
      await backfillColorSlots(a, owner);
      await backfillColorSlots(b, owner);
      expect(await slots(a), await slots(b));
    });

    test('devices that backfilled apart converge on one whole assignment',
        () async {
      // Phone A saw one ledger, phone B another: they order the categories
      // differently. Each wrote ALL its rows under one stamp, so last-write-wins
      // per row picks the same side for every row — never a mix of the two.
      final a = await owners();
      final b = await owners();
      await spend(b, 'Bills', -9000); // B's ledger has a big Bills charge
      await backfillColorSlots(a, owner, now: DateTime(2026, 10, 1, 9, 0, 0));
      await backfillColorSlots(b, owner, now: DateTime(2026, 10, 1, 9, 0, 5));

      Future<Map<String, (int?, DateTime?)>> rows(AppDatabase d) async => {
            for (final r in await (d.select(d.categories)
                  ..where((t) => t.isDeleted.equals(false) & t.type.equals('expense')))
                .get())
              r.name: (r.colorSlot, r.lastUpdated)
          };
      final ra = await rows(a), rb = await rows(b);
      final merged = {
        for (final name in ra.keys)
          name: (rb[name]!.$2!.isAfter(ra[name]!.$2!) ? rb[name]! : ra[name]!).$1
      };

      expect(merged, {for (final e in rb.entries) e.key: e.value.$1},
          reason: 'B stamped later, so B wins every row');
      expect(merged.values.toSet(), hasLength(merged.length),
          reason: 'and B\'s assignment is distinct across the top eight');
    });
  });

  group('rendering', () {
    test('a stored slot wins over the id hash, NULL falls back to it', () {
      // 'a' hashes to slot 0 and '' to slot 1.
      final colors = buildCategoryColors([
        (id: 'a', name: 'Stored', type: 'expense', slot: 5),
        (id: 'a', name: 'Hashed', type: 'expense', slot: null),
        (id: '', name: 'Other', type: 'expense', slot: null),
      ], Brightness.dark);
      expect(colors['Stored'], isNot(colors['Hashed']));
      expect(colors['Hashed'], isNot(colors['Other']));
      final slot0 = buildCategoryColors(
          [(id: 'x', name: 'Z', type: 'expense', slot: 0)], Brightness.dark);
      expect(colors['Hashed'], slot0['Z']);
    });
  });
}
