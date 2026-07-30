import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/ledger_style.dart';
import 'package:budgetti/features/stats/widgets/budget_progress.dart';
import 'package:budgetti/features/stats/widgets/category_hero.dart';
import 'package:budgetti/features/stats/widgets/category_trend_chart.dart';
import 'package:budgetti/features/stats/widgets/section_label.dart';
import 'package:budgetti/features/stats/widgets/stagger.dart';
import 'package:budgetti/features/stats/widgets/transaction_ledger_row.dart';
import 'package:budgetti/models/category.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class CategoryDetailsScreen extends ConsumerStatefulWidget {
  final Category category;

  const CategoryDetailsScreen({super.key, required this.category});

  @override
  ConsumerState<CategoryDetailsScreen> createState() =>
      _CategoryDetailsScreenState();
}

class _CategoryDetailsScreenState extends ConsumerState<CategoryDetailsScreen>
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final period = ref.watch(selectedStatsPeriodProvider);
    final transactionsAsync = ref.watch(transactionsProvider(null));
    final currencyFormatter = ref.watch(currencyProvider);
    final tagMap = ref.watch(tagMapProvider);
    final budgetMap = ref.watch(budgetMapProvider);
    final budget = budgetMap[widget.category.name];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.category.name,
          style: GoogleFonts.jetBrainsMono(
            color: scheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: transactionsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: scheme.primary),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (all) {
          final catColor = ref.watch(categoryColorCacheProvider(
                  scheme.brightness))[widget.category.name] ??
              unknownCategoryInk(scheme);
          final categoryAll = all
              .where((t) =>
                  t.category == widget.category.name && t.amount < 0)
              .toList();

          final forPeriod = categoryAll.where((t) {
            if (t.date.year != period.year) return false;
            if (period.month != null && t.date.month != period.month) {
              return false;
            }
            return true;
          }).toList()
            ..sort((a, b) => b.date.compareTo(a.date));

          if (forPeriod.isEmpty && categoryAll.isEmpty) {
            return _EmptyState(period: period, catColor: catColor);
          }

          final trendMonths = _last12Months();
          final monthlyData = _aggregateByMonth(categoryAll, trendMonths);
          final monthlySpentThisMonth = _currentMonthSpent(categoryAll);

          return CustomScrollView(
            slivers: [
              Stagger(
                controller: _entrance,
                begin: 0.00,
                end: 0.55,
                child: SliverToBoxAdapter(
                  child: CategoryHero(
                    category: widget.category,
                    transactionsForPeriod: forPeriod,
                    period: period,
                    currencyFormatter: currencyFormatter,
                  ),
                ),
              ),
              if (budget != null)
                Stagger(
                  controller: _entrance,
                  begin: 0.10,
                  end: 0.65,
                  child: SliverToBoxAdapter(
                    child: BudgetProgress(
                      spent: monthlySpentThisMonth,
                      limit: budget.limit,
                      accent: catColor,
                      currencyFormatter: currencyFormatter,
                    ),
                  ),
                ),
              Stagger(
                controller: _entrance,
                begin: 0.20,
                end: 0.75,
                child: const SliverToBoxAdapter(
                  child: SectionLabel(text: '12-MONTH TREND'),
                ),
              ),
              Stagger(
                controller: _entrance,
                begin: 0.25,
                end: 0.80,
                child: SliverToBoxAdapter(
                  child: CategoryTrendChart(
                    months: trendMonths,
                    monthlyData: monthlyData,
                    accent: catColor,
                    currencyFormatter: currencyFormatter,
                  ),
                ),
              ),
              Stagger(
                controller: _entrance,
                begin: 0.35,
                end: 0.90,
                child: SliverToBoxAdapter(
                  child: SectionLabel(
                    text: 'TRANSACTIONS',
                    count: forPeriod.length,
                  ),
                ),
              ),
              if (forPeriod.isEmpty)
                Stagger(
                  controller: _entrance,
                  begin: 0.40,
                  end: 0.95,
                  child: SliverToBoxAdapter(
                    child: _NoTxnHint(period: period),
                  ),
                )
              else
                Stagger(
                  controller: _entrance,
                  begin: 0.40,
                  end: 1.0,
                  child: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final txn = forPeriod[index];
                        final isLast = index == forPeriod.length - 1;
                        return Column(
                          children: [
                            TransactionLedgerRow(
                              txn: txn,
                              currencyFormatter: currencyFormatter,
                              tagMap: tagMap,
                            ),
                            if (!isLast)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: Container(
                                  height: 1,
                                  color: scheme.outlineVariant
                                      .withValues(alpha: 0.18),
                                ),
                              ),
                          ],
                        );
                      },
                      childCount: forPeriod.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }

  static List<String> _last12Months() {
    final now = DateTime.now();
    return List.generate(12, (i) {
      final d = DateTime(now.year, now.month - 11 + i, 1);
      return DateFormat('yyyy-MM').format(d);
    });
  }

  static Map<String, double> _aggregateByMonth(
    List<Transaction> transactions,
    List<String> months,
  ) {
    final map = {for (final m in months) m: 0.0};
    for (final t in transactions) {
      final key = DateFormat('yyyy-MM').format(t.date);
      if (map.containsKey(key)) {
        map[key] = map[key]! + t.amount.abs();
      }
    }
    return map;
  }

  static double _currentMonthSpent(List<Transaction> transactions) {
    final now = DateTime.now();
    return transactions
        .where((t) => t.date.year == now.year && t.date.month == now.month)
        .fold<double>(0, (s, t) => s + t.amount.abs());
  }
}

class _NoTxnHint extends StatelessWidget {
  final StatsPeriod period;
  const _NoTxnHint({required this.period});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = period.month != null
        ? DateFormat('MMMM yyyy').format(DateTime(period.year, period.month!))
        : '${period.year}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Text(
        'No transactions in $label.',
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final StatsPeriod period;
  final Color catColor;
  const _EmptyState({required this.period, required this.catColor});

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
          Container(
            width: 3,
            height: 48,
            decoration: BoxDecoration(
              color: catColor,
              borderRadius: BorderRadius.circular(2),
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
            'Nothing recorded for this category in $label.',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
