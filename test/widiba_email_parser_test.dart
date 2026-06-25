import 'package:budgetti/core/services/gmail_service.dart'
    show stripHtmlToText;
import 'package:budgetti/core/services/widiba_email_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = WidibaEmailParser();
  final received = DateTime(2026, 6, 4, 13, 30);

  group('Pagamento con Carta di debito', () {
    const body = 'Ciao Matteo, '
        'il giorno 04/06/2026 alle ore 13:06 hai effettuato un pagamento di '
        '11,00 euro con Carta di debito n. **** **30 presso LO CHEF. '
        'A presto, il tuo team Widiba';

    test('parses as a negative expense with merchant + datetime', () {
      final r = parser.parse(
        subject: 'Pagamento con Carta di debito',
        body: body,
        receivedAt: received,
      );

      expect(r, isNotNull);
      expect(r!.type, 'expense');
      expect(r.amount, -11.00);
      expect(r.description, 'LO CHEF');
      expect(r.counterparty, 'LO CHEF');
      expect(r.date, DateTime(2026, 6, 4, 13, 6));
    });
  });

  group('Hai ricevuto un accredito', () {
    const body = 'Ciao Matteo, '
        'hai ricevuto sul conto 6003/656696 di Moro Matteo, Nicola '
        'accredito di 7,00 euro per Bonifico a tuo favore '
        'FILIALE DISPONENTE 00102 BON. IST. REVITR2606047774 04.06.26 '
        'ORD: Giada Lagetti BIC: REVOITM2XXX IND:Via Madonna Inviato da Revolut '
        'A presto, il tuo team Widiba';

    test('parses as positive income with ordinante + value date', () {
      final r = parser.parse(
        subject: 'Hai ricevuto un accredito',
        body: body,
        receivedAt: received,
      );

      expect(r, isNotNull);
      expect(r!.type, 'income');
      expect(r.amount, 7.00);
      expect(r.description, 'Giada Lagetti');
      expect(r.counterparty, 'Giada Lagetti');
      expect(r.date, DateTime(2026, 6, 4));
    });
  });

  group('Bonifico SEPA inoltrato', () {
    const body = 'Ciao Matteo, hai inserito un bonifico SEPA istantaneo dal Conto '
        'Bonifico SEPA istantaneo inserito il 22/05/2026 '
        'Importo 300,00 € Commissioni bancarie 0,00 € '
        'Dal Conto 6003/656696 Al conto IT82R03268223000EMH0012509 '
        'ID transazione (CRO) A1008405750034424816000020 '
        'Data di addebito 22/05/2026 '
        'Causale Acconto per acquisto moto targata AB123CD';

    test('parses as undecided, negative, with IBAN + causale', () {
      final r = parser.parse(
        subject: 'Bonifico SEPA inoltrato',
        body: body,
        receivedAt: received,
      );

      expect(r, isNotNull);
      expect(r!.type, 'undecided');
      expect(r.amount, -300.00);
      expect(r.description, 'Acconto per acquisto moto targata AB123CD');
      expect(r.counterparty, 'IT82R03268223000EMH0012509');
      expect(r.date, DateTime(2026, 5, 22));
    });

    test('ignores the commissioni amount, takes Importo', () {
      final r = parser.parse(
        subject: 'Bonifico SEPA inoltrato',
        body: body,
        receivedAt: received,
      );
      expect(r!.amount, -300.00);
    });
  });

  group('real HTML samples', () {
    test('card payment HTML parses through the strip pipeline', () {
      const html = '''
<div style="color:#525d66">
Ciao Matteo,<br>
il giorno 25/05/2026 alle ore 21:36 hai effettuato un pagamento di 3,50 euro con Carta di debito n. **** **30 presso  SumUp  *Ravioleria Al.
</div>''';
      final r = parser.parse(
        subject: 'Pagamento con Carta di debito',
        body: stripHtmlToText(html),
        receivedAt: received,
      );
      expect(r, isNotNull);
      expect(r!.type, 'expense');
      expect(r.amount, -3.50);
      expect(r.description, 'SumUp *Ravioleria Al');
      expect(r.date, DateTime(2026, 5, 25, 21, 36));
    });

    test('CBILL bollettino HTML: amount includes commissions, causale', () {
      const html = '''
<p><span style="font-weight:600">Pagamento inserito il 14/05/2026</span></p>
<table><tbody>
<tr><td>Importo</td></tr><tr><td>136,00 €</td></tr>
<tr><td>Commissioni Banca</td></tr><tr><td>1,40 €</td></tr>
<tr><td>Commissioni azienda creditrice</td></tr><tr><td>0,00 €</td></tr>
<tr><td>Codice Bolletta / Avviso</td></tr><tr><td>001000000002310783</td></tr>
<tr><td>C/C N.</td></tr><tr><td>6003/656696</td></tr>
<tr><td>Causale</td></tr><tr><td>Quota 2026</td></tr>
<tr><td>Money Management</td></tr><tr><td>Imposte e tasse</td></tr>
</tbody></table>''';
      final r = parser.parse(
        subject: 'Pagamento bollettino CBILL',
        body: stripHtmlToText(html),
        receivedAt: received,
      );
      expect(r, isNotNull);
      expect(r!.type, 'expense');
      expect(r.amount, closeTo(-137.40, 0.001));
      expect(r.description, 'Quota 2026');
      expect(r.date, DateTime(2026, 5, 14));
    });

    test('instant SEPA HTML: causale stops before Categoria My Money', () {
      const html = '''
<p>Bonifico SEPA istantaneo inserito il 22/05/2026</p>
<table><tbody>
<tr><td>Importo</td></tr><tr><td>300,00 €</td></tr>
<tr><td>Commissioni bancarie</td></tr><tr><td>0,00 €</td></tr>
<tr><td>Dal Conto</td></tr><tr><td>6003/656696</td></tr>
<tr><td>Al conto</td><td></td></tr>
<tr><td>IT82R03268223000EMH00125003</td></tr>
<tr><td>ID transazione (CRO)</td></tr><tr><td>A100840575003442481600002000IT</td></tr>
<tr><td>Data di addebito</td></tr><tr><td>22/05/2026</td></tr>
<tr><td>Causale</td></tr><tr><td>Acconto per acquisto moto targata EX49221</td></tr>
<tr><td>Categoria My Money</td></tr><tr><td>Tempo libero e viaggi</td></tr>
</tbody></table>''';
      final r = parser.parse(
        subject: 'Bonifico SEPA istantaneo',
        body: stripHtmlToText(html),
        receivedAt: received,
      );
      expect(r, isNotNull);
      expect(r!.type, 'undecided');
      expect(r.amount, -300.00);
      expect(r.description, 'Acconto per acquisto moto targata EX49221');
      expect(r.counterparty, 'IT82R03268223000EMH00125003');
      expect(r.date, DateTime(2026, 5, 22));
    });

    test('instant SEPA in your favour parses as income', () {
      const body = 'Bonifico SEPA istantaneo a tuo favore inserito il '
          '03/06/2026 Importo 250,00 € Ordinante Mario Rossi '
          'Causale Regalo compleanno Categoria My Money Altro';
      final r = parser.parse(
        subject: 'Bonifico SEPA istantaneo a tuo favore',
        body: body,
        receivedAt: received,
      );
      expect(r, isNotNull);
      expect(r!.type, 'income');
      expect(r.amount, 250.00);
      expect(r.description, 'Mario Rossi');
      expect(r.date, DateTime(2026, 6, 3));
    });

    test('card payment with INTERNET channel qualifier parses', () {
      const html = '''
<div style="color:#525d66;font-family:'Open Sans',sans-serif">
Ciao Matteo,<br>
il giorno 27/05/2026 alle ore 04:17 hai effettuato un pagamento INTERNET di 4,87 euro con Carta di debito n. **** **30 presso  <a href="http://WWW.LOCKERS4ALL.GR" target="_blank">WWW.LOCKERS4ALL.GR</a>.
</div>''';
      final r = parser.parse(
        subject: 'Pagamento con Carta di debito',
        body: stripHtmlToText(html),
        receivedAt: received,
      );
      expect(r, isNotNull);
      expect(r!.type, 'expense');
      expect(r.amount, -4.87);
      expect(r.description, 'WWW.LOCKERS4ALL.GR');
      expect(r.date, DateTime(2026, 5, 27, 4, 17));
    });

    test('unrecognised subject falls back to body routing (card)', () {
      const body = 'Ciao Matteo, il giorno 27/05/2026 alle ore 04:17 hai '
          'effettuato un pagamento INTERNET di 4,87 euro con Carta di debito '
          'n. **** **30 presso WWW.LOCKERS4ALL.GR. A presto, il tuo team Widiba';
      final r = parser.parse(
        subject: 'Notifica operazione',
        body: body,
        receivedAt: received,
      );
      expect(r, isNotNull);
      expect(r!.amount, -4.87);
      expect(r.description, 'WWW.LOCKERS4ALL.GR');
    });

    test('unrecognised subject falls back to body routing (bonifico table)', () {
      const body = 'Ciao Matteo, '
          'Bonifico SEPA istantaneo inserito il 22/05/2026 '
          'Importo 300,00 € Commissioni bancarie 0,00 € '
          'Dal Conto 6003/656696 Al conto IT82R03268223000EMH00125003 '
          'ID transazione (CRO) A100840575003442481600002000IT '
          'Data di addebito 22/05/2026 '
          'Causale Acconto per acquisto moto targata EX49221 '
          'Categoria My Money Tempo libero e viaggi';
      final r = parser.parse(
        subject: 'Disposizione eseguita',
        body: body,
        receivedAt: received,
      );
      expect(r, isNotNull);
      expect(r!.type, 'undecided');
      expect(r.amount, -300.00);
      expect(r.description, 'Acconto per acquisto moto targata EX49221');
      expect(r.counterparty, 'IT82R03268223000EMH00125003');
      expect(r.date, DateTime(2026, 5, 22));
    });

    test('unrecognised subject falls back to body routing (accredito)', () {
      const html = '''
<div>Ciao Matteo,<br>
hai ricevuto sul conto 6003/656696 di Moro Matteo, Nico Miriam un accredito di 2.777,58 euro  per Bonifico a tuo favore.</div>
<div style="font-style:italic">
FILIALE DISPONENTE 00102 BON. SEPA 0832700202672025486296062730IT DEL 20.05.26 ORD: LABOTICS ITALIA SRL BIC: ICRAITRRROM INF:RI: PAGAMENTO FATTURA 3/26
</div>
<div>A presto,<br><span>il tuo team Widiba</span></div>''';
      final r = parser.parse(
        subject: 'Notifica',
        body: stripHtmlToText(html),
        receivedAt: received,
      );
      expect(r, isNotNull);
      expect(r!.type, 'income');
      expect(r.amount, 2777.58);
      expect(r.description, 'LABOTICS ITALIA SRL');
      expect(r.counterparty, 'LABOTICS ITALIA SRL');
      expect(r.date, DateTime(2026, 5, 20));
    });

    test('conferma ricezione is skipped on purpose', () {
      final r = parser.parse(
        subject: 'Conferma ricezione Bonifico SEPA  istantaneo',
        body: 'Importo 300,00 € Data di addebito 22/05/2026',
        receivedAt: received,
      );
      expect(r, isNull);
    });
  });

  group('robustness', () {
    test('unknown subject returns null', () {
      final r = parser.parse(
        subject: 'Newsletter Widiba',
        body: 'Scopri le novità',
        receivedAt: received,
      );
      expect(r, isNull);
    });

    test('recognised subject but missing amount returns null', () {
      final r = parser.parse(
        subject: 'Pagamento con Carta di debito',
        body: 'Ciao Matteo, qualcosa è andato storto.',
        receivedAt: received,
      );
      expect(r, isNull);
    });

    test('handles HTML-style newlines/whitespace collapsing', () {
      const messy = 'Ciao Matteo,\n\n   il giorno 04/06/2026 alle ore 13:06\n'
          'hai effettuato un pagamento di 11,00 euro\ncon Carta di debito '
          'n. **** **30 presso LO CHEF.\n';
      final r = parser.parse(
        subject: 'Pagamento con Carta di debito',
        body: messy,
        receivedAt: received,
      );
      expect(r, isNotNull);
      expect(r!.amount, -11.00);
      expect(r.description, 'LO CHEF');
    });
  });
}
