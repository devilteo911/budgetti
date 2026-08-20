import 'package:budgetti/core/finance_math.dart';
import 'package:budgetti/models/account.dart';
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
}
