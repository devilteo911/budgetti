import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:budgetti/models/account.dart';

class TransactionAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final List<Transaction>? allTransactions;
  final Set<String> selectedIds;
  final VoidCallback onClearSelection;
  final VoidCallback onDeleteSelected;
  final Function(List<Transaction>) onEditSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onFilterTap;
  final VoidCallback onWalletTap;
  final List<Account> accounts;

  const TransactionAppBar({
    super.key,
    this.allTransactions,
    required this.selectedIds,
    required this.onClearSelection,
    required this.onDeleteSelected,
    required this.onEditSelected,
    required this.onSelectAll,
    required this.onFilterTap,
    required this.onWalletTap,
    required this.accounts,
  });

  bool get _isSelectionMode => selectedIds.isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_isSelectionMode) {
      return AppBar(
        backgroundColor: AppTheme.backgroundBlack,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onClearSelection,
        ),
        title: Text("${selectedIds.length} Selected"),
        actions: [
          if (selectedIds.length == 1 && allTransactions != null)
            IconButton(
              icon: const Icon(Icons.edit, color: AppTheme.primaryGreen),
              onPressed: () => onEditSelected(allTransactions!),
            ),
          if (allTransactions != null)
            IconButton(
              icon: Icon(
                selectedIds.length == allTransactions!.length
                    ? Icons.deselect_outlined
                    : Icons.select_all,
                color: AppTheme.primaryGreen,
              ),
              onPressed: onSelectAll,
            ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: onDeleteSelected,
          ),
        ],
      );
    }

    final selectedWalletId = ref.watch(selectedWalletIdProvider);
    final selectedAccount =
        accounts.where((a) => a.id == selectedWalletId).firstOrNull;
    final filtersActive = !ref.watch(transactionFiltersProvider).isEmpty;

    return AppBar(
      title: accounts.isEmpty
          ? Text(
              "Transactions",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            )
          : InkWell(
              onTap: onWalletTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        selectedAccount?.name ?? "All Wallets",
                        style:
                            Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down,
                        color: AppTheme.primaryGreen),
                  ],
                ),
              ),
            ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.filter_list,
            color: filtersActive ? AppTheme.primaryGreen : Colors.white,
          ),
          onPressed: onFilterTap,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(80);
}
