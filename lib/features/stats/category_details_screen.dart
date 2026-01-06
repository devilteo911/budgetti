import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/models/category.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class CategoryDetailsScreen extends ConsumerWidget {
  final Category category;

  const CategoryDetailsScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider('1')); // Assuming account '1' for now
    final currencyFormatter = ref.watch(currencyProvider);
    final categoryColor = Color(category.colorHex);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppTheme.backgroundBlack,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.backgroundBlack,
        appBar: AppBar(
          title: Text(category.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.backgroundBlack,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
      body: transactionsAsync.when(
        data: (transactions) {
          final categoryTransactions = transactions
              .where((t) => t.category == category.name)
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));

          if (categoryTransactions.isEmpty) {
            return _buildEmptyState();
          }

          final monthlyAggregated = _aggregateByMonth(categoryTransactions);
          final sortedMonths = monthlyAggregated.keys.toList()..sort();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                 // Centered Icon and Name
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: categoryColor.withValues(alpha: 0.4), width: 2),
                  ),
                  child: Icon(
                    IconData(category.iconCode, fontFamily: 'MaterialIcons'),
                    color: categoryColor,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  category.name,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                
                // Description
                if (category.description != null && category.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      category.description!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textGrey, fontSize: 16),
                    ),
                  ),
                ],
                
                const SizedBox(height: 48),

                // Trend Plot
                _buildSectionTitle(context, "Spending Trend"),
                const SizedBox(height: 16),
                _buildChart(sortedMonths, monthlyAggregated, categoryColor),
                
                const SizedBox(height: 40),

                // Monthly List
                _buildSectionTitle(context, "Monthly Summary"),
                const SizedBox(height: 16),
                _buildMonthlyList(sortedMonths, monthlyAggregated, currencyFormatter, categoryColor),
                
                const SizedBox(height: 40),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text("Error: $e")),
      ),
    ),
  );
}

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  double _getRoundedMax(double maxVal) {
    if (maxVal <= 0) return 100;
    // Find the next power of 10 that comfortably fits the max value
    double log10 = (math.log(maxVal) / math.ln10).floorToDouble();
    double powerOf10 = math.pow(10, log10).toDouble();
    
    // Choose a nice step (1x, 2x, 5x the power of 10)
    if (maxVal <= powerOf10) return powerOf10;
    if (maxVal <= powerOf10 * 2) return powerOf10 * 2;
    if (maxVal <= powerOf10 * 5) return powerOf10 * 5;
    return powerOf10 * 10;
  }

  Widget _buildChart(List<String> months, Map<String, double> data, Color color) {
    if (months.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text("No data for trend plot", style: TextStyle(color: AppTheme.textGrey)),
      );
    }

    final maxVal = data.values.isEmpty ? 0.0 : data.values.reduce(math.max);
    final roundedMax = _getRoundedMax(maxVal);

    final barGroups = List.generate(months.length, (i) {
      final value = data[months[i]]!;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: value,
            color: color,
            width: 8, // Thinner bars for 12 months
            borderRadius: BorderRadius.circular(2),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: roundedMax,
              color: color.withValues(alpha: 0.1),
            ),
          ),
        ],
      );
    });

    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          maxY: roundedMax,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppTheme.surfaceGrey,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  "${DateFormat('MMM yyyy').format(DateTime.parse("${months[groupIndex]}-01"))}\n",
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(
                      text: rod.toY.toStringAsFixed(2),
                      style: TextStyle(color: color, fontWeight: FontWeight.w500),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= months.length) return const SizedBox();
                  // Show every 2nd or 3rd month title if it gets too crowded
                  if (index % 2 != 0) return const SizedBox();
                  
                  final date = DateTime.parse("${months[index]}-01");
                  return SideTitleWidget(
                    meta: meta,
                    space: 12,
                    child: Text(
                      DateFormat('MMM').format(date),
                      style: const TextStyle(
                        color: Color(0xff7589a2),
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  );
                },
                reservedSize: 32,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                // Set interval to get nice ticks (roundedMax / 5)
                interval: roundedMax / 5,
                getTitlesWidget: (value, meta) {
                  if (value < 0) return const SizedBox();
                  return SideTitleWidget(
                    meta: meta,
                    space: 8,
                    child: Text(
                      NumberFormat.compact().format(value),
                      style: const TextStyle(
                        color: Color(0xff7589a2),
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: roundedMax / 5,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppTheme.surfaceGreyLight.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          barGroups: barGroups,
        ),
      ),
    );
  }

  Widget _buildMonthlyList(List<String> months, Map<String, double> data, dynamic formatter, Color color) {
    final monthsWithData = months.where((m) => data[m]! > 0).toList();
    final reversedMonths = monthsWithData.reversed.toList();
    
    if (reversedMonths.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(child: Text("No recorded spending", style: TextStyle(color: AppTheme.textGrey))),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reversedMonths.length,
      itemBuilder: (context, index) {
        final monthKey = reversedMonths[index];
        final amount = data[monthKey]!;
        final date = DateTime.parse("$monthKey-01");
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceGrey,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(date),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Text(
                formatter.format(amount),
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        );
      },
    );
  }

  Map<String, double> _aggregateByMonth(List<Transaction> transactions) {
    final map = <String, double>{};
    
    // Initialize Jan-Dec of the current year with 0.0
    final now = DateTime.now();
    for (int i = 1; i <= 12; i++) {
      final date = DateTime(now.year, i, 1);
      final key = DateFormat('yyyy-MM').format(date);
      map[key] = 0.0;
    }

    for (var t in transactions) {
      final key = DateFormat('yyyy-MM').format(t.date);
      if (map.containsKey(key)) {
        map[key] = map[key]! + t.amount.abs();
      }
    }
    return map;
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text("No transactions for this category", style: TextStyle(color: AppTheme.textGrey)),
    );
  }
}
