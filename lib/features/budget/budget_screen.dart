import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/models/budget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum BudgetSort { alphabetical, amountAsc, amountDesc }

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  BudgetSort _sortBy = BudgetSort.alphabetical;

  void _showSetBudgetDialog(String categoryName, double currentLimit) {
    final controller = TextEditingController(text: currentLimit > 0 ? currentLimit.toStringAsFixed(2) : '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceGrey,
        title: Text("Set Budget for $categoryName", style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Enter monthly limit",
            hintStyle: TextStyle(color: AppTheme.textGrey.withValues(alpha: 0.5)),
            prefixIcon: const Icon(Icons.euro, color: AppTheme.primaryGreen),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.textGrey)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryGreen)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: AppTheme.textGrey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newLimit = double.tryParse(controller.text) ?? 0.0;
              Navigator.pop(context);
              await _saveBudget(categoryName, newLimit);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
            child: const Text("Save", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBudget(String category, double limit) async {
    try {
      final service = ref.read(financeServiceProvider);
      await service.upsertBudget(Budget(
        id: '', // Will be ignored by upsert on server
        userId: '', // Handled by service
        category: category,
        limit: limit,
      ));
      ref.invalidate(budgetsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving budget: $e")),
        );
      }
    } finally {
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final budgetsAsync = ref.watch(budgetsProvider);
    final transactionsAsync = ref.watch(transactionsProvider('1'));
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
            // backgroundColor: AppTheme.surfaceGrey, // Removed due to lint error
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
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
        error: (err, _) => Center(child: Text("Error: $err")),
        data: (categories) {
          final expenseCategories = categories.where((c) => c.type == 'expense').toList();
          
          return budgetsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
            error: (err, _) => Center(child: Text("Error: $err")),
            data: (budgets) {
              return transactionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
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
                  final totalSaturation = totalBudget > 0
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
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _buildSummaryCard(
                                    context,
                                    "Total Budget",
                                    currencyFormatter.format(totalBudget),
                                    Icons.account_balance_wallet_outlined,
                                    AppTheme.primaryGreen,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildSummaryCard(
                                    context,
                                    "Saturation",
                                    "${(totalSaturation * 100).toStringAsFixed(1)}%",
                                    Icons.pie_chart_outline,
                                    totalSaturation > 0.9
                                        ? Theme.of(context).colorScheme.error
                                        : AppTheme.primaryGreen,
                                    subtitle: "of total limits",
                                  ),
                                ),
                              ],
                            ),
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
                            final percent = budget.limit > 0
                                ? (spent / budget.limit).clamp(0.0, 1.0)
                                : 0.0;
                            final isOverBudget =
                                spent > budget.limit && budget.limit > 0;

                            return Card(
                              color: AppTheme.surfaceGrey,
                              margin: const EdgeInsets.only(bottom: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: Color(
                                    category.colorHex,
                                  ).withValues(alpha: 0.3),
                                  width: 1.5,
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
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Color(
                                                category.colorHex,
                                              ).withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              IconData(
                                                category.iconCode,
                                                fontFamily: 'MaterialIcons',
                                              ),
                                              color: Color(category.colorHex),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              category.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            budget.limit > 0
                                                ? currencyFormatter.format(
                                                    budget.limit,
                                                  )
                                                : "No limit",
                                            style: TextStyle(
                                              color: budget.limit > 0
                                                  ? AppTheme.primaryGreen
                                                  : AppTheme.textGrey,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Spent: ${currencyFormatter.format(spent)}",
                                            style: TextStyle(
                                              color: isOverBudget
                                                  ? Theme.of(
                                                      context,
                                                    ).colorScheme.error
                                                  : AppTheme.textGrey,
                                            ),
                                          ),
                                          Text(
                                            "${(percent * 100).toStringAsFixed(0)}%",
                                            style: TextStyle(
                                              color: isOverBudget
                                                  ? Theme.of(
                                                      context,
                                                    ).colorScheme.error
                                                  : AppTheme.textGrey,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: percent,
                                          backgroundColor:
                                              AppTheme.backgroundBlack,
                                          color: isOverBudget
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.error
                                              : AppTheme.primaryGreen,
                                          minHeight: 8,
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

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGrey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: AppTheme.textGrey.withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
