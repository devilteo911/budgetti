import 'package:budgetti/core/services/paypal_notification_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// PayPal's notification templates are not captured yet, so these samples are
/// generic Italian/English wordings rather than ground truth. When a real push
/// lands in the review inbox as "unreadable", copy its raw text in here as a new
/// case and make it pass — that's the intended way this parser grows.
void main() {
  const parser = PayPalNotificationParser();
  final when = DateTime.utc(2026, 10, 19, 9, 30);

  ParsedBankDraft? run(String title, String text) =>
      parser.parse(title: title, text: text, when: when);

  group('incoming, the name after the amount', () {
    test('italian: received from a person', () {
      final r = run('PayPal', 'Hai ricevuto 20,00 € EUR da Mario Rossi');

      expect(r, isNotNull);
      expect(r!.type, 'income');
      expect(r.amount, 20.0);
      expect(r.description, 'Mario Rossi');
      expect(r.counterparty, 'Mario Rossi');
      expect(r.date, when.toLocal());
    });

    test('english: received from a person', () {
      final r = run('PayPal', 'You received €20.00 from Jane Doe');

      expect(r!.type, 'income');
      expect(r.amount, 20.0);
      expect(r.description, 'Jane Doe');
    });

    test('a verb between the amount and the name does not hide it', () {
      expect(run('PayPal', '20,00 € ricevuti da Mario Rossi')!.description,
          'Mario Rossi');
      expect(run('PayPal', '€20.00 received from Jane Doe')!.description,
          'Jane Doe');
    });

    test('a refund is money in', () {
      final r = run('PayPal', 'Hai ricevuto un rimborso di 15,00 € da Zalando');

      expect(r!.type, 'income');
      expect(r.amount, 15.0);
      expect(r.description, 'Zalando');
      expect(run('PayPal', 'Refund of €15.00 from Zalando')!.type, 'income');
    });

    test('the balance glued after the name is cut off', () {
      final r = run(
        'PayPal',
        'Hai ricevuto 20,00 € da Mario Rossi Saldo: 120,00 €',
      );

      expect(r!.description, 'Mario Rossi');
    });
  });

  group('incoming, the name before the verb', () {
    test('italian: "<Name> ti ha inviato"', () {
      final r = run('PayPal', 'Mario Rossi ti ha inviato 20,00 €');

      expect(r!.type, 'income');
      expect(r.amount, 20.0);
      expect(r.description, 'Mario Rossi');
      expect(r.counterparty, 'Mario Rossi');
    });

    test('english: "<Name> sent you"', () {
      final r = run('PayPal', 'Jane Doe sent you €20.00');

      expect(r!.type, 'income');
      expect(r.description, 'Jane Doe');
    });

    test('the name can sit in the title, apart from the body', () {
      final r = run('Mario Rossi ti ha inviato 20,00 € EUR', '');

      expect(r!.description, 'Mario Rossi');
    });

    test('someone paying a request of ours is money in', () {
      final r = run('PayPal', 'Mario Rossi ha pagato la tua richiesta di 20,00 €');

      expect(r!.type, 'income');
      expect(r.amount, 20.0);
      expect(r.description, 'Mario Rossi');
    });

    test('a sentence break before the name cuts the sentence off', () {
      final r = run('PayPal', 'Hai ricevuto denaro. Mario Rossi ti ha inviato 20,00 €');

      expect(r!.description, 'Mario Rossi');
    });

    test('the app name is never the payer', () {
      final r = run('Notifica', 'PayPal ti ha inviato 5,00 € di rimborso');

      expect(r!.type, 'income');
      expect(r.description, paypalFallbackDescription);
      expect(r.counterparty, isNull);
    });
  });

  group('incoming with no name', () {
    test('italian', () {
      final r = run('PayPal', 'Hai ricevuto 20,00 €');

      expect(r!.type, 'income');
      expect(r.amount, 20.0);
      expect(r.description, 'Movimento PayPal');
      expect(r.counterparty, isNull);
    });

    test('english', () {
      final r = run('PayPal', 'You received €20.00');

      expect(r!.description, 'Movimento PayPal');
      expect(r.counterparty, isNull);
    });
  });

  group('amount formats', () {
    test('symbol and code together', () {
      final r = run('PayPal', 'Hai ricevuto 20,00 € EUR da Mario Rossi');

      expect(r!.amount, 20.0);
      expect(r.description, 'Mario Rossi'); // euros add no suffix
    });

    test('italian thousands with cents', () {
      expect(run('PayPal', 'Hai ricevuto 1.234,56 € da Mario Rossi')!.amount,
          1234.56);
    });

    test('english thousands with cents', () {
      expect(run('PayPal', 'You received €1,234.56 from Jane Doe')!.amount,
          1234.56);
    });

    test('whole number without separators', () {
      expect(run('PayPal', 'Hai ricevuto 7 €')!.amount, 7.0);
    });
  });

  // The amount is stored as if it were euros; the currency travels in the
  // description as the cue to fix it, as for Revolut.
  group('a foreign currency is named in the description', () {
    test('a symbol and a code before the name', () {
      final r = run('PayPal', 'You received \$20.00 USD from Jane Doe');

      expect(r!.description, 'Jane Doe · 20.00 USD');
      expect(r.counterparty, 'Jane Doe'); // the name stays clean
      expect(r.amount, 20.0);
    });

    test('no name: the fallback text still carries the cue', () {
      final r = run('PayPal', 'Hai ricevuto 15,00 GBP');

      expect(r!.description, '$paypalFallbackDescription · 15,00 GBP');
      expect(r.counterparty, isNull);
    });
  });

  // Outgoing money is funded by the card or bank, which notifies it already.
  group('outgoing is neither parsed nor surfaced', () {
    const outgoing = [
      ('PayPal', 'Hai pagato 25,00 € EUR a Amazon'),
      ('PayPal', 'Hai inviato 20,00 € a Mario Rossi'),
      ('PayPal', 'Hai speso 9,99 € presso Spotify'),
      ('PayPal', 'Pagamento a Spotify di 9,99 €'),
      ('PayPal', 'You paid \$25.00 USD to Amazon'),
      ('PayPal', 'You sent €20.00 to Jane Doe'),
      ('PayPal', "You've sent €20.00 to Jane Doe"),
      ('PayPal', 'Payment to Spotify: €9.99'),
      ('PayPal', 'Hai rimborsato 10,00 € a Mario Rossi'),
      // The payee's name holds an incoming word, the sentence says it is out.
      ('PayPal', 'Hai pagato 10,00 € a Rimborso Spese Srl'),
    ];

    for (final (title, text) in outgoing) {
      test(text, () {
        expect(run(title, text), isNull);
        expect(parser.looksTransactional(title, text), isFalse);
      });
    }
  });

  // The payer's own note rides in the push and may quote a noise word; incoming
  // wording decides, so the credit is still a draft (and is shown).
  group('a noise word in the payer note does not drop a credit', () {
    const credits = [
      ('Mario Rossi ti ha inviato 20,00 € EUR: offerta cena', 'Mario Rossi'),
      ('Mario Rossi ti ha inviato 20,00 € EUR: promo cena', 'Mario Rossi'),
      ('Mario Rossi ti ha inviato 20,00 € EUR: password del wifi', 'Mario Rossi'),
      ('Mario Rossi ti ha inviato 20,00 € EUR: scopri il locale', 'Mario Rossi'),
      ('Jane Doe sent you €20.00: offer for dinner', 'Jane Doe'),
      ('Jane Doe sent you €20.00: promo dinner', 'Jane Doe'),
      ('Jane Doe sent you €20.00 for the password', 'Jane Doe'),
      ('Jane Doe sent you €20.00: discover the venue', 'Jane Doe'),
    ];

    for (final (text, name) in credits) {
      test(text, () {
        final r = run('PayPal', text);

        expect(r, isNotNull);
        expect(r!.type, 'income');
        expect(r.amount, 20.0);
        expect(r.counterparty, name);
        expect(parser.looksTransactional('PayPal', text), isTrue);
      });
    }
  });

  group('noise is neither parsed nor surfaced', () {
    const noise = [
      ('PayPal', 'Il tuo codice di sicurezza PayPal è 123456'),
      ('PayPal', 'Your PayPal security code is 123456'),
      ('PayPal', 'Il tuo codice di verifica PayPal è 123456'),
      ('PayPal', 'Your PayPal verification code is 123456'),
      ('PayPal', 'Scopri PayPal Premium a solo 7,99 € al mese'),
      ('PayPal', 'Discover PayPal Plus for only €7.99 a month'),
      // An amount, but no incoming wording: a promo, not a credit.
      ('PayPal', "Scopri l'offerta PayPal: 10 € di sconto sul tuo prossimo acquisto"),
      ('PayPal', 'Discover the PayPal offer: €10 discount on your next purchase'),
      ('PayPal', 'Invita un amico e ricevi 10 € di bonus'),
      ('PayPal', 'Nuovo accesso al tuo account da un dispositivo sconosciuto'),
    ];

    for (final (title, text) in noise) {
      test(text, () {
        expect(run(title, text), isNull);
        expect(parser.looksTransactional(title, text), isFalse);
      });
    }
  });

  // No draft to invent, but a missed reimbursement is the failure to avoid: the
  // inbox shows the raw text and the owner decides.
  group('unreadable but transactional', () {
    test('an unknown wording with an amount', () {
      const title = 'PayPal';
      const text = 'Pagamento di 15,00 € EUR completato';

      expect(run(title, text), isNull);
      expect(parser.looksTransactional(title, text), isTrue);
      expect(parser.looksTransactional('PayPal', 'Payment of €15.00 completed'),
          isTrue);
    });

    test('a money request is not a credit, but is shown', () {
      const text = 'Mario Rossi ti ha richiesto 20,00 €';

      expect(run('PayPal', text), isNull);
      expect(parser.looksTransactional('PayPal', text), isTrue);
    });

    test('the receipt of a payment we made is not a credit', () {
      const text = 'Ricevuta del pagamento di 9,99 € a Spotify';

      expect(run('PayPal', text), isNull);
      expect(parser.looksTransactional('PayPal', text), isTrue);
    });

    test('incoming wording with no amount is shown, not invented', () {
      const text = 'Hai ricevuto un pagamento da Mario Rossi';

      expect(run('PayPal', text), isNull, reason: 'no amount to invent');
      expect(parser.looksTransactional('PayPal', text), isTrue);
    });

    test('a money word with no amount and no direction is shown', () {
      const text = 'Il tuo pagamento è in elaborazione';

      expect(run('PayPal', text), isNull);
      expect(parser.looksTransactional('PayPal', text), isTrue);
    });

    test('a zero amount is no draft but is shown', () {
      expect(run('PayPal', 'Hai ricevuto 0,00 €'), isNull);
      expect(parser.looksTransactional('PayPal', 'Hai ricevuto 0,00 €'), isTrue);
    });

    test('a push that is not about money stays out', () {
      expect(run('PayPal', 'Hai un nuovo messaggio'), isNull);
      expect(parser.looksTransactional('PayPal', 'Hai un nuovo messaggio'),
          isFalse);
    });

    test('the raw text is kept so the inbox can show it', () {
      final r = run('PayPal', 'Hai ricevuto 20,00 € EUR da Mario Rossi');

      expect(r!.rawSnippet, 'PayPal ⟂ Hai ricevuto 20,00 € EUR da Mario Rossi');
    });
  });
}
