import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/core/widgets/skeleton.dart';
import 'package:budgetti/features/dashboard/widgets/summary_card.dart';
import 'package:flutter/material.dart';

class TransactionItemSkeleton extends StatelessWidget {
  const TransactionItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGrey.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceGreyLight.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          const Skeleton(height: 44, width: 44, borderRadius: 12),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Skeleton(height: 16, width: 120),
                const SizedBox(height: 8),
                const Skeleton(height: 14, width: 80),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Skeleton(height: 16, width: 60),
              const SizedBox(height: 8),
              const Skeleton(height: 12, width: 40),
            ],
          ),
        ],
      ),
    );
  }
}

class BudgetSaturationRecapSkeleton extends StatelessWidget {
  const BudgetSaturationRecapSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Skeleton(height: 24, width: 180), // Title "Budget Saturation"
        const SizedBox(height: 16),
        // 3 items
        for (int i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceGrey,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.surfaceGreyLight.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Skeleton(height: 20, width: 20, borderRadius: 4),
                    const SizedBox(width: 8),
                    const Skeleton(height: 16, width: 100),
                    const Spacer(),
                    const Skeleton(height: 12, width: 120),
                  ],
                ),
                const SizedBox(height: 12),
                const Skeleton(height: 6, width: double.infinity, borderRadius: 4),
              ],
            ),
          ),
      ],
    );
  }
}

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Skeleton(height: 16, width: 100),
                  SizedBox(height: 8),
                  Skeleton(height: 32, width: 160),
                ],
              ),
              const Skeleton(height: 48, width: 48, borderRadius: 24),
            ],
          ),
          const SizedBox(height: 32),
          // Summary Cards
          Row(
            children: [
              Expanded(child: SummaryCardSkeleton()),
              SizedBox(width: 12),
              Expanded(child: SummaryCardSkeleton()),
            ],
          ),
          const SizedBox(height: 32),
          // Budget Saturation
          const BudgetSaturationRecapSkeleton(),
          const SizedBox(height: 32),
          // Recent Transactions
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Skeleton(height: 24, width: 180),
                ],
              ),
              const SizedBox(height: 16),
              ...List.generate(3, (index) => const TransactionItemSkeleton()),
            ],
          ),
        ],
      ),
    );
  }
}
