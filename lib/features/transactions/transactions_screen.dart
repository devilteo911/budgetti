import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/features/transactions/add_transaction_modal.dart';
import 'package:budgetti/features/transactions/transaction_filter_sheet.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:budgetti/models/tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final Set<String> _selectedIds = {};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;

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
        ref.invalidate(transactionsProvider);
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
    const accountId = '1';
    final transactionsAsync = ref.watch(filteredTransactionsProvider(accountId));
    final filters = ref.watch(transactionFiltersProvider);

    return transactionsAsync.when(
      loading: () => Scaffold(
        appBar: _buildAppBar(null),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
      ),
      error: (err, stack) => Scaffold(
        appBar: _buildAppBar(null),
        body: Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
      ),
      data: (transactions) {
        return Scaffold(
          appBar: _buildAppBar(transactions),
          body: SafeArea(
            child: Column(
              children: [
                if (!filters.isEmpty) _buildActiveFilters(filters),
                Expanded(
                  child: transactions.isEmpty
                      ? const Center(
                          child: Text("No transactions found",
                              style: TextStyle(color: AppTheme.textGrey)))
                      : Builder(
                          builder: (context) {
                            final grouped = _groupTransactionsByDate(transactions);
                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              itemCount: grouped.length,
                              itemBuilder: (context, index) {
                                final date = grouped.keys.elementAt(index);
                                final dayTransactions = grouped[date]!;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Text(
                                        _formatDateHeader(date),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              color: AppTheme.textGrey,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.2,
                                            ),
                                      ),
                                    ),
                                    ...dayTransactions.map((t) => _TransactionItem(
                                      transaction: t,
                                      isSelected: _selectedIds.contains(t.id),
                                      onLongPress: () => _toggleSelection(t.id),
                                      onTap: () {
                                        if (_isSelectionMode) {
                                          _toggleSelection(t.id);
                                        }
                                      },
                                    )),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(List<Transaction>? transactions) {
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
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteSelected,
          ),
        ],
      );
    }
    return AppBar(
      title: Text(
        "Transactions",
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textWhite,
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
                          orElse: () => Tag(id: '', name: tagName, colorHex: 0xFF9E9E9E),
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
