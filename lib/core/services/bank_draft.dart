/// A transaction draft extracted from a bank message, whatever the source
/// (Widiba emails, Revolut and PayPal push notifications). Shared so the dedup,
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

/// A draft has no currency of its own: its amount is euros by convention. A push
/// in another currency keeps its ORIGINAL amount in the description, as a
/// " · 12,50 USD" suffix, and these two functions are the only place that knows
/// the shape — the parser writes it with [withForeignAmount], the review inbox
/// reads it back with [foreignAmountOf] — so the two cannot drift apart.
///
/// ponytail: a description, not a column. A v18 column would be sturdier but is a
/// migration for a hint the owner replaces the moment they type the euro amount;
/// the only false reading is a euro merchant whose name literally ends in
/// " · NUMBER CODE".
String withForeignAmount(String description, String amount, String currency) =>
    '$description · $amount $currency';

/// The original amount and currency [withForeignAmount] wrote, or null for a
/// euro draft (which has no suffix).
({String amount, String currency})? foreignAmountOf(String description) {
  final m = _foreignSuffix.firstMatch(description);
  return m == null ? null : (amount: m.group(1)!, currency: m.group(2)!);
}

final _foreignSuffix = RegExp(r' · (\d[\d.,]*\d|\d) ((?!EUR)[A-Z]{3})$');

/// Amount with the currency on either side: "€12,50", "12.50 EUR", "£1,234.56".
/// The push-notification parsers are amount-first and share it: groups 1 + 2
/// are currency-then-number, groups 3 + 4 number-then-currency.
final bankAmountRe = RegExp(
  r'(?:([€$£]|eur|usd|gbp)\s*(\d[\d.,]*\d|\d)'
  r'|(\d[\d.,]*\d|\d)\s*([€$£]|eur|usd|gbp))',
  caseSensitive: false,
);

/// The ISO code of the symbol or code a [bankAmountRe] match carries.
String currencyCodeOf(String symbolOrCode) => switch (symbolOrCode.toLowerCase()) {
      '\$' || 'usd' => 'USD',
      '£' || 'gbp' => 'GBP',
      _ => 'EUR',
    };
