import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/error_text.dart';
import 'package:budgetti/core/theme/ledger_style.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:budgetti/core/widgets/app_sheet.dart';
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
  Transaction get _tx => widget.transaction;

  /// Persist an edit and let every list that shows this row hear about it.
  Future<void> _save(Transaction updated, {bool balancesChanged = true}) async {
    await ref.read(financeServiceProvider).updateTransaction(updated);
    widget.onTransactionUpdated(updated);
    ref.invalidate(transactionsProvider(null));
    if (balancesChanged) ref.invalidate(accountsProvider);
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = _tx.date.isAfter(now) ? now : _tx.date;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: now,
    );

    if (picked != null && picked != _tx.date) {
      await _save(_tx.copyWith(date: picked), balancesChanged: false);
    }
  }

  void _showAccountPicker(
      BuildContext context, List<dynamic> accounts, bool isFrom) {
    showAppSheet(
      context,
      builder: (context) => WalletPickerSheet(
        title: isFrom
            ? context.l10n.txSelectFromAccount
            : context.l10n.txSelectToAccount,
        selectedWalletId: isFrom ? _tx.accountId : _tx.toAccountId,
        onWalletSelected: (account) async {
          if (account == null) return;
          await _save(_tx.copyWith(
            accountId: isFrom ? account.id : _tx.accountId,
            toAccountId: isFrom ? _tx.toAccountId : account.id,
          ));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isTransfer = _tx.type == 'transfer';

    return SafeArea(
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(cs, isTransfer),
                const SizedBox(height: 32),
                if (isTransfer) ...[
                  _sectionTitle(cs, context.l10n.txTransferDetails),
                  const SizedBox(height: 16),
                  _transferAccounts(cs),
                  const SizedBox(height: 32),
                ],
                _sectionTitle(cs, context.l10n.commonCategory),
                const SizedBox(height: 16),
                _categoryChips(cs, isTransfer),
                const SizedBox(height: 32),
                _sectionTitle(cs, context.l10n.commonTags),
                const SizedBox(height: 16),
                _tagChips(cs),
                // Room for the swipe hint floating over the scroll view.
                const SizedBox(height: 100),
              ],
            ),
          ),
          _swipeHint(cs),
        ],
      ),
    );
  }

  Widget _sectionTitle(ColorScheme cs, String text) => Text(
        text,
        style: TextStyle(
          color: cs.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      );

  Widget _header(ColorScheme cs, bool isTransfer) {
    final formatter = ref.watch(currencyProvider);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _titleCase(_tx.description),
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
                    DateFormat('EEEE, MMM d, yyyy').format(_tx.date),
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
              ? formatter.format(_tx.amount.abs())
              : _tx.amount > 0
                  ? "+${formatter.format(_tx.amount)}"
                  : formatter.format(_tx.amount),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: amountInk(cs,
                isTransfer: isTransfer, isIncome: _tx.isIncome),
          ),
        ),
      ],
    );
  }

  Widget _transferAccounts(ColorScheme cs) {
    return ref.watch(accountsProvider).when(
          loading: () => const CircularProgressIndicator(),
          error: (e, s) => Text(
              context.l10n.txErrorLoadingAccounts(errorText(context, e))),
          data: (accounts) {
            final from =
                accounts.where((a) => a.id == _tx.accountId).firstOrNull;
            final to =
                accounts.where((a) => a.id == _tx.toAccountId).firstOrNull;
            return Row(
              children: [
                Expanded(
                  child: WalletSelectorChip(
                    label: context.l10n.txFrom.toUpperCase(),
                    accountName: from?.name,
                    isSelected: true,
                    onTap: () => _showAccountPicker(context, accounts, true),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child:
                      Icon(Icons.arrow_forward, color: cs.onSurfaceVariant),
                ),
                Expanded(
                  child: WalletSelectorChip(
                    label: context.l10n.txTo.toUpperCase(),
                    accountName: to?.name,
                    isSelected: true,
                    color: cs.tertiary,
                    onTap: () => _showAccountPicker(context, accounts, false),
                  ),
                ),
              ],
            );
          },
        );
  }

  /// The one chip shape the category and tag pickers share. `dense` is the
  /// tag variant: pill-shaped, smaller, no leading icon.
  Widget _pickChip(
    ColorScheme cs, {
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
    bool dense = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: dense
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? color.withValues(alpha: 0.2) : cs.surfaceContainer,
          borderRadius: BorderRadius.circular(dense ? 20 : 12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: dense ? 1.5 : 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 16, color: isSelected ? color : cs.onSurfaceVariant),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? cs.onSurface : cs.onSurfaceVariant,
                fontSize: dense ? 13 : 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChips(ColorScheme cs, bool isTransfer) {
    final colors = ref.watch(categoryColorCacheProvider(cs.brightness));
    return ref.watch(categoriesProvider).when(
          loading: () => const CircularProgressIndicator(),
          error: (e, s) => Text(
              context.l10n.txErrorLoadingCategories(errorText(context, e))),
          data: (categories) {
            final wanted = _tx.amount > 0 ? 'income' : 'expense';
            return Wrap(
              spacing: 8,
              runSpacing: 12,
              children: categories.where((c) => c.type == wanted).map((c) {
                final isSelected = _tx.category == c.name && !isTransfer;
                return _pickChip(
                  cs,
                  label: c.name,
                  color: colors[c.name] ?? Colors.grey,
                  isSelected: isSelected,
                  // Outlined, not filled: onSurfaceVariant is near-black in
                  // light mode, where a solid dot shouts louder than the label.
                  icon: isSelected ? Icons.check_circle : Icons.circle_outlined,
                  onTap: () =>
                      _save(_tx.copyWith(category: c.name, type: wanted)),
                );
              }).toList(),
            );
          },
        );
  }

  Widget _tagChips(ColorScheme cs) {
    final colors = ref.watch(tagColorCacheProvider);
    return ref.watch(tagsProvider).when(
          loading: () => const CircularProgressIndicator(),
          error: (e, s) =>
              Text(context.l10n.txErrorLoadingTags(errorText(context, e))),
          data: (tags) => Wrap(
            spacing: 8,
            runSpacing: 12,
            children: tags.map((tag) {
              final isSelected = _tx.tags.contains(tag.name);
              return _pickChip(
                cs,
                label: tag.name,
                color: colors[tag.name] ?? Colors.grey,
                isSelected: isSelected,
                dense: true,
                onTap: () {
                  final next = List<String>.from(_tx.tags);
                  if (isSelected) {
                    next.remove(tag.name);
                  } else {
                    next.add(tag.name);
                  }
                  _save(_tx.copyWith(tags: next), balancesChanged: false);
                },
              );
            }).toList(),
          ),
        );
  }

  Widget _swipeHint(ColorScheme cs) => Positioned(
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
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
}
