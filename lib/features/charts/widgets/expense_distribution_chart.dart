import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/core/theme/ledger_style.dart';
import 'package:budgetti/models/category.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExpenseDistributionChart extends ConsumerStatefulWidget {
  const ExpenseDistributionChart({super.key});

  @override
  ConsumerState<ExpenseDistributionChart> createState() => _ExpenseDistributionChartState();
}

class _ExpenseDistributionChartState extends ConsumerState<ExpenseDistributionChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    // We can reuse statsDataProvider for the distribution as it already calculates category totals
    final statsAsync = ref.watch(
      statsDataProvider(StatsPeriod(year: DateTime.now().year)),
    );
    final categoryMap = ref.watch(categoryMapProvider);
    final currencyFormatter = ref.watch(currencyProvider);
    final scheme = Theme.of(context).colorScheme;
    final catColors = ref.watch(categoryColorCacheProvider(scheme.brightness));
    final catIcons = ref.watch(categoryIconCacheProvider);

    return statsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryGreen),
      ),
      error: (err, _) => Center(child: Text("Error: $err")),
      data: (stats) {
        if (stats.categoryTotals.isEmpty) {
          return Center(
            child: Text(
              context.l10n.chartNoDataYear,
              style: const TextStyle(color: AppTheme.textGrey),
            ),
          );
        }

        final sortedCategoryEntries = stats.categoryTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 20),
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
                      final category = categoryMap[data.key] ??
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
                      final percentage =
                          (data.value / stats.totalExpenses * 100).toStringAsFixed(1);

                      return PieChartSectionData(
                        color: catColors[category.name] ??
                            unknownCategoryInk(scheme),
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
              const SizedBox(height: 32),
              ...sortedCategoryEntries.map((entry) {
                final category = categoryMap[entry.key] ??
                    Category(
                      id: '',
                      userId: '',
                      name: entry.key,
                      iconCode: Icons.help_outline.codePoint,
                      colorHex: 0xFF9E9E9E,
                      type: 'expense',
                    );
                final percentage =
                    (entry.value / stats.totalExpenses * 100).toStringAsFixed(1);

                return _buildLegendItem(category, entry.value, percentage,
                    currencyFormatter, catColors, catIcons, scheme);
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(
      Category category,
      double value,
      String percentage,
      dynamic currencyFormatter,
      Map<String, Color> catColors,
      Map<String, IconData> catIcons,
      ColorScheme scheme) {
    final catColor = catColors[category.name] ?? unknownCategoryInk(scheme);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: catColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            catIcons[category.name] ?? categoryIcon(category.name),
            color: catColor,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              category.name,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currencyFormatter.format(value),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                "$percentage%",
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
