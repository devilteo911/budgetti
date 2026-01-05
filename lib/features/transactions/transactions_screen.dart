import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/models/transaction.dart';
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

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider('1'));

    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: transactionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
            error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
            data: (transactions) {
              if (transactions.isEmpty) {
                return const Center(child: Text("No transactions yet", style: TextStyle(color: AppTheme.textGrey)));
              }
              
              final grouped = _groupTransactionsByDate(transactions);
              return ListView.builder(
                padding: const EdgeInsets.only(top: 16, bottom: 24),
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
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: AppTheme.textGrey,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                        ),
                      ),
                      ...dayTransactions.map((t) => _TransactionItem(
                        transaction: t,
                        isSelected: _selectedIds.contains(t.id),
                        onLongPress: () => _toggleSelection(t.id), // Enter selection mode
                        onTap: () {
                          if (_isSelectionMode) {
                            _toggleSelection(t.id);
                          }
                          // Else: Show details (not implemented yet)
                        },
                      )),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_isSelectionMode) {
      return AppBar(
        backgroundColor: AppTheme.backgroundBlack,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _selectedIds.clear()),
        ),
        title: Text("${_selectedIds.length} Selected"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteSelected,
          ),
        ],
      );
    }
    return AppBar(
      backgroundColor: AppTheme.backgroundBlack,
      title: Text(
        "Transactions",
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textWhite,
            ),
      ),
      centerTitle: false,
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

    return GestureDetector(
      onLongPress: onLongPress,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.1) : AppTheme.surfaceGrey,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: AppTheme.primaryGreen, width: 2) : null,
        ),
        child: Row(
          children: [
            // Checkmark or Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryGreen : AppTheme.surfaceGreyLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: isSelected 
                ? const Icon(Icons.check, color: AppTheme.backgroundBlack, size: 20)
                : Icon(
                    isIncome ? Icons.arrow_downward : Icons.shopping_bag_outlined,
                    color: isIncome ? AppTheme.primaryGreen : Colors.white,
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
                  Text(
                    transaction.category, 
                    style: const TextStyle(color: AppTheme.textGrey, fontSize: 14)
                  ),
                ],
              ),
            ),
            Text(
              isIncome ? "+${formatter.format(transaction.amount)}" : formatter.format(transaction.amount.abs()),
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
