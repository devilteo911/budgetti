import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/core/widgets/skeleton.dart';
import 'package:flutter/material.dart';

class BudgetSummaryCardSkeleton extends StatelessWidget {
  const BudgetSummaryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGrey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceGreyLight.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
               Skeleton(height: 20, width: 20, borderRadius: 4),
               SizedBox(width: 8),
               Skeleton(height: 12, width: 80),
            ],
          ),
          SizedBox(height: 8),
          Skeleton(height: 24, width: 100),
        ],
      ),
    );
  }
}

class BudgetCardSkeleton extends StatelessWidget {
  const BudgetCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGrey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceGreyLight.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
               Skeleton(height: 32, width: 32, borderRadius: 8),
               SizedBox(width: 12),
               Expanded(child: Skeleton(height: 20, width: 120)),
               Skeleton(height: 20, width: 60),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Skeleton(height: 16, width: 80),
              Skeleton(height: 16, width: 40),
            ],
          ),
          SizedBox(height: 8),
          Skeleton(height: 8, width: double.infinity, borderRadius: 4),
        ],
      ),
    );
  }
}

class BudgetScreenSkeleton extends StatelessWidget {
  const BudgetScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: IntrinsicHeight(
              child: Row(
                children: const [
                  Expanded(child: BudgetSummaryCardSkeleton()),
                  SizedBox(width: 16),
                  Expanded(child: BudgetSummaryCardSkeleton()),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => const BudgetCardSkeleton(),
              childCount: 5,
            ),
          ),
        ),
      ],
    );
  }
}
