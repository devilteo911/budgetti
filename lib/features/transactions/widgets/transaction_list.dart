import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:draggable_scrollbar/draggable_scrollbar.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:budgetti/features/transactions/widgets/transaction_item.dart';
import 'package:budgetti/features/transactions/transaction_detail_screen.dart';

class TransactionList extends ConsumerWidget {
  final List<Transaction> transactions;
  final PaginatedTransactionsState paginatedState;
  final ScrollController scrollController;
  final Set<String> selectedIds;
  final Function(String) onToggleSelection;

  const TransactionList({
    super.key,
    required this.transactions,
    required this.paginatedState,
    required this.scrollController,
    required this.selectedIds,
    required this.onToggleSelection,
  });

  String _formatDateHeader(DateTime date) {
    return DateFormat('MMMM yyyy').format(date).toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupedData = ref.watch(groupedTransactionsProvider);
    final flatList = groupedData.flatList;
    final dateIndices = groupedData.dateIndices;
    final sortedDates = groupedData.sortedDates;

    bool isSelectionMode = selectedIds.isNotEmpty;

    if (transactions.isEmpty) {
      return ListView(
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
      );
    }

    return DraggableScrollbar.semicircle(
      controller: scrollController,
      backgroundColor: AppTheme.surfaceGrey,
      labelTextBuilder: (double offset) {
        if (sortedDates.isEmpty) return const Text("");

        final totalScrollable = scrollController.position.maxScrollExtent;
        if (totalScrollable <= 0) {
          return Text(
            DateFormat('MMM yyyy').format(sortedDates.first),
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          );
        }

        final fraction = (offset / totalScrollable).clamp(0.0, 1.0);
        final index = (fraction * (flatList.length - 1)).floor();
        final labelDate = dateIndices[index] ?? sortedDates.first;

        return Text(
          DateFormat('MMM yyyy').format(labelDate).toUpperCase(),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        );
      },
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 16,
          bottom: 100,
        ),
        itemCount: flatList.length + (paginatedState.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == flatList.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 32.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final item = flatList[index];
          if (item is DateTime) {
            return _buildDateHeader(context, item);
          }
          if (item is Transaction) {
            return _buildAnimatedItem(
              context,
              index,
              TransactionItem(
                key: ValueKey(item.id),
                transaction: item,
                isSelected: selectedIds.contains(item.id),
                showDate:
                    index == 0 ||
                    !(flatList[index - 1] is Transaction &&
                        (flatList[index - 1] as Transaction).date.day ==
                            item.date.day &&
                        (flatList[index - 1] as Transaction).date.month ==
                            item.date.month &&
                        (flatList[index - 1] as Transaction).date.year ==
                            item.date.year),
                onLongPress: () => onToggleSelection(item.id),
                onTap: () {
                  if (isSelectionMode) {
                    onToggleSelection(item.id);
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
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildDateHeader(BuildContext context, DateTime date) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryGreen.withOpacity(0.2),
                  AppTheme.primaryGreen.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryGreen.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              _formatDateHeader(date),
              style: const TextStyle(
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryGreen.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedItem(BuildContext context, int index, Widget child) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index % 10 * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
