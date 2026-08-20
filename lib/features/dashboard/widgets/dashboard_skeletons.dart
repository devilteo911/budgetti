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
        color: Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHigh
                .withValues(alpha: 0.2),
            width: 1),
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

class TransactionLedgerItemSkeleton extends StatelessWidget {
  const TransactionLedgerItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 20, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Skeleton(height: 40, width: 3, borderRadius: 2),
          const SizedBox(width: 13),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Skeleton(height: 14, width: 22, borderRadius: 3),
              SizedBox(height: 6),
              Skeleton(height: 8, width: 28, borderRadius: 3),
            ],
          ),
          const SizedBox(width: 12),
          const Skeleton(height: 36, width: 36, borderRadius: 12),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Skeleton(height: 14, width: 140),
                SizedBox(height: 8),
                Skeleton(height: 10, width: 80),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Skeleton(height: 14, width: 64, borderRadius: 3),
        ],
      ),
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
          // Header row (wordmark + date)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Skeleton(height: 20, width: 90),
              Skeleton(height: 14, width: 100),
            ],
          ),
          const SizedBox(height: 20),
          // Carousel (3-card swipable) — one card's worth of skeleton
          const SizedBox(height: 168, child: SummaryCardSkeleton()),
          const SizedBox(height: 10),
          // Page indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Skeleton(height: 6, width: 18, borderRadius: 3),
              SizedBox(width: 6),
              Skeleton(height: 6, width: 6, borderRadius: 3),
              SizedBox(width: 6),
              Skeleton(height: 6, width: 6, borderRadius: 3),
            ],
          ),
          const SizedBox(height: 24),
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
              ...List.generate(5, (index) => const TransactionItemSkeleton()),
            ],
          ),
        ],
      ),
    );
  }
}
