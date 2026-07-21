/// Parses transaction-notification emails from Banca Widiba (widiba@widiba.it)
/// into structured drafts. Pure Dart — no Flutter/IO deps — so it can be unit
/// tested against real email bodies.
///
/// Known subjects:
///   - "Pagamento con Carta di debito"        -> expense
///   - "Pagamento bollettino CBILL"           -> expense
///   - "Modello F24 inserito"                  -> expense
///   - "Hai ricevuto un accredito"            -> income
///   - "Bonifico SEPA ... a tuo favore"       -> income
///   - "Bonifico SEPA inoltrato/istantaneo"   -> undecided (expense or transfer)
///   - "Conferma ricezione Bonifico SEPA"     -> null on purpose (duplicate of
///     the real notification)
library;

/// Result of parsing a single Widiba email. [amount] is signed
/// (negative = money out). [type] is one of income/expense/undecided.
class ParsedWidibaEmail {
  final double amount;
  final String description;
  final DateTime date;
  final String type;
  final String? counterparty;
  final String rawSnippet;

  const ParsedWidibaEmail({
    required this.amount,
    required this.description,
    required this.date,
    required this.type,
    required this.counterparty,
    required this.rawSnippet,
  });
}

class WidibaEmailParser {
  const WidibaEmailParser();

  /// Returns a parsed draft, or null if the email is unrecognised or is missing
  /// the amount (the one field we never invent).
  ParsedWidibaEmail? parse({
    required String subject,
    required String body,
    required DateTime receivedAt,
  }) {
    final text = _normalize(body);
    final snippet = text.length > 240 ? '${text.substring(0, 240)}…' : text;
    final s = subject.toLowerCase();

    // Sent alongside the real transfer notification with the same data.
    if (s.contains('conferma ricezione')) return null;

    // Subjects vary more than the "Ciao Matteo, ..." body templates, so when
    // the subject doesn't route (or its branch can't read the body), retry
    // routing on the body itself.
    return _route(s, text, receivedAt, snippet) ??
        _route(text.toLowerCase(), text, receivedAt, snippet);
  }

  ParsedWidibaEmail? _route(
    String haystack,
    String text,
    DateTime receivedAt,
    String snippet,
  ) {
    if (haystack.contains('carta di debito')) {
      return _parseCardPayment(text, receivedAt, snippet);
    }
    if (haystack.contains('accredito') || haystack.contains('a tuo favore')) {
      return _parseCredit(text, receivedAt, snippet);
    }
    // "bollett" covers both "bollettino" (subject) and "Codice Bolletta" (body).
    if (haystack.contains('cbill') || haystack.contains('bollett')) {
      return _parseCbill(text, receivedAt, snippet);
    }
    if (haystack.contains('bonifico')) {
      return _parseSepaTransfer(text, receivedAt, snippet);
    }
    if (haystack.contains('f24')) {
      return _parseF24(text, receivedAt, snippet);
    }
    return null;
  }

  // "il giorno 04/06/2026 alle ore 13:06 hai effettuato un pagamento di 11,00
  //  euro con Carta di debito n. **** **30 presso LO CHEF."
  // The payment may carry a channel qualifier: "un pagamento INTERNET di".
  ParsedWidibaEmail? _parseCardPayment(
    String text,
    DateTime receivedAt,
    String snippet,
  ) {
    final m = RegExp(
      r'il giorno (\d{1,2}/\d{1,2}/\d{4})(?:\s+alle ore\s+(\d{1,2}[:.]\d{2}))?\s+hai effettuato un pagamento(?:\s+\w+)?\s+di\s+([\d.]+,\d{2})\s+euro con carta di debito(?:\s+n\.?\s*[*\d\s]+?)?\s+presso\s+(.+?)(?:\.(?:\s|$)|$)',
      caseSensitive: false,
    ).firstMatch(text);
    if (m == null) return null;

    final amount = _parseAmount(m.group(3)!);
    if (amount == null) return null;

    final merchant = m.group(4)!.trim();
    final date = _parseDate(m.group(1)!, time: m.group(2)) ?? receivedAt;

    return ParsedWidibaEmail(
      amount: -amount,
      description: merchant,
      date: date,
      type: 'expense',
      counterparty: merchant,
      rawSnippet: snippet,
    );
  }

  // Prose form: "hai ricevuto sul conto 6003/656696 ... accredito di 7,00 euro
  // per Bonifico a tuo favore ... ORD: Giada Lagetti BIC: REVOITM2XXX 04.06.26"
  // Label/value form (instant SEPA in your favour): "Importo 7,00 € ...
  // Ordinante ... Causale ..."
  ParsedWidibaEmail? _parseCredit(
    String text,
    DateTime receivedAt,
    String snippet,
  ) {
    final amountMatch =
        RegExp(r'accredito di ([\d.]+,\d{2}) euro', caseSensitive: false)
                .firstMatch(text) ??
            RegExp(r'Importo\s+([\d.]+,\d{2})\s*€', caseSensitive: false)
                .firstMatch(text);
    if (amountMatch == null) return null;

    final amount = _parseAmount(amountMatch.group(1)!);
    if (amount == null) return null;

    final ordinante = RegExp(r'ORD:\s*(.+?)\s+BIC:', caseSensitive: false)
            .firstMatch(text)
            ?.group(1)
            ?.trim() ??
        _labelValue(text, 'Ordinante');

    final causale =
        RegExp(r'euro per (.+?)(?:\s+FILIALE|\s+ORD:|$)', caseSensitive: false)
                .firstMatch(text)
                ?.group(1)
                ?.trim() ??
            _labelValue(text, 'Causale');

    // Value date like "04.06.26", or a labeled dd/MM/yyyy; else received date.
    final dateStr =
        RegExp(r'(\d{2}\.\d{2}\.\d{2})').firstMatch(text)?.group(1) ??
            RegExp(r'(?:Data di accredito|inserito il)\s+(\d{1,2}/\d{1,2}/\d{4})',
                    caseSensitive: false)
                .firstMatch(text)
                ?.group(1);
    final date = (dateStr != null ? _parseDate(dateStr) : null) ?? receivedAt;

    final description = ordinante ?? causale ?? 'Accredito';

    return ParsedWidibaEmail(
      amount: amount,
      description: description,
      date: date,
      type: 'income',
      counterparty: ordinante,
      rawSnippet: snippet,
    );
  }

  // Structured label/value email. After whitespace normalisation:
  // "... Importo 300,00 € Commissioni bancarie 0,00 € Dal Conto 6003/656696
  //  Al conto IT82R... ID transazione (CRO) A100... Data di addebito 22/05/2026
  //  Causale Acconto per acquisto moto targata ..."
  ParsedWidibaEmail? _parseSepaTransfer(
    String text,
    DateTime receivedAt,
    String snippet,
  ) {
    final amountMatch =
        RegExp(r'Importo\s+([\d.]+,\d{2})\s*€', caseSensitive: false)
            .firstMatch(text);
    if (amountMatch == null) return null;

    final amount = _parseAmount(amountMatch.group(1)!);
    if (amount == null) return null;

    final dateStr = RegExp(r'Data di addebito\s+(\d{2}/\d{2}/\d{4})',
                caseSensitive: false)
            .firstMatch(text)
            ?.group(1) ??
        RegExp(r'inserito il\s+(\d{2}/\d{2}/\d{4})', caseSensitive: false)
            .firstMatch(text)
            ?.group(1);
    final date = (dateStr != null ? _parseDate(dateStr) : null) ?? receivedAt;

    final iban = RegExp(r'Al conto\s+([A-Z]{2}\d{2}[A-Z0-9]+)')
        .firstMatch(text)
        ?.group(1)
        ?.trim();

    final causale = _labelValue(text, 'Causale');

    return ParsedWidibaEmail(
      amount: -amount,
      description: causale ?? 'Bonifico SEPA',
      date: date,
      type: 'undecided',
      counterparty: iban,
      rawSnippet: snippet,
    );
  }

  // "Pagamento inserito il 14/05/2026 ... Importo 136,00 € Commissioni Banca
  //  1,40 € ... Causale Quota 2026 Money Management Imposte e tasse"
  ParsedWidibaEmail? _parseCbill(
    String text,
    DateTime receivedAt,
    String snippet,
  ) {
    final debit = _parseStructuredDebit(text, receivedAt);
    if (debit == null) return null;

    final causale = _labelValue(text, 'Causale');

    return ParsedWidibaEmail(
      amount: -debit.amount,
      description: causale ?? 'Bollettino CBILL',
      date: debit.date,
      type: 'expense',
      counterparty: null,
      rawSnippet: snippet,
    );
  }

  // "Modello F24 inserito il 14/05/2026 ... Importo 250,00 € [Commissioni ...]".
  // Same structured-debit shape as CBILL; the payee is always the tax authority,
  // so the description is fixed rather than pulled from a causale.
  ParsedWidibaEmail? _parseF24(
    String text,
    DateTime receivedAt,
    String snippet,
  ) {
    final debit = _parseStructuredDebit(text, receivedAt);
    if (debit == null) return null;

    return ParsedWidibaEmail(
      amount: -debit.amount,
      description: 'Modello F24',
      date: debit.date,
      type: 'expense',
      counterparty: null,
      rawSnippet: snippet,
    );
  }

  /// Shared extraction for Widiba's structured debit emails (CBILL, F24):
  /// the `Importo` plus every `Commissioni` line (all part of the real debit),
  /// and the `inserito il` date. Null when there is no amount to invent.
  ({double amount, DateTime date})? _parseStructuredDebit(
    String text,
    DateTime receivedAt,
  ) {
    final amountMatch =
        RegExp(r'Importo\s+([\d.]+,\d{2})\s*€', caseSensitive: false)
            .firstMatch(text);
    if (amountMatch == null) return null;

    var amount = _parseAmount(amountMatch.group(1)!);
    if (amount == null) return null;

    // Commissions are part of the actual debit.
    for (final m in RegExp(r'Commissioni[^€]*?([\d.]+,\d{2})\s*€',
            caseSensitive: false)
        .allMatches(text)) {
      amount = amount! + (_parseAmount(m.group(1)!) ?? 0);
    }

    final dateStr =
        RegExp(r'inserito il\s+(\d{1,2}/\d{1,2}/\d{4})', caseSensitive: false)
            .firstMatch(text)
            ?.group(1);
    final date = (dateStr != null ? _parseDate(dateStr) : null) ?? receivedAt;

    return (amount: amount!, date: date);
  }

  /// Value of a label/value pair in the bank's table emails, stopping at the
  /// next known label or the signature. Case-sensitive on purpose: the labels
  /// are always capitalized, lowercase occurrences belong to the value.
  String? _labelValue(String text, String label) {
    return RegExp(
      '$label'
      r'\s+(.+?)(?:\s+(?:Causale|Importo|Commissioni|Ordinante|Dal Conto|Al conto|Data di|ID transazione|Codice Bolletta|Categoria My Money|Money Management|A presto)\b|\s*$)',
    ).firstMatch(text)?.group(1)?.trim();
  }

  /// Collapses all whitespace (incl. newlines from HTML) into single spaces so
  /// the same regexes work whether the source was text/plain or stripped HTML.
  String _normalize(String body) =>
      body.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// "1.234,56" -> 1234.56, "11,00" -> 11.0 (Italian formatting).
  double? _parseAmount(String raw) {
    final cleaned = raw.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(cleaned);
  }

  /// Accepts "dd/MM/yyyy" or "dd.MM.yy", with optional "HH:mm"/"HH.mm" time.
  DateTime? _parseDate(String raw, {String? time}) {
    int day, month, year;
    final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(raw);
    final dot = RegExp(r'^(\d{2})\.(\d{2})\.(\d{2})$').firstMatch(raw);
    if (slash != null) {
      day = int.parse(slash.group(1)!);
      month = int.parse(slash.group(2)!);
      year = int.parse(slash.group(3)!);
    } else if (dot != null) {
      day = int.parse(dot.group(1)!);
      month = int.parse(dot.group(2)!);
      year = 2000 + int.parse(dot.group(3)!);
    } else {
      return null;
    }

    var hour = 0, minute = 0;
    if (time != null) {
      final t = RegExp(r'^(\d{1,2})[:.](\d{2})$').firstMatch(time);
      if (t != null) {
        hour = int.parse(t.group(1)!);
        minute = int.parse(t.group(2)!);
      }
    }
    return DateTime(year, month, day, hour, minute);
  }
}
