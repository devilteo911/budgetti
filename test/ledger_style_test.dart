import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetti/core/theme/ledger_style.dart';

void main() {
  group('buildCategoryColors', () {
    const cats = [
      (name: 'Transport', type: 'expense'),
      (name: 'Eating out', type: 'expense'),
      (name: 'Shopping', type: 'expense'),
      (name: 'Salary', type: 'income'),
    ];

    test('assigns expense slots by case-folded name order, like the web', () {
      final colors = buildCategoryColors(cats, Brightness.dark);
      // Eating out < Shopping < Transport → slots 1, 2, 3.
      expect(colors['Eating out'], isNot(colors['Shopping']));
      expect(colors['Shopping'], isNot(colors['Transport']));
      // Order, not insertion order: 'Eating out' takes the first slot even
      // though 'Transport' was listed first.
      final byOrder = buildCategoryColors([
        (name: 'Eating out', type: 'expense'),
      ], Brightness.dark);
      expect(colors['Eating out'], byOrder['Eating out']);
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

    test('wraps past the eighth category instead of running out', () {
      final many = [
        // Zero-padded so string order is numeric order.
        for (var i = 0; i < 11; i++)
          (name: 'Cat${i.toString().padLeft(2, '0')}', type: 'expense'),
      ];
      final colors = buildCategoryColors(many, Brightness.dark);
      expect(colors.length, 11);
      expect(colors['Cat00'], colors['Cat08']); // ramp wraps at 8
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
