import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:budgetti/features/transactions/add_transaction_modal.dart';
import 'package:budgetti/features/transactions/transaction_filter_sheet.dart';
import 'package:budgetti/features/dashboard/widgets/dashboard_skeletons.dart';
import 'package:budgetti/core/widgets/skeleton.dart';
import 'package:budgetti/core/widgets/wallet_picker_sheet.dart';
import 'package:budgetti/features/transactions/widgets/transaction_list.dart';
import 'package:budgetti/features/transactions/widgets/transaction_app_bar.dart';
import 'package:budgetti/features/transactions/widgets/transactions_hero.dart';
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

    final scheme = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.txDeleteTransactionsTitle),
        content: Text(context.l10n.txDeleteConfirm(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.commonDelete,
                style: TextStyle(color: scheme.error)),
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
        ref.invalidate(transactionsProvider(null));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.txError(e.toString()))));
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
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
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
      useRootNavigator: true,
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const TransactionFilterSheet(),
    );
  }

  void _showWalletFilterSheet() {
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => WalletPickerSheet(
        title: context.l10n.txFilterByWallet,
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
    final scheme = Theme.of(context).colorScheme;

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
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 140, bottom: 16),
            itemCount: 10,
            itemBuilder: (context, index) =>
                const TransactionLedgerItemSkeleton(),
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
            context.l10n.txError(paginatedState.error!),
            style: TextStyle(color: scheme.error),
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
        child: RefreshIndicator(
          onRefresh: () async {
            final notifier = ref.read(paginatedTransactionsProvider.notifier);
            ref.invalidate(accountsProvider);
            final tasks = <Future>[
              notifier.refresh(),
              performSheetsSync(ref),
            ];
            final persistence = ref.read(persistenceServiceProvider);
            if (persistence.getEmailSyncEnabled()) {
              tasks.add(ref
                  .read(bankSyncServiceProvider)
                  .sync(days: persistence.getEmailSyncWindowDays()));
            }
            if (persistence.getRevolutSyncEnabled()) {
              tasks.add(ref.read(bankSyncServiceProvider).syncNotifications());
            }
            await Future.wait(tasks);
          },
          color: scheme.primary,
          backgroundColor: scheme.surfaceContainer,
          child: TransactionList(
            transactions: transactions,
            paginatedState: paginatedState,
            scrollController: _scrollController,
            selectedIds: _selectedIds,
            onToggleSelection: _toggleSelection,
            leadingSlivers: [
              const SliverToBoxAdapter(child: TransactionsHero()),
              _buildReviewBannerSliver(),
              _buildFiltersSliver(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewBannerSliver() {
    final count = ref.watch(pendingTransactionsCountProvider);
    final skipped = ref.watch(skippedEmailsProvider).maybeWhen(
          data: (s) => s.length,
          orElse: () => 0,
        );
    if (count == 0 && skipped == 0) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final scheme = Theme.of(context).colorScheme;
    final parts = [
      if (count > 0) context.l10n.txReviewBannerCount(count),
      if (skipped > 0) context.l10n.txUnrecognizedCount(skipped),
    ];
    final label = parts.join(' · ');

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Material(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push('/review-inbox'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.mark_email_unread_outlined,
                      color: scheme.onPrimaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersSliver() {
    final filters = ref.watch(transactionFiltersProvider);
    if (filters.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final chips = <Widget>[];
    if (filters.dateRange != null) {
      final start = filters.dateRange!.start;
      final end = filters.dateRange!.end;
      final sameDay = start.year == end.year &&
          start.month == end.month &&
          start.day == end.day;
      final label = sameDay
          ? DateFormat('dd MMM').format(start)
          : '${DateFormat('dd MMM').format(start)} → ${DateFormat('dd MMM').format(end)}';
      chips.add(
        ActiveFilterChip(
          prefix: context.l10n.commonDate.toUpperCase(),
          label: label,
          onDeleted: () =>
              ref.read(transactionFiltersProvider.notifier).setDateRange(null),
        ),
      );
    }
    for (final c in filters.categories) {
      chips.add(
        ActiveFilterChip(
          label: c,
          onDeleted: () =>
              ref.read(transactionFiltersProvider.notifier).toggleCategory(c),
        ),
      );
    }
    for (final t in filters.tags) {
      chips.add(
        ActiveFilterChip(
          prefix: '#',
          label: t,
          onDeleted: () =>
              ref.read(transactionFiltersProvider.notifier).toggleTag(t),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Container(
        height: 40,
        margin: const EdgeInsets.only(top: 4, bottom: 12),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: chips,
        ),
      ),
    );
  }
}
