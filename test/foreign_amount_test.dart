import 'package:budgetti/core/services/bank_draft.dart';
import 'package:budgetti/core/services/revolut_notification_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// A draft has no currency of its own — its amount is euros by convention — so a
/// non-euro push carries its original amount in the description, " · 12,50 USD".
/// One pair of functions writes and reads that suffix, so the parser and the
/// inbox cannot drift apart.
void main() {
  group('withForeignAmount / foreignAmountOf', () {
    test('round-trip', () {
      final d = withForeignAmount('Starbucks', '12,50', 'USD');

      expect(d, 'Starbucks · 12,50 USD');
      expect(foreignAmountOf(d), (amount: '12,50', currency: 'USD'));
    });

    test('a whole amount, another currency, the fallback description', () {
      expect(foreignAmountOf(withForeignAmount('Movimento Revolut', '4', 'GBP')),
          (amount: '4', currency: 'GBP'));
      expect(foreignAmountOf('Movimento Revolut · 4.20 USD'),
          (amount: '4.20', currency: 'USD'));
      expect(foreignAmountOf('IKEA · 1.234,56 GBP'),
          (amount: '1.234,56', currency: 'GBP'));
    });

    test('a euro description has none', () {
      expect(foreignAmountOf('Lo Chef'), isNull);
      expect(foreignAmountOf(''), isNull);
    });

    test('a merchant name that itself contains " · " is read from the end', () {
      final d = withForeignAmount('Bar · Sport', '12,50', 'USD');

      expect(d, 'Bar · Sport · 12,50 USD');
      expect(foreignAmountOf(d), (amount: '12,50', currency: 'USD'));
      expect(foreignAmountOf('Bar · Sport'), isNull);
    });

    test('an amount and currency that are not a suffix are not one', () {
      expect(foreignAmountOf('Pizza 12,50 USD'), isNull); // no " · "
      expect(foreignAmountOf('Shop · 12,50 USD extra'), isNull); // not at the end
      expect(foreignAmountOf('Shop · USD 12,50'), isNull);
      expect(foreignAmountOf('Shop · 12,50 EUR'), isNull); // euros are the default
    });
  });

  group('the parser writes what the inbox reads', () {
    const parser = RevolutNotificationParser();
    ParsedBankDraft? run(String text) =>
        parser.parse(title: 'Revolut', text: text, when: DateTime.utc(2026, 7, 30));

    test('a dollar push', () {
      final r = run('Hai speso 12,50 USD presso Starbucks ZZ')!;

      expect(foreignAmountOf(r.description), (amount: '12,50', currency: 'USD'));
      expect(r.counterparty, 'Starbucks Zz');
    });

    test('a pound push, symbol first', () {
      expect(foreignAmountOf(run('You received £20.00 from Jane')!.description),
          (amount: '20.00', currency: 'GBP'));
    });

    test('a euro push has none', () {
      expect(foreignAmountOf(run('Hai speso 12,50 € presso Starbucks')!.description),
          isNull);
      expect(foreignAmountOf(run('€4.20')!.description), isNull);
    });
  });
}
