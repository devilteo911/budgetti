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

    test('income keeps its own table', () {
      expect(guess('Stipendio agosto', type: 'income'), 'Salary');
    });
  });
}
