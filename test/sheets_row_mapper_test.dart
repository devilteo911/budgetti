import 'package:budgetti/core/services/sheets_row_mapper.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Sheets export's debit/credit column. It was read off the stored `type`,
/// so a positive row booked as 'expense' (the pre-fix QIF import) went out as
/// a debit and a negative one typed 'income' as a credit. The sign decides,
/// like everywhere else (`Transaction.isIncome` / `isExpense`).
void main() {
  Transaction tx(double amount, String type, {String? toAccountId}) =>
      Transaction(
        id: 'x',
        accountId: 'a1',
        toAccountId: toAccountId,
        amount: amount,
        date: DateTime(2026, 8, 1),
        description: 'thing',
        category: 'Food',
        type: type,
      );

  String transizione(Transaction t) =>
      SheetsRowMapper.transactionToSheetRows(t, {'a1': 'Widiba', 'a2': 'Revolut'})
          .single[3]
          .toString();

  test('a negative amount exports as debit, a positive one as credit', () {
    expect(transizione(tx(-12.5, 'expense')), 'debit');
    expect(transizione(tx(100, 'income')), 'credit');
  });

  test('a positive row booked as expense exports as credit', () {
    expect(transizione(tx(11.95, 'expense')), 'credit');
  });

  test('a negative row typed income exports as debit', () {
    expect(transizione(tx(-5, 'income')), 'debit');
  });

  test('a transfer still exports as two legs with no debit/credit', () {
    final rows = SheetsRowMapper.transactionToSheetRows(
      tx(500, 'transfer', toAccountId: 'a2'),
      {'a1': 'Widiba', 'a2': 'Revolut'},
    );
    expect(rows, hasLength(2));
    expect(rows.map((r) => r[3]), everyElement(''));
  });
}
