import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/models/budget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {

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
        backgroundColor: AppTheme.backgroundBlack,
        title: Text(
          "Monthly Budgets",
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textWhite,
              ),
        ),
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

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: expenseCategories.length,
                    itemBuilder: (context, index) {
                      final category = expenseCategories[index];
                      final budget = budgets.firstWhere(
                        (b) => b.category == category.name,
                        orElse: () => Budget(id: '', userId: '', category: category.name, limit: 0),
                      );
                      final spent = categorySpending[category.name] ?? 0.0;
                      final percent = budget.limit > 0 ? (spent / budget.limit).clamp(0.0, 1.0) : 0.0;
                      final isOverBudget = spent > budget.limit && budget.limit > 0;

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
                          onTap: () => _showSetBudgetDialog(category.name, budget.limit),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Color(category.colorHex).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        IconData(category.iconCode, fontFamily: 'MaterialIcons'),
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
                                      budget.limit > 0 ? currencyFormatter.format(budget.limit) : "No limit",
                                      style: TextStyle(
                                        color: budget.limit > 0 ? AppTheme.primaryGreen : AppTheme.textGrey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    backgroundColor: AppTheme.backgroundBlack,
                                    color: isOverBudget
                                        ? Theme.of(context).colorScheme.error
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
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
