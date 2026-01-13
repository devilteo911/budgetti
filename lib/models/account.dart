class Account {
  final String id;
  final String name;
  final double balance;
  final double initialBalance;
  final String currency;
  final String providerName; // e.g. "Widiba"
  final bool isDefault;
  final DateTime? initialBalanceDate;

  Account({
    required this.id,
    required this.name,
    required this.balance,
    this.initialBalance = 0.0,
    required this.currency,
    required this.providerName,
    this.isDefault = false,
    this.initialBalanceDate,
  });

  Account copyWith({
    String? id,
    String? name,
    double? balance,
    double? initialBalance,
    String? currency,
    String? providerName,
    bool? isDefault,
    DateTime? initialBalanceDate,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      initialBalance: initialBalance ?? this.initialBalance,
      currency: currency ?? this.currency,
      providerName: providerName ?? this.providerName,
      isDefault: isDefault ?? this.isDefault,
      initialBalanceDate: initialBalanceDate ?? this.initialBalanceDate,
    );
  }

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'],
      name: json['name'],
      balance: (json['balance'] as num?)?.toDouble() ?? (json['initial_balance'] as num?)?.toDouble() ?? 0.0,
      initialBalance: (json['initial_balance'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'],
      providerName: json['provider_name'] ?? 'Supabase',
      isDefault: json['is_default'] ?? false,
      initialBalanceDate: json['initial_balance_date'] != null
          ? DateTime.parse(json['initial_balance_date'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      // 'balance' and 'provider_name' are not stored in the wallets table
      'initial_balance': initialBalance,
      'currency': currency,
      'is_default': isDefault,
      'initial_balance_date': initialBalanceDate?.toIso8601String(),
    };
  }
}
