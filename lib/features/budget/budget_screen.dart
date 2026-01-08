import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/core/widgets/skeleton.dart';
import 'package:budgetti/features/budget/widgets/budget_skeleton.dart';
import 'package:budgetti/features/budget/set_budget_modal.dart';
import 'package:budgetti/models/budget.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

enum BudgetSort { alphabetical, amountAsc, amountDesc }

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  BudgetSort _sortBy = BudgetSort.alphabetical;

  void _showSetBudgetDialog(String categoryName, double currentLimit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceGrey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SetBudgetModal(
        categoryName: categoryName,
        currentLimit: currentLimit,
      ),
    );
  }

  Color _getStatusColor(double percentage) {
    if (percentage < 0.75) return AppTheme.primaryGreen;
    if (percentage < 1.0) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final budgetsAsync = ref.watch(budgetsProvider);
    final transactionsAsync = ref.watch(transactionsProvider(null));
    final currencyFormatter = ref.watch(currencyProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: Text(
          "Monthly Budgets",
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textWhite,
              ),
        ),
        actions: [
          PopupMenuButton<BudgetSort>(
            icon: const Icon(Icons.sort, color: AppTheme.primaryGreen),
            color: AppTheme.surfaceGrey,
            onSelected: (sort) {
              setState(() {
                _sortBy = sort;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: BudgetSort.alphabetical,
                child: Text("Alphabetical"),
              ),
              const PopupMenuItem(
                value: BudgetSort.amountAsc,
                child: Text("Budget: Low to High"),
              ),
              const PopupMenuItem(
                value: BudgetSort.amountDesc,
                child: Text("Budget: High to Low"),
              ),
            ],
          ),
        ],
      ),
      body: categoriesAsync.when(
        loading: () => const ShimmerLoading(child: BudgetScreenSkeleton()),
        error: (err, _) => Center(child: Text("Error: $err")),
        data: (categories) {
          final expenseCategories = categories.where((c) => c.type == 'expense').toList();
          
          return budgetsAsync.when(
            loading: () => const ShimmerLoading(child: BudgetScreenSkeleton()),
            error: (err, _) => Center(child: Text("Error: $err")),
            data: (budgets) {
              return transactionsAsync.when(
                loading: () => const ShimmerLoading(child: BudgetScreenSkeleton()),
                error: (err, _) => Center(child: Text("Error: $err")),
                data: (transactions) {
                  // Calculate current month spending per category
                  final now = DateTime.now();
                  final currentMonthTransactions = transactions.where((t) => 
                    t.date.year == now.year && t.date.month == now.month && t.amount < 0
                  );

                  final categorySpending = <String, double>{};
                  for (var t in currentMonthTransactions) {
                    categorySpending[t.category] = (categorySpending[t.category] ?? 0) + t.amount.abs();
                  }

                  // Sorting and calculations
                  final totalBudget = budgets.fold<double>(
                    0,
                    (sum, b) => sum + b.limit,
                  );
                  final categoriesWithBudget = expenseCategories.where((c) {
                    final budget = budgets.firstWhere(
                      (b) => b.category == c.name,
                      orElse: () => Budget(
                        id: '',
                        userId: '',
                        category: c.name,
                        limit: 0,
                      ),
                    );
                    return budget.limit > 0;
                  }).toList();

                  final totalSpentOnBudgeted = categoriesWithBudget
                      .fold<double>(
                        0,
                        (sum, c) => sum + (categorySpending[c.name] ?? 0),
                      );
                  final totalUtilization = totalBudget > 0
                      ? (totalSpentOnBudgeted / totalBudget).clamp(0.0, 1.0)
                      : 0.0;

                  final sortedCategories = List.from(expenseCategories);
                  sortedCategories.sort((a, b) {
                    final budgetA = budgets
                        .firstWhere(
                          (bg) => bg.category == a.name,
                          orElse: () => Budget(
                            id: '',
                            userId: '',
                            category: a.name,
                            limit: 0,
                          ),
                        )
                        .limit;
                    final budgetB = budgets
                        .firstWhere(
                          (bg) => bg.category == b.name,
                          orElse: () => Budget(
                            id: '',
                            userId: '',
                            category: b.name,
                            limit: 0,
                          ),
                        )
                        .limit;

                    switch (_sortBy) {
                      case BudgetSort.alphabetical:
                        return a.name.compareTo(b.name);
                      case BudgetSort.amountAsc:
                        return budgetA.compareTo(budgetB);
                      case BudgetSort.amountDesc:
                        return budgetB.compareTo(budgetA);
                    }
                  });

                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverToBoxAdapter(
                          child: _buildOverviewCard(
                            context,
                            totalSpentOnBudgeted,
                            totalBudget,
                            totalUtilization,
                            currencyFormatter,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final category = sortedCategories[index];
                            final budget = budgets.firstWhere(
                              (b) => b.category == category.name,
                              orElse: () => Budget(
                                id: '',
                                userId: '',
                                category: category.name,
                                limit: 0,
                              ),
                            );
                            final spent =
                                categorySpending[category.name] ?? 0.0;
                            final hasLimit = budget.limit > 0;
                            final percent = hasLimit
                                ? (spent / budget.limit).clamp(0.0, 1.0)
                                : 0.0;
                            final statusColor = hasLimit
                                ? _getStatusColor(spent / budget.limit)
                                : AppTheme.textGrey;

                            return Card(
                              color: AppTheme.surfaceGrey,
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: AppTheme.textGrey.withValues(
                                    alpha: 0.1,
                                  ),
                                  width: 1,
                                ),
                              ),
                              child: InkWell(
                                onTap: () => _showSetBudgetDialog(
                                  category.name,
                                  budget.limit,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Color(
                                                category.colorHex,
                                              ).withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              IconData(
                                                category.iconCode,
                                                fontFamily: 'MaterialIcons',
                                              ),
                                              color: Color(category.colorHex),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              category.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                hasLimit
                                                    ? "${currencyFormatter.format(spent)} / ${currencyFormatter.format(budget.limit)}"
                                                    : currencyFormatter.format(
                                                        spent,
                                                      ),
                                                style: TextStyle(
                                                  color: statusColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              if (!hasLimit)
                                                const Text(
                                                  "No limit",
                                                  style: TextStyle(
                                                    color: AppTheme.textGrey,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (hasLimit) ...[
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              "${((spent / budget.limit) * 100).toStringAsFixed(0)}% used",
                                              style: TextStyle(
                                                color: statusColor.withValues(
                                                  alpha: 0.7,
                                                ),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          child: LinearProgressIndicator(
                                            value: percent,
                                            backgroundColor:
                                                AppTheme.backgroundBlack,
                                            color: statusColor,
                                            minHeight: 6,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                            childCount: sortedCategories.length),
                        ),
                      ),
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

  Widget _buildOverviewCard(
    BuildContext context,
    double spent,
    double limit,
    double utilization,
    NumberFormat formatter,
  ) {
    final statusColor = _getStatusColor(utilization);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGrey,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.textGrey.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          const Text(
            "Overall Utilization",
            style: TextStyle(
              color: AppTheme.textGrey,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 160,
            child: Stack(
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 0,
                    centerSpaceRadius: 65,
                    startDegreeOffset: -90,
                    sections: [
                      PieChartSectionData(
                        color: statusColor,
                        value: utilization * 100,
                        title: '',
                        radius: 12,
                      ),
                      PieChartSectionData(
                        color: AppTheme.backgroundBlack,
                        value: (1 - utilization) * 100,
                        title: '',
                        radius: 10,
                      ),
                    ],
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatter.format(spent),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "of ${formatter.format(limit)} limit",
                        style: const TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMetricItem(
                "Utilization",
                "${(utilization * 100).toStringAsFixed(1)}%",
                statusColor,
              ),
              const SizedBox(width: 48),
              _buildMetricItem(
                "Remaining",
                formatter.format((limit - spent).clamp(0, double.infinity)),
                limit - spent > 0 ? AppTheme.primaryGreen : Colors.redAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.textGrey, fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
