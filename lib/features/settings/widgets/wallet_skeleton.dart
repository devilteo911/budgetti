import 'package:budgetti/core/widgets/skeleton.dart';
import 'package:flutter/material.dart';

class WalletItemSkeleton extends StatelessWidget {
  const WalletItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: const [
          Skeleton(height: 40, width: 40, borderRadius: 20),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(height: 16, width: 120),
                SizedBox(height: 8),
                Skeleton(height: 14, width: 80),
              ],
            ),
          ),
          Skeleton(height: 24, width: 24, borderRadius: 12),
        ],
      ),
    );
  }
}
