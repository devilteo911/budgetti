import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:budgetti/models/account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ImportTransactionsScreen extends ConsumerStatefulWidget {
  final List<Transaction> transactions;

  const ImportTransactionsScreen({super.key, required this.transactions});

  @override
  ConsumerState<ImportTransactionsScreen> createState() => _ImportTransactionsScreenState();
}

class _ImportTransactionsScreenState extends ConsumerState<ImportTransactionsScreen> {
  String? _selectedWalletId;
  late List<Transaction> _transactions;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _transactions = List.from(widget.transactions);
    
    // Attempt to pre-select default wallet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accounts = ref.read(accountsProvider).asData?.value ?? [];
      if (accounts.isNotEmpty) {
        final defaultAcc = accounts.firstWhere((a) => a.isDefault, orElse: () => accounts.first);
        setState(() => _selectedWalletId = defaultAcc.id);
      }
    });
  }

  void _import() async {
    if (_selectedWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a wallet')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final financeService = ref.read(financeServiceProvider);
      
      // Update transaction Account IDs and import
      for (var txn in _transactions) {
        final finalTxn = txn.copyWith(accountId: _selectedWalletId);
        await financeService.addTransaction(finalTxn);
      }

      // Refresh providers
      ref.invalidate(accountsProvider);
      ref.invalidate(transactionsProvider(_selectedWalletId));
      ref.invalidate(transactionsProvider(null));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully imported ${_transactions.length} transactions')),
        );
        context.pop(); // Close screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showWalletPicker(List<Account> accounts) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceGrey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               const Text("Select Wallet", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
               const SizedBox(height: 16),
               Flexible(
                 child: ListView.builder(
                   shrinkWrap: true,
                   itemCount: accounts.length,
                   itemBuilder: (context, index) {
                     final acc = accounts[index];
                     final isSelected = acc.id == _selectedWalletId;
                     return ListTile(
                       title: Text(acc.name, style: const TextStyle(color: Colors.white)),
                       trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.primaryGreen) : null,
                       onTap: () {
                         setState(() => _selectedWalletId = acc.id);
                         Navigator.pop(context);
                       },
                     );
                   },
                 ),
               ),
             ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = ref.watch(currencyProvider);
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: const Text("Import Preview"),
        backgroundColor: AppTheme.backgroundBlack,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Wallet Selector
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: accountsAsync.when(
                data: (accounts) {
                  final selectedWallet = accounts.where((a) => a.id == _selectedWalletId).firstOrNull;
                  return InkWell(
                    onTap: () => _showWalletPicker(accounts),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceGrey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet, color: AppTheme.primaryGreen),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Import to Wallet", style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                                Text(
                                  selectedWallet?.name ?? "Select Wallet",
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: AppTheme.textGrey),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_,__) => const SizedBox(),
              ),
            ),
            
            // Stats Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Transactions found: ${_transactions.length}", style: const TextStyle(color: AppTheme.textGrey)),
                  Text(
                    "Total: ${currencyFormatter.format(_transactions.fold(0.0, (sum, t) => sum + t.amount))}",
                     style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // List
            Expanded(
              child: ListView.builder(
                itemCount: _transactions.length,
                itemBuilder: (context, index) {
                  final t = _transactions[index];
                  final isExpense = t.amount < 0;
                  return Dismissible(
                    key: ValueKey(t.id),
                    background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete, color: Colors.white)),
                    onDismissed: (_) {
                      setState(() {
                        _transactions.removeAt(index);
                      });
                    },
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: (isExpense ? Colors.red : AppTheme.primaryGreen).withValues(alpha: 0.1),
                        child: Icon(
                          isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                          color: isExpense ? Colors.red : AppTheme.primaryGreen,
                          size: 16,
                        ),
                      ),
                      title: Text(t.description, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(DateFormat.yMMMd().format(t.date), style: const TextStyle(color: AppTheme.textGrey)),
                      trailing: Text(
                        currencyFormatter.format(t.amount),
                        style: TextStyle(
                          color: isExpense ? Colors.white : AppTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Action Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading || _transactions.isEmpty ? null : _import,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black))
                    : const Text("Confirm Import", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
