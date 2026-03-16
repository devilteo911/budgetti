import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/models/category.dart';
import 'package:budgetti/features/stats/category_details_screen.dart';
import 'package:budgetti/features/charts/widgets/spending_bar_chart.dart';
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
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: Text(
          "Stats",
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.textWhite,
          ),
        ),
        actions: [
          _buildViewToggle(period),
          const SizedBox(width: 8),
        ],
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

          return CustomScrollView(
            slivers: [
              // 0. Period Selector
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _buildPeriodSelector(period),
                ),
              ),

              // 1. Quick Insights Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildQuickInsights(stats, currencyFormatter, period),
                ),
              ),

              // 2. Spending Trends Header
              SliverToBoxAdapter(
                child: _buildSectionHeader(context, "Spending Trends"),
              ),

              // 3. Spending Trends Chart
              SliverToBoxAdapter(
                child: const SizedBox(height: 300, child: SpendingBarChart()),
              ),

              // 4. Pie Chart Header
              SliverToBoxAdapter(
                child: _buildSectionHeader(context, "Category Distribution"),
              ),

              // 4. Pie Chart
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 300,
                  child: _buildPieChart(
                    stats.categoryTotals,
                    categoryMap,
                    totalExpenses,
                  ),
                ),
              ),

              // 5. Category Details List
              _buildCategorySliverList(
                stats.categoryTotals,
                categoryMap,
                totalExpenses,
                currencyFormatter,
              ),

              // 6. Monthly Breakdown Header (Only in Yearly Mode)
              if (period.month == null) ...[
                SliverToBoxAdapter(child: const SizedBox(height: 24)),
                SliverToBoxAdapter(
                  child: _buildSectionHeader(context, "Monthly Breakdown"),
                ),

                // 7. Monthly Table
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: _buildMonthlyTableTab(
                      stats.monthlyBreakdown,
                      currencyFormatter,
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildViewToggle(StatsPeriod period) {
    final isMonthlyMode = period.month != null;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleItem(
            label: "Year",
            isSelected: !isMonthlyMode,
            onTap: () {
              ref.read(selectedStatsPeriodProvider.notifier).setMonth(null);
              ref
                  .read(chartGranularityProvider.notifier)
                  .set(ChartGranularity.monthly);
            },
          ),
          _ToggleItem(
            label: "Month",
            isSelected: isMonthlyMode,
            onTap: () {
              ref
                  .read(selectedStatsPeriodProvider.notifier)
                  .setMonth(DateTime.now().month);
              ref
                  .read(chartGranularityProvider.notifier)
                  .set(ChartGranularity.daily);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(StatsPeriod period) {
    final isMonthlyMode = period.month != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_left, color: AppTheme.primaryGreen),
          onPressed: () {
            if (isMonthlyMode) {
              if (period.month == 1) {
                ref
                    .read(selectedStatsPeriodProvider.notifier)
                    .setYear(period.year - 1);
                ref.read(selectedStatsPeriodProvider.notifier).setMonth(12);
              } else {
                ref
                    .read(selectedStatsPeriodProvider.notifier)
                    .setMonth(period.month! - 1);
              }
            } else {
              ref
                  .read(selectedStatsPeriodProvider.notifier)
                  .setYear(period.year - 1);
            }
          },
        ),
        Text(
          isMonthlyMode
              ? DateFormat('MMM').format(DateTime(period.year, period.month!))
              : "${period.year}",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_right, color: AppTheme.primaryGreen),
          onPressed:
              (isMonthlyMode &&
                      period.year == DateTime.now().year &&
                      period.month == DateTime.now().month) ||
                  (!isMonthlyMode && period.year == DateTime.now().year)
              ? null
              : () {
                  if (isMonthlyMode) {
                    if (period.month == 12) {
                      ref
                          .read(selectedStatsPeriodProvider.notifier)
                          .setYear(period.year + 1);
                      ref
                          .read(selectedStatsPeriodProvider.notifier)
                          .setMonth(1);
                    } else {
                      ref
                          .read(selectedStatsPeriodProvider.notifier)
                          .setMonth(period.month! + 1);
                    }
                  } else {
                    ref
                        .read(selectedStatsPeriodProvider.notifier)
                        .setYear(period.year + 1);
                  }
                },
        ),
      ],
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
  ) {
    final now = DateTime.now();
    final totalExpenses = stats.totalExpenses;
    final isMonthlyMode = period.month != null;

    // Correct Prediction logic: Use current month's spending
    final monthKey = DateFormat('yyyy-MM').format(now);
    final currentMonthData = stats.monthlyBreakdown[monthKey];
    final currentMonthSpent = currentMonthData?['spent'] ?? 0.0;

    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final currentDay = now.day;
    final predictedTotal = period.year == now.year && currentMonthSpent > 0
        ? (currentMonthSpent / currentDay) * daysInMonth
        : 0.0;

    // Daily Average
    final daysToDivide = isMonthlyMode
        ? (period.year == now.year && period.month == now.month
              ? now.day
              : DateTime(period.year, period.month! + 1, 0).day)
        : 365;
    final dailyAvg = totalExpenses / daysToDivide;

    // Net Flow (Calculated from breakdown)
    final totalEarned = stats.monthlyBreakdown.values.fold(
      0.0,
      (sum, val) => sum + (val['earned'] ?? 0.0),
    );
    final netFlow = totalEarned - totalExpenses;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _InsightCard(
                title: isMonthlyMode
                    ? "Total Spent"
                    : "Total Spent (${period.year})",
                value: currencyFormatter.format(totalExpenses),
                icon: Icons.account_balance_wallet,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(width: 16),
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
        const SizedBox(height: 16),
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
            const SizedBox(width: 16),
            if (period.year == now.year &&
                (!isMonthlyMode || period.month == now.month) &&
                predictedTotal > 0)
              Expanded(
                child: _InsightCard(
                  title: "Predicted (This Mo)",
                  value: currencyFormatter.format(predictedTotal),
                  icon: Icons.trending_up,
                  color: Colors.orangeAccent,
                ),
              )
            else
              const Spacer(),
          ],
        ),
      ],
    );
  }

  Widget _buildPieChart(
    Map<String, double> categoryTotals,
    Map<String, Category> categoryMap,
    double totalExpenses,
  ) {
    final sortedCategoryEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return PieChart(
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
        centerSpaceRadius: 60,
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
          final percentage = (data.value / totalExpenses * 100).toStringAsFixed(
            1,
          );

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
    );
  }

  Widget _buildCategorySliverList(
    Map<String, double> categoryTotals,
    Map<String, Category> categoryMap,
    double totalExpenses,
    dynamic currencyFormatter,
  ) {
    final sortedCategoryEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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

  Widget _buildMonthlyTableTab(
    Map<String, Map<String, double>> monthlyData,
    dynamic currencyFormatter,
  ) {
    final sortedMonths = monthlyData.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceGrey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceGreyLight, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            horizontalMargin: 16,
            columnSpacing: 24,
            headingRowColor: WidgetStateProperty.all(AppTheme.surfaceGreyLight),
            columns: const [
              DataColumn(
                label: Text(
                  "Month",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  "Earned",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                numeric: true,
              ),
              DataColumn(
                label: Text(
                  "Spent",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                numeric: true,
              ),
              DataColumn(
                label: Text(
                  "Ratio",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                numeric: true,
              ),
            ],
            rows: sortedMonths.map((monthKey) {
              final data = monthlyData[monthKey]!;
              final earned = data['earned']!;
              final spent = data['spent']!;
              final overspent = spent > earned;
              final ratioStr = earned > 0
                  ? "${(spent / earned * 100).toStringAsFixed(0)}%"
                  : "-";

              final displayDate = DateFormat(
                'MMM yyyy',
              ).format(DateTime.parse("$monthKey-01"));

              return DataRow(
                color: WidgetStateProperty.resolveWith<Color?>((states) {
                  return overspent
                      ? Colors.red.withValues(alpha: 0.08)
                      : Colors.green.withValues(alpha: 0.08);
                }),
                cells: [
                  DataCell(
                    Text(
                      displayDate,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  DataCell(
                    Text(
                      currencyFormatter.format(earned),
                      style: const TextStyle(color: AppTheme.primaryGreen),
                    ),
                  ),
                  DataCell(
                    Text(
                      currencyFormatter.format(spent),
                      style: TextStyle(
                        color: overspent ? Colors.redAccent : Colors.white,
                      ),
                    ),
                  ),
                  DataCell(Text(ratioStr)),
                ],
              );
            }).toList(),
          ),
        ),
      ),
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
              Text(
                title,
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
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

class _ToggleItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
