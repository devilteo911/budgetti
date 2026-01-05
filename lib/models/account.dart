class Account {
  final String id;
  final String name;
  final double balance;
  final String currency;
  final String providerName; // e.g. "Widiba"

  Account({
    required this.id,
    required this.name,
    required this.balance,
    required this.currency,
    required this.providerName,
  });
}
