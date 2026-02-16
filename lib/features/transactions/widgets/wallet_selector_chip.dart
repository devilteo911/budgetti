import 'package:flutter/material.dart';
import 'package:budgetti/core/theme/app_theme.dart';

class WalletSelectorChip extends StatelessWidget {
  final String label;
  final String? accountName;
  final VoidCallback onTap;
  final bool isSelected;
  final Color? color;

  const WalletSelectorChip({
    super.key,
    required this.label,
    this.accountName,
    required this.onTap,
    this.isSelected = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textGrey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? (color ?? AppTheme.primaryGreen).withOpacity(0.1)
                  : AppTheme.surfaceGrey,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? (color ?? AppTheme.primaryGreen).withOpacity(0.5)
                    : AppTheme.textGrey.withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  size: 16,
                  color: isSelected ? (color ?? AppTheme.primaryGreen) : AppTheme.textGrey,
                ),
                const SizedBox(width: 8),
                Text(
                  accountName ?? "Select Wallet",
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textGrey,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: AppTheme.textGrey,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
