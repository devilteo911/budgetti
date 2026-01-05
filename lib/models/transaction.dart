class Transaction {
  final String id;
  final String accountId;
  final double amount;
  final DateTime date;
  final String description;
  final String category;

  Transaction({
    required this.id,
    required this.accountId,
    required this.amount,
    required this.date,
    required this.description,
    required this.category,
  });
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      accountId: '1', // Supabase will manage user_id, we can ignore accountId or map it to user_id
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date']),
      description: json['description'],
      category: json['category'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // 'id': id, // Let Supabase generate ID for new insertions if needed, or we send it
      'amount': amount,
      'description': description,
      'category': category,
      'date': date.toIso8601String(),
    };
  }
}
