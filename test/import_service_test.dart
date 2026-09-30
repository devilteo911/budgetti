import 'package:budgetti/core/services/import_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// One QIF record: date, amount, payee, end marker.
List<String> _record(String amount, {String payee = 'Conad'}) =>
    ['D20/08/2026', 'T$amount', 'P$payee', '^'];

void main() {
  final service = ImportService();

  test('a comma decimal is money, not thousands', () {
    // '12,50' used to lose its comma and become 1250.
    final t = service.parseQif(['!Type:Bank', ..._record('-12,50')]).single;
    expect(t.amount, -12.5);
  });

  test('dot decimals and both thousands styles read right', () {
    final amounts = service
        .parseQif([
          ..._record('-7.25'),
          ..._record('1.234,56'),
          ..._record('-1,234.50'),
        ])
        .map((t) => t.amount);
    expect(amounts, [-7.25, 1234.56, -1234.5]);
  });

  test('the sign decides expense or income', () {
    // Every imported row used to default to "expense", so money in was booked
    // as a negative-type row with a positive amount.
    final types = service
        .parseQif([..._record('-10,00'), ..._record('2.500,00')])
        .map((t) => t.type);
    expect(types, ['expense', 'income']);
  });

  test('a record without a readable amount is skipped', () {
    expect(service.parseQif(_record('abc')), isEmpty);
  });

  test('payee and category come through', () {
    final t = service.parseQif([
      'D20/08/2026',
      'T-3,00',
      'PBar Sport',
      'LDining',
      '^',
    ]).single;
    expect(t.description, 'Bar Sport');
    expect(t.category, 'Dining');
    expect(t.date, DateTime(2026, 8, 20));
  });
}
