import 'package:budgetti/core/database/database.dart' hide SyncedTransaction;
import 'package:budgetti/core/services/gocardless_service.dart';
import 'package:budgetti/models/bank_connection.dart' as model;
import 'package:budgetti/models/synced_transaction.dart';
import 'package:uuid/uuid.dart';

class BankSyncService {
  final GocardlessService _gocardless;
  final AppDatabase _db;
  final String _userId;

  BankSyncService(this._gocardless, this._db, this._userId);

  // ============ BANK CONNECTIONS ============

  Future<List<model.BankConnection>> getConnections() async {
    final connections = await _db.getBankConnections(_userId);
    return connections.map((c) => model.BankConnection.fromJson({
      'id': c.id,
      'user_id': c.userId,
      'institution_id': c.institutionId,
      'institution_name': c.institutionName,
      'account_holder_name': c.accountHolderName,
      'account_number_masked': c.accountNumberMasked,
      'requisition_id': c.requisitionId,
      'wallet_id': c.walletId,
      'status': c.status,
      'last_sync_at': c.lastSyncAt?.toIso8601String(),
      'created_at': c.createdAt.toIso8601String(),
      'access_valid_until': c.accessValidUntil?.toIso8601String(),
    })).toList();
  }

  Future<model.BankConnection> addConnection({
    required String requisitionId,
    required String institutionId,
    required String institutionName,
    String? walletId,
  }) async {
    // Get requisition details from GoCardless
    final requisition = await _gocardless.getRequisition(requisitionId);
    final List<dynamic> accounts = requisition['accounts'] ?? [];
    
    if (accounts.isEmpty) {
      throw Exception('No accounts linked to this requisition');
    }

    // Get details for the first account
    final accountId = accounts.first;
    final accountDetails = await _gocardless.getAccountDetails(accountId);
    final account = accountDetails['account'];
    
    // Extract account holder and number
    final accountHolderName = account['ownerName'] ?? 'Unknown';
    final iban = account['iban'] ?? '';
    final accountNumberMasked = iban.isNotEmpty ? '****${iban.substring(iban.length - 4)}' : '****';

    // Calculate access expiry
    final String? agreementId = requisition['agreement'];
    DateTime? accessValidUntil;
    if (agreementId != null) {
      // Agreements typically last 90 days
      accessValidUntil = DateTime.now().add(const Duration(days: 90));
    }

    final connection = model.BankConnection(
      id: const Uuid().v4(),
      userId: _userId,
      institutionId: institutionId,
      institutionName: institutionName,
      accountHolderName: accountHolderName,
      accountNumberMasked: accountNumberMasked,
      requisitionId: requisitionId,
      walletId: walletId,
      status: 'active',
      createdAt: DateTime.now(),
      accessValidUntil: accessValidUntil,
    );

    await _db.addBankConnection(connection);
    return connection;
  }

  Future<void> updateConnectionWallet(String connectionId, String? walletId) async {
    await _db.updateBankConnectionWallet(connectionId, walletId);
  }

  Future<void> deleteConnection(String connectionId) async {
    final connections = await getConnections();
    final connection = connections.firstWhere((c) => c.id == connectionId);
    
    // Revoke access on GoCardless side
    try {
      await _gocardless.deleteRequisition(connection.requisitionId);
    } catch (e) {
      // Continue even if deletion fails
      print('Failed to delete requisition: $e');
    }

    // Delete from local database
    await _db.deleteBankConnection(connectionId);
  }

  // ============ TRANSACTION SYNCING ============

  Future<int> syncAllConnections({int? daysBack}) async {
    final connections = await getConnections();
    int totalSynced = 0;

    for (final connection in connections) {
      if (connection.isActive) {
        try {
          final count = await syncConnection(connection.id, daysBack: daysBack);
          totalSynced += count;
        } catch (e) {
          print('Failed to sync connection ${connection.id}: $e');
          // Update connection status to error
          await _db.updateBankConnectionStatus(connection.id, 'error');
        }
      }
    }

    return totalSynced;
  }

  Future<int> syncConnection(String connectionId, {int? daysBack}) async {
    final connections = await getConnections();
    final connection = connections.firstWhere((c) => c.id == connectionId);

    // Get requisition to find account IDs
    final requisition = await _gocardless.getRequisition(connection.requisitionId);
    final List<dynamic> accounts = requisition['accounts'] ?? [];
    
    if (accounts.isEmpty) {
      throw Exception('No accounts found for this connection');
    }

    final accountId = accounts.first; // Use first account
    
    // Calculate date range
    final dateTo = DateTime.now();
    final dateFrom = connection.lastSyncAt ?? dateTo.subtract(Duration(days: daysBack ?? 90));

    // Fetch transactions from GoCardless
    final transactionsData = await _gocardless.getAccountTransactions(
      accountId,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );

    // Parse transactions
    final transactions = _parseGocardlessTransactions(
      transactionsData,
      connection.walletId ?? 'default',
      connectionId,
    );

    // Save to database as pending
    int syncedCount = 0;
    for (final transaction in transactions) {
      try {
        // Check if this transaction already exists
        final exists = await _db.syncedTransactionExists(
          transaction.bankTransactionId,
        );
        
        if (!exists) {
          await _db.addSyncedTransaction(
            id: transaction.id,
            userId: _userId,
            accountId: transaction.accountId,
            amount: transaction.amount,
            description: transaction.description,
            category: transaction.category,
            date: transaction.date,
            tags: transaction.tags,
            bankTransactionId: transaction.bankTransactionId,
            syncStatus: transaction.syncStatus,
            merchantName: transaction.merchantName,
            syncedAt: transaction.syncedAt,
            suggestedCategory: transaction.suggestedCategory,
            categorizationConfidence: transaction.categorizationConfidence,
            bankConnectionId: transaction.bankConnectionId,
          );
          syncedCount++;
        }
      } catch (e) {
        print('Failed to save transaction ${transaction.bankTransactionId}: $e');
      }
    }

    // Update last sync time
    await _db.updateBankConnectionLastSync(connectionId, DateTime.now());

    return syncedCount;
  }

  List<SyncedTransaction> _parseGocardlessTransactions(
    Map<String, dynamic> data,
    String accountId,
    String connectionId,
  ) {
    final List<SyncedTransaction> transactions = [];
    
    // GoCardless returns transactions in 'transactions' field
    final bookedTx = data['transactions']?['booked'] as List<dynamic>? ?? [];
    final pendingTx = data['transactions']?['pending'] as List<dynamic>? ?? [];
    
    // Process booked transactions
    for (final tx in bookedTx) {
      try {
        transactions.add(_parseTransaction(tx, accountId, connectionId, false));
      } catch (e) {
        print('Failed to parse transaction: $e');
      }
    }
    
    // Process pending transactions
    for (final tx in pendingTx) {
      try {
        transactions.add(_parseTransaction(tx, accountId, connectionId, true));
      } catch (e) {
        print('Failed to parse transaction: $e');
      }
    }

    return transactions;
  }

  SyncedTransaction _parseTransaction(
    Map<String, dynamic> tx,
    String accountId,
    String connectionId,
    bool isPending,
  ) {
    // Extract amount (can be in different formats)
    double amount = 0.0;
    if (tx['transactionAmount'] != null) {
      amount = double.tryParse(tx['transactionAmount']['amount']?.toString() ?? '0') ?? 0.0;
    }

    // Make debits negative
    if (tx['debitCreditIndicator'] == 'DBIT' || tx['creditDebitIndicator'] == 'DBIT') {
      amount = -amount.abs();
    } else {
      amount = amount.abs();
    }

    // Extract merchant/creditor name
    String merchantName = '';
    if (tx['creditorName'] != null) {
      merchantName = tx['creditorName'];
    } else if (tx['debtorName'] != null) {
      merchantName = tx['debtorName'];
    } else if (tx['remittanceInformationUnstructured'] != null) {
      merchantName = tx['remittanceInformationUnstructured'];
    }

    // Extract description
    String description = tx['remittanceInformationUnstructured'] ?? merchantName;
    if (description.isEmpty) {
      description = merchantName;
    }

    // Parse date
    DateTime date = DateTime.now();
    if (tx['bookingDate'] != null) {
      date = DateTime.tryParse(tx['bookingDate']) ?? DateTime.now();
    } else if (tx['valueDate'] != null) {
      date = DateTime.tryParse(tx['valueDate']) ?? DateTime.now();
    }

    // Create synced transaction
    final syncedTx = SyncedTransaction.fromBankData(
      bankTransactionId: tx['transactionId'] ?? tx['internalTransactionId'] ?? const Uuid().v4(),
      accountId: accountId,
      amount: amount,
      date: date,
      merchantName: merchantName,
      remittanceInfo: description,
      bankConnectionId: connectionId,
    );

    // Auto-categorize
    return _autoCategorize(syncedTx);
  }

  // ============ AUTO-CATEGORIZATION ============

  SyncedTransaction _autoCategorize(SyncedTransaction transaction) {
    // Simple keyword-based categorization
    final String lowerDesc = transaction.description.toLowerCase();
    final String lowerMerchant = transaction.merchantName.toLowerCase();
    
    String? category;
    double confidence = 0.0;

    // Food & Dining
    if (_containsAny(lowerDesc, ['restaurant', 'cafe', 'coffee', 'food', 'pizza', 'burger']) ||
        _containsAny(lowerMerchant, ['restaurant', 'cafe', 'coffee', 'starbucks', 'mcdonalds'])) {
      category = 'Food & Dining';
      confidence = 0.8;
    }
    // Shopping
    else if (_containsAny(lowerDesc, ['amazon', 'shop', 'store', 'retail']) ||
             _containsAny(lowerMerchant, ['amazon', 'ebay', 'walmart', 'target'])) {
      category = 'Shopping';
      confidence = 0.75;
    }
    // Transportation
    else if (_containsAny(lowerDesc, ['uber', 'lyft', 'taxi', 'gas', 'fuel', 'parking']) ||
             _containsAny(lowerMerchant, ['uber', 'lyft', 'shell', 'bp'])) {
      category = 'Transportation';
      confidence = 0.8;
    }
    // Bills & Utilities
    else if (_containsAny(lowerDesc, ['electric', 'water', 'gas', 'internet', 'phone', 'utility']) ||
             _containsAny(lowerMerchant, ['verizon', 'att', 'comcast'])) {
      category = 'Bills';
      confidence = 0.85;
    }
    // Income
    else if (transaction.amount > 0 && _containsAny(lowerDesc, ['salary', 'payroll', 'payment', 'deposit'])) {
      category = 'Income';
      confidence = 0.7;
    }
    // Default
    else {
      category = transaction.amount > 0 ? 'Income' : 'Other';
      confidence = 0.3;
    }

    return transaction.withSuggestion(
      category: category,
      confidence: confidence,
    );
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  // ============ PENDING TRANSACTIONS ============

  Future<List<SyncedTransaction>> getPendingTransactions() async {
    final transactions = await _db.getPendingSyncedTransactions(_userId);
    return transactions.map((tx) => SyncedTransaction.fromJson(tx)).toList();
  }

  Future<void> approveTransaction(String transactionId) async {
    // Get the synced transaction
    final tx = await _db.getSyncedTransaction(transactionId);
    
    // Convert to regular transaction and add to main transactions table
    final regularTx = SyncedTransaction.fromJson(tx).toRegularTransaction();
    await _db.addTransaction(regularTx.accountId, regularTx.amount, regularTx.description,
        regularTx.category, regularTx.date, regularTx.tags);
    
    // Update sync status to approved
    await _db.updateSyncedTransactionStatus(transactionId, 'approved');
  }

  Future<void> discardTransaction(String transactionId) async {
    await _db.updateSyncedTransactionStatus(transactionId, 'discarded');
  }

  Future<void> approveAll() async {
    final pending = await getPendingTransactions();
    for (final tx in pending) {
      await approveTransaction(tx.id);
    }
  }

  Future<void> discardAll() async {
    final pending = await getPendingTransactions();
    for (final tx in pending) {
      await discardTransaction(tx.id);
    }
  }
}
