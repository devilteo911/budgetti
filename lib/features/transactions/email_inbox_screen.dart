import 'package:budgetti/core/database/database.dart' show PendingTransaction;
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/notification_logic.dart';
import 'package:budgetti/core/widgets/wallet_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Review inbox for transaction drafts parsed from Widiba emails. Approving a
/// draft creates a real transaction (mapped to the "widiba" wallet); SEPA
/// transfers ask whether they're an expense or a wallet-to-wallet transfer.
class EmailInboxScreen extends ConsumerWidget {
  const EmailInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingTransactionsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Da rivedere')),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (drafts) {
          if (drafts.isEmpty) {
            return _EmptyState(scheme: scheme);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: drafts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _DraftCard(draft: drafts[i]),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mark_email_read_outlined,
              size: 56, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('Nessuna transazione da rivedere',
              style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _DraftCard extends ConsumerWidget {
  const _DraftCard({required this.draft});
  final PendingTransaction draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final currency = ref.watch(currencyProvider);
    final isExpense = draft.parsedAmount < 0;

    final (icon, typeLabel) = switch (draft.suggestedType) {
      'income' => (Icons.south_west, 'Accredito'),
      'undecided' => (Icons.help_outline, 'Bonifico SEPA — da decidere'),
      _ => (Icons.north_east, 'Pagamento'),
    };

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(typeLabel,
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant)),
              const Spacer(),
              Text(
                currency.format(draft.parsedAmount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isExpense ? scheme.error : scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(draft.parsedDescription,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(DateFormat('dd MMM yyyy').format(draft.parsedDate),
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant)),
              if (draft.suggestedCategory != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(draft.suggestedCategory!,
                      style:
                          TextStyle(fontSize: 11, color: scheme.primary)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _reject(ref),
                  child: const Text('Ignora'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => _approve(context, ref),
                  child: const Text('Approva'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _reject(WidgetRef ref) =>
      ref.read(pendingTransactionServiceProvider).reject(draft.id);

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final service = ref.read(pendingTransactionServiceProvider);

    var type = draft.suggestedType;
    String? toAccountId;

    if (type == 'undecided') {
      final choice = await _askExpenseOrTransfer(context);
      if (choice == null) return;
      type = choice;
      if (type == 'transfer') {
        if (!context.mounted) return;
        toAccountId = await _pickDestinationAccount(context, ref);
        if (toAccountId == null) return;
      }
    }

    var sourceId = await service.resolveWidibaAccountId();
    if (sourceId == null) {
      if (!context.mounted) return;
      sourceId = await _pickSourceAccount(context, ref);
    }
    if (sourceId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Nessun portafoglio selezionato')));
      }
      return;
    }

    final tx = await service.approve(
      draft,
      type: type,
      accountId: sourceId,
      toAccountId: toAccountId,
      category: draft.suggestedCategory,
    );

    ref.invalidate(accountsProvider);
    ref.invalidate(transactionsProvider(null));
    ref.invalidate(paginatedTransactionsProvider);
    if (type != 'transfer') {
      ref.invalidate(budgetsProvider);
      ref.read(notificationLogicProvider).checkBudgetAlerts(tx);
    }
    performSheetsSync(ref);
  }

  Future<String?> _askExpenseOrTransfer(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Che tipo di bonifico è?',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.north_east),
              title: const Text('Spesa'),
              subtitle: const Text('Uscita verso esterno'),
              onTap: () => Navigator.pop(context, 'expense'),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Trasferimento'),
              subtitle: const Text('Giro tra i tuoi portafogli'),
              onTap: () => Navigator.pop(context, 'transfer'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<String?> _pickDestinationAccount(BuildContext context, WidgetRef ref) {
    return _pickAccount(context, ref, 'Portafoglio di destinazione');
  }

  Future<String?> _pickSourceAccount(BuildContext context, WidgetRef ref) {
    return _pickAccount(context, ref, 'Portafoglio di origine');
  }

  Future<String?> _pickAccount(
      BuildContext context, WidgetRef ref, String title) async {
    // WalletPickerSheet pops itself, so capture the choice instead of popping
    // again here (which would dismiss the inbox screen too).
    String? selectedId;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => WalletPickerSheet(
        title: title,
        selectedWalletId: null,
        showAllWalletsOption: false,
        onWalletSelected: (account) => selectedId = account?.id,
      ),
    );
    return selectedId;
  }
}
