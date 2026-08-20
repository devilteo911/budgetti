/// Every derivation the dashboard, stats and charts run over a list of
/// transactions, as pure functions.
///
/// They lived inline in `providers.dart`, where the only way to exercise them
/// was to build a widget tree with a seeded database — so none of them were
/// tested, and the sign and transfer rules drifted between them. Every
/// function here takes `now` as a parameter so a test can pin the clock.
///
/// The income/expense rule is always the model's ([Transaction.isIncome] /
/// [Transaction.isExpense]): transfers are neither, and the sign decides.
/// `web/src/finance.ts` is the mirror — change one, change both.
library;

import 'package:intl/intl.dart';

import 'package:budgetti/models/account.dart';
import 'package:budgetti/models/transaction.dart';

const _monthKeyFormat = 'yyyy-MM';

/// `2026-08` for a date — the key both clients use for a month bucket.
String monthKey(DateTime d) => DateFormat(_monthKeyFormat).format(d);

/// The last [count] month keys, oldest first, ending with the month of [now].
List<String> lastMonthKeys(int count, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  return List.generate(
    count,
    (i) => monthKey(DateTime(ref.year, ref.month - (count - 1) + i, 1)),
  );
}

class DashboardStats {
  final double totalBalance;
  final double monthlyIncome;
  final double monthlyExpenses;
  final double netFlow;
  final List<Transaction> recentTransactions;

  DashboardStats({
    required this.totalBalance,
    required this.monthlyIncome,
    required this.monthlyExpenses,
    required this.recentTransactions,
    required this.netFlow,
  });

  double get monthlyNetFlow => monthlyIncome - monthlyExpenses;
}

/// Balance across all wallets, this calendar month's income and expenses, the
/// rolling 30-day net flow, and the newest [recentCount] rows.
///
/// [transactions] must already be newest-first — the caller's query orders it.
DashboardStats dashboardStats(
  List<Transaction> transactions,
  List<Account> accounts, {
  DateTime? now,
  int recentCount = 10,
}) {
  final ref = now ?? DateTime.now();
  final last30Days = ref.subtract(const Duration(days: 30));

  var monthlyIncome = 0.0;
  var monthlyExpenses = 0.0;
  var netFlow = 0.0;
  for (final t in transactions) {
    if (t.date.year == ref.year && t.date.month == ref.month) {
      if (t.isIncome) {
        monthlyIncome += t.amount;
      } else if (t.isExpense) {
        monthlyExpenses += t.amount.abs();
      }
    }
    // Transfers excluded: a wallet-to-wallet move is neither, and transfers
    // are stored positive — summing them raw shows a self-transfer as growth.
    if (t.date.isAfter(last30Days) && t.type != 'transfer') {
      netFlow += t.amount;
    }
  }

  return DashboardStats(
    totalBalance: accounts.fold(0.0, (sum, a) => sum + a.balance),
    monthlyIncome: monthlyIncome,
    monthlyExpenses: monthlyExpenses,
    netFlow: netFlow,
    recentTransactions: transactions.take(recentCount).toList(),
  );
}

/// Signed net flow per month for the last [months] months, oldest first.
/// Months with no activity are 0, not absent — the sparkline needs a slot.
List<double> monthlyNetFlow(
  List<Transaction> transactions, {
  DateTime? now,
  int months = 6,
}) {
  final keys = lastMonthKeys(months, now: now);
  final buckets = {for (final k in keys) k: 0.0};
  for (final t in transactions) {
    if (t.type == 'transfer') continue;
    final k = monthKey(t.date);
    if (buckets.containsKey(k)) buckets[k] = buckets[k]! + t.amount;
  }
  return [for (final k in keys) buckets[k]!];
}

/// Category → amount spent this calendar month. Expenses only, positive.
Map<String, double> categorySpendForMonth(
  List<Transaction> transactions, {
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final spend = <String, double>{};
  for (final t in transactions) {
    if (t.date.year != ref.year || t.date.month != ref.month) continue;
    if (!t.isExpense) continue;
    spend[t.category] = (spend[t.category] ?? 0) + t.amount.abs();
  }
  return spend;
}

/// Month key → amount spent, restricted to [months] and pre-zeroed so the
/// trend chart has a bar for every month in the window.
Map<String, double> spendByMonth(
  List<Transaction> transactions,
  List<String> months,
) {
  final map = {for (final m in months) m: 0.0};
  for (final t in transactions) {
    final k = monthKey(t.date);
    if (map.containsKey(k)) map[k] = map[k]! + t.amount.abs();
  }
  return map;
}

class StatsPeriod {
  final int year;
  final int? month;

  StatsPeriod({required this.year, this.month});

  /// Whether a row falls inside this period. A null [month] means the year.
  bool contains(DateTime date) =>
      date.year == year && (month == null || date.month == month);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatsPeriod &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          month == other.month;

  @override
  int get hashCode => year.hashCode ^ month.hashCode;
}

class StatsData {
  final Map<String, double> categoryTotals;

  /// Can sum above [totalExpenses]: a transaction carrying several tags counts
  /// once per tag.
  final Map<String, double> tagTotals;
  final Map<String, Map<String, double>> monthlyBreakdown;
  final double totalExpenses;

  StatsData({
    required this.categoryTotals,
    required this.tagTotals,
    required this.monthlyBreakdown,
    required this.totalExpenses,
  });
}

/// Category, tag and per-month totals for the rows of [period].
///
/// Filters by [period] itself rather than trusting the caller's query, which
/// fetches a whole year even when a single month is selected.
StatsData statsForPeriod(List<Transaction> transactions, StatsPeriod period) {
  final categoryTotals = <String, double>{};
  final tagTotals = <String, double>{};
  final monthlyBreakdown = <String, Map<String, double>>{};
  var totalExpenses = 0.0;

  for (final t in transactions) {
    if (!period.contains(t.date)) continue;

    if (t.isExpense) {
      final spent = t.amount.abs();
      categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + spent;
      for (final tag in t.tags) {
        tagTotals[tag] = (tagTotals[tag] ?? 0) + spent;
      }
      totalExpenses += spent;
    }

    final bucket = monthlyBreakdown.putIfAbsent(
      monthKey(t.date),
      () => {'earned': 0.0, 'spent': 0.0},
    );
    if (t.isIncome) {
      bucket['earned'] = bucket['earned']! + t.amount;
    } else if (t.isExpense) {
      bucket['spent'] = bucket['spent']! + t.amount.abs();
    }
  }

  return StatsData(
    categoryTotals: categoryTotals,
    tagTotals: tagTotals,
    monthlyBreakdown: monthlyBreakdown,
    totalExpenses: totalExpenses,
  );
}

enum ChartGranularity { daily, weekly, monthly }

class ChartDataPoint {
  final DateTime label;
  final double amount;

  ChartDataPoint(this.label, this.amount);
}

/// Per-bucket trend series, split by sign. Scoped stats modes plot one of the
/// two; "all" overlays both — a single abs() series would mash income and
/// expenses into "money moved", which says nothing.
class ChartSeries {
  final List<ChartDataPoint> expenses;
  final List<ChartDataPoint> income;

  ChartSeries({required this.expenses, required this.income});

  bool get isEmpty => expenses.isEmpty && income.isEmpty;
}

/// Start of the bucket a date falls in, at the given granularity. Weeks start
/// on Monday.
DateTime bucketStart(DateTime date, ChartGranularity granularity) =>
    switch (granularity) {
      ChartGranularity.daily => DateTime(date.year, date.month, date.day),
      ChartGranularity.weekly => DateTime(
        date.year,
        date.month,
        date.day - (date.weekday - 1),
      ),
      ChartGranularity.monthly => DateTime(date.year, date.month, 1),
    };

/// Expense and income series over [period], bucketed and sorted oldest first.
ChartSeries chartSeries(
  List<Transaction> transactions,
  StatsPeriod period,
  ChartGranularity granularity,
) {
  final expenseBuckets = <DateTime, double>{};
  final incomeBuckets = <DateTime, double>{};

  for (final t in transactions) {
    if (!period.contains(t.date)) continue;
    // Transfers are stored positive and would land in the income series.
    if (t.amount == 0 || t.type == 'transfer') continue;
    final key = bucketStart(t.date, granularity);
    final buckets = t.amount < 0 ? expenseBuckets : incomeBuckets;
    buckets[key] = (buckets[key] ?? 0) + t.amount.abs();
  }

  List<ChartDataPoint> sorted(Map<DateTime, double> buckets) {
    final keys = buckets.keys.toList()..sort();
    return [for (final k in keys) ChartDataPoint(k, buckets[k]!)];
  }

  return ChartSeries(
    expenses: sorted(expenseBuckets),
    income: sorted(incomeBuckets),
  );
}
