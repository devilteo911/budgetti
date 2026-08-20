import 'package:budgetti/core/l10n.dart';
import 'package:flutter/material.dart';

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
    final cs = Theme.of(context).colorScheme;
    final accent = color ?? cs.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: cs.onSurfaceVariant,
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
                  ? accent.withValues(alpha: 0.1)
                  : cs.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? accent.withValues(alpha: 0.5)
                    : cs.onSurfaceVariant.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  size: 16,
                  color: isSelected ? accent : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  accountName ?? context.l10n.txSelectWallet,
                  style: TextStyle(
                    color: isSelected ? cs.onSurface : cs.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
