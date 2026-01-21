import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class TransactionDetailScreen extends ConsumerStatefulWidget {
  final List<Transaction> transactions;
  final int initialIndex;

  const TransactionDetailScreen({
    super.key,
    required this.transactions,
    required this.initialIndex,
  });

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<TransactionDetailScreen> {
  late PageController _pageController;
  late List<Transaction> _currentTransactions;

  @override
  void initState() {
    super.initState();
    _currentTransactions = widget.transactions;
    _pageController = PageController(initialPage: widget.initialIndex);
    _pageController.addListener(() {
      if (_pageController.hasClients) {
        setState(() {}); // Rebuild to update AppBar title
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: Text(
          _currentTransactions.isNotEmpty
              ? _currentTransactions[_pageController.hasClients
                        ? _pageController.page?.round() ?? widget.initialIndex
                        : widget.initialIndex]
                    .description
              : "Fast Categorization",
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.horizontal,
        itemCount: _currentTransactions.length,
        itemBuilder: (context, index) {
          return _TransactionPage(
            transaction: _currentTransactions[index],
            onTransactionUpdated: (updatedTransaction) {
              setState(() {
                _currentTransactions[index] = updatedTransaction;
              });
            },
          );
        },
      ),
    );
  }
}

class _TransactionPage extends ConsumerStatefulWidget {
  final Transaction transaction;
  final Function(Transaction) onTransactionUpdated;

  const _TransactionPage({
    required this.transaction,
    required this.onTransactionUpdated,
  });

  @override
  ConsumerState<_TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends ConsumerState<_TransactionPage> {
  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final tagsAsync = ref.watch(tagsProvider);
    final currencyFormatter = ref.watch(currencyProvider);

    final t = widget.transaction;

    return SafeArea(
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Amount & Date
                Center(
                  child: Column(
                    children: [
                      Text(
                        t.type == 'transfer'
                            ? currencyFormatter.format(t.amount.abs())
                            : (t.amount >= 0
                                  ? "+${currencyFormatter.format(t.amount)}"
                                  : "-${currencyFormatter.format(t.amount.abs())}"),
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              color: t.type == 'transfer'
                                  ? Colors.blue
                                  : (t.amount >= 0
                                        ? AppTheme.primaryGreen
                                        : Colors.white),
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('MMMM d, yyyy').format(t.date),
                        style: const TextStyle(color: AppTheme.textGrey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Transfer Section
                Row(
                  children: [
                    const Text(
                      "TRANSFER",
                      style: TextStyle(
                        color: AppTheme.textGrey,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    if (t.type != 'transfer')
                      Consumer(
                        builder: (context, ref, child) {
                          final accounts =
                              ref.watch(accountsProvider).value ?? [];
                          final defaultAccount =
                              accounts.where((a) => a.isDefault).firstOrNull ??
                              accounts.firstOrNull;
                          return InkWell(
                            onTap: () async {
                              if (defaultAccount != null &&
                                  accounts.length > 1) {
                                final toAcc = accounts.firstWhere(
                                  (a) => a.id != defaultAccount.id,
                                );
                                final updated = t.copyWith(
                                  type: 'transfer',
                                  accountId: defaultAccount.id,
                                  toAccountId: toAcc.id,
                                  category: 'Transfer',
                                  amount: t.amount.abs(),
                                );
                                await ref
                                    .read(financeServiceProvider)
                                    .updateTransaction(updated);
                                widget.onTransactionUpdated(updated);
                                ref.invalidate(transactionsProvider);
                                ref.invalidate(accountsProvider);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    size: 14,
                                    color: AppTheme.primaryGreen,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Quick Transfer",
                                    style: TextStyle(
                                      color: AppTheme.primaryGreen.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Consumer(
                  builder: (context, ref, child) {
                    final accounts = ref.watch(accountsProvider).value ?? [];
                    final fromAccount = accounts
                        .where((a) => a.id == t.accountId)
                        .firstOrNull;
                    final toAccount = accounts
                        .where((a) => a.id == t.toAccountId)
                        .firstOrNull;
                    final defaultAccount =
                        accounts.where((a) => a.isDefault).firstOrNull ??
                        accounts.firstOrNull;

                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceGrey.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: t.type == 'transfer'
                            ? Border.all(
                                color: Colors.blue.withValues(alpha: 0.3),
                                width: 1,
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final selectedId = await _showAccountPicker(
                                  context,
                                  accounts,
                                  t.accountId,
                                );
                                if (selectedId != null) {
                                  final updated = t.copyWith(
                                    accountId: selectedId,
                                  );
                                  await ref
                                      .read(financeServiceProvider)
                                      .updateTransaction(updated);
                                  widget.onTransactionUpdated(updated);
                                  ref.invalidate(transactionsProvider);
                                  ref.invalidate(accountsProvider);
                                }
                              },
                              child: _WalletSelectorChip(
                                label: "FROM",
                                accountName: fromAccount?.name ?? "Select",
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              color: AppTheme.textGrey,
                              size: 16,
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final selectedId = await _showAccountPicker(
                                  context,
                                  accounts,
                                  t.toAccountId,
                                );
                                if (selectedId != null) {
                                  final updated = t.copyWith(
                                    type: 'transfer',
                                    accountId: t.type != 'transfer'
                                        ? defaultAccount?.id ?? t.accountId
                                        : t.accountId,
                                    toAccountId: selectedId,
                                    category: 'Transfer',
                                    amount: t.amount.abs(),
                                  );
                                  await ref
                                      .read(financeServiceProvider)
                                      .updateTransaction(updated);
                                  widget.onTransactionUpdated(updated);
                                  ref.invalidate(transactionsProvider);
                                  ref.invalidate(accountsProvider);
                                }
                              },
                              child: _WalletSelectorChip(
                                label: "TO",
                                accountName: toAccount?.name ?? "Select",
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Categories
                const Text(
                  "CATEGORY",
                  style: TextStyle(
                    color: AppTheme.textGrey,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                categoriesAsync.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (err, stack) => Text(
                      "Error: $err",
                      style: const TextStyle(color: Colors.red),
                    ),
                    data: (categories) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((category) {
                        final isSelected =
                            t.category == category.name && t.type != 'transfer';
                        return InkWell(
                          onTap: () async {
                            final newAmount = category.type == 'expense'
                                ? -t.amount.abs()
                                : t.amount.abs();
                            final updated = t.copyWith(
                              category: category.name,
                              type: category.type,
                              amount: newAmount,
                              toAccountId: null,
                            );
                            await ref
                                .read(financeServiceProvider)
                                .updateTransaction(updated);
                            widget.onTransactionUpdated(updated);
                            ref.invalidate(transactionsProvider);
                            ref.invalidate(accountsProvider);
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Color(category.colorHex)
                                  : AppTheme.surfaceGrey.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 2)
                                  : Border.all(
                                      color: AppTheme.textGrey.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  IconData(
                                    category.iconCode,
                                    fontFamily: 'MaterialIcons',
                                  ),
                                  size: 16,
                                  color: isSelected
                                      ? Colors.white
                                      : AppTheme.textGrey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  category.name,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : AppTheme.textGrey,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  category.type == 'income'
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  size: 12,
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : (category.type == 'income'
                                            ? AppTheme.primaryGreen
                                            : Colors.red.withValues(
                                                alpha: 0.5,
                                              )),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                const SizedBox(height: 32),

                // Tags
                const Text(
                  "TAGS",
                  style: TextStyle(
                    color: AppTheme.textGrey,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                tagsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (tags) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags.map((tag) {
                      final isSelected = t.tags.contains(tag.name);
                      return FilterChip(
                        label: Text(tag.name),
                        selected: isSelected,
                        onSelected: (selected) async {
                          List<String> newTags = List.from(t.tags);
                          if (selected) {
                            newTags.add(tag.name);
                          } else {
                            newTags.remove(tag.name);
                          }
                          final updated = t.copyWith(tags: newTags);
                          await ref.read(financeServiceProvider).updateTransaction(updated);
                          widget.onTransactionUpdated(updated);
                          ref.invalidate(transactionsProvider);
                        },
                        backgroundColor: AppTheme.surfaceGrey,
                        selectedColor: Color(tag.colorHex).withValues(alpha: 0.3),
                        checkmarkColor: Color(tag.colorHex),
                        labelStyle: TextStyle(
                          color: isSelected ? Color(tag.colorHex) : AppTheme.textGrey,
                          fontWeight: FontWeight.w500,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? Color(tag.colorHex) : Colors.transparent,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chevron_left,
                  color: AppTheme.textGrey.withValues(alpha: 0.5),
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  "SWIPE",
                  style: TextStyle(
                    color: AppTheme.textGrey,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: AppTheme.textGrey.withValues(alpha: 0.5),
                  size: 24,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _showAccountPicker(
    BuildContext context,
    List<dynamic> accounts,
    String? currentId,
  ) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surfaceGrey,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Select Wallet",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: accounts.map((account) {
                    final isSelected = account.id == currentId;
                    return ListTile(
                      title: Text(
                        account.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle,
                              color: AppTheme.primaryGreen,
                            )
                          : null,
                      onTap: () => Navigator.of(context).pop(account.id),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WalletSelectorChip extends StatelessWidget {
  final String label;
  final String accountName;
  const _WalletSelectorChip({required this.label, required this.accountName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGrey.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.textGrey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textGrey,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            accountName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
