import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:budgetti/models/account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

String _titleCase(String s) {
  if (s.isEmpty) return s;
  return s.split(' ').map((w) {
    if (w.isEmpty) return w;
    return w[0].toUpperCase() + w.substring(1).toLowerCase();
  }).join(' ');
}

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
        SnackBar(content: Text(context.l10n.importSelectWalletError)),
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
          SnackBar(content: Text(context.l10n.importSuccess(_transactions.length))),
        );
        context.pop(); // Close screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.importError('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showWalletPicker(List<Account> accounts) {
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               Text(context.l10n.importSelectWalletTitle,
                   style: Theme.of(context).textTheme.titleLarge?.copyWith(
                         fontWeight: FontWeight.bold,
                       )),
               const SizedBox(height: 16),
               Flexible(
                 child: ListView.builder(
                   shrinkWrap: true,
                   itemCount: accounts.length,
                   itemBuilder: (context, index) {
                     final acc = accounts[index];
                     final isSelected = acc.id == _selectedWalletId;
                     return ListTile(
                       title: Text(acc.name),
                       trailing: isSelected
                           ? Icon(Icons.check_circle,
                               color: Theme.of(context).colorScheme.primary)
                           : null,
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
    final cs = Theme.of(context).colorScheme;
    final currencyFormatter = ref.watch(currencyProvider);
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.importPreviewTitle)),
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
                        color: cs.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.account_balance_wallet, color: cs.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(context.l10n.importToWallet,
                                    style: TextStyle(
                                        color: cs.onSurfaceVariant, fontSize: 12)),
                                Text(
                                  selectedWallet?.name ?? context.l10n.importSelectWalletTitle,
                                  style: TextStyle(
                                      color: cs.onSurface,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_drop_down, color: cs.onSurfaceVariant),
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
                  Text(context.l10n.importFound(_transactions.length),
                      style: TextStyle(color: cs.onSurfaceVariant)),
                  Text(
                    context.l10n.importTotal(currencyFormatter.format(_transactions.fold(0.0, (sum, t) => sum + t.amount))),
                     style: TextStyle(
                         color: cs.onSurface, fontWeight: FontWeight.bold),
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
                    background: Container(
                        color: cs.errorContainer,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: Icon(Icons.delete, color: cs.onErrorContainer)),
                    onDismissed: (_) {
                      setState(() {
                        _transactions.removeAt(index);
                      });
                    },
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: (isExpense ? cs.error : cs.primary)
                            .withValues(alpha: 0.1),
                        child: Icon(
                          isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                          color: isExpense ? cs.error : cs.primary,
                          size: 16,
                        ),
                      ),
                      title: Text(_titleCase(t.description)),
                      subtitle: Text(DateFormat.yMMMd().format(t.date),
                          style: TextStyle(color: cs.onSurfaceVariant)),
                      trailing: Text(
                        currencyFormatter.format(t.amount),
                        style: TextStyle(
                          color: isExpense ? cs.onSurface : cs.primary,
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: cs.onPrimary))
                    : Text(context.l10n.importConfirm, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
