import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/bank_sync_service.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/models/transaction.dart' as model;
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Reads and resolves email-derived transaction drafts ([PendingTransactions]).
/// Approval converts a draft into a real [Transactions] row; the draft is then
/// marked (not deleted) so its Gmail id stays in the de-duplication ledger.
class PendingTransactionService {
  final AppDatabase _db;
  final FinanceService _finance;

  PendingTransactionService(this._db, this._finance);

  Future<List<PendingTransaction>> getPending() => _pendingQuery().get();

  /// Live stream of pending drafts — updates as the sync inserts new ones or
  /// the user approves/rejects.
  Stream<List<PendingTransaction>> watchPending() => _pendingQuery().watch();

  /// Transaction-looking emails the parser couldn't read, surfaced so the user
  /// knows the sync skipped something.
  Stream<List<PendingTransaction>> watchSkipped() {
    return (_db.select(_db.pendingTransactions)
          ..where((t) => t.status.equals('skipped'))
          ..orderBy([(t) => OrderingTerm.desc(t.emailReceivedAt)]))
        .watch();
  }

  MultiSelectable<PendingTransaction> _pendingQuery() {
    return _db.select(_db.pendingTransactions)
      ..where((t) => t.status.equals('pending'))
      ..orderBy([(t) => OrderingTerm.desc(t.emailReceivedAt)]);
  }

  /// The wallet a draft's [source] belongs to: the one whose name (or provider)
  /// mentions the bank, e.g. source 'revolut' -> a wallet called "Revolut".
  /// Null when there's no match, in which case the inbox asks the user.
  Future<String?> resolveAccountIdForSource(String source) async {
    final needle = source.toLowerCase();
    final accounts = await _finance.getAccounts();
    for (final a in accounts) {
      if (a.name.toLowerCase().contains(needle) ||
          a.providerName.toLowerCase().contains(needle)) {
        return a.id;
      }
    }
    return null;
  }

  /// Converts a draft into a real transaction and marks it approved. Mirrors the
  /// sign and category conventions of the add-transaction modal: expenses are
  /// negative, income/transfer positive, transfers use the "Transfer" category.
  ///
  /// Returns the booked transaction, or null when nothing was booked: the draft
  /// was already handled (double-tap, crash retry), or — new — a twin showed up
  /// since capture. A draft that was never flagged or dismissed is re-checked
  /// against the ledger here, because the capture-time check goes stale: the
  /// owner may have logged the same purchase by hand, or another device synced
  /// it in, in the meantime. The new match is written onto the draft (the inbox
  /// re-renders it with the amber notice) and the owner decides.
  Future<model.Transaction?> approve(
    PendingTransaction draft, {
    required String type,
    required String accountId,
    String? toAccountId,
    String? category,
  }) async {
    final amountAbs = draft.parsedAmount.abs();
    final tx = model.Transaction(
      id: const Uuid().v4(),
      accountId: accountId,
      toAccountId: type == 'transfer' ? toAccountId : null,
      amount: type == 'expense' ? -amountAbs : amountAbs,
      date: draft.parsedDate,
      description: draft.parsedDescription,
      category: type == 'transfer' ? 'Transfer' : (category ?? 'Uncategorized'),
      type: type,
    );

    return _db.transaction(() async {
      // Re-check under the transaction: a double-tap or a crash-retried
      // approval must not book the same draft twice.
      final still = await (_db.select(_db.pendingTransactions)
            ..where(
                (t) => t.id.equals(draft.id) & t.status.equals('pending')))
          .getSingleOrNull();
      if (still == null) return null;

      // Flagged at capture and approved anyway, or dismissed: the owner has
      // already ruled on it.
      if (!still.duplicateDismissed && still.duplicateOfId == null) {
        final twin = await findDuplicate(
          _db,
          amount: still.parsedAmount,
          description: still.parsedDescription,
          date: still.parsedDate,
        );
        if (twin != null) {
          await (_db.update(_db.pendingTransactions)
                ..where((t) => t.id.equals(draft.id)))
              .write(PendingTransactionsCompanion(
            duplicateOfId: Value(twin.transactionId),
            duplicateScore: Value(twin.score),
          ));
          return null;
        }
      }

      await _finance.addTransaction(tx);
      await _markStatus(draft.id, 'approved');
      return tx;
    });
  }

  Future<void> reject(String id) => _markStatus(id, 'rejected');

  /// "No, it's a different one": permanently un-flags the draft — the dismissed
  /// marker stops the approve-time recheck from raising the warning again.
  Future<void> clearDuplicateFlag(String id) {
    return (_db.update(_db.pendingTransactions)..where((t) => t.id.equals(id)))
        .write(const PendingTransactionsCompanion(
      duplicateOfId: Value(null),
      duplicateScore: Value(null),
      duplicateDismissed: Value(true),
    ));
  }

  /// The existing transaction a draft was flagged against, for the compare UI.
  Future<Transaction?> getTransactionById(String id) {
    // A deleted twin is no evidence of a duplicate: the notice must not point
    // at a row the owner already removed.
    return (_db.select(_db.transactions)
          ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  Future<void> _markStatus(String id, String status) {
    return (_db.update(_db.pendingTransactions)..where((t) => t.id.equals(id)))
        .write(PendingTransactionsCompanion(status: Value(status)));
  }
}
