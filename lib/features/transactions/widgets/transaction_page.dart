import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryGreen,
              onPrimary: AppTheme.backgroundBlack,
              surface: AppTheme.surfaceGrey,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
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
      context: context,
      backgroundColor: AppTheme.surfaceGrey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return WalletPickerSheet(
          title: isFrom ? "Select From Account" : "Select To Account",
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
    final t = widget.transaction;
    final formatter = ref.watch(currencyProvider);
    final isTransfer = t.type == 'transfer';
    final categoriesAsync = ref.watch(categoriesProvider);
    final tagsAsync = ref.watch(tagsProvider);
    final accountsAsync = ref.watch(accountsProvider);
    
    final categoryColors = ref.watch(categoryColorCacheProvider);
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
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          InkWell(
                            onTap: () => _pickDate(context),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                DateFormat('EEEE, MMM d, yyyy').format(t.date),
                                style: const TextStyle(
                                  color: AppTheme.textGrey,
                                  fontSize: 14,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppTheme.textGrey,
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
                        color: isTransfer
                            ? Colors.blue
                            : (t.amount > 0 ? AppTheme.primaryGreen : Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Transfer Section
                if (isTransfer) ...[
                  const Text(
                    "Transfer Details",
                    style: TextStyle(
                      color: Colors.white,
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
                              label: "FROM",
                              accountName: fromAccount?.name,
                              isSelected: true,
                              onTap: () => _showAccountPicker(context, accounts, true),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(Icons.arrow_forward, color: AppTheme.textGrey),
                          ),
                          Expanded(
                            child: WalletSelectorChip(
                              label: "TO",
                              accountName: toAccount?.name,
                              isSelected: true,
                              color: Colors.blue,
                              onTap: () => _showAccountPicker(context, accounts, false),
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (e, s) => Text("Error loading accounts: $e"),
                  ),
                  const SizedBox(height: 32),
                ],

                // Categories
                const Text(
                  "Category",
                  style: TextStyle(
                    color: Colors.white,
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
                              color: isSelected ? color.withOpacity(0.2) : AppTheme.surfaceGrey,
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
                                  color: isSelected ? color : AppTheme.textGrey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  category.name,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : AppTheme.textGrey,
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
                  error: (e, s) => Text("Error loading categories: $e"),
                ),
                const SizedBox(height: 32),

                // Tags
                const Text(
                  "Tags",
                  style: TextStyle(
                    color: Colors.white,
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
                              color: isSelected ? color.withOpacity(0.2) : AppTheme.surfaceGrey,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? color : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              tag.name,
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppTheme.textGrey,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (e, s) => Text("Error loading tags: $e"),
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
                  color: AppTheme.surfaceGrey.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swipe, color: AppTheme.textGrey, size: 16),
                    SizedBox(width: 8),
                    Text(
                      "Swipe for next transaction",
                      style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
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
