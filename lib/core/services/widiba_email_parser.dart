/// Parses transaction-notification emails from Banca Widiba (widiba@widiba.it)
/// into structured drafts. Pure Dart — no Flutter/IO deps — so it can be unit
/// tested against real email bodies.
///
/// Three known subjects are handled:
///   - "Pagamento con Carta di debito"  -> expense
///   - "Hai ricevuto un accredito"      -> income
///   - "Bonifico SEPA inoltrato"        -> undecided (user picks expense/transfer)
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

    if (s.contains('carta di debito')) {
      return _parseCardPayment(text, receivedAt, snippet);
    }
    if (s.contains('accredito')) {
      return _parseCredit(text, receivedAt, snippet);
    }
    if (s.contains('bonifico sepa')) {
      return _parseSepaTransfer(text, receivedAt, snippet);
    }
    return null;
  }

  // "il giorno 04/06/2026 alle ore 13:06 hai effettuato un pagamento di 11,00
  //  euro con Carta di debito n. **** **30 presso LO CHEF."
  ParsedWidibaEmail? _parseCardPayment(
    String text,
    DateTime receivedAt,
    String snippet,
  ) {
    final m = RegExp(
      r'il giorno (\d{2}/\d{2}/\d{4}) alle ore (\d{2}:\d{2}) hai effettuato un pagamento di ([\d.]+,\d{2}) euro con Carta di debito n\.?\s*(.+?)\s+presso\s+(.+?)\.',
      caseSensitive: false,
    ).firstMatch(text);
    if (m == null) return null;

    final amount = _parseAmount(m.group(3)!);
    if (amount == null) return null;

    final merchant = m.group(5)!.trim();
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

  // "hai ricevuto sul conto 6003/656696 ... accredito di 7,00 euro per Bonifico
  //  a tuo favore ... ORD: Giada Lagetti BIC: REVOITM2XXX ... 04.06.26 ..."
  ParsedWidibaEmail? _parseCredit(
    String text,
    DateTime receivedAt,
    String snippet,
  ) {
    final amountMatch =
        RegExp(r'accredito di ([\d.]+,\d{2}) euro', caseSensitive: false)
            .firstMatch(text);
    if (amountMatch == null) return null;

    final amount = _parseAmount(amountMatch.group(1)!);
    if (amount == null) return null;

    final ordinante = RegExp(r'ORD:\s*(.+?)\s+BIC:', caseSensitive: false)
        .firstMatch(text)
        ?.group(1)
        ?.trim();

    final causale =
        RegExp(r'euro per (.+?)(?:\s+FILIALE|\s+ORD:|$)', caseSensitive: false)
            .firstMatch(text)
            ?.group(1)
            ?.trim();

    // Value date like "04.06.26"; fall back to email received date.
    final valueDate = RegExp(r'(\d{2}\.\d{2}\.\d{2})').firstMatch(text)?.group(1);
    final date = (valueDate != null ? _parseDate(valueDate) : null) ?? receivedAt;

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

    final causale = RegExp(r'Causale\s+(.+?)\s*$', caseSensitive: false)
        .firstMatch(text)
        ?.group(1)
        ?.trim();

    return ParsedWidibaEmail(
      amount: -amount,
      description: causale ?? 'Bonifico SEPA',
      date: date,
      type: 'undecided',
      counterparty: iban,
      rawSnippet: snippet,
    );
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

  /// Accepts "dd/MM/yyyy" or "dd.MM.yy", with optional "HH:mm" time.
  DateTime? _parseDate(String raw, {String? time}) {
    int day, month, year;
    final slash = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(raw);
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
      final t = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(time);
      if (t != null) {
        hour = int.parse(t.group(1)!);
        minute = int.parse(t.group(2)!);
      }
    }
    return DateTime(year, month, day, hour, minute);
  }
}
