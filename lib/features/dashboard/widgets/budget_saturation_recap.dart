import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BudgetSaturationRecap extends ConsumerWidget {
  const BudgetSaturationRecap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsProvider);
    final transactionsAsync = ref.watch(transactionsProvider('1'));
    final categoriesAsync = ref.watch(categoriesProvider);
    final currencyFormatter = ref.watch(currencyProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Budget Saturation",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textWhite,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        budgetsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
          error: (err, _) => Text("Error: $err", style: const TextStyle(color: Colors.red)),
          data: (budgets) {
            if (budgets.isEmpty || budgets.every((b) => b.limit == 0)) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceGrey,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    "No budgets set yet. Go to the Budgets tab to set your limits!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textGrey),
                  ),
                ),
              );
            }

            return transactionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
              error: (err, _) => Text("Error: $err"),
              data: (transactions) {
                return categoriesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
                  error: (err, _) => Text("Error: $err"),
                  data: (categories) {
                    // Calculate current month spending
                    final now = DateTime.now();
                    final currentMonthTransactions = transactions.where((t) => 
                      t.date.year == now.year && t.date.month == now.month && t.amount < 0
                    );

                    final categorySpending = <String, double>{};
                    for (var t in currentMonthTransactions) {
                      categorySpending[t.category] = (categorySpending[t.category] ?? 0) + t.amount.abs();
                    }

                    // Calculate saturation levels
                    final saturationList = budgets
                      .where((b) => b.limit > 0)
                      .map((b) {
                        final spent = categorySpending[b.category] ?? 0.0;
                        final ratio = spent / b.limit;
                        return {
                          'category': b.category,
                          'ratio': ratio,
                          'spent': spent,
                          'limit': b.limit,
                        };
                      })
                      .toList()
                      ..sort((a, b) => (b['ratio'] as double).compareTo(a['ratio'] as double));

                    // Take top 3
                    final top3 = saturationList.take(3).toList();

                    return Column(
                      children: top3.map((item) {
                        final categoryName = item['category'] as String;
                        final ratio = (item['ratio'] as double).clamp(0.0, 1.2); // Cap visually
                        final spent = item['spent'] as double;
                        final limit = item['limit'] as double;
                        
                        final category = categories.firstWhere(
                          (c) => c.name == categoryName,
                          orElse: () => categories.first,
                        );

                        final isNearLimit = ratio >= 0.8;
                        final isOverLimit = ratio >= 1.0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceGrey,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    IconData(category.iconCode, fontFamily: 'MaterialIcons'),
                                    color: Color(category.colorHex),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    categoryName,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  Text(
                                    "${currencyFormatter.format(spent)} / ${currencyFormatter.format(limit)}",
                                    style: TextStyle(
                                      color: isOverLimit ? Colors.red : (isNearLimit ? Colors.orange : AppTheme.textGrey),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: ratio.clamp(0.0, 1.0),
                                  backgroundColor: AppTheme.backgroundBlack,
                                  color: isOverLimit ? Colors.red : (isNearLimit ? Colors.orange : AppTheme.primaryGreen),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  }
                );
              },
            );
          },
        ),
      ],
    );
  }
}
