import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/models/synced_transaction.dart';
import 'package:intl/intl.dart';

final pendingTransactionsProvider = FutureProvider<List<SyncedTransaction>>((ref) async {
  final bankSyncService = ref.watch(bankSyncServiceProvider);
  return bankSyncService.getPendingTransactions();
});

class PendingTransactionsScreen extends ConsumerWidget {
  const PendingTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Transactions'),
        actions: [
          pendingAsync.when(
            data: (transactions) => transactions.isNotEmpty
                ? PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'approve_all') {
                        await _approveAll(context, ref);
                      } else if (value == 'discard_all') {
                        await _discardAll(context, ref);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'approve_all',
                        child: Text('Approve All'),
                      ),
                      const PopupMenuItem(
                        value: 'discard_all',
                        child: Text('Discard All'),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: pendingAsync.when(
        data: (transactions) {
          if (transactions.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No pending transactions',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'All synced transactions have been reviewed',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              return _PendingTransactionCard(
                transaction: transaction,
                onApprove: () => _approveTransaction(context, ref, transaction.id),
                onDiscard: () => _discardTransaction(context, ref, transaction.id),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: ${error.toString()}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(pendingTransactionsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _approveTransaction(BuildContext context, WidgetRef ref, String id) async {
    try {
      final bankSyncService = ref.read(bankSyncServiceProvider);
      await bankSyncService.approveTransaction(id);
      ref.invalidate(pendingTransactionsProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction approved'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _discardTransaction(BuildContext context, WidgetRef ref, String id) async {
    try {
      final bankSyncService = ref.read(bankSyncServiceProvider);
      await bankSyncService.discardTransaction(id);
      ref.invalidate(pendingTransactionsProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction discarded')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _approveAll(BuildContext context, WidgetRef ref) async {
    try {
      final bankSyncService = ref.read(bankSyncServiceProvider);
      await bankSyncService.approveAll();
      ref.invalidate(pendingTransactionsProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All transactions approved'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _discardAll(BuildContext context, WidgetRef ref) async {
    try {
      final bankSyncService = ref.read(bankSyncServiceProvider);
      await bankSyncService.discardAll();
      ref.invalidate(pendingTransactionsProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All transactions discarded')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _PendingTransactionCard extends StatelessWidget {
  final SyncedTransaction transaction;
  final VoidCallback onApprove;
  final VoidCallback onDiscard;

  const _PendingTransactionCard({
    required this.transaction,
    required this.onApprove,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.simpleCurrency(name: 'EUR');
    final isIncome = transaction.amount > 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.merchantName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, yyyy').format(transaction.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  currencyFormat.format(transaction.amount.abs()),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isIncome ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Description
            if (transaction.description.isNotEmpty) ...[
              Text(
                transaction.description,
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
            ],

            // Suggested Category
            if (transaction.suggestedCategory != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.category, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 6),
                    Text(
                      transaction.suggestedCategory!,
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (transaction.categorizationConfidence != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${(transaction.categorizationConfidence! * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onDiscard,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Discard'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
