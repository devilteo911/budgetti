import 'package:uuid/uuid.dart';

class Budget {
  final String id;
  final String userId;
  final String category;
  final double limit;
  final String period;

  Budget({
    required this.id,
    required this.userId,
    required this.category,
    required this.limit,
    this.period = 'monthly',
  });

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id']?.toString() ?? const Uuid().v4(),
      userId: json['user_id']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      limit: (json['limit_amount'] as num?)?.toDouble() ?? 0.0,
      period: json['period']?.toString() ?? 'monthly',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'limit_amount': limit,
      'period': period,
    };
  }

  Budget copyWith({
    String? id,
    String? userId,
    String? category,
    double? limit,
    String? period,
  }) {
    return Budget(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      limit: limit ?? this.limit,
      period: period ?? this.period,
    );
  }
}
