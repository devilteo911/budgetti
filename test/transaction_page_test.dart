import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/features/transactions/widgets/transaction_page.dart';
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:budgetti/models/account.dart';
import 'package:budgetti/models/tag.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// The write: records what it was asked to save; [fail] makes it throw as a
/// refused write does.
class _Finance extends Fake implements FinanceService {
  final saved = <Transaction>[];
  bool fail = false;

  @override
  Future<void> updateTransaction(Transaction t, {bool followUp = true}) async {
    if (fail) throw StateError('disk full');
    saved.add(t);
  }
}

/// The quick edit of a transaction: every tap saves at once, so what it
/// refuses and what fails must be said on the spot.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late _Finance finance;
  late List<Transaction> updated;

  Account wallet(String id, String name) => Account(
      id: id, name: name, balance: 0, currency: 'EUR', providerName: '');

  /// The quick edit of a transfer of 50 from Widiba to Revolut.
  Future<void> pump(WidgetTester tester) async {
    finance = _Finance();
    updated = [];
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        financeServiceProvider.overrideWithValue(finance),
        accountsProvider.overrideWith((ref) => Stream.value([
              wallet('w1', 'Widiba'),
              wallet('w2', 'Revolut'),
              wallet('w3', 'PayPal'),
            ])),
        tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
        currencyProvider.overrideWithValue(
            NumberFormat.simpleCurrency(name: 'EUR', locale: 'en_US')),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TransactionPage(
            transaction: Transaction(
              id: 't1',
              accountId: 'w1',
              toAccountId: 'w2',
              amount: 50,
              date: DateTime(2026, 6, 24),
              description: 'Ricarica',
              category: 'Transfer',
              type: 'transfer',
            ),
            onTransactionUpdated: updated.add,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Opens the destination picker and picks the wallet called [name].
  Future<void> pickDestination(WidgetTester tester, String name) async {
    await tester.tap(find.text('Revolut'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  testWidgets('another destination wallet is saved', (tester) async {
    await pump(tester);

    await pickDestination(tester, 'PayPal');

    expect([for (final t in finance.saved) t.toAccountId], ['w3']);
    expect([for (final t in updated) t.toAccountId], ['w3']);
  });

  testWidgets('the source wallet as destination is refused with a message',
      (tester) async {
    await pump(tester);

    await pickDestination(tester, 'Widiba');

    expect(find.text('Please select a different destination wallet'),
        findsOneWidget);
    expect(finance.saved, isEmpty);
    expect(updated, isEmpty);
  });

  testWidgets('a save that fails says so and changes nothing', (tester) async {
    await pump(tester);
    finance.fail = true;

    await pickDestination(tester, 'PayPal');

    expect(find.text('Error: Something went wrong. Try again.'), findsOneWidget);
    expect(updated, isEmpty);
  });
}
