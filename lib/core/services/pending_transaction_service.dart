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

  MultiSelectable<PendingTransaction> _pendingQuery() {
    return _db.select(_db.pendingTransactions)
      ..where((t) => t.status.equals('pending'))
      ..orderBy([(t) => OrderingTerm.desc(t.emailReceivedAt)]);
  }

  /// The wallet whose name contains "widiba" (case-insensitive), or null.
  Future<String?> resolveWidibaAccountId() async {
    final accounts = await _finance.getAccounts();
    for (final a in accounts) {
      if (a.name.toLowerCase().contains('widiba')) return a.id;
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

    await _finance.addTransaction(tx);
    await _markStatus(draft.id, 'approved');
    return tx;
  }

  Future<void> reject(String id) => _markStatus(id, 'rejected');

  Future<void> _markStatus(String id, String status) {
    return (_db.update(_db.pendingTransactions)..where((t) => t.id.equals(id)))
        .write(PendingTransactionsCompanion(status: Value(status)));
  }
}
