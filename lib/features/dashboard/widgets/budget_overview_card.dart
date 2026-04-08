import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/widgets/expressive_card.dart';

/// Aggregate budget overview for the current month.
/// Shows total spent vs total budgeted with a progress bar.
/// Tap "View all" → /budgets.
class BudgetOverviewCard extends ConsumerWidget {
  const BudgetOverviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final currency = ref.watch(currencyProvider);
    final budgetsAsync = ref.watch(budgetsProvider);
    final spendingAsync = ref.watch(budgetStatsProvider);

    final budgets = budgetsAsync.value ?? const [];
    final spending = spendingAsync.value ?? const {};

    if (budgets.isEmpty) {
      return ExpressiveCard(
        onTap: () => context.push('/budgets'),
        child: Row(
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                color: scheme.primary, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set up budgets',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Track category spending each month',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                color: scheme.onSurfaceVariant, size: 14),
          ],
        ),
      );
    }

    final totalBudgeted =
        budgets.fold<double>(0, (sum, b) => sum + b.limit);
    final totalSpent = budgets.fold<double>(
      0,
      (sum, b) => sum + (spending[b.category] ?? 0),
    );
    final progress =
        totalBudgeted == 0 ? 0.0 : (totalSpent / totalBudgeted).clamp(0.0, 1.5);
    final overBudget = progress > 1.0;

    final barColor = overBudget
        ? scheme.error
        : progress >= 0.75
            ? const Color(0xFFFFB870)
            : scheme.primary;

    return ExpressiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monthly Budget',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () => context.push('/budgets'),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View all',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 12),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currency.format(totalSpent),
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  'of ${currency.format(totalBudgeted)}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            overBudget
                ? '${((progress - 1) * 100).toStringAsFixed(0)}% over budget'
                : '${(progress * 100).toStringAsFixed(0)}% used',
            style: TextStyle(
              color: overBudget ? scheme.error : scheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
