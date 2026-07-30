import 'package:budgetti/core/services/revolut_statement_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Same file, same cases as `web/src/revolut.test.ts` — the two parsers read the
/// same export and have to agree. The sample is real output from Revolut's
/// "Estratto conto" CSV, trimmed, plus one deliberately broken line.
const _sample = '''
"Conti correnti Riepiloghi",,,,,,,
,,,,,,,
"Conto personale (EUR)",,,,,,,
"Numero di conto (IBAN)","IT00X0000000000000000000000","Data di apertura","23 giu 2026",,,,
,,,,,,,
"Valore del deposito",,,,,,,
,,"Saldo di apertura","0,00€",,,,
---------,,,,,,,
"Riepilogo delle transazioni",,,,,,,
Data,Descrizione,Categoria,"Denaro in entrata/uscita",Saldo,"Imposte ritenute","Altre imposte",Costi
"23 giu 2026","Pagamento da ROSSI MARIO,BIANCHI ANNA",Ricarica,"100,00€","100,00€","0,00€","0,00€","0,00€"
"24 giu 2026",Conad,Esercente,"-12,26€","87,74€","0,00€","0,00€","0,00€"
"1 lug 2026","Alí & Alíper",Esercente,"-1.019,59€","13,72€","0,00€","0,00€","-0,50€"
"8 lug 2026","www.ridedott.com*Dott manual bike ri*AMSTERDAM",Altri,"-0,70€","69,98€","0,00€","0,00€","0,00€"
"32 pippo 2026",Garbage,Esercente,"-1,00€","0,00€","0,00€","0,00€","0,00€"
Totale,,,"34,53€",,"0,00€","0,00€","0,00€"
,,,,,,,
---------,,,,,,,
''';

void main() {
  const parser = RevolutStatementParser();

  test('parses only the transaction table, dropping preamble and Totale', () {
    final s = parser.parse(_sample);
    expect(s.rows.map((r) => r.description), [
      'Pagamento da ROSSI MARIO,BIANCHI ANNA', // quoted comma kept intact
      'Conad',
      'Alí & Alíper',
      'www.ridedott.com*Dott manual bike ri*AMSTERDAM',
    ]);
  });

  test('Italian money: thousands dot, decimal comma, € suffix, fee folded in',
      () {
    final s = parser.parse(_sample);
    expect(s.rows.map((r) => r.amount), [100.0, -12.26, -1020.09, -0.70]);
    expect(s.rows.map((r) => r.type), ['income', 'expense', 'expense', 'expense']);
  });

  test('Italian dates land on the right local day', () {
    final d = parser.parse(_sample).rows[2].date;
    expect([d.year, d.month, d.day], [2026, 7, 1]);
  });

  test('unparsable table lines are surfaced, not dropped', () {
    final s = parser.parse(_sample);
    expect(s.skipped, hasLength(1));
    expect(s.skipped.single, contains('Garbage'));
  });

  test('a file with no transaction table yields nothing rather than throwing',
      () {
    final s = parser.parse('"Conti correnti Riepiloghi",,,\n,,,\n');
    expect(s.rows, isEmpty);
    expect(s.skipped, isEmpty);
  });
}
