part of 'database.dart';

// Extension with helper methods for bank sync
extension BankSyncExtension on AppDatabase {
  // ============ BANK CONNECTIONS ============
  
  Future<List<BankConnection>> getBankConnections(String userId) {
    return (select(bankConnections)
      ..where((t) => t.userId.equals(userId)))
      .get();
  }

  Future<void> addBankConnection(model.BankConnection connection) {
    return into(bankConnections).insert(
      BankConnectionsCompanion.insert(
        id: connection.id,
        userId: connection.userId,
        institutionId: connection.institutionId,
        institutionName: connection.institutionName,
        accountHolderName: connection.accountHolderName,
        accountNumberMasked: connection.accountNumberMasked,
        requisitionId: connection.requisitionId,
        walletId: Value(connection.walletId),
        status: connection.status,
        lastSyncAt: Value(connection.lastSyncAt),
        createdAt: connection.createdAt,
        accessValidUntil: Value(connection.accessValidUntil),
      ),
    );
  }

  Future<void> updateBankConnectionWallet(String connectionId, String? walletId) {
    return (update(bankConnections)
      ..where((t) => t.id.equals(connectionId)))
      .write(BankConnectionsCompanion(walletId: Value(walletId)));
  }

  Future<void> updateBankConnectionStatus(String connectionId, String status) {
    return (update(bankConnections)
      ..where((t) => t.id.equals(connectionId)))
      .write(BankConnectionsCompanion(status: Value(status)));
  }

  Future<void> updateBankConnectionLastSync(String connectionId, DateTime lastSync) {
    return (update(bankConnections)
      ..where((t) => t.id.equals(connectionId)))
      .write(BankConnectionsCompanion(lastSyncAt: Value(lastSync)));
  }

  Future<void> deleteBankConnection(String connectionId) {
    return (delete(bankConnections)
      ..where((t) => t.id.equals(connectionId)))
      .go();
  }

  // ============ SYNCED TRANSACTIONS ============

  Future<List<Map<String, dynamic>>> getPendingSyncedTransactions(String userId) async {
    final results = await (select(syncedTransactions)
     ..where((t) => t.userId.equals(userId) & t.syncStatus.equals('pending')))
      .get();
    
    return results.map((row) => {
      'id': row.id,
      'user_id': row.userId,
      'account_id': row.accountId,
      'amount': row.amount,
      'description': row.description,
      'category': row.category,
      'date': row.date.toIso8601String(),
      'tags': row.tags,
      'bank_transaction_id': row.bankTransactionId,
      'sync_status': row.syncStatus,
      'merchant_name': row.merchantName,
      'synced_at': row.syncedAt.toIso8601String(),
      'suggested_category': row.suggestedCategory,
      'categorization_confidence': row.categorizationConfidence,
      'bank_connection_id': row.bankConnectionId,
    }).toList();
  }

  Future<Map<String, dynamic>> getSyncedTransaction(String transactionId) async {
    final row = await (select(syncedTransactions)
      ..where((t) => t.id.equals(transactionId)))
      .getSingle();
    
    return {
      'id': row.id,
      'user_id': row.userId,
      'account_id': row.accountId,
      'amount': row.amount,
      'description': row.description,
      'category': row.category,
      'date': row.date.toIso8601String(),
      'tags': row.tags,
      'bank_transaction_id': row.bankTransactionId,
      'sync_status': row.syncStatus,
      'merchant_name': row.merchantName,
      'synced_at': row.syncedAt.toIso8601String(),
      'suggested_category': row.suggestedCategory,
      'categorization_confidence': row.categorizationConfidence,
      'bank_connection_id': row.bankConnectionId,
    };
  }

  Future<bool> syncedTransactionExists(String bankTransactionId) async {
    final count = await (select(syncedTransactions)
      ..where((t) => t.bankTransactionId.equals(bankTransactionId))
      ..limit(1))
      .get();
    return count.isNotEmpty;
  }

  Future<void> addSyncedTransaction({
    required String id,
    required String userId,
    required String accountId,
    required double amount,
    required String description,
    required String category,
    required DateTime date,
    required List<String> tags,
    required String bankTransactionId,
    required String syncStatus,
    required String merchantName,
    required DateTime syncedAt,
    String? suggestedCategory,
    double? categorizationConfidence,
    String? bankConnectionId,
  }) {
    return into(syncedTransactions).insert(
      SyncedTransactionsCompanion.insert(
        id: id,
        userId: userId,
        accountId: accountId,
        amount: amount,
        description: description,
        category: category,
        date: date,
        tags: Value(tags),
        bankTransactionId: bankTransactionId,
        syncStatus: syncStatus,
        merchantName: merchantName,
        syncedAt: syncedAt,
        suggestedCategory: Value(suggestedCategory),
        categorizationConfidence: Value(categorizationConfidence),
        bankConnectionId: Value(bankConnectionId),
      ),
    );
  }

  Future<void> updateSyncedTransactionStatus(String transactionId, String status) {
    return (update(syncedTransactions)
      ..where((t) => t.id.equals(transactionId)))
      .write(SyncedTransactionsCompanion(syncStatus: Value(status)));
  }

  // ============ REGULAR TRANSACTIONS ============

  Future<void> addTransaction(
    String accountId,
    double amount,
    String description,
    String category,
    DateTime date,
    List<String> tags,
  ) {
    return into(transactions).insert(
      TransactionsCompanion.insert(
        id: const Uuid().v4(),
        accountId: Value(accountId),
        amount: amount,
        description: description,
        category: category,
        date: date,
        tags: Value(tags),
      ),
    );
  }
}
