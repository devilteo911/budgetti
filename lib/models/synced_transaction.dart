import 'package:budgetti/models/transaction.dart';
import 'package:uuid/uuid.dart';

class SyncedTransaction extends Transaction {
  final String bankTransactionId;
  final String syncStatus; // 'pending', 'approved', 'discarded'
  final String merchantName;
  final DateTime syncedAt;
  final String? suggestedCategory;
  final double? categorizationConfidence;
  final String? bankConnectionId;

  SyncedTransaction({
    required super.id,
    required super.accountId,
    required super.amount,
    required super.date,
    required super.description,
    required super.category,
    super.tags = const [],
    required this.bankTransactionId,
    required this.syncStatus,
    required this.merchantName,
    required this.syncedAt,
    this.suggestedCategory,
    this.categorizationConfidence,
    this.bankConnectionId,
  });

  factory SyncedTransaction.fromBankData({
    required String bankTransactionId,
    required String accountId,
    required double amount,
    required DateTime date,
    required String merchantName,
    String? remittanceInfo,
    String? bankConnectionId,
  }) {
    final description = remittanceInfo ?? merchantName;
    
    return SyncedTransaction(
      id: const Uuid().v4(),
      accountId: accountId,
      amount: amount,
      date: date,
      description: description,
      category: '', // Will be set by auto-categorization
      tags: const [],
      bankTransactionId: bankTransactionId,
      syncStatus: 'pending',
      merchantName: merchantName,
      syncedAt: DateTime.now(),
      bankConnectionId: bankConnectionId,
    );
  }

  factory SyncedTransaction.fromJson(Map<String, dynamic> json) {
    // First parse as base Transaction
    final transaction = Transaction.fromJson(json);
    
    return SyncedTransaction(
      id: transaction.id,
      accountId: transaction.accountId,
      amount: transaction.amount,
      date: transaction.date,
      description: transaction.description,
      category: transaction.category,
      tags: transaction.tags,
      bankTransactionId: json['bank_transaction_id']?.toString() ?? '',
      syncStatus: json['sync_status']?.toString() ?? 'pending',
      merchantName: json['merchant_name']?.toString() ?? '',
      syncedAt: json['synced_at'] != null
          ? DateTime.tryParse(json['synced_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      suggestedCategory: json['suggested_category']?.toString(),
      categorizationConfidence: (json['categorization_confidence'] as num?)?.toDouble(),
      bankConnectionId: json['bank_connection_id']?.toString(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['bank_transaction_id'] = bankTransactionId;
    json['sync_status'] = syncStatus;
    json['merchant_name'] = merchantName;
    json['synced_at'] = syncedAt.toIso8601String();
    json['suggested_category'] = suggestedCategory;
    json['categorization_confidence'] = categorizationConfidence;
    json['bank_connection_id'] = bankConnectionId;
    return json;
  }

  SyncedTransaction copyWithStatus(String newStatus) {
    return SyncedTransaction(
      id: id,
      accountId: accountId,
      amount: amount,
      date: date,
      description: description,
      category: category,
      tags: tags,
      bankTransactionId: bankTransactionId,
      syncStatus: newStatus,
      merchantName: merchantName,
      syncedAt: syncedAt,
      suggestedCategory: suggestedCategory,
      categorizationConfidence: categorizationConfidence,
      bankConnectionId: bankConnectionId,
    );
  }

  SyncedTransaction withSuggestion({
    required String category,
    required double confidence,
  }) {
    return SyncedTransaction(
      id: id,
      accountId: accountId,
      amount: amount,
      date: date,
      description: description,
      category: category,
      tags: tags,
      bankTransactionId: bankTransactionId,
      syncStatus: syncStatus,
      merchantName: merchantName,
      syncedAt: syncedAt,
      suggestedCategory: category,
      categorizationConfidence: confidence,
      bankConnectionId: bankConnectionId,
    );
  }

  Transaction toRegularTransaction() {
    return Transaction(
      id: id,
      accountId: accountId,
      amount: amount,
      date: date,
      description: description,
      category: category,
      tags: tags,
    );
  }

  bool get isPending => syncStatus == 'pending';
  bool get isApproved => syncStatus == 'approved';
  bool get isDiscarded => syncStatus == 'discarded';
}
