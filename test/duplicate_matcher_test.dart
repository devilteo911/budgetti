import 'package:budgetti/core/services/bank_draft.dart';
import 'package:budgetti/core/services/bank_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('descriptionSimilarity', () {
    test('merchant name buried in POS boilerplate scores high', () {
      final sim = descriptionSimilarity(
        'Esselunga',
        'PAGAMENTO POS ESSELUNGA SPA MILANO',
      );
      expect(sim, greaterThanOrEqualTo(0.9));
    });

    test('identical strings score 1.0', () {
      expect(descriptionSimilarity('Netflix', 'Netflix'), 1.0);
    });

    test('unrelated merchants score low', () {
      final sim = descriptionSimilarity(
        'Farmacia Comunale',
        'PAGAMENTO POS ESSELUNGA SPA',
      );
      expect(sim, lessThan(0.2));
    });

    test('boilerplate-only overlap does not count', () {
      final sim = descriptionSimilarity(
        'PAGAMENTO POS CARTA',
        'PAGAMENTO POS ESSELUNGA',
      );
      expect(sim, 0);
    });
  });

  group('duplicateConfidence', () {
    final day = DateTime(2026, 6, 9);

    test('same day + same merchant is a confident duplicate', () {
      final score = duplicateConfidence(
        draftDate: day,
        draftDescription: 'PAGAMENTO POS ESSELUNGA SPA',
        txDate: day,
        txDescription: 'Esselunga',
      );
      expect(score, greaterThanOrEqualTo(duplicateThreshold));
    });

    test('same day with unrelated title still gets flagged', () {
      final score = duplicateConfidence(
        draftDate: day,
        draftDescription: 'PAGAMENTO POS ESSELUNGA SPA',
        txDate: day,
        txDescription: 'Spesa settimanale',
      );
      expect(score, greaterThanOrEqualTo(duplicateThreshold));
    });

    test('3 days apart with unrelated title is not flagged', () {
      final score = duplicateConfidence(
        draftDate: day,
        draftDescription: 'PAGAMENTO POS ESSELUNGA SPA',
        txDate: day.subtract(const Duration(days: 3)),
        txDescription: 'Cena fuori',
      );
      expect(score, lessThan(duplicateThreshold));
    });

    test('3 days apart but same merchant is flagged', () {
      final score = duplicateConfidence(
        draftDate: day,
        draftDescription: 'PAGAMENTO POS ESSELUNGA SPA',
        txDate: day.subtract(const Duration(days: 3)),
        txDescription: 'Esselunga',
      );
      expect(score, greaterThanOrEqualTo(duplicateThreshold));
    });
  });

  group('guessCategory', () {
    String? guess(String description, {String type = 'expense'}) =>
        guessCategory(ParsedBankDraft(
          amount: type == 'income' ? 10 : -10,
          description: description,
          date: DateTime(2026, 8, 20),
          type: type,
          counterparty: null,
          rawSnippet: description,
        ));

    test('a cash withdrawal is never a tram ticket', () {
      // "atm" is a Transport keyword (the Milan transit company).
      expect(guess('Prelievo ATM Intesa'), isNull);
      expect(guess('Prelievo Bancomat'), isNull);
    });

    test('short keywords are whole words, not substrings', () {
      expect(guess('Genius'), isNull); // eni
      expect(guess('Timberland'), isNull); // tim
      expect(guess('Intimissimi'), isNull); // tim
      expect(guess('Espresso House'), isNull); // esso
      expect(guess('Cooperativa Sociale'), isNull); // coop
      expect(guess('Barilla'), isNull); // bar
    });

    test('a short keyword still matches as a word', () {
      expect(guess('Conad'), 'Groceries');
      expect(guess('PAGAMENTO POS COOP LOMBARDIA'), 'Groceries');
      expect(guess('ENI STATION 1234'), 'Transport');
      expect(guess('TIM SPA'), 'Bills');
      expect(guess('Bar Sport'), 'Dining');
    });

    test('long stems still match as a word prefix', () {
      expect(guess('Pizzeria Da Mario'), 'Dining');
      expect(guess('SUPERMERCATI ROSSI'), 'Groceries');
      expect(guess('Carburanti Vega'), 'Transport');
      expect(guess('Pineapple Studio'), isNull); // apple, mid-word
    });

    test('a Bancomat Pay purchase is a purchase, only cash is not', () {
      // "bancomat" alone means the ATM circuit; "Bancomat Pay" is a merchant
      // payment whose text ends with the shop.
      expect(
        guess('Bancomat Pay - A1000000000 Pagamento Effettuato Con Bancomat '
            'Pay Vs Amazon'),
        'Shopping',
      );
      expect(guess('Prelievo Bancomat'), isNull);
      expect(guess('Bancomat ATM Milano'), isNull);
    });

    test('a short keyword may be followed by digits (station codes)', () {
      expect(guess('ENI80018 Cesena'), 'Transport');
      expect(guess('Eni Station'), 'Transport');
      expect(guess('Genius2000'), isNull);
    });

    test('"bar" may end a word but never start one', () {
      expect(guess('Sportbar Gargazon'), 'Dining');
      expect(guess('Bar Sport'), 'Dining');
      expect(guess('Barilla'), isNull);
      expect(guess('Barcelona Viaggi'), isNull);
    });

    test('glued merchant names the stems missed', () {
      expect(guess('OCONAD Cesena'), 'Groceries');
      expect(guess('Enimoov Ricarica'), 'Transport');
    });

    test('words that merely contain a keyword stay unguessed', () {
      expect(guess('LA SERENISSIMA'), isNull); // eni
      expect(guess('Mafaldina'), isNull); // aldi
      expect(guess('Accessori Moda'), isNull); // esso
      expect(guess('Gelato a Firenze'), isNull); // iren
      expect(guess('Acqua Firenze'), isNull); // iren
      expect(guess('Zenith'), isNull); // eni
    });

    test('income keeps its own table', () {
      expect(guess('Stipendio agosto', type: 'income'), 'Salary');
    });
  });
}
