import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/core/widgets/skeleton.dart';
import 'package:budgetti/features/budget/widgets/budget_skeleton.dart';
import 'package:budgetti/features/budget/set_budget_modal.dart';
import 'package:budgetti/models/budget.dart';
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
    final budgetStatsAsync = ref.watch(budgetStatsProvider);
    final budgetMap = ref.watch(budgetMapProvider);
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
            error: (err, _) => Center(child: Text("Error Budgets: $err")),
            data: (budgets) {
              return budgetStatsAsync.when(
                loading: () => const ShimmerLoading(child: BudgetScreenSkeleton()),
                error: (err, _) => Center(child: Text("Error Stats: $err")),
                data: (categorySpending) {
                  // Pre-sorting
                  final totalBudget = budgets.fold<double>(
                    0,
                    (sum, b) => sum + b.limit,
                  );
                  final totalSpentOnBudgeted = budgets.fold<double>(
                    0,
                    (sum, b) => sum + (categorySpending[b.category] ?? 0),
                  );
                  
                  final totalUtilization = totalBudget > 0
                      ? (totalSpentOnBudgeted / totalBudget).clamp(0.0, 1.0)
                      : 0.0;

                  final sortedCategories = List.from(expenseCategories);
                  sortedCategories.sort((a, b) {
                    final budgetA = budgetMap[a.name]?.limit ?? 0.0;
                    final budgetB = budgetMap[b.name]?.limit ?? 0.0;

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
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                mainAxisExtent:
                                    140, // Fixed height for consistency
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final category = sortedCategories[index];
                            final budget =
                                budgetMap[category.name] ??
                                Budget(
                                  id: '',
                                  userId: '',
                                  category: category.name,
                                  limit: 0,
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
                              margin: EdgeInsets.zero,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: AppTheme.textGrey.withOpacity(0.1),
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
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Color(
                                                category.colorHex,
                                              ).withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              IconData(
                                                category.iconCode,
                                                fontFamily: 'MaterialIcons',
                                              ),
                                              color: Color(category.colorHex),
                                              size: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              category.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            hasLimit
                                                ? currencyFormatter.format(
                                                    spent,
                                                  )
                                                : currencyFormatter.format(
                                                    spent,
                                                  ),
                                            style: TextStyle(
                                              color: statusColor,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                            Text(
                                            hasLimit
                                                ? "of ${currencyFormatter.format(budget.limit)}"
                                                : "No limit",
                                            style: const TextStyle(
                                              color: AppTheme.textGrey,
                                              fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      if (hasLimit)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          child: LinearProgressIndicator(
                                            value: percent,
                                            backgroundColor:
                                                AppTheme.backgroundBlack,
                                            color: statusColor,
                                            minHeight: 4,
                                          ),
                                        ),
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
    final remaining = (limit - spent).clamp(0.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGrey,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.textGrey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Overall Utilization",
                style: TextStyle(
                  color: AppTheme.textGrey,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${(utilization * 100).toStringAsFixed(1)}%",
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatter.format(spent),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "of ${formatter.format(limit)}",
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: utilization,
              backgroundColor: AppTheme.backgroundBlack,
              color: statusColor,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "REMAINING",
                style: TextStyle(
                  color: AppTheme.textGrey.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                formatter.format(remaining),
                style: TextStyle(
                  color: remaining > 0
                      ? AppTheme.primaryGreen
                      : Colors.redAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}
