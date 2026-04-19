import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/widgets/skeleton.dart';
import 'package:budgetti/features/budget/widgets/budget_hero.dart';
import 'package:budgetti/features/budget/widgets/budget_row.dart';
import 'package:budgetti/features/budget/widgets/budget_skeleton.dart';
import 'package:budgetti/features/budget/set_budget_modal.dart';
import 'package:budgetti/features/stats/widgets/section_label.dart';
import 'package:budgetti/features/stats/widgets/stagger.dart';
import 'package:budgetti/models/category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

enum BudgetSort { alphabetical, amountAsc, amountDesc, utilization }

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen>
    with SingleTickerProviderStateMixin {
  BudgetSort _sortBy = BudgetSort.utilization;
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

  void _showSetBudgetDialog(String categoryName, double currentLimit) {
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SetBudgetModal(
        categoryName: categoryName,
        currentLimit: currentLimit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final categoriesAsync = ref.watch(categoriesProvider);
    final budgetsAsync = ref.watch(budgetsProvider);
    final budgetStatsAsync = ref.watch(budgetStatsProvider);
    final budgetMap = ref.watch(budgetMapProvider);
    final currencyFormatter = ref.watch(currencyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Budgets',
          style: GoogleFonts.jetBrainsMono(
            color: scheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          PopupMenuButton<BudgetSort>(
            icon: Icon(Icons.sort, color: scheme.onSurface),
            color: scheme.surfaceContainerHigh,
            position: PopupMenuPosition.under,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (sort) => setState(() => _sortBy = sort),
            itemBuilder: (context) => [
              _sortItem(BudgetSort.utilization, 'Utilization'),
              _sortItem(BudgetSort.alphabetical, 'Alphabetical'),
              _sortItem(BudgetSort.amountDesc, 'Limit: High to Low'),
              _sortItem(BudgetSort.amountAsc, 'Limit: Low to High'),
            ],
          ),
        ],
      ),
      body: categoriesAsync.when(
        loading: () => const ShimmerLoading(child: BudgetScreenSkeleton()),
        error: (err, _) => _ErrorView(message: '$err'),
        data: (categories) {
          final expenseCategories =
              categories.where((c) => c.type == 'expense').toList();

          return budgetsAsync.when(
            loading: () => const ShimmerLoading(child: BudgetScreenSkeleton()),
            error: (err, _) => _ErrorView(message: '$err'),
            data: (budgets) {
              return budgetStatsAsync.when(
                loading: () =>
                    const ShimmerLoading(child: BudgetScreenSkeleton()),
                error: (err, _) => _ErrorView(message: '$err'),
                data: (categorySpending) {
                  final totalBudget = budgets.fold<double>(
                    0,
                    (sum, b) => sum + b.limit,
                  );
                  final totalSpent = budgets.fold<double>(
                    0,
                    (sum, b) => sum + (categorySpending[b.category] ?? 0),
                  );
                  final utilization = totalBudget > 0
                      ? (totalSpent / totalBudget).clamp(0.0, 1.0)
                      : 0.0;

                  final active = <Category>[];
                  final unset = <Category>[];
                  for (final c in expenseCategories) {
                    final limit = budgetMap[c.name]?.limit ?? 0.0;
                    if (limit > 0) {
                      active.add(c);
                    } else {
                      unset.add(c);
                    }
                  }

                  double limitOf(Category c) =>
                      budgetMap[c.name]?.limit ?? 0.0;
                  double spentOf(Category c) =>
                      categorySpending[c.name] ?? 0.0;
                  double utilOf(Category c) {
                    final l = limitOf(c);
                    return l > 0 ? spentOf(c) / l : 0.0;
                  }

                  active.sort((a, b) {
                    switch (_sortBy) {
                      case BudgetSort.alphabetical:
                        return a.name.compareTo(b.name);
                      case BudgetSort.amountAsc:
                        return limitOf(a).compareTo(limitOf(b));
                      case BudgetSort.amountDesc:
                        return limitOf(b).compareTo(limitOf(a));
                      case BudgetSort.utilization:
                        return utilOf(b).compareTo(utilOf(a));
                    }
                  });
                  unset.sort((a, b) => a.name.compareTo(b.name));

                  final isEmpty =
                      expenseCategories.isEmpty || budgets.isEmpty;

                  return CustomScrollView(
                    slivers: [
                      Stagger(
                        controller: _entrance,
                        begin: 0.00,
                        end: 0.55,
                        child: SliverToBoxAdapter(
                          child: BudgetHero(
                            spent: totalSpent,
                            limit: totalBudget,
                            utilization: utilization,
                            activeCount: active.length,
                            currencyFormatter: currencyFormatter,
                          ),
                        ),
                      ),
                      if (isEmpty && expenseCategories.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyState(),
                        )
                      else ...[
                        if (active.isNotEmpty) ...[
                          Stagger(
                            controller: _entrance,
                            begin: 0.10,
                            end: 0.65,
                            child: SliverToBoxAdapter(
                              child: SectionLabel(
                                text: 'TRACKED',
                                count: active.length,
                              ),
                            ),
                          ),
                          Stagger(
                            controller: _entrance,
                            begin: 0.15,
                            end: 0.80,
                            child: _BudgetSliver(
                              categories: active,
                              spentOf: spentOf,
                              limitOf: limitOf,
                              currencyFormatter: currencyFormatter,
                              onTapCategory: _showSetBudgetDialog,
                            ),
                          ),
                        ],
                        if (unset.isNotEmpty) ...[
                          Stagger(
                            controller: _entrance,
                            begin: 0.25,
                            end: 0.90,
                            child: SliverToBoxAdapter(
                              child: SectionLabel(
                                text: 'UNSET',
                                count: unset.length,
                              ),
                            ),
                          ),
                          Stagger(
                            controller: _entrance,
                            begin: 0.30,
                            end: 1.0,
                            child: _BudgetSliver(
                              categories: unset,
                              spentOf: spentOf,
                              limitOf: limitOf,
                              currencyFormatter: currencyFormatter,
                              onTapCategory: _showSetBudgetDialog,
                              startRank: active.length + 1,
                            ),
                          ),
                        ],
                        const SliverToBoxAdapter(child: SizedBox(height: 32)),
                      ],
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  PopupMenuItem<BudgetSort> _sortItem(BudgetSort value, String label) {
    final selected = value == _sortBy;
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (selected)
            Icon(Icons.check, size: 16, color: scheme.primary),
        ],
      ),
    );
  }
}

class _BudgetSliver extends StatelessWidget {
  final List<Category> categories;
  final double Function(Category) spentOf;
  final double Function(Category) limitOf;
  final NumberFormat currencyFormatter;
  final void Function(String name, double limit) onTapCategory;
  final int startRank;

  const _BudgetSliver({
    required this.categories,
    required this.spentOf,
    required this.limitOf,
    required this.currencyFormatter,
    required this.onTapCategory,
    this.startRank = 1,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final category = categories[index];
          final isLast = index == categories.length - 1;
          final spent = spentOf(category);
          final limit = limitOf(category);
          return Column(
            children: [
              BudgetRow(
                rank: startRank + index,
                category: category,
                spent: spent,
                limit: limit,
                currencyFormatter: currencyFormatter,
                onTap: () => onTapCategory(category.name, limit),
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
        childCount: categories.length,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
            'NO CATEGORIES',
            style: GoogleFonts.jetBrainsMono(
              color: scheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add expense categories first to start tracking budgets.',
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

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ERROR',
              style: GoogleFonts.jetBrainsMono(
                color: scheme.error,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
