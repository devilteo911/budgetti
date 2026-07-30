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
}
