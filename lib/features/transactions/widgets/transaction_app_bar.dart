import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:budgetti/core/l10n.dart';
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
    final scheme = Theme.of(context).colorScheme;

    if (_isSelectionMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onClearSelection,
        ),
        title: Text(
          context.l10n.txSelected(selectedIds.length).toUpperCase(),
          style: GoogleFonts.jetBrainsMono(
            color: scheme.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          if (selectedIds.length == 1 && allTransactions != null)
            IconButton(
              icon: Icon(Icons.edit, color: scheme.primary),
              onPressed: () => onEditSelected(allTransactions!),
            ),
          if (allTransactions != null)
            IconButton(
              icon: Icon(
                selectedIds.length == allTransactions!.length
                    ? Icons.deselect_outlined
                    : Icons.select_all,
                color: scheme.primary,
              ),
              onPressed: onSelectAll,
            ),
          IconButton(
            icon: Icon(Icons.delete, color: scheme.error),
            onPressed: onDeleteSelected,
          ),
        ],
      );
    }

    final selectedWalletId = ref.watch(selectedWalletIdProvider);
    final selectedAccount =
        accounts.where((a) => a.id == selectedWalletId).firstOrNull;
    final filtersActive = !ref.watch(transactionFiltersProvider).isEmpty;
    final walletName = selectedAccount?.name ?? context.l10n.txAllWallets;

    return AppBar(
      titleSpacing: 16,
      title: InkWell(
        onTap: accounts.isEmpty ? null : onWalletTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.txLedger.toUpperCase(),
                style: GoogleFonts.jetBrainsMono(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      walletName,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (accounts.isNotEmpty) ...[
                    const SizedBox(width: 2),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: scheme.onSurface,
                      size: 18,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.filter_list,
            color: filtersActive ? scheme.primary : scheme.onSurface,
          ),
          onPressed: onFilterTap,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(72);
}
