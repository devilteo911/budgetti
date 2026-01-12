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
        title: const Text("Fast Categorization"),
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
                        currencyFormatter.format(t.amount),
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              color: t.amount >= 0
                                  ? AppTheme.primaryGreen
                                  : Colors.white,
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
                const SizedBox(height: 40),

                // Description
                Text(
                  t.description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.left,
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
                  error: (err, stack) =>
                      Text("Error: $err", style: const TextStyle(color: Colors.red)),
                  data: (categories) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((category) {
                      final isSelected = t.category == category.name;
                      return InkWell(
                        onTap: () async {
                          final updated = t.copyWith(category: category.name);
                          await ref.read(financeServiceProvider).updateTransaction(updated);
                          widget.onTransactionUpdated(updated);
                          ref.invalidate(transactionsProvider);
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Color(category.colorHex)
                                : AppTheme.surfaceGrey,
                            borderRadius: BorderRadius.circular(20),
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                IconData(category.iconCode, fontFamily: 'MaterialIcons'),
                                size: 18,
                                color: isSelected ? Colors.white : AppTheme.textGrey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                category.name,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppTheme.textGrey,
                                  fontWeight: FontWeight.w500,
                                ),
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
}
