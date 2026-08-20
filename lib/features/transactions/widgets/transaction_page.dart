import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/theme/ledger_style.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:budgetti/core/widgets/wallet_picker_sheet.dart';
import 'package:budgetti/features/transactions/widgets/wallet_selector_chip.dart';

String _titleCase(String s) {
  if (s.isEmpty) return s;
  return s.split(' ').map((w) {
    if (w.isEmpty) return w;
    return w[0].toUpperCase() + w.substring(1).toLowerCase();
  }).join(' ');
}

class TransactionPage extends ConsumerStatefulWidget {
  final Transaction transaction;
  final Function(Transaction) onTransactionUpdated;

  const TransactionPage({
    super.key,
    required this.transaction,
    required this.onTransactionUpdated,
  });

  @override
  ConsumerState<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends ConsumerState<TransactionPage> {
  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = widget.transaction.date.isAfter(now) ? now : widget.transaction.date;
    
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: now,
    );

    if (picked != null && picked != widget.transaction.date) {
      final updated = widget.transaction.copyWith(date: picked);
      await ref.read(financeServiceProvider).updateTransaction(updated);
      widget.onTransactionUpdated(updated);
      ref.invalidate(transactionsProvider(null));
    }
  }

  void _showAccountPicker(
      BuildContext context, List<dynamic> accounts, bool isFrom) {
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return WalletPickerSheet(
          title: isFrom
              ? context.l10n.txSelectFromAccount
              : context.l10n.txSelectToAccount,
          selectedWalletId: isFrom ? widget.transaction.accountId : widget.transaction.toAccountId,
          onWalletSelected: (account) async {
            if (account == null) return;
            
            final updated = widget.transaction.copyWith(
              accountId: isFrom ? account.id : widget.transaction.accountId,
              toAccountId: isFrom ? widget.transaction.toAccountId : account.id,
            );
            
            await ref.read(financeServiceProvider).updateTransaction(updated);
            widget.onTransactionUpdated(updated);
            ref.invalidate(transactionsProvider(null));
            ref.invalidate(accountsProvider);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = widget.transaction;
    final formatter = ref.watch(currencyProvider);
    final isTransfer = t.type == 'transfer';
    final categoriesAsync = ref.watch(categoriesProvider);
    final tagsAsync = ref.watch(tagsProvider);
    final accountsAsync = ref.watch(accountsProvider);
    
    final categoryColors =
        ref.watch(categoryColorCacheProvider(cs.brightness));
    final tagColors = ref.watch(tagColorCacheProvider);

    return SafeArea(
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Amount and Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _titleCase(t.description),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: cs.onSurface,
                            ),
                          ),
                          InkWell(
                            onTap: () => _pickDate(context),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                DateFormat('EEEE, MMM d, yyyy').format(t.date),
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 14,
                                  decoration: TextDecoration.underline,
                                  decorationColor: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      isTransfer
                          ? formatter.format(t.amount.abs())
                          : t.amount > 0
                              ? "+${formatter.format(t.amount)}"
                              : formatter.format(t.amount),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: amountInk(cs,
                            isTransfer: isTransfer, isIncome: t.isIncome),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Transfer Section
                if (isTransfer) ...[
                  Text(
                    context.l10n.txTransferDetails,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  accountsAsync.when(
                    data: (accounts) {
                      final fromAccount = accounts
                          .where((a) => a.id == t.accountId)
                          .firstOrNull;
                      final toAccount = accounts
                          .where((a) => a.id == t.toAccountId)
                          .firstOrNull;
                      return Row(
                        children: [
                          Expanded(
                            child: WalletSelectorChip(
                              label: context.l10n.txFrom.toUpperCase(),
                              accountName: fromAccount?.name,
                              isSelected: true,
                              onTap: () => _showAccountPicker(context, accounts, true),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(Icons.arrow_forward,
                                color: cs.onSurfaceVariant),
                          ),
                          Expanded(
                            child: WalletSelectorChip(
                              label: context.l10n.txTo.toUpperCase(),
                              accountName: toAccount?.name,
                              isSelected: true,
                              color: cs.tertiary,
                              onTap: () => _showAccountPicker(context, accounts, false),
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (e, s) => Text(
                        context.l10n.txErrorLoadingAccounts(e.toString())),
                  ),
                  const SizedBox(height: 32),
                ],

                // Categories
                Text(
                  context.l10n.commonCategory,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                categoriesAsync.when(
                  data: (categories) {
                    final typeCategories = categories
                        .where((c) => c.type == (t.amount > 0 ? 'income' : 'expense'))
                        .toList();
                    return Wrap(
                      spacing: 8,
                      runSpacing: 12,
                      children: typeCategories.map((category) {
                        final isSelected = t.category == category.name && !isTransfer;
                        final color = categoryColors[category.name] ?? Colors.grey;
                        return InkWell(
                          onTap: () async {
                            final updated = t.copyWith(
                              category: category.name,
                              type: t.amount > 0 ? 'income' : 'expense',
                            );
                            await ref.read(financeServiceProvider).updateTransaction(updated);
                            widget.onTransactionUpdated(updated);
                            ref.invalidate(transactionsProvider(null));
                            ref.invalidate(accountsProvider);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withValues(alpha: 0.2)
                                  : cs.surfaceContainer,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? color : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSelected ? Icons.check_circle : Icons.circle,
                                  size: 16,
                                  color: isSelected ? color : cs.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  category.name,
                                  style: TextStyle(
                                    color: isSelected
                                        ? cs.onSurface
                                        : cs.onSurfaceVariant,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (e, s) => Text(
                      context.l10n.txErrorLoadingCategories(e.toString())),
                ),
                const SizedBox(height: 32),

                // Tags
                Text(
                  context.l10n.commonTags,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                tagsAsync.when(
                  data: (tags) {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 12,
                      children: tags.map((tag) {
                        final isSelected = t.tags.contains(tag.name);
                        final color = tagColors[tag.name] ?? Colors.grey;
                        return InkWell(
                          onTap: () async {
                            final newTags = List<String>.from(t.tags);
                            if (isSelected) {
                              newTags.remove(tag.name);
                            } else {
                              newTags.add(tag.name);
                            }
                            final updated = t.copyWith(tags: newTags);
                            await ref.read(financeServiceProvider).updateTransaction(updated);
                            widget.onTransactionUpdated(updated);
                            ref.invalidate(transactionsProvider(null));
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withValues(alpha: 0.2)
                                  : cs.surfaceContainer,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? color : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              tag.name,
                              style: TextStyle(
                                color: isSelected
                                    ? cs.onSurface
                                    : cs.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (e, s) =>
                      Text(context.l10n.txErrorLoadingTags(e.toString())),
                ),
                const SizedBox(height: 100), // Extra space for swipe indicator
              ],
            ),
          ),
          // Swipe Indicator
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainer.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swipe, color: cs.onSurfaceVariant, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.txSwipeNext,
                      style: TextStyle(
                          color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
