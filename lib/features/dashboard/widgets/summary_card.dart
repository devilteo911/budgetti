import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/core/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


class SummaryCard extends StatelessWidget {
  final String title;
  final String amount;
  final String trend;
  final bool isPositive;
  final bool isVisible;
  final VoidCallback? onToggleVisibility;

  const SummaryCard({
    super.key,
    required this.title,
    required this.amount,
    required this.trend,
    this.isPositive = true,
    this.isVisible = true,
    this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGrey,
        borderRadius: BorderRadius.circular(24),
      ),
      child: GestureDetector(
        onLongPress: () {
          if (onToggleVisibility != null) {
            HapticFeedback.mediumImpact();
            onToggleVisibility?.call();
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
          Text(
            isVisible ? amount : "******",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 8),
            Visibility(
              visible: isVisible,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color:
                      (isPositive
                              ? AppTheme.primaryGreen
                              : Theme.of(context).colorScheme.error)
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  trend,
                  style: TextStyle(
                    color: isPositive
                        ? AppTheme.primaryGreen
                        : Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SummaryCardSkeleton extends StatelessWidget {
  const SummaryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGrey,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Skeleton(height: 14, width: 100),
          const SizedBox(height: 8),
          const Skeleton(height: 28, width: 140, borderRadius: 8),
          const SizedBox(height: 12),
          const Skeleton(height: 20, width: 80, borderRadius: 20),
        ],
      ),
    );
  }
}
