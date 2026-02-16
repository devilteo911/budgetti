import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:budgetti/features/transactions/add_transaction_modal.dart';
import 'package:budgetti/features/transactions/transaction_filter_sheet.dart';
import 'package:budgetti/features/dashboard/widgets/dashboard_skeletons.dart';
import 'package:budgetti/core/widgets/skeleton.dart';
import 'package:budgetti/core/widgets/wallet_picker_sheet.dart';
import 'package:budgetti/features/transactions/widgets/transaction_list.dart';
import 'package:budgetti/features/transactions/widgets/transaction_app_bar.dart';
import 'package:budgetti/features/transactions/widgets/active_filter_chip.dart';


class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final Set<String> _selectedIds = {};
  final ScrollController _scrollController = ScrollController();

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
        ref.invalidate(paginatedTransactionsProvider);
        ref.invalidate(accountsProvider);
        ref.invalidate(transactionsProvider(null)); // Refresh charts and stats
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

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const TransactionFilterSheet(),
    );
  }

  void _showWalletFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceGrey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => WalletPickerSheet(
        title: "Filter by Wallet",
        selectedWalletId: ref.watch(selectedWalletIdProvider),
        showAllWalletsOption: true,
        onWalletSelected: (account) {
          ref.read(selectedWalletIdProvider.notifier).set(account?.id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final paginatedState = ref.watch(paginatedTransactionsProvider);
    final transactions = paginatedState.transactions;
    final filters = ref.watch(transactionFiltersProvider);

    if (paginatedState.isLoading && transactions.isEmpty) {
      return Scaffold(
        appBar: TransactionAppBar(
          selectedIds: _selectedIds,
          onClearSelection: () => setState(() => _selectedIds.clear()),
          onDeleteSelected: _deleteSelected,
          onEditSelected: _editSelected,
          onSelectAll: () {},
          onFilterTap: _showFilterSheet,
          onWalletTap: _showWalletFilterSheet,
          accounts: accountsAsync.value ?? [],
        ),
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
        appBar: TransactionAppBar(
          selectedIds: _selectedIds,
          onClearSelection: () => setState(() => _selectedIds.clear()),
          onDeleteSelected: _deleteSelected,
          onEditSelected: _editSelected,
          onSelectAll: () {},
          onFilterTap: _showFilterSheet,
          onWalletTap: _showWalletFilterSheet,
          accounts: accountsAsync.value ?? [],
        ),
        body: Center(
          child: Text(
            'Error: ${paginatedState.error}',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: TransactionAppBar(
        allTransactions: transactions,
        selectedIds: _selectedIds,
        onClearSelection: () => setState(() => _selectedIds.clear()),
        onDeleteSelected: _deleteSelected,
        onEditSelected: _editSelected,
        onSelectAll: () {
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
        onFilterTap: _showFilterSheet,
        onWalletTap: _showWalletFilterSheet,
        accounts: accountsAsync.value ?? [],
      ),
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
                child: TransactionList(
                  transactions: transactions,
                  paginatedState: paginatedState,
                  scrollController: _scrollController,
                  selectedIds: _selectedIds,
                  onToggleSelection: _toggleSelection,
                ),
              ),
            ),
          ],
        ),
      ),
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
            ActiveFilterChip(
              label: filters.dateRange!.start.year == filters.dateRange!.end.year &&
                     filters.dateRange!.start.month == filters.dateRange!.end.month &&
                     filters.dateRange!.start.day == filters.dateRange!.end.day
                  ? DateFormat('dd MMM').format(filters.dateRange!.start)
                  : "${DateFormat('dd MMM').format(filters.dateRange!.start)} - ${DateFormat('dd MMM').format(filters.dateRange!.end)}",
              onDeleted: () => ref.read(transactionFiltersProvider.notifier).setDateRange(null),
            ),
          ...filters.categories.map(
            (c) => ActiveFilterChip(
            label: c,
            onDeleted: () => ref.read(transactionFiltersProvider.notifier).toggleCategory(c),
          )),
          ...filters.tags.map(
            (t) => ActiveFilterChip(
            label: t,
            onDeleted: () => ref.read(transactionFiltersProvider.notifier).toggleTag(t),
          )),
        ],
      ),
    );
  }
}


