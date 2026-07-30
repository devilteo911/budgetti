import 'package:budgetti/models/installment.dart';
import 'package:flutter_test/flutter_test.dart';

Installment plan({
  double total = 1200,
  int count = 12,
  required DateTime start,
}) =>
    Installment(
      id: 'p1',
      userId: 'u',
      description: 'Divano',
      totalAmount: total,
      installmentCount: count,
      startDate: start,
    );

void main() {
  group('Installment derivation', () {
    test('rate amount splits the total', () {
      expect(plan(start: DateTime(2026, 1, 10)).amountPerInstallment, 100);
    });

    test('nothing paid before the first due date', () {
      final p = plan(start: DateTime(2026, 8, 10));
      final now = DateTime(2026, 7, 30);
      expect(p.paidCount(now), 0);
      expect(p.remainingAmount(now), 1200);
      expect(p.nextDueDate(now), DateTime(2026, 8, 10));
      expect(p.isActive(now), isTrue);
    });

    test('the current month counts only from its due day', () {
      final p = plan(start: DateTime(2026, 1, 15));
      expect(p.paidCount(DateTime(2026, 7, 14)), 6); // Jan..Jun
      expect(p.paidCount(DateTime(2026, 7, 15)), 7); // July's rate charged
      expect(p.nextDueDate(DateTime(2026, 7, 15)), DateTime(2026, 8, 15));
    });

    test('a settled plan is inactive and has no next due date', () {
      final p = plan(start: DateTime(2025, 1, 10));
      final now = DateTime(2026, 7, 30);
      expect(p.paidCount(now), 12); // clamped, not 18
      expect(p.remainingCount(now), 0);
      expect(p.remainingAmount(now), 0);
      expect(p.isActive(now), isFalse);
      expect(p.nextDueDate(now), isNull);
      expect(p.progress(now), 1.0);
    });

    test('a day-31 plan lands on the last day of short months', () {
      final p = plan(start: DateTime(2026, 1, 31), count: 3);
      // Feb has 28 days in 2026 → the February rate is due on the 28th.
      expect(p.paidCount(DateTime(2026, 2, 27)), 1);
      expect(p.paidCount(DateTime(2026, 2, 28)), 2);
      expect(p.nextDueDate(DateTime(2026, 2, 28)), DateTime(2026, 3, 31));
      expect(p.endDate, DateTime(2026, 3, 31));
    });

    test('a 0-rate row degrades instead of dividing by zero', () {
      final p = plan(start: DateTime(2026, 1, 1), count: 0);
      expect(p.amountPerInstallment, 0);
      expect(p.paidCount(DateTime(2026, 7, 30)), 0);
      expect(p.progress(DateTime(2026, 7, 30)), 0);
    });
  });
}
