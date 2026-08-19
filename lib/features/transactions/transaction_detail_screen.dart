import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:budgetti/features/transactions/widgets/transaction_page.dart';


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
    _pageController = PageController(initialPage: widget.initialIndex);
    _currentTransactions = List.from(widget.transactions);
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          context.l10n.txFastCategorization,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: _currentTransactions.length,
        itemBuilder: (context, index) {
          return TransactionPage(
            transaction: _currentTransactions[index],
            onTransactionUpdated: (updated) {
              setState(() {
                _currentTransactions[index] = updated;
              });
            },
          );
        },
      ),
    );
  }
}
