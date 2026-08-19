import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/models/transaction.dart' as model;
import 'package:drift/drift.dart';

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
  Future<model.Transaction> approve(
    PendingTransaction draft, {
    required String type,
    required String accountId,
    String? toAccountId,
    String? category,
  }) async {
    final amountAbs = draft.parsedAmount.abs();
    final tx = model.Transaction(
      id: '',
      accountId: accountId,
      toAccountId: type == 'transfer' ? toAccountId : null,
      amount: type == 'expense' ? -amountAbs : amountAbs,
      date: draft.parsedDate,
      description: draft.parsedDescription,
      category: type == 'transfer' ? 'Transfer' : (category ?? 'Uncategorized'),
      type: type,
    );

    await _db.transaction(() async {
      // Re-check under the transaction: a double-tap or a crash-retried
      // approval must not book the same draft twice.
      final still = await (_db.select(_db.pendingTransactions)
            ..where(
                (t) => t.id.equals(draft.id) & t.status.equals('pending')))
          .getSingleOrNull();
      if (still == null) return;

      await _finance.addTransaction(tx);
      await _markStatus(draft.id, 'approved');
    });
    return tx;
  }

  Future<void> reject(String id) => _markStatus(id, 'rejected');

  /// "No, it's a different one": permanently un-flags the draft so the warning
  /// doesn't come back on the next sync.
  Future<void> clearDuplicateFlag(String id) {
    return (_db.update(_db.pendingTransactions)..where((t) => t.id.equals(id)))
        .write(const PendingTransactionsCompanion(
      duplicateOfId: Value(null),
      duplicateScore: Value(null),
    ));
  }

  /// The existing transaction a draft was flagged against, for the compare UI.
  Future<Transaction?> getTransactionById(String id) {
    return (_db.select(_db.transactions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> _markStatus(String id, String status) {
    return (_db.update(_db.pendingTransactions)..where((t) => t.id.equals(id)))
        .write(PendingTransactionsCompanion(status: Value(status)));
  }
}
