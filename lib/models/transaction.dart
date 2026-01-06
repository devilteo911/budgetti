import 'package:uuid/uuid.dart';

class Transaction {
  final String id;
  final String accountId;
  final double amount;
  final DateTime date;
  final String description;
  final String category;
  final List<String> tags;

  Transaction({
    required this.id,
    required this.accountId,
    required this.amount,
    required this.date,
    required this.description,
    required this.category,
    this.tags = const [],
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
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: json['date'] != null ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now() : DateTime.now(),
      description: (json['description'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      tags: tags,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'account_id': accountId,
      'amount': amount,
      'description': description,
      'category': category,
      'date': date.toIso8601String(),
      'tags': tags,
    };
  }

  Transaction copyWith({
    String? id,
    String? accountId,
    double? amount,
    DateTime? date,
    String? description,
    String? category,
    List<String>? tags,
  }) {
    return Transaction(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      description: description ?? this.description,
      category: category ?? this.category,
      tags: tags ?? this.tags,
    );
  }
}
