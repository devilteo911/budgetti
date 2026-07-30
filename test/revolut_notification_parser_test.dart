import 'package:budgetti/core/services/revolut_notification_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Revolut's notification templates are undocumented, so these samples are the
/// shapes we expect rather than captured ground truth. When a real notification
/// lands in the review inbox as "unrecognised", copy its raw text in here as a
/// new case and make it pass — that's the intended way this parser grows.
void main() {
  const parser = RevolutNotificationParser();
  final when = DateTime.utc(2026, 7, 30, 10, 15);

  ParsedBankDraft? run(String title, String text) =>
      parser.parse(title: title, text: text, when: when);

  group('card payments', () {
    test('italian template: expense, merchant, negative amount', () {
      final r = run('Revolut', 'Hai speso €12,50 presso LO CHEF');

      expect(r, isNotNull);
      expect(r!.type, 'expense');
      expect(r.amount, -12.50);
      expect(r.description, 'Lo Chef');
      expect(r.counterparty, 'Lo Chef');
      expect(r.date, when.toLocal());
    });

    test('english template', () {
      final r = run('Revolut', '€12.50 at Tesco');

      expect(r!.type, 'expense');
      expect(r.amount, -12.50);
      expect(r.counterparty, 'Tesco');
    });

    test('merchant in the title, amount in the body', () {
      final r = run('Tesco', '€12.50');

      expect(r!.amount, -12.50);
      expect(r.counterparty, 'Tesco');
    });

    test('bullet-separated merchant', () {
      final r = run('Revolut', '€8.00 · Amazon');

      expect(r!.amount, -8.00);
      expect(r.counterparty, 'Amazon');
    });

    test('no direction word at all falls back to expense', () {
      final r = run('Revolut', '€4.20');

      expect(r!.type, 'expense');
      expect(r.amount, -4.20);
      expect(r.description, 'Movimento Revolut');
    });
  });

  group('incoming money', () {
    test('italian: received from a person', () {
      final r = run('Revolut', 'Hai ricevuto €50,00 da Mario Rossi');

      expect(r!.type, 'income');
      expect(r.amount, 50.00);
      expect(r.counterparty, 'Mario Rossi');
    });

    test('english: received', () {
      final r = run('Revolut', 'You received £20.00 from Jane');

      expect(r!.type, 'income');
      expect(r.amount, 20.00);
    });

    test('top-up is income', () {
      expect(run('Revolut', 'Ricarica di €100,00 completata')!.type, 'income');
    });

    test('refund is income', () {
      expect(run('Revolut', 'Rimborso di €15,00 da Zalando')!.type, 'income');
    });

    test('"pagamento ricevuto" is money in, not out', () {
      expect(run('Revolut', 'Pagamento ricevuto: €30,00')!.type, 'income');
    });
  });

  group('direction hints never beat the verb', () {
    test('"Prelievo da ATM" is an expense despite " da "', () {
      final r = run('Revolut', 'Prelievo di €50,00 da ATM Intesa');

      expect(r!.type, 'expense');
      expect(r.amount, -50.00);
    });

    test('"Inviato a" is an expense', () {
      final r = run('Revolut', 'Hai inviato €20,00 a Mario Rossi');

      expect(r!.type, 'expense');
      expect(r.amount, -20.00);
      expect(r.counterparty, 'Mario Rossi');
    });
  });

  group('amount formats', () {
    test('italian thousands with cents', () {
      expect(run('Revolut', 'Hai speso €1.234,56 presso Ikea')!.amount,
          -1234.56);
    });

    test('english thousands with cents', () {
      expect(run('Revolut', 'You spent €1,234.56 at Ikea')!.amount, -1234.56);
    });

    test('italian thousands without cents', () {
      expect(run('Revolut', 'Hai speso €1.234 presso Ikea')!.amount, -1234.0);
    });

    test('currency code after the number', () {
      expect(run('Revolut', 'Hai speso 12,50 EUR presso Bar')!.amount, -12.50);
    });

    test('currency symbol after the number', () {
      expect(run('Revolut', 'Hai speso 12,50€ presso Bar')!.amount, -12.50);
    });

    test('whole number without separators', () {
      expect(run('Revolut', 'Hai speso €7 presso Bar')!.amount, -7.0);
    });
  });

  group('non-transactional pushes', () {
    test('statement notice is neither parsed nor surfaced', () {
      expect(run('Revolut', 'Il tuo estratto conto è pronto'), isNull);
      expect(
        parser.looksTransactional('Revolut', 'Il tuo estratto conto è pronto'),
        isFalse,
      );
    });

    test('a promo with a price in it is still noise', () {
      expect(run('Revolut', 'Scopri Premium a solo €7,99 al mese'), isNull);
      expect(
        parser.looksTransactional('Revolut', 'Scopri Premium a solo €7,99 al mese'),
        isFalse,
      );
    });

    test('security code is noise', () {
      expect(
        parser.looksTransactional('Revolut', 'Il tuo codice di verifica è 123456'),
        isFalse,
      );
    });
  });

  group('unreadable but transactional', () {
    test('a movement wording with no amount is surfaced for review', () {
      const title = 'Revolut';
      const text = 'Pagamento in elaborazione presso un nuovo esercente';

      expect(run(title, text), isNull, reason: 'no amount to invent');
      expect(parser.looksTransactional(title, text), isTrue);
    });

    test('the raw text is kept so the inbox can show it', () {
      final r = run('Revolut', 'Hai speso €12,50 presso LO CHEF');
      expect(r!.rawSnippet, 'Revolut ⟂ Hai speso €12,50 presso LO CHEF');
    });
  });
}
