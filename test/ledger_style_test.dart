import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetti/core/theme/ledger_style.dart';

void main() {
  group('categorySlot', () {
    // Same vectors as web/src/finance.test.ts: a category has to land on the same
    // palette slot on the phone and on the dashboard. Change one, change both.
    const vectors = {
      '': 1,
      'a': 0,
      'uidA_cat_Groceries': 1,
      'uidA_cat_Bills': 4,
      '85d564f1-217c-4edc-aaf8-3df30c1d62fc_cat_Bills': 4,
      '1767781286735Transport': 7,
      '03099f5d-9cf3-4166-8b5f-ebb73cb80a38': 4,
      'Caffè': 2, // a non-ASCII UTF-16 unit
      'x\u{1F600}y': 3, // a surrogate pair is two units
    };

    test('is FNV-1a over UTF-16 units folded to 8 slots, like the web', () {
      vectors.forEach((id, slot) => expect(categorySlot(id), slot, reason: id));
    });
  });

  group('buildCategoryColors', () {
    const cats = [
      (id: 'c-transport', name: 'Transport', type: 'expense', slot: null),
      (id: 'c-eating', name: 'Eating out', type: 'expense', slot: null),
      (id: 'c-shopping', name: 'Shopping', type: 'expense', slot: null),
      (id: 'c-salary', name: 'Salary', type: 'income', slot: null),
    ];

    test('an expense takes the palette slot its id hashes to', () {
      final colors = buildCategoryColors(cats, Brightness.dark);
      final sameSlot = buildCategoryColors([
        (id: 'uidA_cat_Groceries', name: 'A', type: 'expense', slot: null),
        (id: '', name: 'B', type: 'expense', slot: null), // both hash to slot 1
        (id: 'a', name: 'C', type: 'expense', slot: null), // slot 0
      ], Brightness.dark);
      expect(sameSlot['A'], sameSlot['B']);
      expect(sameSlot['A'], isNot(sameSlot['C']));
      expect(colors.keys, containsAll(['Transport', 'Eating out', 'Shopping']));
    });

    // The point of the hash: a colour never moves because of its neighbours.
    test('adding, removing or renaming other categories repaints none', () {
      final before = buildCategoryColors(cats, Brightness.dark);

      final more = buildCategoryColors([
        (id: 'aaa-first', name: 'Aardvark', type: 'expense', slot: null), // sorts before all
        ...cats,
        (id: 'zzz-last', name: 'Zebra', type: 'expense', slot: null),
      ], Brightness.dark);
      final fewer = buildCategoryColors(
          [cats.first, cats.last], Brightness.dark);
      final renamed = buildCategoryColors([
        (id: 'c-transport', name: 'Commute', type: 'expense', slot: null),
        ...cats.skip(1),
      ], Brightness.dark);

      for (final name in ['Transport', 'Eating out', 'Shopping']) {
        expect(more[name], before[name], reason: 'added others: $name');
      }
      expect(fewer['Transport'], before['Transport']);
      expect(renamed['Commute'], before['Transport'],
          reason: 'a rename keeps the id, so the colour');
    });

    test('income is always the positive green, never a categorical slot', () {
      final colors = buildCategoryColors(cats, Brightness.dark);
      expect(colors['Salary'], incomeInk(Brightness.dark));
    });

    test('re-steps per brightness', () {
      expect(
        buildCategoryColors(cats, Brightness.dark)['Shopping'],
        isNot(buildCategoryColors(cats, Brightness.light)['Shopping']),
      );
    });

    test('more than eight expenses share slots instead of running out', () {
      final many = [
        for (var i = 0; i < 20; i++)
          (id: 'id-$i', name: 'Cat$i', type: 'expense', slot: null),
      ];
      final colors = buildCategoryColors(many, Brightness.dark);
      expect(colors.length, 20);
      expect(colors.values.toSet().length, lessThanOrEqualTo(8));
    });

    test('twins under one name resolve to the first, the one the list shows', () {
      final colors = buildCategoryColors([
        (id: 'a', name: 'Groceries', type: 'expense', slot: null), // slot 0
        (id: '', name: 'Groceries', type: 'expense', slot: null), // slot 1
      ], Brightness.dark);
      final first = buildCategoryColors(
          [(id: 'a', name: 'Groceries', type: 'expense', slot: null)], Brightness.dark);
      expect(colors['Groceries'], first['Groceries']);
    });
  });

  group('categoryIcon', () {
    test('trusts a codepoint the picker could have produced', () {
      expect(
        categoryIcon('Whatever', iconCode: Icons.local_pizza.codePoint),
        IconData(Icons.local_pizza.codePoint, fontFamily: 'MaterialIcons'),
      );
    });

    test('ignores a stale codepoint and reads the name instead', () {
      // 59600 is the legacy code that made "Shopping" render as a boat.
      expect(categoryIcon('Shopping', iconCode: 59600), Icons.shopping_bag);
    });

    test('matches Italian names too', () {
      expect(categoryIcon('Ristorante'), Icons.restaurant);
      expect(categoryIcon('Bollette'), Icons.receipt_long);
      expect(categoryIcon('Carburante'), Icons.local_gas_station);
    });

    test('falls back to a neutral glyph rather than a wrong one', () {
      expect(categoryIcon('Zxqv'), Icons.category_outlined);
      expect(categoryIcon('Zxqv', isIncome: true), Icons.payments);
    });
  });

  group('amountInk', () {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF356859),
      brightness: Brightness.dark,
    );

    test('income and transfer never collide', () {
      final income = amountInk(scheme, isTransfer: false, isIncome: true);
      final transfer = amountInk(scheme, isTransfer: true, isIncome: false);
      expect(income, isNot(transfer));
    });

    test('an expense is neutral, not an error', () {
      final expense = amountInk(scheme, isTransfer: false, isIncome: false);
      expect(expense, scheme.onSurface);
      expect(expense, isNot(scheme.error));
    });
  });
}
