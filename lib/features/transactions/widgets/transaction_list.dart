import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:budgetti/features/stats/widgets/section_label.dart';
import 'package:budgetti/features/stats/widgets/stagger.dart';
import 'package:budgetti/features/transactions/widgets/transaction_ledger_item.dart';
import 'package:budgetti/features/transactions/transaction_detail_screen.dart';

class TransactionList extends ConsumerStatefulWidget {
  final List<Transaction> transactions;
  final PaginatedTransactionsState paginatedState;
  final ScrollController scrollController;
  final Set<String> selectedIds;
  final Function(String) onToggleSelection;
  final List<Widget> leadingSlivers;

  const TransactionList({
    super.key,
    required this.transactions,
    required this.paginatedState,
    required this.scrollController,
    required this.selectedIds,
    required this.onToggleSelection,
    this.leadingSlivers = const [],
  });

  @override
  ConsumerState<TransactionList> createState() => _TransactionListState();
}

class _TransactionListState extends ConsumerState<TransactionList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grouped = ref.watch(groupedTransactionsProvider);
    final sortedDates = grouped.sortedDates;
    final scheme = Theme.of(context).colorScheme;
    final isSelectionMode = widget.selectedIds.isNotEmpty;

    if (widget.transactions.isEmpty) {
      return CustomScrollView(
        controller: widget.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          ...widget.leadingSlivers,
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(),
          ),
        ],
      );
    }

    final slivers = <Widget>[];
    slivers.addAll(widget.leadingSlivers);

    for (var i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      final monthTxns = widget.transactions
          .where((t) => t.date.year == date.year && t.date.month == date.month)
          .toList();

      final begin = (0.05 + i * 0.08).clamp(0.0, 0.95);
      final end = (begin + 0.45).clamp(0.0, 1.0);

      slivers.add(
        Stagger(
          controller: _controller,
          begin: begin,
          end: end,
          child: SliverToBoxAdapter(
            child: SectionLabel(
              text: DateFormat('MMMM yyyy').format(date).toUpperCase(),
              count: monthTxns.length,
            ),
          ),
        ),
      );

      slivers.add(
        Stagger(
          controller: _controller,
          begin: begin,
          end: end,
          child: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final itemIndex = index ~/ 2;
                if (itemIndex >= monthTxns.length) return null;
                final isDivider = index.isOdd;
                if (isDivider) {
                  if (itemIndex >= monthTxns.length - 1) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      height: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.18),
                    ),
                  );
                }
                final txn = monthTxns[itemIndex];
                return TransactionLedgerItem(
                  key: ValueKey(txn.id),
                  transaction: txn,
                  isSelected: widget.selectedIds.contains(txn.id),
                  onLongPress: () => widget.onToggleSelection(txn.id),
                  onTap: () {
                    if (isSelectionMode) {
                      widget.onToggleSelection(txn.id);
                    } else {
                      final originalIndex =
                          widget.transactions.indexOf(txn);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TransactionDetailScreen(
                            transactions: widget.transactions,
                            initialIndex: originalIndex,
                          ),
                        ),
                      );
                    }
                  },
                );
              },
              childCount: monthTxns.length * 2,
            ),
          ),
        ),
      );
    }

    if (widget.paginatedState.hasMore) {
      slivers.add(
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    slivers.add(const SliverPadding(padding: EdgeInsets.only(bottom: 100)));

    return CustomScrollView(
      controller: widget.scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: slivers,
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'NO ACTIVITY',
            style: GoogleFonts.jetBrainsMono(
              color: scheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Nessuna transazione in questo periodo',
            style: TextStyle(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
