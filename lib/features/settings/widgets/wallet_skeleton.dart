import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/core/widgets/skeleton.dart';
import 'package:flutter/material.dart';

class WalletItemSkeleton extends StatelessWidget {
  const WalletItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: AppTheme.surfaceGrey,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: const Skeleton(height: 40, width: 40, borderRadius: 20),
      title: const Skeleton(height: 16, width: 120),
      subtitle: const Padding(
        padding: EdgeInsets.only(top: 8.0),
        child: Skeleton(height: 14, width: 80),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
           Skeleton(height: 24, width: 24, borderRadius: 12),
           SizedBox(width: 16),
           Skeleton(height: 24, width: 24, borderRadius: 12),
        ],
      ),
    );
  }
}
