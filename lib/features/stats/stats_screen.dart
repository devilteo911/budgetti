import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/models/category.dart';
import 'package:budgetti/features/stats/category_details_screen.dart';
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
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(statsDataProvider(_selectedYear));
    final categoryMap = ref.watch(categoryMapProvider);
    final currencyFormatter = ref.watch(currencyProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundBlack,
        appBar: AppBar(
          title: Row(
            children: [
              Text(
                "Stats",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textWhite,
                ),
              ),
              const Spacer(),
              // Year Selector
              IconButton(
                icon: const Icon(
                  Icons.arrow_left,
                  color: AppTheme.primaryGreen,
                ),
                onPressed: () => setState(() => _selectedYear--),
              ),
              Text(
                "$_selectedYear",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.arrow_right,
                  color: AppTheme.primaryGreen,
                ),
                onPressed: () => setState(() => _selectedYear++),
              ),
            ],
          ),
          bottom: const TabBar(
            indicatorColor: AppTheme.primaryGreen,
            labelColor: AppTheme.primaryGreen,
            unselectedLabelColor: AppTheme.textGrey,
            tabs: [
              Tab(text: "Distribution"),
              Tab(text: "Mo. Breakdown"), 
              Tab(text: "Prediction"),
            ],
          ),
        ),
        body: statsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryGreen),
          ),
          error: (err, _) => Center(child: Text("Error: $err")),
          data: (stats) {
            if (stats.categoryTotals.isEmpty &&
                stats.monthlyBreakdown.isEmpty) {
              return Center(
                child: Text(
                  "No transactions in $_selectedYear",
                  style: const TextStyle(color: AppTheme.textGrey),
                ),
              );
            }

            return TabBarView(
              children: [
                _buildDistributionTab(
                  stats.categoryTotals,
                  categoryMap,
                  currencyFormatter,
                ),
                _buildMonthlyTableTab(
                  stats.monthlyBreakdown,
                  currencyFormatter,
                ),
                _selectedYear == DateTime.now().year
                    ? _buildPredictionTab(
                        stats.categoryTotals,
                        categoryMap,
                        currencyFormatter,
                      )
                    : const Center(
                        child: Text(
                          "Prediction available for current year only",
                          style: TextStyle(color: AppTheme.textGrey),
                        ),
                      ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDistributionTab(
    Map<String, double> categoryTotals,
    Map<String, Category> categoryMap,
    dynamic currencyFormatter,
  ) {
    final sortedCategoryEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalExpenses = categoryTotals.values.fold(
      0.0,
      (sum, val) => sum + val,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1.3,
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
                  final fontSize = isTouched ? 20.0 : 12.0;
                  final radius = isTouched ? 70.0 : 60.0;
                  final percentage = (data.value / totalExpenses * 100)
                      .toStringAsFixed(1);

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
          const SizedBox(height: 10),
          Text(
            "Total Expenses",
            style: TextStyle(color: AppTheme.textGrey, fontSize: 16),
          ),
          Text(
            currencyFormatter.format(totalExpenses),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          ...sortedCategoryEntries.map(
            (entry) => GestureDetector(
              onTap: () {
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
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionTab(
    Map<String, double> categoryTotals,
    Map<String, Category> categoryMap,
    dynamic currencyFormatter,
  ) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final currentDay = now.day;

    final currentTotal = categoryTotals.values.fold(
      0.0,
      (sum, val) => sum + val,
    );
    final predictedTotal = (currentTotal / currentDay) * daysInMonth;

    final predictedCategoryEntries = categoryTotals.entries.map((e) {
      return MapEntry(e.key, (e.value / currentDay) * daysInMonth);
    }).toList()..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.primaryGreen.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                const Text(
                  "Predicted Monthly Expense",
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  currencyFormatter.format(predictedTotal),
                  style: const TextStyle(
                    color: AppTheme.primaryGreen,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.trending_up,
                      color: AppTheme.textGrey,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Based on ${now.day} days of spending",
                      style: const TextStyle(
                        color: AppTheme.textGrey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Predicted by Category",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...predictedCategoryEntries.map(
            (entry) => _buildCategoryRow(
              entry,
              categoryMap,
              predictedTotal,
              currencyFormatter,
              isPrediction: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(
    MapEntry<String, double> entry,
    Map<String, Category> categoryMap,
    double total,
    dynamic currencyFormatter, {
    bool isPrediction = false,
  }) {
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(category.colorHex).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(category.colorHex).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color(category.colorHex).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Color(category.colorHex).withValues(alpha: 0.3),
              ),
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
                  "$percentage% ${isPrediction ? 'of prediction' : ''}",
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceGrey,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.surfaceGreyLight, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
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
