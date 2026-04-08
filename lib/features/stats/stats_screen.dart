import 'dart:math' as math;
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/models/category.dart';
import 'package:budgetti/features/stats/category_details_screen.dart';
import 'package:budgetti/features/stats/widgets/stats_filter_bar.dart';
import 'package:budgetti/features/charts/widgets/spending_line_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(selectedStatsPeriodProvider);
    final statsAsync = ref.watch(statsDataProvider(period));
    final categoryMap = ref.watch(categoryMapProvider);
    final currencyFormatter = ref.watch(currencyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Stats",
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.textWhite,
          ),
        ),
      ),
      body: statsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryGreen),
        ),
        error: (err, _) => Center(child: Text("Error: $err")),
        data: (stats) {
          if (stats.categoryTotals.isEmpty && stats.monthlyBreakdown.isEmpty) {
            return Center(
              child: Text(
                "No transactions in ${period.year}",
                style: const TextStyle(color: AppTheme.textGrey),
              ),
            );
          }

          final totalExpenses = stats.totalExpenses;
          final scope = ref.watch(statsScopeProvider);
          final sortedCategoryEntries = stats.categoryTotals.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          return CustomScrollView(
            slivers: [
              // 0. Filter chips (scope + view + period)
              const SliverToBoxAdapter(
                child: StatsFilterBar(),
              ),

              // 1. Quick Insights Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildQuickInsights(
                    stats,
                    currencyFormatter,
                    period,
                    scope,
                  ),
                ),
              ),

              // 2. Spending Trends Header
              SliverToBoxAdapter(
                child: _buildSectionHeader(context, "Spending Trends"),
              ),

              // 3. Spending Line Chart
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const SpendingLineChart(),
                ),
              ),

              // 4. Category Distribution Header
              SliverToBoxAdapter(
                child: _buildSectionHeader(context, "Category Distribution"),
              ),

              // 5. Pie Chart
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 260,
                  child: _buildPieChart(
                    sortedCategoryEntries,
                    categoryMap,
                    totalExpenses,
                    currencyFormatter,
                  ),
                ),
              ),

              // 6. Category Details List
              _buildCategorySliverList(
                sortedCategoryEntries,
                categoryMap,
                totalExpenses,
                currencyFormatter,
              ),

              // 7. Monthly Breakdown (Only in Yearly Mode)
              if (period.month == null) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(
                  child: _buildSectionHeader(context, "Monthly Breakdown"),
                ),
                _buildMonthlyBreakdownSliver(
                  stats.monthlyBreakdown,
                  currencyFormatter,
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildQuickInsights(
    StatsData stats,
    dynamic currencyFormatter,
    StatsPeriod period,
    StatsScope scope,
  ) {
    final now = DateTime.now();
    final totalExpenses = stats.totalExpenses;
    final isMonthlyMode = period.month != null;

    final monthKey = DateFormat('yyyy-MM').format(now);
    final currentMonthData = stats.monthlyBreakdown[monthKey];
    final currentMonthSpent = currentMonthData?['spent'] ?? 0.0;

    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final currentDay = now.day;
    final predictedTotal = period.year == now.year && currentMonthSpent > 0
        ? (currentMonthSpent / currentDay) * daysInMonth
        : 0.0;

    final daysToDivide = isMonthlyMode
        ? (period.year == now.year && period.month == now.month
              ? now.day
              : DateTime(period.year, period.month! + 1, 0).day)
        : 365;
    final dailyAvg = totalExpenses / daysToDivide;

    final totalEarned = stats.monthlyBreakdown.values.fold(
      0.0,
      (sum, val) => sum + (val['earned'] ?? 0.0),
    );
    final netFlow = totalEarned - totalExpenses;

    final showPrediction = period.year == now.year &&
        (!isMonthlyMode || period.month == now.month) &&
        predictedTotal > 0;

    // 4th card: Predicted if current period, otherwise Savings Rate
    Widget fourthCard;
    if (showPrediction) {
      fourthCard = Expanded(
        child: _InsightCard(
          title: "Predicted (Mo)",
          value: currencyFormatter.format(predictedTotal),
          icon: Icons.trending_up,
          color: Colors.orangeAccent,
        ),
      );
    } else if (totalEarned > 0) {
      final savingsRate = (netFlow / totalEarned * 100);
      fourthCard = Expanded(
        child: _InsightCard(
          title: "Savings Rate",
          value: "${savingsRate.toStringAsFixed(0)}%",
          icon: Icons.savings,
          color: savingsRate >= 0 ? AppTheme.primaryGreen : Colors.redAccent,
        ),
      );
    } else {
      fourthCard = Expanded(
        child: _InsightCard(
          title: "Savings Rate",
          value: "N/A",
          icon: Icons.savings,
          color: AppTheme.textGrey,
        ),
      );
    }

    final scopeNoun = switch (scope) {
      StatsScope.expenses => 'Spent',
      StatsScope.income => 'Earned',
      StatsScope.all => 'Activity',
    };
    final scopeValue = switch (scope) {
      StatsScope.expenses => totalExpenses,
      StatsScope.income => totalEarned,
      StatsScope.all => totalEarned + totalExpenses,
    };

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _InsightCard(
                title: isMonthlyMode
                    ? "Total $scopeNoun"
                    : "Total $scopeNoun (${period.year})",
                value: currencyFormatter.format(scopeValue),
                icon: Icons.account_balance_wallet,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InsightCard(
                title: "Daily Avg",
                value: currencyFormatter.format(dailyAvg),
                icon: Icons.calendar_today,
                color: Colors.blueAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _InsightCard(
                title: "Net Flow",
                value:
                    (netFlow >= 0 ? "+" : "") +
                    currencyFormatter.format(netFlow),
                icon: Icons.unfold_more,
                color: netFlow >= 0 ? AppTheme.primaryGreen : Colors.redAccent,
              ),
            ),
            const SizedBox(width: 12),
            fourthCard,
          ],
        ),
      ],
    );
  }

  Widget _buildPieChart(
    List<MapEntry<String, double>> sortedCategoryEntries,
    Map<String, Category> categoryMap,
    double totalExpenses,
    dynamic currencyFormatter,
  ) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: 260,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      touchedIndex = -1;
                      return;
                    }
                    touchedIndex =
                        pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 4,
              centerSpaceRadius: 50,
              sections: sortedCategoryEntries.asMap().entries.map((entry) {
                final idx = entry.key;
                final data = entry.value;
                final category =
                    categoryMap[data.key] ??
                    Category(
                      id: '',
                      userId: '',
                      name: data.key,
                      iconCode: Icons.help_outline.codePoint,
                      colorHex: 0xFF9E9E9E,
                      type: 'expense',
                    );
                final isTouched = idx == touchedIndex;
                final fontSize = isTouched ? 18.0 : 12.0;
                final radius = isTouched ? 70.0 : 60.0;
                final percentage =
                    (data.value / totalExpenses * 100).toStringAsFixed(1);

                return PieChartSectionData(
                  color: Color(category.colorHex),
                  value: data.value,
                  title: isTouched ? "$percentage%" : '',
                  radius: radius,
                  titleStyle: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Total",
              style: TextStyle(color: AppTheme.textGrey, fontSize: 11),
            ),
            Text(
              currencyFormatter.format(totalExpenses),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategorySliverList(
    List<MapEntry<String, double>> sortedCategoryEntries,
    Map<String, Category> categoryMap,
    double totalExpenses,
    dynamic currencyFormatter,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final entry = sortedCategoryEntries[index];
          final category =
              categoryMap[entry.key] ??
              Category(
                id: '',
                userId: '',
                name: entry.key,
                iconCode: Icons.help_outline.codePoint,
                colorHex: 0xFF9E9E9E,
                type: 'expense',
              );

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        CategoryDetailsScreen(category: category),
                  ),
                );
              },
              child: _buildCategoryRow(
                entry,
                categoryMap,
                totalExpenses,
                currencyFormatter,
              ),
            ),
          );
        }, childCount: sortedCategoryEntries.length),
      ),
    );
  }

  Widget _buildCategoryRow(
    MapEntry<String, double> entry,
    Map<String, Category> categoryMap,
    double total,
    dynamic currencyFormatter,
  ) {
    final category =
        categoryMap[entry.key] ??
        Category(
          id: '',
          userId: '',
          name: entry.key,
          iconCode: Icons.help_outline.codePoint,
          colorHex: 0xFF9E9E9E,
          type: 'expense',
        );
    final percentage = (entry.value / total * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(category.colorHex).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(category.colorHex).withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color(category.colorHex).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              IconData(category.iconCode, fontFamily: 'MaterialIcons'),
              color: Color(category.colorHex),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                Text(
                  "$percentage% of total",
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            currencyFormatter.format(entry.value),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyBreakdownSliver(
    Map<String, Map<String, double>> monthlyData,
    dynamic currencyFormatter,
  ) {
    final sortedMonths = monthlyData.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final monthKey = sortedMonths[index];
        final data = monthlyData[monthKey]!;
        final earned = data['earned'] ?? 0.0;
        final spent = data['spent'] ?? 0.0;
        final netFlow = earned - spent;
        final netIsPositive = netFlow >= 0;
        final displayMonth = DateFormat(
          'MMMM yyyy',
        ).format(DateTime.parse("$monthKey-01"));

        return _MonthlyBreakdownCard(
          month: displayMonth,
          earned: earned,
          spent: spent,
          netFlow: netFlow,
          netIsPositive: netIsPositive,
          currencyFormatter: currencyFormatter,
        );
      }, childCount: sortedMonths.length),
    );
  }
}

class _MonthlyBreakdownCard extends StatelessWidget {
  final String month;
  final double earned;
  final double spent;
  final double netFlow;
  final bool netIsPositive;
  final dynamic currencyFormatter;

  const _MonthlyBreakdownCard({
    required this.month,
    required this.earned,
    required this.spent,
    required this.netFlow,
    required this.netIsPositive,
    required this.currencyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final max = math.max(earned, spent);

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGrey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: netIsPositive
              ? AppTheme.primaryGreen.withValues(alpha: 0.15)
              : Colors.redAccent.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                month,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              _NetChip(amount: netFlow, currencyFormatter: currencyFormatter),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniProgressBar(
                  label: "Earned",
                  amount: earned,
                  color: AppTheme.primaryGreen,
                  ratio: max > 0 ? earned / max : 0.0,
                  currencyFormatter: currencyFormatter,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MiniProgressBar(
                  label: "Spent",
                  amount: spent,
                  color: spent > earned ? Colors.redAccent : AppTheme.textGrey,
                  ratio: max > 0 ? spent / max : 0.0,
                  currencyFormatter: currencyFormatter,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NetChip extends StatelessWidget {
  final double amount;
  final dynamic currencyFormatter;

  const _NetChip({required this.amount, required this.currencyFormatter});

  @override
  Widget build(BuildContext context) {
    final isPositive = amount >= 0;
    final color = isPositive ? AppTheme.primaryGreen : Colors.redAccent;
    final prefix = isPositive ? "+" : "";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "$prefix${currencyFormatter.format(amount)}",
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MiniProgressBar extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final double ratio;
  final dynamic currencyFormatter;

  const _MiniProgressBar({
    required this.label,
    required this.amount,
    required this.color,
    required this.ratio,
    required this.currencyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            backgroundColor: AppTheme.surfaceGreyLight,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          currencyFormatter.format(amount),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _InsightCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

