/// A transaction draft extracted from a bank message, whatever the source
/// (Widiba emails, Revolut push notifications). Shared so the dedup,
/// duplicate-flagging and category-guessing in `bank_sync_service.dart` work
/// the same way for every capture path.
library;

/// [amount] is signed (negative = money out). [type] is one of
/// income/expense/transfer/undecided.
class ParsedBankDraft {
  final double amount;
  final String description;
  final DateTime date;
  final String type;
  final String? counterparty;
  final String rawSnippet;

  const ParsedBankDraft({
    required this.amount,
    required this.description,
    required this.date,
    required this.type,
    required this.counterparty,
    required this.rawSnippet,
  });
}
