import 'package:budgetti/core/finance_math.dart';
import 'package:budgetti/models/account.dart';
import 'package:budgetti/models/category.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixed clock: mid-month so "this month" and "last 30 days" are distinct
/// windows and a bug in one cannot hide behind the other.
final _now = DateTime(2026, 8, 20, 12);

var _seq = 0;
Transaction tx(
  double amount,
  DateTime date, {
  String category = 'Food',
  String type = 'expense',
  List<String> tags = const [],
}) => Transaction(
  id: 't${_seq++}',
  accountId: 'a1',
  amount: amount,
  date: date,
  description: 'x',
  category: category,
  type: type,
  tags: tags,
);

Account acc(double balance) => Account(
  id: 'a$balance',
  name: 'w',
  balance: balance,
  currency: 'EUR',
  providerName: 'Local',
);

void main() {
  group('parseAmount', () {
    test('reads both locales, the last separator is the decimal one', () {
      expect(parseAmount('1234,56'), 1234.56);
      expect(parseAmount('1.234,56'), 1234.56);
      expect(parseAmount('1,234.50'), 1234.5);
      expect(parseAmount('12,50'), 12.5);
      expect(parseAmount('12.5'), 12.5);
      expect(parseAmount('1234'), 1234);
    });

    test('three trailing digits are thousands, not decimals', () {
      expect(parseAmount('1.234'), 1234);
      expect(parseAmount('1,234'), 1234);
    });

    test('keeps the sign and tolerates padding', () {
      expect(parseAmount(' -12,50 '), -12.5);
      expect(parseAmount('+3,5'), 3.5);
    });

    test('garbage is null, not zero', () {
      expect(parseAmount(''), isNull);
      expect(parseAmount('abc'), isNull);
      expect(parseAmount('12,x'), isNull);
      expect(parseAmount('1,2,3x'), isNull);
    });
  });

  group('dashboardStats', () {
    test('splits this month by sign and excludes transfers', () {
      final stats = dashboardStats(
        [
          tx(-10, DateTime(2026, 8, 19)),
          tx(-5, DateTime(2026, 8, 2)),
          tx(100, DateTime(2026, 8, 1), type: 'income'),
          // Transfers are stored positive and must not read as income.
          tx(500, DateTime(2026, 8, 10), type: 'transfer'),
          // Last month: outside the monthly window.
          tx(-99, DateTime(2026, 7, 20)),
        ],
        [acc(40), acc(2.5)],
        now: _now,
      );

      expect(stats.monthlyIncome, 100);
      expect(stats.monthlyExpenses, 15);
      expect(stats.monthlyNetFlow, 85);
      expect(stats.totalBalance, 42.5);
    });

    test('netFlow is the rolling 30 days, not the calendar month', () {
      // 2026-07-25 is inside 30 days of 2026-08-20 but outside August.
      final stats = dashboardStats(
        [tx(-30, DateTime(2026, 7, 25)), tx(-70, DateTime(2026, 6, 25))],
        const [],
        now: _now,
      );

      expect(stats.netFlow, -30);
      expect(stats.monthlyExpenses, 0, reason: 'neither row is in August');
    });

    test('recentTransactions keeps the caller order, capped', () {
      final rows = [for (var i = 0; i < 15; i++) tx(-1, DateTime(2026, 8, 15))];
      final stats = dashboardStats(rows, const [], now: _now, recentCount: 10);
      expect(stats.recentTransactions, rows.take(10));
    });
  });

  group('monthlyNetFlow', () {
    test('one signed slot per month, oldest first, zeros kept', () {
      final flow = monthlyNetFlow(
        [
          tx(100, DateTime(2026, 8, 3), type: 'income'),
          tx(-40, DateTime(2026, 8, 4)),
          tx(-10, DateTime(2026, 6, 1)),
          tx(999, DateTime(2026, 7, 1), type: 'transfer'),
          // Older than the window.
          tx(-1000, DateTime(2025, 1, 1)),
        ],
        now: _now,
        months: 4,
      );

      // May, June, July, August.
      expect(flow, [0.0, -10.0, 0.0, 60.0]);
    });
  });

  group('categorySpendForMonth', () {
    test('expenses only, positive, this month only', () {
      final spend = categorySpendForMonth([
        tx(-10, DateTime(2026, 8, 5), category: 'Food'),
        tx(-2.5, DateTime(2026, 8, 6), category: 'Food'),
        tx(-7, DateTime(2026, 8, 7), category: 'Fuel'),
        tx(50, DateTime(2026, 8, 8), category: 'Salary', type: 'income'),
        tx(-99, DateTime(2026, 7, 5), category: 'Food'),
      ], now: _now);

      expect(spend, {'Food': 12.5, 'Fuel': 7.0});
    });
  });

  group('lastMonthKeys / spendByMonth', () {
    test('keys end on the current month and roll over the year', () {
      expect(lastMonthKeys(3, now: DateTime(2026, 2, 10)), [
        '2025-12',
        '2026-01',
        '2026-02',
      ]);
    });

    test('spend outside the window is dropped, months inside stay at zero', () {
      final months = lastMonthKeys(3, now: _now);
      final spend = spendByMonth([
        tx(-10, DateTime(2026, 8, 1)),
        tx(-5, DateTime(2026, 6, 1)),
        tx(-1000, DateTime(2024, 8, 1)),
      ], months);

      expect(spend, {'2026-06': 5.0, '2026-07': 0.0, '2026-08': 10.0});
    });
  });

  group('statsForPeriod', () {
    final rows = [
      tx(-10, DateTime(2026, 8, 5), category: 'Food', tags: ['work', 'card']),
      tx(-20, DateTime(2026, 8, 6), category: 'Fuel', tags: ['card']),
      tx(300, DateTime(2026, 8, 7), category: 'Salary', type: 'income'),
      tx(-7, DateTime(2026, 3, 1), category: 'Food'),
      tx(-1, DateTime(2025, 8, 1), category: 'Food'),
      tx(999, DateTime(2026, 8, 8), type: 'transfer'),
    ];

    test('a year rolls up every month of it', () {
      final s = statsForPeriod(rows, StatsPeriod(year: 2026));

      expect(s.totalExpenses, 37);
      expect(s.categoryTotals, {'Food': 17.0, 'Fuel': 20.0});
      expect(s.monthlyBreakdown['2026-08'], {'earned': 300.0, 'spent': 30.0});
      expect(s.monthlyBreakdown['2026-03'], {'earned': 0.0, 'spent': 7.0});
      expect(s.monthlyBreakdown.containsKey('2025-08'), isFalse);
    });

    test('a month narrows to that month', () {
      final s = statsForPeriod(rows, StatsPeriod(year: 2026, month: 8));

      expect(s.totalExpenses, 30);
      expect(s.categoryTotals, {'Food': 10.0, 'Fuel': 20.0});
    });

    test('a multi-tagged expense counts once per tag', () {
      final s = statsForPeriod(rows, StatsPeriod(year: 2026, month: 8));

      expect(s.tagTotals, {'work': 10.0, 'card': 30.0});
      expect(
        s.tagTotals.values.reduce((a, b) => a + b),
        greaterThan(s.totalExpenses),
        reason: 'tag totals deliberately over-count; the UI says so',
      );
    });
  });

  group('daysInPeriod', () {
    test('the running year counts to today, not 365', () {
      // Aug 20 = 31+28+31+30+31+30+31+20; dividing a part-year by 365 made
      // the daily average look 37% smaller than it is.
      expect(daysInPeriod(StatsPeriod(year: 2026), now: _now), 232);
    });

    test('a finished year is 365 or 366', () {
      expect(daysInPeriod(StatsPeriod(year: 2025), now: _now), 365);
      expect(daysInPeriod(StatsPeriod(year: 2024), now: _now), 366);
    });

    test('a month counts to today when running, else its full length', () {
      expect(daysInPeriod(StatsPeriod(year: 2026, month: 8), now: _now), 20);
      expect(daysInPeriod(StatsPeriod(year: 2026, month: 7), now: _now), 31);
      expect(daysInPeriod(StatsPeriod(year: 2024, month: 2), now: _now), 29);
    });

    test('a DST change inside the year does not eat a day', () {
      // Local difference() across the March clock change is 23h short in
      // Europe/Rome and inDays floors it to 88.
      expect(
        daysInPeriod(StatsPeriod(year: 2026), now: DateTime(2026, 3, 30, 12)),
        89,
      );
    });
  });

  group('chartSeries', () {
    test('weekly buckets start on Monday', () {
      // 2026-08-20 is a Thursday; its week starts Monday 2026-08-17.
      expect(
        bucketStart(DateTime(2026, 8, 20), ChartGranularity.weekly),
        DateTime(2026, 8, 17),
      );
      expect(
        bucketStart(DateTime(2026, 8, 17), ChartGranularity.weekly),
        DateTime(2026, 8, 17),
      );
    });

    test('splits by sign, drops transfers and zeroes, sorts oldest first', () {
      final s = chartSeries(
        [
          tx(-10, DateTime(2026, 8, 20)),
          tx(-5, DateTime(2026, 8, 19)),
          tx(200, DateTime(2026, 8, 18), type: 'income'),
          tx(999, DateTime(2026, 8, 18), type: 'transfer'),
          tx(0, DateTime(2026, 8, 18)),
          tx(-1, DateTime(2025, 8, 18)),
        ],
        StatsPeriod(year: 2026, month: 8),
        ChartGranularity.monthly,
      );

      expect(s.expenses.single.amount, 15);
      expect(s.income.single.amount, 200);
      expect(s.expenses.single.label, DateTime(2026, 8, 1));
    });

    test('daily buckets stay in date order', () {
      final s = chartSeries(
        [
          tx(-1, DateTime(2026, 8, 20)),
          tx(-2, DateTime(2026, 8, 3)),
          tx(-3, DateTime(2026, 8, 11)),
        ],
        StatsPeriod(year: 2026, month: 8),
        ChartGranularity.daily,
      );

      expect([for (final p in s.expenses) p.label.day], [3, 11, 20]);
      expect(s.income, isEmpty);
    });
  });

  // A new sheet starts on the category the owner last used for that kind of
  // movement — habit, not the alphabetically first category.
  group('defaultCategoryFor', () {
    Category cat(String name, String type) => Category(
          id: 'c$name',
          userId: 'u',
          name: name,
          iconCode: 0,
          colorHex: 0,
          type: type,
        );
    final categories = [
      cat('Dining', 'expense'),
      cat('Groceries', 'expense'),
      cat('Freelance', 'income'),
      cat('Salary', 'income'),
    ];
    final d = DateTime(2026, 8, 20);

    test('no history: the first category of the type', () {
      expect(defaultCategoryFor('expense', categories, const []), 'Dining');
      expect(defaultCategoryFor('income', categories, const []), 'Freelance');
    });

    test('the newest transaction of that type decides', () {
      final history = [
        tx(-9, d, category: 'Groceries'),
        tx(-5, d, category: 'Dining'),
      ];

      expect(defaultCategoryFor('expense', categories, history), 'Groceries');
    });

    test('a transaction of the other type is ignored', () {
      final history = [
        tx(100, d, category: 'Salary', type: 'income'), // newest, but income
        tx(-5, d, category: 'Groceries'),
      ];

      expect(defaultCategoryFor('expense', categories, history), 'Groceries');
      expect(defaultCategoryFor('income', categories, history), 'Salary');
    });

    test('a transfer is neither', () {
      final history = [tx(50, d, category: 'Transfer', type: 'transfer')];

      expect(defaultCategoryFor('expense', categories, history), 'Dining');
    });

    test('a last category that is gone or a placeholder falls back to the '
        'first, not to an older transaction', () {
      final gone = [tx(-1, d, category: 'Pranzo'), tx(-5, d, category: 'Groceries')];
      final uncategorized = [tx(-1, d, category: 'Uncategorized')];

      expect(defaultCategoryFor('expense', categories, gone), 'Dining');
      expect(defaultCategoryFor('expense', categories, uncategorized), 'Dining');
    });

    test('a category of the other kind is not inherited', () {
      // Legacy row: an expense filed under an income category.
      final history = [tx(-5, d, category: 'Salary')];

      expect(defaultCategoryFor('expense', categories, history), 'Dining');
    });

    test('null when the type has no category (a transfer)', () {
      expect(defaultCategoryFor('transfer', categories, const []), isNull);
      expect(defaultCategoryFor('expense', const [], const []), isNull);
    });
  });
}
