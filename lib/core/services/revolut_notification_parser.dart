/// Parses Revolut Android push notifications into transaction drafts. Pure
/// Dart — no Flutter/IO deps — so it can be unit tested against real captured
/// notification text.
///
/// Unlike the Widiba emails, Revolut's notification templates are undocumented
/// and localized, and they change without notice. So this parser is
/// *amount-first* rather than template-matched: find a currency amount, decide
/// the direction from the verbs around it, and take the counterparty from the
/// "at / presso / da / a" tail. Anything with no readable amount is left
/// unparsed on purpose — [looksTransactional] then routes it to the review
/// inbox with its raw text, which is how new templates get discovered instead
/// of being silently dropped.
library;

import 'package:budgetti/core/services/bank_draft.dart';

export 'package:budgetti/core/services/bank_draft.dart' show ParsedBankDraft;

class RevolutNotificationParser {
  const RevolutNotificationParser();

  /// Returns a draft, or null when the notification carries no readable amount
  /// (the one field we never invent) or is recognisably not about money.
  ParsedBankDraft? parse({
    required String title,
    required String text,
    required DateTime when,
  }) {
    final haystack = _haystack(title, text);
    if (_isNoise(haystack)) return null;

    final match = _amountRe.firstMatch(haystack);
    if (match == null) return null;

    // ponytail: first amount wins. On an FX card payment Revolut may show both
    // the foreign and the account amount, and this can take the foreign one —
    // visible and fixable in the review inbox before approval. Prefer-by-
    // currency only if that turns out to be common.
    final amount = _parseAmount(match.group(2) ?? match.group(3)!);
    if (amount == null || amount == 0) return null;

    final counterparty = _counterparty(haystack, match.end, title);
    final type = _type(haystack);

    return ParsedBankDraft(
      amount: type == 'income' ? amount : -amount,
      description: counterparty ?? 'Movimento Revolut',
      date: when.toLocal(),
      type: type,
      counterparty: counterparty,
      rawSnippet: _snippet(title, text),
    );
  }

  /// Whether an unparsed notification looks like it was about a movement, and
  /// so deserves surfacing in the review inbox rather than being ignored.
  /// Deliberately generous: a false positive costs one "ignore" tap, a false
  /// negative loses a transaction.
  bool looksTransactional(String title, String text) {
    final haystack = _haystack(title, text);
    if (_isNoise(haystack)) return false;
    if (_amountRe.hasMatch(haystack)) return true;
    return [
      ..._incomeVerbs,
      ..._expenseVerbs,
      ..._incomeHints,
      ..._expenseHints,
    ].any(haystack.contains);
  }

  /// Lowercased title + text, space-padded so ' at '/' to ' markers can be
  /// matched with their delimiters instead of hitting substrings of words.
  String _haystack(String title, String text) =>
      ' ${title.trim()} ${text.trim()} '
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), ' ');

  String _snippet(String title, String text) {
    final joined = [title.trim(), text.trim()].where((s) => s.isNotEmpty).join(' ⟂ ');
    return joined.length > 240 ? '${joined.substring(0, 240)}…' : joined;
  }

  /// Revolut also pushes statements, promos, security codes and chat messages.
  /// Those can contain a euro amount ("solo €7,99/mese"), so the deny list is
  /// checked before the amount, not after.
  bool _isNoise(String haystack) => _noiseMarkers.any(haystack.contains);

  /// Direction from the wording. Verbs beat positional hints in both
  /// directions, because the hints are ambiguous on their own: "Prelievo da
  /// ATM" contains " da " but is money out, and its verb is what settles it.
  /// Within each tier income wins, so "pagamento ricevuto" reads as money in.
  String _type(String haystack) {
    if (_incomeVerbs.any(haystack.contains)) return 'income';
    if (_expenseVerbs.any(haystack.contains)) return 'expense';
    if (_incomeHints.any(haystack.contains)) return 'income';
    if (_expenseHints.any(haystack.contains)) return 'expense';
    // ponytail: unmarked notifications are card spends in practice. If income
    // templates without an income verb show up, switch this to 'undecided'.
    return 'expense';
  }

  /// The name after the amount ("… presso LO CHEF", "… at Tesco", "… · Amazon"),
  /// else the title when it carries something more specific than the app name.
  String? _counterparty(String haystack, int amountEnd, String title) {
    final tail = haystack.substring(amountEnd);
    final m = RegExp(r'^\s*(?:presso|at|from|da|to|per|in|a|[·•\-–—:])\s+(.{2,})$')
        .firstMatch(tail);
    final name = _merchantOnly(m?.group(1) ?? '');
    if (name.isNotEmpty) return _titleCase(name);

    final t = title.trim();
    if (t.isEmpty || _genericTitles.contains(t.toLowerCase())) return null;
    // A title that is itself the sentence carrying the amount is no better
    // than the fallback description.
    if (_amountRe.hasMatch(' ${t.toLowerCase()} ')) return null;
    return t;
  }

  /// Revolut glues the running balance and a category emoji onto the merchant
  /// ("… presso Vega Carburanti 🚎 ⚠️ Saldo: 24,53 €"). Cut at whichever of the
  /// balance word or a second amount comes first, then drop the surrounding
  /// punctuation and symbols so the ledger reads "Vega Carburanti".
  String _merchantOnly(String raw) {
    final cut = [
      RegExp(r'\b(saldo|balance)\b').firstMatch(raw)?.start,
      _amountRe.firstMatch(raw)?.start,
    ].whereType<int>().fold(raw.length, (a, b) => b < a ? b : a);
    return raw.substring(0, cut).replaceAll(_edgeJunkRe, '');
  }

  static final _edgeJunkRe = RegExp(
    r'^[\s\p{P}\p{S}\p{M}]+|[\s\p{P}\p{S}\p{M}]+$',
    unicode: true,
  );

  /// Merchant names arrive shouted ("LO CHEF") or lowercased depending on the
  /// template; normalise so the ledger reads consistently.
  String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty
          ? w
          : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');

  /// Amount with the currency on either side: "€12,50", "12.50 EUR", "£1,234.56".
  static final _amountRe = RegExp(
    r'(?:([€$£]|eur|usd|gbp)\s*(\d[\d.,]*\d|\d)'
    r'|(\d[\d.,]*\d|\d)\s*([€$£]|eur|usd|gbp))',
    caseSensitive: false,
  );

  /// Locale-agnostic: Revolut renders €1.234,56 in Italian and €1,234.56 in
  /// English, so the separator that appears *last* is the decimal one. A group
  /// of exactly three trailing digits is thousands, anything else is decimals
  /// (money never has three).
  double? _parseAmount(String raw) {
    final s = raw.trim();
    final decimalAt =
        [s.lastIndexOf('.'), s.lastIndexOf(',')].reduce((a, b) => a > b ? a : b);
    if (decimalAt < 0) return double.tryParse(s);

    final stripped = s.replaceAll(RegExp(r'[.,]'), '');
    if (s.length - decimalAt - 1 == 3) return double.tryParse(stripped);

    final digits = s.substring(0, decimalAt).replaceAll(RegExp(r'[.,]'), '');
    return double.tryParse('${digits.isEmpty ? '0' : digits}'
        '.${s.substring(decimalAt + 1)}');
  }
}

const _genericTitles = <String>{'revolut', 'revolut pay', 'revolut business'};

const _incomeVerbs = <String>[
  // Italian
  'ricevuto', 'ricevuti', 'ricarica', 'ricaricato', 'rimborso', 'rimborsato',
  'accredito', 'accreditato', 'aggiunto', 'entrata',
  // English
  'received', 'refund', 'top-up', 'top up', 'topped up', 'added', 'deposit',
  'money in', 'cashback',
];

const _expenseVerbs = <String>[
  // Italian
  'speso', 'spesa', 'pagamento', 'pagato', 'prelievo', 'prelevato', 'inviato',
  'addebito', 'addebitato', 'acquisto', 'uscita',
  // English
  'spent', 'paid', 'payment', 'sent', 'withdrew', 'withdrawal', 'purchase',
  'charged', 'money out',
];

// Positional only — they say where the money moved, not which way.
const _incomeHints = <String>[' da ', ' from '];
const _expenseHints = <String>[' at ', ' presso ', ' to '];

/// Non-money pushes. Kept narrow: over-matching here silently drops real
/// movements, which is the failure mode this whole pipeline exists to avoid.
const _noiseMarkers = <String>[
  // One card payment is pushed three times — the pre-auth hold, the adjustment
  // to the real amount, then "hai pagato X presso Y" when it settles. Only the
  // last is the movement; the first two are the same money counted twice.
  // ponytail: if a hold is ever seen settling with no payment push, the planned
  // CSV statement import is the backstop, not a fourth template here.
  'temporary hold', 'blocco temporaneo', 'importo bloccato',
  'pagamento aggiornato', 'payment updated', 'importo aggiornato',
  // Balance warnings quote a threshold ("Saldo inferiore a €30"), which the
  // amount-first parser would otherwise book as a €30 top-up.
  'saldo inferiore', 'low balance', 'saldo basso',
  'estratto conto', 'statement is ready', 'statement ready',
  'codice di verifica', 'verification code', 'security code',
  'codice di sicurezza', 'accedi al tuo account', 'log in to',
  'invita un amico', 'invite a friend', 'sondaggio', 'survey',
  'scopri ', 'discover ', 'offerta', 'offer ends', 'promo',
  'ti ricordiamo che', 'aggiorna l\'app', 'update your app',
];
