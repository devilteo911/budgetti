import 'package:budgetti/core/database/database.dart'
    show PendingTransaction, Transaction;
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
          final skipped = ref.watch(skippedEmailsProvider).maybeWhen(
                data: (s) => s,
                orElse: () => const <PendingTransaction>[],
              );
          if (drafts.isEmpty && skipped.isEmpty) {
            return _EmptyState(scheme: scheme);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final d in drafts) ...[
                _DraftCard(draft: d),
                const SizedBox(height: 12),
              ],
              if (skipped.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                  child: Text(
                    'Email non riconosciute',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final s in skipped) ...[
                  _SkippedCard(item: s),
                  const SizedBox(height: 12),
                ],
              ],
            ],
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
          if (draft.duplicateOfId != null) ...[
            const SizedBox(height: 12),
            _DuplicateNotice(draft: draft),
          ],
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

/// A transaction-looking email the parser couldn't read. Shown so the sync
/// never swallows movements silently; tap reveals the raw snippet.
class _SkippedCard extends ConsumerWidget {
  const _SkippedCard({required this.item});
  final PendingTransaction item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.emailSubject,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Email del ${DateFormat('dd MMM yyyy').format(item.emailReceivedAt)} '
            '— non sono riuscito a leggerla',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      ref.read(pendingTransactionServiceProvider).reject(item.id),
                  child: const Text('Ignora'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () => _showSnippet(context),
                  child: const Text('Dettagli'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSnippet(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.emailSubject),
        content: SingleChildScrollView(
          child: Text(
            item.rawSnippet.isEmpty ? '(nessun contenuto)' : item.rawSnippet,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }
}

/// Amber "might already be in your account" notice shown on flagged drafts.
/// Tapping it opens a side-by-side compare sheet where the user resolves the
/// doubt: reject the draft or clear the flag.
class _DuplicateNotice extends ConsumerWidget {
  const _DuplicateNotice({required this.draft});
  final PendingTransaction draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = ref
        .watch(duplicateSourceTxProvider(draft.duplicateOfId!))
        .maybeWhen(data: (tx) => tx, orElse: () => null);
    if (tx == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final currency = ref.watch(currencyProvider);
    final summary = '"${tx.description}" · '
        '${DateFormat('dd MMM').format(tx.date)} · '
        '${currency.format(tx.amount)}';

    return Material(
      color: Colors.amber.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showCompareSheet(context, ref, tx),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 20, color: Colors.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Forse già registrata',
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCompareSheet(
      BuildContext context, WidgetRef ref, Transaction tx) async {
    final currency = ref.read(currencyProvider);
    final service = ref.read(pendingTransactionServiceProvider);

    String? walletName;
    final accounts = ref
        .read(accountsProvider)
        .maybeWhen(data: (a) => a, orElse: () => null);
    if (accounts != null) {
      for (final a in accounts) {
        if (a.id == tx.accountId) walletName = a.name;
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'È la stessa spesa?',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              _CompareBlock(
                label: 'Dall\'email',
                description: draft.parsedDescription,
                date: draft.parsedDate,
                amountLabel: currency.format(draft.parsedAmount),
              ),
              const SizedBox(height: 8),
              _CompareBlock(
                label: 'Già nel conto',
                description: tx.description,
                date: tx.date,
                amountLabel: currency.format(tx.amount),
                walletName: walletName,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        service.clearDuplicateFlag(draft.id);
                        Navigator.pop(sheetContext);
                      },
                      child: const Text('No, è diversa'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        service.reject(draft.id);
                        Navigator.pop(sheetContext);
                      },
                      child: const Text('Sì, è la stessa'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompareBlock extends StatelessWidget {
  const _CompareBlock({
    required this.label,
    required this.description,
    required this.date,
    required this.amountLabel,
    this.walletName,
  });

  final String label;
  final String description;
  final DateTime date;
  final String amountLabel;
  final String? walletName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final details = [
      DateFormat('dd MMM yyyy').format(date),
      if (walletName != null) walletName!,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Text(amountLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(details,
              style:
                  TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
