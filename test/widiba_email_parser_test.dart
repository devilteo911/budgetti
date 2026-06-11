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
