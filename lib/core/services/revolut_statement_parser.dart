import 'package:budgetti/core/services/bank_draft.dart';

/// Parses the CSV behind Revolut's "Estratto conto" export — the backstop for
/// everything the notification listener can't capture: the whole backlog from
/// before it was switched on, plus whatever Revolut never pushes.
///
/// The file is a document, not a data export: ~38 lines of account preamble,
/// then an Italian-formatted transaction table per account, then a "Totale"
/// footer. Hence the section state machine rather than "skip N lines".
///
/// Mirror of `web/src/revolut.ts parseStatement` — same file, same rules, same
/// cases in both test suites. Change one, change the other.
class RevolutStatementParser {
  const RevolutStatementParser();

  static const _months = [
    'gen', 'feb', 'mar', 'apr', 'mag', 'giu',
    'lug', 'ago', 'set', 'ott', 'nov', 'dic',
  ];

  RevolutStatement parse(String csv) {
    final rows = <ParsedBankDraft>[];
    final skipped = <String>[];
    var inTable = false;

    for (final line in csv.split(RegExp(r'\r?\n'))) {
      final f = _splitCsvLine(line);
      if (f.length > 1 && f[0] == 'Data' && f[1] == 'Descrizione') {
        inTable = true;
        continue;
      }
      if (!inTable) continue;
      if (f[0] == 'Totale' || f.every((x) => x.isEmpty || x.startsWith('---'))) {
        inTable = false;
        continue;
      }

      final date = _parseDate(f[0]);
      final amount = f.length > 3 ? _parseAmount(f[3]) : null;
      if (date == null || amount == null) {
        skipped.add(line);
        continue;
      }
      // Costi is its own column, never its own line — fold it into the movement.
      final fee = f.length > 7 ? (_parseAmount(f[7]) ?? 0) : 0;
      final signed = amount - fee.abs();
      final description = f.length > 1 ? f[1] : '';

      rows.add(ParsedBankDraft(
        amount: signed,
        description: description,
        date: date,
        type: signed < 0 ? 'expense' : 'income',
        counterparty: description.isEmpty ? null : description,
        rawSnippet: line.length > 240 ? '${line.substring(0, 240)}…' : line,
      ));
    }
    return RevolutStatement(rows: rows, skipped: skipped);
  }

  /// One CSV line → fields, honouring "quoted, commas" and "" escapes. Revolut
  /// quotes any description holding a comma ("Pagamento da MORO,NICO").
  List<String> _splitCsvLine(String line) {
    final out = <String>[];
    final field = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (quoted) {
        if (c != '"') {
          field.write(c);
        } else if (i + 1 < line.length && line[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else if (c == '"') {
        quoted = true;
      } else if (c == ',') {
        out.add(field.toString().trim());
        field.clear();
      } else {
        field.write(c);
      }
    }
    out.add(field.toString().trim());
    return out;
  }

  /// "23 giu 2026" → local date at noon. The statement has no time of day, and
  /// noon survives any timezone shift without landing on the day before.
  DateTime? _parseDate(String s) {
    final m = RegExp(r'^(\d{1,2})\s+([a-zà-ú]+)\s+(\d{4})$', caseSensitive: false)
        .firstMatch(s);
    if (m == null) return null;
    final month = _months.indexOf(m.group(2)!.toLowerCase().substring(0, 3));
    if (month < 0) return null;
    return DateTime(int.parse(m.group(3)!), month + 1, int.parse(m.group(1)!), 12);
  }

  /// "-1.234,56€" → -1234.56 (Italian: '.' groups, ',' decimals).
  double? _parseAmount(String s) {
    final cleaned = s
        .replaceAll(RegExp(r'[^\d,.-]'), '')
        .replaceAll('.', '')
        .replaceAll(',', '.');
    if (!RegExp(r'^-?\d+(\.\d+)?$').hasMatch(cleaned)) return null;
    return double.parse(cleaned);
  }
}

class RevolutStatement {
  final List<ParsedBankDraft> rows;

  /// Table lines that didn't parse, verbatim — surfaced, never dropped silently.
  final List<String> skipped;

  const RevolutStatement({required this.rows, required this.skipped});
}
