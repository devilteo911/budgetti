import 'package:budgetti/core/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/models/account.dart';

class WalletPickerSheet extends ConsumerWidget {
  final String? title;
  final String? selectedWalletId;
  final Function(Account?) onWalletSelected;
  final bool showAllWalletsOption;

  const WalletPickerSheet({
    super.key,
    this.title,
    this.selectedWalletId,
    required this.onWalletSelected,
    this.showAllWalletsOption = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final accountsAsync = ref.watch(accountsProvider);
    final currencyFormatter = ref.watch(currencyProvider);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title ?? context.l10n.uiSelectWallet,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 12),
            accountsAsync.when(
              data: (accounts) => Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (showAllWalletsOption)
                      _WalletTile(
                        icon: Icons.all_inclusive,
                        name: context.l10n.uiAllWallets,
                        isSelected: selectedWalletId == null,
                        onTap: () {
                          onWalletSelected(null);
                          Navigator.pop(context);
                        },
                      ),
                    ...accounts.map((account) {
                      return _WalletTile(
                        icon: Icons.account_balance_wallet,
                        name: account.name,
                        subtitle: currencyFormatter.format(account.balance),
                        isSelected: account.id == selectedWalletId,
                        onTap: () {
                          onWalletSelected(account);
                          Navigator.pop(context);
                        },
                      );
                    }),
                  ],
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
              error: (e, s) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "Error: $e",
                  style: TextStyle(color: scheme.error),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _WalletTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _WalletTile({
    required this.icon,
    required this.name,
    required this.isSelected,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = isSelected ? scheme.primary : scheme.onSurfaceVariant;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primary.withValues(alpha: 0.12)
              : scheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: accent, size: 20),
      ),
      title: Text(
        name,
        style: TextStyle(
          color: scheme.onSurface,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: TextStyle(color: accent)),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: scheme.primary)
          : null,
      onTap: onTap,
    );
  }
}
