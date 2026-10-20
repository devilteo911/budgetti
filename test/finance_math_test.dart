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
  String? id,
  String category = 'Food',
  String type = 'expense',
  List<String> tags = const [],
  String? toAccountId,
  double othersShare = 0,
  String? reimbursesId,
}) => Transaction(
  id: id ?? 't${_seq++}',
  accountId: 'a1',
  toAccountId: toAccountId,
  amount: amount,
  date: date,
  description: 'x',
  category: category,
  type: type,
  tags: tags,
  othersShare: othersShare,
  reimbursesId: reimbursesId,
);

Account acc(double balance) => Account(
  id: 'a$balance',
  name: 'w',
  balance: balance,
  currency: 'EUR',
  providerName: 'Local',
);

void main() {
  // Mirror of web/src/finance.test.ts parseAmount — change one, change both.
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

    // The shapes the web port derived by reading this function.
    test('a bare separator is allowed at either end of the digits', () {
      expect(parseAmount('.5'), 0.5);
      expect(parseAmount('12,'), 12);
    });

    test('the sign may be followed by spaces', () {
      expect(parseAmount('- 12,5'), -12.5);
    });

    test('several groups: the last separator still decides', () {
      expect(parseAmount('1.234.567,89'), 1234567.89);
      expect(parseAmount('1,234,567'), 1234567);
      expect(parseAmount('1,2,3'), 12.3); // ceiling: not a valid grouping
    });

    test('the decimal count is whatever follows, except exactly three', () {
      expect(parseAmount('1.2345'), 1.2345);
      // Documented ceiling: three trailing digits are always thousands.
      expect(parseAmount('0,125'), 125);
    });

    test('a sign alone, a doubled sign, exponents, inner spaces, NaN: null', () {
      for (final raw in ['-', '+', '--5', '1e5', '1 234,56', 'NaN']) {
        expect(parseAmount(raw), isNull, reason: raw);
      }
    });

    test('a signed zero is zero', () {
      expect(parseAmount('-0'), 0); // -0.0 == 0
    });
  });

  // Mirror of web/src/finance.test.ts "clampShare and othersShareOf: the server
  // never sees a negative share" — change one, change both. The `othersShareOf`
  // bullets are web only (the phone's form rules come with its form).
  group('clampShare', () {
    test('the server never sees a negative share', () {
      expect(
        [
          clampShare(-5, -100),
          clampShare(150, -100),
          clampShare(75, -100),
          clampShare(double.nan, -100),
        ],
        [0.0, 100.0, 75.0, 0.0],
      );
    });

    test('an infinite share is 0, the cent is rounded and zero is never -0.0',
        () {
      expect(clampShare(double.infinity, -100), 0.0);
      expect(clampShare(double.negativeInfinity, -100), 0.0);
      expect(clampShare(33.333, -100), 33.33);
      expect(clampShare(5, 0), 0.0); // a share cannot exceed a zero amount
      expect(clampShare(-0.0, -100).isNegative, isFalse);
      expect(clampShare(-0.004, -100).isNegative, isFalse);
    });
  });

  // Mirror of web/src/finance.test.ts "shared expenses" cases 1-12 — change one,
  // change both. A 100 € dinner for four, the others owe 75; 25 € came back in
  // June and 25 € in July, around a salary, a grocery run and a transfer. Same
  // names and figures as the web; where the web function has no Dart twin, the
  // Dart quantity that computes the same thing stands in (`statsForPeriod`'s
  // month bucket for `monthlyFlow`, `monthlyNetFlow` for the history and the
  // savings, `categorySpendForMonth` for `spendByCategory` and `budgetStatus`).
  group('shared expenses (mirror: web/src/finance.test.ts)', () {
    // Local noon, like the web's `at()`: nothing here depends on the zone.
    DateTime at(int y, int m, int d) => DateTime(y, m, d, 12);
    final now = at(2026, 7, 22);
    final june15 = at(2026, 6, 15);

    final dinner = tx(
      -100,
      at(2026, 6, 10),
      id: 'dinner',
      category: 'Eating out',
      othersShare: 75,
    );
    final back1 = tx(
      25,
      at(2026, 6, 12),
      id: 'back1',
      category: 'Gifts',
      type: 'income',
      reimbursesId: 'dinner',
    );
    final back2 = tx(
      25,
      at(2026, 7, 3),
      id: 'back2',
      category: 'Gifts',
      type: 'income',
      reimbursesId: 'dinner',
    );
    final pay = tx(
      2000,
      at(2026, 6, 1),
      id: 'pay',
      category: 'Salary',
      type: 'income',
    );
    final food = tx(
      -50,
      at(2026, 6, 5),
      id: 'food',
      category: 'Groceries',
    );
    final move = tx(
      300,
      at(2026, 6, 20),
      id: 'move',
      category: 'Transfer',
      type: 'transfer',
      toAccountId: 'a2',
    );
    final split = [pay, food, dinner, back1, back2, move];

    // The web's `monthlyFlow` for a month: {earned, spent} of `statsForPeriod`.
    Map<String, double>? bucket(List<Transaction> txns, int month) =>
        statsForPeriod(
          txns,
          StatsPeriod(year: 2026, month: month),
        ).monthlyBreakdown['2026-0$month'];
    double earned(List<Transaction> txns, int month) =>
        bucket(txns, month)?['earned'] ?? 0.0; // a month with no row is absent
    double sum(List<double> xs) => xs.fold(0.0, (a, b) => a + b);

    test('ownShare: a 100 € dinner for four counts 25', () {
      expect(
        [dinner, back1, back2, pay, food, move].map(ownShare).toList(),
        [-25, 0, 0, 2000, -50, 300],
        reason: 'shared expense, reimbursements, the rest',
      );
      expect(
        ownShare(tx(-33.34, june15, othersShare: 22.23)),
        -11.11,
        reason: 'rounded to the cent',
      );
    });

    test(
      'ownView: shared expenses carry their own share, reimbursements are dropped',
      () {
        final v = ownView(split);
        expect([for (final t in v) t.id], ['pay', 'food', 'dinner', 'move']);
        expect([for (final t in v) t.amount], [2000, -50, -25, 300]);
        expect(dinner.amount, -100, reason: 'the input is not mutated');
      },
    );

    test('own view by category: the dinner is 25 € in Eating out', () {
      expect(categorySpendForMonth(ownView(split), now: june15), {
        'Groceries': 50.0,
        'Eating out': 25.0,
      }, reason: 'own');
      expect(categorySpendForMonth(split, now: june15), {
        'Eating out': 100.0,
        'Groceries': 50.0,
      }, reason: 'raw');
      expect(bucket(ownView(split), 6), {
        'earned': 2000.0,
        'spent': 75.0,
      }, reason: 'own flow');
      expect(bucket(split, 6), {
        'earned': 2025.0,
        'spent': 150.0,
      }, reason: 'raw flow');
    });

    test('month boundary: the expense in June, its reimbursement in July', () {
      expect(earned(ownView(split), 7), 0.0, reason: 'own July income');
      expect(earned(split, 7), 25.0, reason: 'raw July income');
      // The web's `incomeExpenseHistory` [[5, 2000, 75], [6, 0, 0]]: its net.
      expect(
        monthlyNetFlow(ownView(split), now: now, months: 2),
        [1925, 0],
        reason: 'June, July',
      );
    });

    test('dangling reimbursesId: still never income', () {
      final lost = tx(
        40,
        june15,
        id: 'lost',
        category: 'Gifts',
        type: 'income',
        reimbursesId: 'gone',
      );
      expect(ownShare(lost), 0, reason: 'ownShare');
      expect(
        [for (final t in ownView([pay, lost])) t.id],
        ['pay'],
        reason: 'dropped from the own view',
      );
      expect(
        earned(ownView([pay, lost]), 6),
        2000.0,
        reason: 'own June income',
      );
      expect(
        receivable(dinner, [dinner, lost]).received,
        0,
        reason: 'not received by the dinner',
      );
    });

    test('receivable: owed, received, outstanding, on the raw list', () {
      expect(receivable(dinner, split), (
        owed: 75.0,
        received: 50.0,
        outstanding: 25.0,
      ), reason: 'two reimbursements');
      // The web's `isDeleted: true` variant: a deleted row never reaches the
      // Dart model, so it is left out of the list.
      expect(receivable(dinner, [pay, food, dinner, back2, move]), (
        owed: 75.0,
        received: 25.0,
        outstanding: 50.0,
      ), reason: 'a deleted reimbursement is not received');
      expect(receivable(food, split), (
        owed: 0.0,
        received: 0.0,
        outstanding: 0.0,
      ), reason: 'not shared');
      expect(receivable(dinner, ownView(split)), (
        owed: 75.0,
        received: 0.0,
        outstanding: 75.0,
      ), reason: 'the own view has no reimbursements left: it takes the raw list');
    });

    test('over-payment: more received than owed moves no analytic', () {
      final extra = tx(
        50,
        at(2026, 7, 10),
        id: 'extra',
        category: 'Gifts',
        type: 'income',
        reimbursesId: 'dinner',
      );
      final all = [...split, extra];
      expect(receivable(dinner, all), (
        owed: 75.0,
        received: 100.0,
        outstanding: -25.0,
      ), reason: 'over-paid');
      expect(categorySpendForMonth(ownView(all), now: june15), {
        'Groceries': 50.0,
        'Eating out': 25.0,
      }, reason: 'June unchanged');
      expect(earned(ownView(all), 7), 0.0, reason: 'July own income');
    });

    test(
      'own share 0: a fully paid-back expense leaves the category totals',
      () {
        final gift = tx(
          -60,
          at(2026, 6, 8),
          id: 'gift',
          category: 'Gifts',
          othersShare: 60,
        );
        final over = tx(
          -40,
          at(2026, 6, 9),
          id: 'over',
          category: 'Gifts',
          othersShare: 80,
        );
        final v = ownView([food, gift, over]);
        expect(
          [for (final t in v) t.amount],
          [-50, 0, 0],
          reason: 'shares 50, 0 and 0 (over-paid, never negative)',
        );
        expect(
          [for (final t in v) t.amount.isNegative],
          [true, false, false],
          reason: 'a zero share is 0.0, never a -0.0 that formats "-0,00"',
        );
        expect(categorySpendForMonth(v, now: june15), {
          'Groceries': 50.0,
        }, reason: 'June');
        // `topExpenses` (largest expenses) is web only, not ported.
      },
    );

    test('transfers and balances stay raw', () {
      expect(
        identical(ownView([move]).single, move),
        isTrue,
        reason: 'a transfer is untouched',
      );
      // The web's `liveBalance` bullets are not ported here: the app's balance
      // is `FinanceService.getAccounts`, whose suite is account_balance_test.dart.
    });

    test('budget pacing counts the own share', () {
      const limit = 50.0; // an Eating out budget for June
      final own = categorySpendForMonth(ownView(split), now: june15);
      final raw = categorySpendForMonth(split, now: june15);
      expect([own['Eating out'], own['Eating out']! / limit], [25.0, 0.5]);
      expect(raw['Eating out'], 100.0, reason: 'raw');
      // The web's budget `level` is web only, not ported.
    });

    test('savings: a reimbursement is not money saved', () {
      final own = monthlyNetFlow(ownView(split), now: now, months: 12);
      expect(own[10], 1925.0, reason: 'June');
      expect(sum(own), 1925.0, reason: 'own year to date');
      final raw = monthlyNetFlow(split, now: now, months: 12);
      expect([raw[10], raw[11]], [1875.0, 25.0], reason: 'raw June, July');
      expect(sum(raw), 1900.0, reason: 'raw year to date');
      // `positive`, `complete` and `bestNet` are web only, not ported.
    });

    test('splitShare: split in N', () {
      expect(
        [
          splitShare(-100, 4),
          splitShare(100, 3),
          splitShare(-50, 2),
          splitShare(-100, 1),
          splitShare(-100, 0),
        ],
        [75.0, 66.67, 25.0, 0.0, 0.0],
        reason: 'N = 4, 3, 2, 1, 0',
      );
    });

    // Not in the web suite (no dashboard there): note it in the PR so the web
    // may add it.
    test('dashboardStats: totals at the own share, recent rows raw', () {
      final stats = dashboardStats(split, const [], now: at(2026, 6, 25));

      expect(stats.monthlyExpenses, 75.0, reason: 'dinner 25 + groceries 50');
      expect(stats.monthlyIncome, 2000.0, reason: 'no reimbursement in it');
      expect(stats.netFlow, 1925.0, reason: '30 days: 2000 - 50 - 25');
      expect(
        [for (final t in stats.recentTransactions) t.amount],
        [2000, -50, -100, 25, 25, 300],
        reason: 'the rows are raw: the dinner at -100, both reimbursements',
      );
    });

    test('statsForPeriod and chartSeries over the own view: category, tag, series',
        () {
      final trip = tx(
        -20,
        at(2026, 6, 18),
        id: 'trip',
        category: 'Eating out',
        tags: ['Trip'],
      );
      final rows = [dinner.copyWith(tags: ['Trip']), back1, trip];
      final june = StatsPeriod(year: 2026, month: 6);

      final s = statsForPeriod(ownView(rows), june);
      expect(s.categoryTotals, {'Eating out': 45.0}, reason: '25 + 20');
      expect(s.tagTotals, {'Trip': 45.0}, reason: 'the dinner counts 25');
      expect(s.totalExpenses, 45.0);
      expect(s.monthlyBreakdown['2026-06'], {
        'earned': 0.0,
        'spent': 45.0,
      }, reason: 'the reimbursement adds nothing to earned');
      expect(statsForPeriod(rows, june).totalExpenses, 120.0, reason: 'raw');

      final c = chartSeries(ownView(rows), june, ChartGranularity.daily);
      expect([for (final p in c.expenses) p.amount], [25.0, 20.0]);
      expect(c.income, isEmpty, reason: 'nor to the income series');
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
