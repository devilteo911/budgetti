import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/models/account.dart';

class WalletPickerSheet extends ConsumerWidget {
  final String title;
  final String? selectedWalletId;
  final Function(Account?) onWalletSelected;
  final bool showAllWalletsOption;

  const WalletPickerSheet({
    super.key,
    this.title = "Select Wallet",
    this.selectedWalletId,
    required this.onWalletSelected,
    this.showAllWalletsOption = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final currencyFormatter = ref.watch(currencyProvider);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textGrey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 16),
            accountsAsync.when(
              data: (accounts) => Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (showAllWalletsOption)
                      ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 24),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: selectedWalletId == null
                                ? AppTheme.primaryGreen.withOpacity(0.1)
                                : AppTheme.surfaceGreyLight,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.all_inclusive,
                            color: selectedWalletId == null
                                ? AppTheme.primaryGreen
                                : AppTheme.textGrey,
                          ),
                        ),
                        title: Text(
                          "All Wallets",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: selectedWalletId == null
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: selectedWalletId == null
                            ? const Icon(Icons.check_circle,
                                color: AppTheme.primaryGreen)
                            : null,
                        onTap: () {
                          onWalletSelected(null);
                          Navigator.pop(context);
                        },
                      ),
                    ...accounts.map((account) {
                      final isSelected = account.id == selectedWalletId;
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryGreen.withOpacity(0.1)
                                : AppTheme.surfaceGreyLight,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.account_balance_wallet,
                            color: isSelected
                                ? AppTheme.primaryGreen
                                : AppTheme.textGrey,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          account.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          currencyFormatter.format(account.balance),
                          style: TextStyle(
                              color: isSelected
                                  ? AppTheme.primaryGreen
                                  : AppTheme.textGrey),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle,
                                color: AppTheme.primaryGreen)
                            : null,
                        onTap: () {
                          onWalletSelected(account);
                          Navigator.pop(context);
                        },
                      );
                    }),
                  ],
                ),
              ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppTheme.primaryGreen),
                ),
              ),
              error: (e, s) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text("Error: $e",
                      style: const TextStyle(color: Colors.red)),
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
