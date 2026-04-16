import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/models/category.dart';
import 'package:budgetti/features/stats/category_details_screen.dart';
import 'package:budgetti/features/stats/widgets/category_distribution.dart';
import 'package:budgetti/features/stats/widgets/category_row.dart';
import 'package:budgetti/features/stats/widgets/monthly_row.dart';
import 'package:budgetti/features/stats/widgets/section_label.dart';
import 'package:budgetti/features/stats/widgets/stagger.dart';
import 'package:budgetti/features/stats/widgets/stats_filter_bar.dart';
import 'package:budgetti/features/stats/widgets/stats_hero.dart';
import 'package:budgetti/features/charts/widgets/spending_line_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _replay() {
    _entrance
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(selectedStatsPeriodProvider, (_, __) => _replay());
    ref.listen(statsScopeProvider, (_, __) => _replay());

    final scheme = Theme.of(context).colorScheme;
    final period = ref.watch(selectedStatsPeriodProvider);
    final statsAsync = ref.watch(statsDataProvider(period));
    final categoryMap = ref.watch(categoryMapProvider);
    final currencyFormatter = ref.watch(currencyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Stats',
          style: GoogleFonts.jetBrainsMono(
            color: scheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: statsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: scheme.primary),
        ),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (stats) {
          final isEmpty =
              stats.categoryTotals.isEmpty && stats.monthlyBreakdown.isEmpty;
          final totalExpenses = stats.totalExpenses;
          final sortedCategoryEntries = stats.categoryTotals.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: StatsFilterBar()),
              if (isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(period: period),
                )
              else ...[
                Stagger(
                  controller: _entrance,
                  begin: 0.00,
                  end: 0.55,
                  child: const SliverToBoxAdapter(child: StatsHero()),
                ),
                if (sortedCategoryEntries.isNotEmpty) ...[
                  Stagger(
                    controller: _entrance,
                    begin: 0.10,
                    end: 0.65,
                    child: SliverToBoxAdapter(
                      child: SectionLabel(
                        text: 'DISTRIBUTION',
                        count: sortedCategoryEntries.length,
                      ),
                    ),
                  ),
                  Stagger(
                    controller: _entrance,
                    begin: 0.15,
                    end: 0.75,
                    child: SliverToBoxAdapter(
                      child: CategoryDistribution(
                        sortedEntries: sortedCategoryEntries,
                        categoryMap: categoryMap,
                        total: totalExpenses,
                        currencyFormatter: currencyFormatter,
                      ),
                    ),
                  ),
                ],
                Stagger(
                  controller: _entrance,
                  begin: 0.25,
                  end: 0.80,
                  child: const SliverToBoxAdapter(
                    child: SectionLabel(text: 'TRENDS'),
                  ),
                ),
                Stagger(
                  controller: _entrance,
                  begin: 0.30,
                  end: 0.85,
                  child: const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: SpendingLineChart(),
                    ),
                  ),
                ),
                if (sortedCategoryEntries.isNotEmpty) ...[
                  Stagger(
                    controller: _entrance,
                    begin: 0.35,
                    end: 0.90,
                    child: const SliverToBoxAdapter(
                      child: SectionLabel(text: 'BREAKDOWN'),
                    ),
                  ),
                  Stagger(
                    controller: _entrance,
                    begin: 0.40,
                    end: 0.95,
                    child: _CategorySliver(
                      sortedEntries: sortedCategoryEntries,
                      categoryMap: categoryMap,
                      total: totalExpenses,
                      currencyFormatter: currencyFormatter,
                    ),
                  ),
                ],
                if (period.month == null &&
                    stats.monthlyBreakdown.isNotEmpty) ...[
                  Stagger(
                    controller: _entrance,
                    begin: 0.45,
                    end: 1.0,
                    child: const SliverToBoxAdapter(
                      child: SectionLabel(text: 'LEDGER · MONTHLY'),
                    ),
                  ),
                  Stagger(
                    controller: _entrance,
                    begin: 0.50,
                    end: 1.0,
                    child: _MonthlySliver(
                      monthlyData: stats.monthlyBreakdown,
                      currencyFormatter: currencyFormatter,
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CategorySliver extends StatelessWidget {
  final List<MapEntry<String, double>> sortedEntries;
  final Map<String, Category> categoryMap;
  final double total;
  final NumberFormat currencyFormatter;

  const _CategorySliver({
    required this.sortedEntries,
    required this.categoryMap,
    required this.total,
    required this.currencyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final entry = sortedEntries[index];
          final category = categoryMap[entry.key] ??
              Category(
                id: '',
                userId: '',
                name: entry.key,
                iconCode: Icons.help_outline.codePoint,
                colorHex: 0xFF9E9E9E,
                type: 'expense',
              );
          final isLast = index == sortedEntries.length - 1;
          return Column(
            children: [
              CategoryRow(
                rank: index + 1,
                category: category,
                amount: entry.value,
                total: total,
                currencyFormatter: currencyFormatter,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          CategoryDetailsScreen(category: category),
                    ),
                  );
                },
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.18),
                  ),
                ),
            ],
          );
        },
        childCount: sortedEntries.length,
      ),
    );
  }
}

class _MonthlySliver extends StatelessWidget {
  final Map<String, Map<String, double>> monthlyData;
  final NumberFormat currencyFormatter;

  const _MonthlySliver({
    required this.monthlyData,
    required this.currencyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sortedMonths = monthlyData.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final monthKey = sortedMonths[index];
          final data = monthlyData[monthKey]!;
          final displayMonth = DateFormat('MMMM yyyy')
              .format(DateTime.parse('$monthKey-01'));
          final isLast = index == sortedMonths.length - 1;
          return Column(
            children: [
              MonthlyRow(
                month: displayMonth,
                earned: data['earned'] ?? 0.0,
                spent: data['spent'] ?? 0.0,
                currencyFormatter: currencyFormatter,
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.18),
                  ),
                ),
            ],
          );
        },
        childCount: sortedMonths.length,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final StatsPeriod period;
  const _EmptyState({required this.period});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = period.month != null
        ? DateFormat('MMMM yyyy').format(DateTime(period.year, period.month!))
        : '${period.year}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '—',
            style: GoogleFonts.jetBrainsMono(
              color: scheme.onSurfaceVariant,
              fontSize: 72,
              fontWeight: FontWeight.w300,
              height: 0.8,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'NO ACTIVITY',
            style: GoogleFonts.jetBrainsMono(
              color: scheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nothing recorded for $label.',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try another period from the filters above.',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
