import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:budgetti/models/tag.dart';
import 'package:budgetti/features/transactions/add_transaction_modal.dart';
import 'package:budgetti/features/transactions/transaction_detail_screen.dart';
import 'package:budgetti/features/transactions/transaction_filter_sheet.dart';
import 'package:budgetti/features/settings/wallets_screen.dart';
import 'package:budgetti/features/dashboard/widgets/dashboard_skeletons.dart';
import 'package:budgetti/core/widgets/skeleton.dart';
import 'package:draggable_scrollbar/draggable_scrollbar.dart';

class _DateHeader {
  final String title;
  _DateHeader({required this.title});
}

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final Set<String> _selectedIds = {};
  final ScrollController _scrollController = ScrollController();
  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(paginatedTransactionsProvider.notifier).loadMore();
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    if (count == 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceGrey,
        title: const Text("Delete Transactions?", style: TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to delete near $count items?", style: const TextStyle(color: AppTheme.textGrey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(financeServiceProvider).deleteTransactions(_selectedIds.toList());
        setState(() {
          _selectedIds.clear();
        });
        ref.invalidate(paginatedTransactionsProvider); // Refresh balance
        ref.invalidate(accountsProvider); // Refresh balance
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
  }

  void _editSelected(List<Transaction> allTransactions) {
    if (_selectedIds.length != 1) return;
    
    final transactionToEdit = allTransactions.firstWhere(
      (t) => _selectedIds.contains(t.id),
    );
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundBlack,
      isScrollControlled: true,
      useRootNavigator: true,
      barrierColor: Colors.black54,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => AddTransactionModal(transaction: transactionToEdit),
    ).then((_) {
      setState(() => _selectedIds.clear());
    });
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final paginatedState = ref.watch(paginatedTransactionsProvider);
    final transactions = paginatedState.transactions;
    final filters = ref.watch(transactionFiltersProvider);

    if (paginatedState.isLoading && transactions.isEmpty) {
      return Scaffold(
        appBar: _buildAppBar(null, accountsAsync.value ?? []),
        body: ShimmerLoading(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
            itemCount: 10,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => const TransactionItemSkeleton(),
          ),
        ),
      );
    }

    if (paginatedState.error != null && transactions.isEmpty) {
      return Scaffold(
        appBar: _buildAppBar(null, accountsAsync.value ?? []),
        body: Center(
          child: Text(
            'Error: ${paginatedState.error}',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(transactions, accountsAsync.value ?? []),
      body: SafeArea(
        child: Column(
          children: [
            if (!filters.isEmpty) _buildActiveFilters(filters),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  final notifier = ref.read(paginatedTransactionsProvider.notifier);
                  ref.invalidate(accountsProvider);
                  await Future.wait([
                    notifier.refresh(),
                    ref.read(accountsProvider.future),
                  ]);
                },
                color: AppTheme.primaryGreen,
                backgroundColor: AppTheme.surfaceGrey,
                child: transactions.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: const Center(
                              child: Text(
                                "No transactions found",
                                style: TextStyle(color: AppTheme.textGrey),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Builder(
                        builder: (context) {
                          final grouped = _groupTransactionsByDate(transactions);
                          final sortedDates = grouped.keys.toList()
                            ..sort((a, b) => b.compareTo(a));
                          
                          final flatList = <dynamic>[];
                          final dateIndices = <int, DateTime>{};

                          for (var date in sortedDates) {
                            dateIndices[flatList.length] = date;
                            flatList.add(_DateHeader(title: _formatDateHeader(date)));
                            for (var t in grouped[date]!) {
                              dateIndices[flatList.length] = date;
                              flatList.add(t);
                            }
                          }

                          flatList.add(const SizedBox(height: 80));

                          return DraggableScrollbar.semicircle(
                            controller: _scrollController,
                            backgroundColor: AppTheme.surfaceGrey,
                            labelTextBuilder: (double offset) {
                              if (sortedDates.isEmpty) return const Text("");

                              final totalScrollable = _scrollController.position.maxScrollExtent;
                              final current = offset;

                              if (totalScrollable == 0) {
                                return Text(
                                  DateFormat('MMM yyyy').format(sortedDates.first),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }

                              final fraction = (current / totalScrollable).clamp(0.0, 1.0);
                              final index = (fraction * (flatList.length - 1)).floor();

                              var labelDate = DateTime.now();
                              int nearestHeader = -1;
                              for (var idx in dateIndices.keys) {
                                if (idx <= index && idx > nearestHeader) {
                                  nearestHeader = idx;
                                }
                              }
                              if (nearestHeader != -1) {
                                labelDate = dateIndices[nearestHeader]!;
                              }
                              
                              return Text(
                                DateFormat('MMM yyyy').format(labelDate).toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                            child: ListView.builder(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
                              itemCount: flatList.length + (paginatedState.hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == flatList.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 32.0),
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }
                                final item = flatList[index];
                                if (item is Widget) return item;
                                if (item is _DateHeader) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Text(
                                      item.title,
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        color: AppTheme.textGrey,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  );
                                }
                                if (item is Transaction) {
                                  return _TransactionItem(
                                    transaction: item,
                                    isSelected: _selectedIds.contains(item.id),
                                    onLongPress: () => _toggleSelection(item.id),
                                    onTap: () {
                                      if (_isSelectionMode) {
                                        _toggleSelection(item.id);
                                      } else {
                                        final originalIndex = transactions.indexOf(item);
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => TransactionDetailScreen(
                                              transactions: transactions,
                                              initialIndex: originalIndex,
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(List<Transaction>? transactions, List<dynamic> accounts) {
    if (_isSelectionMode) {
      return AppBar(
        backgroundColor: AppTheme.backgroundBlack,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _selectedIds.clear()),
        ),
        title: Text("${_selectedIds.length} Selected"),
        actions: [
          if (_selectedIds.length == 1 && transactions != null)
            IconButton(
              icon: const Icon(Icons.edit, color: AppTheme.primaryGreen),
              onPressed: () => _editSelected(transactions),
            ),
          if (transactions != null)
            IconButton(
              icon: Icon(
                _selectedIds.length == transactions.length
                    ? Icons.deselect_outlined
                    : Icons.select_all,
                color: AppTheme.primaryGreen,
              ),
              onPressed: () {
                setState(() {
                  final allIds = transactions.map((t) => t.id).toSet();
                  if (_selectedIds.length == transactions.length &&
                      _selectedIds.containsAll(allIds)) {
                    _selectedIds.clear();
                  } else {
                    _selectedIds.addAll(allIds);
                  }
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteSelected,
          ),
        ],
      );
    }
    
    final selectedWalletId = ref.watch(selectedWalletIdProvider);
    final selectedAccount = accounts.where((a) => a.id == selectedWalletId).firstOrNull;

    return AppBar(
      titleSpacing: 16,
      title: accounts.isEmpty 
          ? const Text("Transactions", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          : InkWell(
              onTap: () => _showWalletFilterSheet(context, ref, accounts),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.only(left: 0, right: 8, top: 4, bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedAccount?.name ?? "All Wallets",
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textWhite,
                          ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down, color: AppTheme.primaryGreen),
                  ],
                ),
              ),
            ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.filter_list,
            color: ref.watch(transactionFiltersProvider).isEmpty 
                ? Colors.white 
                : AppTheme.primaryGreen,
          ),
          onPressed: _showFilterSheet,
        ),
      ],
    );
  }

  Widget _buildActiveFilters(TransactionFilterState filters) {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8, top: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        children: [
          if (filters.dateRange != null)
            _ActiveFilterChip(
              label: filters.dateRange!.start.year == filters.dateRange!.end.year &&
                     filters.dateRange!.start.month == filters.dateRange!.end.month &&
                     filters.dateRange!.start.day == filters.dateRange!.end.day
                  ? DateFormat('dd MMM').format(filters.dateRange!.start)
                  : "${DateFormat('dd MMM').format(filters.dateRange!.start)} - ${DateFormat('dd MMM').format(filters.dateRange!.end)}",
              onDeleted: () => ref.read(transactionFiltersProvider.notifier).setDateRange(null),
            ),
          ...filters.categories.map((c) => _ActiveFilterChip(
            label: c,
            onDeleted: () => ref.read(transactionFiltersProvider.notifier).toggleCategory(c),
          )),
          ...filters.tags.map((t) => _ActiveFilterChip(
            label: t,
            onDeleted: () => ref.read(transactionFiltersProvider.notifier).toggleTag(t),
          )),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const TransactionFilterSheet(),
    );
  }

  void _showWalletFilterSheet(BuildContext context, WidgetRef ref, List<dynamic> accounts) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceGrey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final selectedWalletId = ref.watch(selectedWalletIdProvider);
        final currencyFormatter = ref.watch(currencyProvider);

        return Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textGrey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Filter by Wallet",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: selectedWalletId == null ? AppTheme.primaryGreen.withValues(alpha: 0.1) : AppTheme.surfaceGreyLight,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.all_inclusive, color: selectedWalletId == null ? AppTheme.primaryGreen : AppTheme.textGrey),
                      ),
                      title: Text("All Wallets", style: TextStyle(color: Colors.white, fontWeight: selectedWalletId == null ? FontWeight.bold : FontWeight.normal)),
                      trailing: selectedWalletId == null ? const Icon(Icons.check_circle, color: AppTheme.primaryGreen) : null,
                      onTap: () {
                        ref.read(selectedWalletIdProvider.notifier).set(null);
                        Navigator.pop(context);
                      },
                    ),
                    const Divider(color: AppTheme.surfaceGreyLight, indent: 16, endIndent: 16),
                    ...accounts.map((account) {
                      final isSelected = account.id == selectedWalletId;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.1) : AppTheme.surfaceGreyLight,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.account_balance_wallet, color: isSelected ? AppTheme.primaryGreen : AppTheme.textGrey),
                        ),
                        title: Text(account.name, style: TextStyle(color: Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Text(currencyFormatter.format(account.balance), style: TextStyle(color: isSelected ? AppTheme.primaryGreen : AppTheme.textGrey)),
                        trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.primaryGreen) : null,
                        onTap: () {
                          ref.read(selectedWalletIdProvider.notifier).set(account.id);
                          Navigator.pop(context);
                        },
                      );
                    }),
                    const Divider(color: AppTheme.surfaceGreyLight, indent: 16, endIndent: 16),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                      leading: const Icon(Icons.settings, color: AppTheme.textGrey),
                      title: const Text("Manage Wallets...", style: TextStyle(color: AppTheme.textGrey, fontStyle: FontStyle.italic)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const WalletsScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Map<DateTime, List<Transaction>> _groupTransactionsByDate(List<Transaction> transactions) {
     final map = <DateTime, List<Transaction>>{};
     for (var t in transactions) {
       final date = DateTime(t.date.year, t.date.month, t.date.day);
       if (map[date] == null) map[date] = [];
       map[date]!.add(t);
     }
     return map;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) return "TODAY";
    if (date == yesterday) return "YESTERDAY";
    return DateFormat('MMMM d').format(date).toUpperCase();
  }
}

class _TransactionItem extends ConsumerWidget {
  final Transaction transaction;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  const _TransactionItem({
    required this.transaction,
    this.isSelected = false,
    this.onLongPress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIncome = transaction.amount > 0;
    final formatter = ref.watch(currencyProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final tagsAsync = ref.watch(tagsProvider);
    
    // Find the category 
    final category = categoriesAsync.value?.firstWhere(
      (c) => c.name == transaction.category,
      orElse: () => categoriesAsync.value!.first,
    );

    final categoryColor = category != null ? Color(category.colorHex) : null;
    final allTags = tagsAsync.value ?? [];

    return GestureDetector(
      onLongPress: onLongPress,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
            ? AppTheme.primaryGreen.withValues(alpha: 0.1) 
            : categoryColor != null 
              ? categoryColor.withValues(alpha: 0.08)
              : AppTheme.surfaceGrey,
          borderRadius: BorderRadius.circular(16),
          border: isSelected 
            ? Border.all(color: AppTheme.primaryGreen, width: 2) 
            : categoryColor != null
              ? Border.all(color: categoryColor.withValues(alpha: 0.3), width: 1)
              : null,
        ),
        child: Row(
          children: [
            // Checkmark or Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected 
                  ? AppTheme.primaryGreen 
                  : categoryColor != null
                    ? categoryColor.withValues(alpha: 0.2)
                    : AppTheme.surfaceGreyLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: isSelected 
                ? const Icon(Icons.check, color: AppTheme.backgroundBlack, size: 20)
                : Icon(
                    category != null 
                      ? IconData(category.iconCode, fontFamily: 'MaterialIcons')
                      : (isIncome ? Icons.arrow_downward : Icons.shopping_bag_outlined),
                    color: categoryColor ?? (isIncome ? AppTheme.primaryGreen : Colors.white),
                    size: 20,
                  ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description, 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        transaction.category, 
                        style: TextStyle(
                          color: categoryColor?.withValues(alpha: 0.8) ?? AppTheme.textGrey, 
                          fontSize: 14
                        )
                      ),
                      ...transaction.tags.map((tagName) {
                        final tag = allTags.firstWhere(
                          (t) => t.name == tagName,
                          orElse: () => Tag(
                            id: '',
                            userId: 'local',
                            name: tagName,
                            colorHex: 0xFF9E9E9E,
                          ),
                        );
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Color(tag.colorHex).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Color(tag.colorHex).withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            tag.name,
                            style: TextStyle(
                              color: Color(tag.colorHex),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              isIncome 
                ? "+${formatter.format(transaction.amount)}" 
                : "-${formatter.format(transaction.amount.abs())}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isIncome ? AppTheme.primaryGreen : Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onDeleted;

  const _ActiveFilterChip({required this.label, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InputChip(
        label: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.primaryGreen)),
        onDeleted: onDeleted,
        deleteIcon: const Icon(Icons.close, size: 14, color: AppTheme.primaryGreen),
        backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
        ),
      ),
    );
  }
}


