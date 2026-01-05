import 'package:budgetti/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGrey,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textGrey,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (onToggleVisibility != null) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: onToggleVisibility,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      isVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppTheme.textGrey,
                      size: 26,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isVisible ? amount : "******",
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 8),
          if (isVisible)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (isPositive ? AppTheme.primaryGreen : Theme.of(context).colorScheme.error).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                trend,
                style: TextStyle(
                  color: isPositive ? AppTheme.primaryGreen : Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
