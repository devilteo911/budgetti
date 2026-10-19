/// Parses PayPal Android push notifications into income drafts. Pure Dart, like
/// the Revolut parser it is modelled on (see its header: the approach is
/// *amount-first*, not template-matched).
///
/// Only money RECEIVED becomes a draft. A payment made from PayPal is funded by
/// the card or bank behind it, which already notifies it, so capturing it here
/// too would book it twice. Every push is sorted four ways:
///
/// - noise (codes, promos, account notices): no draft, not surfaced;
/// - outgoing wording: no draft, not surfaced;
/// - incoming wording with an amount: an income draft;
/// - anything else with an amount or a money word: no draft, but
///   [PayPalNotificationParser.looksTransactional], so the review inbox shows
///   its raw text.
///
/// No real PayPal text was available when this was written: the wordings are
/// generic Italian/English ones, and the inbox is how the real templates get
/// discovered. A false positive costs one "Ignora" tap; a missed reimbursement
/// is the failure this parser exists to avoid.
library;

import 'package:budgetti/core/finance_math.dart';
import 'package:budgetti/core/services/bank_draft.dart';

export 'package:budgetti/core/services/bank_draft.dart' show ParsedBankDraft;

/// Description of a draft whose push named no payer. Every such credit shares
/// it, so it is no merchant identity: the learned category ignores it. Duplicate
/// matching still runs on it, on date + amount alone, on purpose (see the
/// Revolut twin).
const paypalFallbackDescription = 'Movimento PayPal';

class PayPalNotificationParser {
  const PayPalNotificationParser();

  /// Returns an income draft, or null when the notification is noise, outgoing,
  /// carries no readable amount (the one field we never invent) or has no
  /// recognisable incoming wording.
  ParsedBankDraft? parse({
    required String title,
    required String text,
    required DateTime when,
  }) {
    final haystack = _haystack(title, text);
    if (_isNoise(haystack) || _direction(haystack) != _Direction.incoming) {
      return null;
    }

    final match = bankAmountRe.firstMatch(haystack);
    if (match == null) return null;

    // ponytail: first amount wins, as in the Revolut parser. A balance quoted
    // before the credit would be read as the credit, and a foreign amount is
    // stored as if it were euros (the currency in the description is the cue);
    // both are visible and fixable in the review inbox before approval.
    final rawAmount = match.group(2) ?? match.group(3)!;
    final amount = parseAmount(rawAmount);
    if (amount == null || amount == 0) return null;

    final counterparty = _counterparty(title, text, haystack, match.end);
    final currency = currencyCodeOf(match.group(1) ?? match.group(4)!);
    final description = counterparty ?? paypalFallbackDescription;

    return ParsedBankDraft(
      amount: amount,
      description: currency == 'EUR'
          ? description
          : withForeignAmount(description, rawAmount, currency),
      date: when.toLocal(),
      type: 'income',
      counterparty: counterparty,
      rawSnippet: _snippet(title, text),
    );
  }

  /// Whether an unparsed notification looks like it was about money coming in
  /// (or about money at all, when its direction is unknown) and so deserves
  /// surfacing in the review inbox. Noise and outgoing pushes never do.
  bool looksTransactional(String title, String text) {
    final haystack = _haystack(title, text);
    if (_isNoise(haystack)) return false;
    return switch (_direction(haystack)) {
      _Direction.incoming => true,
      _Direction.outgoing => false,
      _Direction.unknown =>
        bankAmountRe.hasMatch(haystack) || _moneyWordRe.hasMatch(haystack),
    };
  }

  // ponytail: private copies of the Revolut parser's text helpers (haystack,
  // snippet, edge junk, title case). Hoist them next to bankAmountRe in
  // bank_draft.dart when a third push source needs them.

  /// Lowercased title + text, space-padded so ' da '-style markers can be
  /// matched with their delimiters instead of hitting substrings of words.
  String _haystack(String title, String text) =>
      ' ${title.trim()} ${text.trim()} '
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), ' ');

  String _snippet(String title, String text) {
    final joined = [title.trim(), text.trim()].where((s) => s.isNotEmpty).join(' ⟂ ');
    return joined.length > 240 ? '${joined.substring(0, 240)}…' : joined;
  }

  /// Codes, promos and account notices. Kept narrow: over-matching here
  /// silently drops a real credit. A sender's free-text note that quotes one of
  /// these words would be dropped too (ponytail: if a real push shows notes in
  /// the notification, check the incoming wording before this list).
  bool _isNoise(String haystack) => _noiseMarkers.any(haystack.contains);

  /// Direction from the wording. When both kinds are present the one that comes
  /// FIRST wins: the free text of a push (a payer's name, a merchant, a note) is
  /// after or inside the sentence, so "Hai pagato 10 € a Rimborso Spese Srl"
  /// stays outgoing and "Mario ti ha inviato 20 € (hai pagato tu)" stays
  /// incoming.
  _Direction _direction(String haystack) {
    final incoming = _incomingRe.firstMatch(haystack)?.start;
    final outgoing = _outgoingRe.firstMatch(haystack)?.start;
    if (incoming != null && (outgoing == null || incoming < outgoing)) {
      return _Direction.incoming;
    }
    return outgoing != null ? _Direction.outgoing : _Direction.unknown;
  }

  /// The payer: "`Name` ti ha inviato …" / "`Name` sent you …" (read in the body
  /// first, then the title, never glued together: the generic title "PayPal"
  /// would end up in the name), else the name after the amount ("20,00 € da
  /// `Name`", "$20.00 USD from `Name`"). Null when the push names nobody.
  ///
  /// ponytail: the title is never taken as the name itself. PayPal's titles are
  /// the app name or a sentence; add it when a real push puts the payer there.
  String? _counterparty(
    String title,
    String text,
    String haystack,
    int amountEnd,
  ) {
    for (final zone in [_haystack('', text), _haystack(title, '')]) {
      final name = _merchantOnly(_nameBeforeVerbRe.firstMatch(zone)?.group(1) ?? '');
      if (name.isNotEmpty && !_genericTitles.contains(name)) {
        return _titleCase(name);
      }
    }

    // Right after the amount ("20,00 € da Mario"), else after a word or two of
    // the sentence ("20,00 € EUR da Mario", "€20.00 received from Jane"). At
    // most three: further out a "da" is as likely part of something else.
    final m = _nameAfterAmountRe.firstMatch(haystack.substring(amountEnd));
    final after = _merchantOnly(m?.group(1) ?? '');
    return after.isNotEmpty && !_genericTitles.contains(after)
        ? _titleCase(after)
        : null;
  }

  /// A push may glue the running balance after the name ("… da Mario Saldo:
  /// 24,53 €"). Cut at whichever of the balance word or a second amount comes
  /// first, then drop the surrounding punctuation and symbols.
  String _merchantOnly(String raw) {
    final cut = [
      RegExp(r'\b(saldo|balance)\b').firstMatch(raw)?.start,
      bankAmountRe.firstMatch(raw)?.start,
    ].whereType<int>().fold(raw.length, (a, b) => b < a ? b : a);
    return raw.substring(0, cut).replaceAll(_edgeJunkRe, '');
  }

  static final _edgeJunkRe = RegExp(
    r'^[\s\p{P}\p{S}\p{M}]+|[\s\p{P}\p{S}\p{M}]+$',
    unicode: true,
  );

  /// Names arrive shouted or lowercased depending on the template; normalise so
  /// the ledger reads consistently.
  String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty
          ? w
          : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');

  /// The name before a person-verb, cut at the last sentence break before it.
  static final _nameBeforeVerbRe =
      RegExp(r'([^.:!?|·•]{2,}?)\s+(?:' '$_fromPerson)');

  static final _nameAfterAmountRe =
      RegExp(r'^\s*(?:\S+\s+){0,3}?(?:da|from)\s+(.{2,})$');
}

enum _Direction { incoming, outgoing, unknown }

/// What the app calls itself in the title; never a payer.
const _genericTitles = <String>{'paypal'};

/// Wordings that name a PERSON as the payer, shared by the direction check and
/// the "`Name` `verb`" counterparty read.
const _fromPerson = r'ti ha (?:inviato|mandato|pagato|trasferito)'
    r'|ha pagato|sent you|paid you|has paid';

/// Money in. Stems on purpose ("rimbors" is rimborso/rimborsato/rimborsi), and
/// "ricevut[oi]" without the feminine so a receipt ("ricevuta") for a payment
/// the owner made is not read as a credit.
final _incomingRe = RegExp(
  r'\b(?:ricevut[oi]|rimbors|accredit|pagamento da|in entrata'
  r'|received|refund|credited|payment from|money in|'
  '$_fromPerson)',
);

/// Money out, first person: the owner paid, sent or refunded. Deliberately
/// short — everything else with an amount is surfaced, not dropped.
final _outgoingRe = RegExp(
  r'\b(?:hai (?:pagato|inviato|mandato|speso|trasferito|rimborsato)'
  r'|you(?:.?ve)? (?:paid|sent|spent|transferred|refunded)'
  r'|pagamento a\b|payment to\b)',
);

/// A push with no amount and no direction that still talks about money.
final _moneyWordRe = RegExp(
  r'pagament|payment|denaro|soldi|money|bonific|transfer|trasferiment'
  r'|transazion|transaction|donazion|donation',
);

/// Non-money pushes. Kept narrow: over-matching here silently drops real
/// credits, which is the failure mode this whole pipeline exists to avoid.
const _noiseMarkers = <String>[
  'codice di verifica', 'verification code', 'security code',
  'codice di sicurezza', 'codice monouso', 'one-time', 'il tuo codice',
  'your code', 'accedi al tuo account', 'log in to', 'nuovo accesso',
  'new login', 'password',
  'invita un amico', 'invite a friend', 'sondaggio', 'survey',
  'scopri ', 'discover ', 'offerta', 'offer ', 'promo', 'sconto', 'discount',
  'ti ricordiamo che', 'aggiorna l\'app', 'update your app',
  'informativa sulla privacy', 'privacy policy', 'termini e condizioni',
  'terms and conditions', 'user agreement',
];
