import 'package:uuid/uuid.dart';

class Transaction {
  final String id;
  final String accountId;
  final String? toAccountId;
  final double amount;
  final DateTime date;
  final String description;
  final String category;
  final String type; // 'income', 'expense', or 'transfer'
  final List<String> tags;

  /// Id of the installment plan this charge pays a rate of, if any.
  final String? installmentId;

  /// Income/expense aggregates skip transfers — a wallet-to-wallet move is
  /// neither. Sign decides within the rest, so legacy/imported rows whose
  /// `type` disagrees with their sign still classify consistently everywhere.
  bool get isIncome => type != 'transfer' && amount > 0;
  bool get isExpense => type != 'transfer' && amount < 0;

  Transaction({
    required this.id,
    required this.accountId,
    this.toAccountId,
    required this.amount,
    required this.date,
    required this.description,
    required this.category,
    this.type = 'expense',
    this.tags = const [],
    this.installmentId,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    // Determine tags with high resilience
    List<String> tags = [];
    final rawTags = json['tags'];
    
    if (rawTags is List) {
      tags = List<String>.from(rawTags.map((e) => e?.toString() ?? ''));
    } else if (rawTags is String) {
      final s = rawTags.trim();
      if (s.startsWith('{') && s.endsWith('}')) {
        tags = List<String>.from(
          s.substring(1, s.length - 1)
           .split(',')
           .map((e) => e.trim())
           .where((e) => e.isNotEmpty)
        );
      } else if (s.isNotEmpty) {
        tags = [s];
      }
    }

    return Transaction(
      id: (json['id'] ?? const Uuid().v4()).toString(),
      accountId: (json['account_id'] ?? '1').toString(),
      toAccountId: json['to_account_id']?.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: json['date'] != null ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now() : DateTime.now(),
      description: (json['description'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      type:
          (json['type'] ??
                  (rawTags != null && (json['amount'] as num? ?? 0) >= 0
                      ? 'income'
                      : 'expense'))
              .toString(),
      tags: tags,
      installmentId: json["installment_id"]?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'account_id': accountId,
      'to_account_id': toAccountId,
      'amount': amount,
      'description': description,
      'category': category,
      'type': type,
      'date': date.toIso8601String(),
      'tags': tags,
      'installment_id': installmentId,
    };
  }

  Transaction copyWith({
    String? id,
    String? accountId,
    String? toAccountId,
    double? amount,
    DateTime? date,
    String? description,
    String? category,
    String? type,
    List<String>? tags,
    String? installmentId,
    bool clearInstallment = false,
  }) {
    return Transaction(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      description: description ?? this.description,
      category: category ?? this.category,
      type: type ?? this.type,
      tags: tags ?? this.tags,
      installmentId:
          clearInstallment ? null : (installmentId ?? this.installmentId),
    );
  }
}
