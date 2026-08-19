import 'package:budgetti/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

/// The aggregate classifier: income/expense views must agree with each other
/// (dashboard classified by `type`, stats by sign — they disagreed on
/// transfers and legacy rows) and transfers must stay out of both.
void main() {
  Transaction tx({String type = 'expense', double amount = -10}) =>
      Transaction(
        id: 'x',
        accountId: 'a',
        amount: amount,
        date: DateTime(2026, 1, 1),
        description: '',
        category: 'C',
        type: type,
      );

  test('transfers are neither income nor expense (stored positive)', () {
    final t = tx(type: 'transfer', amount: 500);
    expect(t.isIncome, isFalse);
    expect(t.isExpense, isFalse);
  });

  test('income and expense classify by sign', () {
    expect(tx(type: 'income', amount: 100).isIncome, isTrue);
    expect(tx(type: 'expense', amount: -100).isExpense, isTrue);
    expect(tx(type: 'income', amount: 100).isExpense, isFalse);
    expect(tx(type: 'expense', amount: -100).isIncome, isFalse);
  });

  test('legacy row whose type disagrees with its sign classifies by sign', () {
    // fromJson infers type from sign only when absent — old/imported rows
    // can disagree, and both classification styles must land on one answer.
    expect(tx(type: 'income', amount: -5).isExpense, isTrue);
    expect(tx(type: 'expense', amount: 5).isIncome, isTrue);
  });

  test('zero-amount rows are neither', () {
    final t = tx(amount: 0);
    expect(t.isIncome, isFalse);
    expect(t.isExpense, isFalse);
  });
}
