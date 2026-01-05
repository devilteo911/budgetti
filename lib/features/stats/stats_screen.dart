import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/models/category.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider('1'));
    final categoriesAsync = ref.watch(categoriesProvider);
    final currencyFormatter = ref.watch(currencyProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundBlack,
        title: Text(
          "Stats",
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textWhite,
              ),
        ),
        centerTitle: false,
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
        error: (err, _) => Center(child: Text("Error: $err")),
        data: (transactions) => categoriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
          error: (err, _) => Center(child: Text("Error categories: $err")),
          data: (categories) {
            final expenses = transactions.where((t) => t.amount < 0).toList();
            if (expenses.isEmpty) {
              return const Center(child: Text("No expenses to show", style: TextStyle(color: AppTheme.textGrey)));
            }

            final categoryTotals = <String, double>{};
            for (var t in expenses) {
              categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount.abs();
            }

            final sortedCategoryEntries = categoryTotals.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            final totalExpenses = categoryTotals.values.fold(0.0, (sum, val) => sum + val);

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
                              touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 4,
                        centerSpaceRadius: 60,
                        sections: sortedCategoryEntries.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final data = entry.value;
                          final category = categories.firstWhere(
                            (c) => c.name == data.key,
                            orElse: () => Category(
                              id: '',
                              userId: '',
                              name: data.key,
                              iconCode: Icons.help_outline.codePoint,
                              colorHex: 0xFF9E9E9E,
                              type: 'expense',
                            ),
                          );
                          final isTouched = idx == touchedIndex;
                          final fontSize = isTouched ? 20.0 : 12.0;
                          final radius = isTouched ? 70.0 : 60.0;
                          final percentage = (data.value / totalExpenses * 100).toStringAsFixed(1);

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
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ...sortedCategoryEntries.map((entry) {
                    final category = categories.firstWhere(
                      (c) => c.name == entry.key,
                      orElse: () => Category(
                        id: '',
                        userId: '',
                        name: entry.key,
                        iconCode: Icons.help_outline.codePoint,
                        colorHex: 0xFF9E9E9E,
                        type: 'expense',
                      ),
                    );
                    final percentage = (entry.value / totalExpenses * 100).toStringAsFixed(1);

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
                                  "$percentage%",
                                  style: TextStyle(
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
                  }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
