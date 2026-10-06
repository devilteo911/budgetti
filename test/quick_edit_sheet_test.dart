import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/features/transactions/widgets/quick_edit_sheet.dart';
import 'package:budgetti/features/transactions/widgets/sheet_parts.dart';
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// The detail page's in-place edit of title and amount: it must never change
/// what the row *is* (expense / income / transfer), only the two values.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Transaction tx({double amount = -10, String type = 'expense'}) => Transaction(
        id: 't1',
        accountId: 'w1',
        amount: amount,
        date: DateTime(2026, 6, 24),
        description: 'PAYPAL *PAGA IN 3 RATE',
        category: 'Other',
        type: type,
      );

  /// Opens the sheet for [t]; the returned getter reads what it popped.
  Future<Transaction? Function()> open(WidgetTester tester, Transaction t) async {
    Transaction? popped;
    var done = false;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currencyProvider.overrideWithValue(
          NumberFormat.currency(locale: 'it_IT', symbol: '€'),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                popped = await showModalBottomSheet<Transaction>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => QuickEditSheet(transaction: t),
                );
                done = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () {
      expect(done, isTrue, reason: 'the sheet should have closed');
      return popped;
    };
  }

  Future<void> fill(WidgetTester tester, {String? amount, String? title}) async {
    final fields = find.byType(TextFormField); // amount first, then title
    if (amount != null) await tester.enterText(fields.at(0), amount);
    if (title != null) await tester.enterText(fields.at(1), title);
    await tester.tap(find.byType(SaveButton));
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the row\'s own values, amount unsigned', (tester) async {
    await open(tester, tx(amount: -208.8));
    final fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
    expect(fields.first.controller!.text, '208.80');
    expect(fields.last.controller!.text, 'PAYPAL *PAGA IN 3 RATE');
  });

  testWidgets('an expense stays an expense; the title is trimmed', (tester) async {
    final result = await open(tester, tx());
    await fill(tester, amount: '12,5', title: '  PayPal, 3 rate ');
    final t = result()!;
    expect(t.amount, -12.5);
    expect(t.description, 'PayPal, 3 rate');
    expect([t.type, t.category, t.accountId], ['expense', 'Other', 'w1']);
  });

  testWidgets('an income stays positive', (tester) async {
    final result = await open(tester, tx(amount: 100, type: 'income'));
    await fill(tester, amount: '-250.00');
    expect(result()!.amount, 250);
  });

  testWidgets('a transfer stays a positive transfer', (tester) async {
    final result = await open(tester, tx(amount: 40, type: 'transfer'));
    await fill(tester, amount: '55');
    expect([result()!.amount, result()!.type], [55, 'transfer']);
  });

  testWidgets('a blank title or a non-number keeps the sheet open', (tester) async {
    final result = await open(tester, tx());
    await fill(tester, title: '   ');
    expect(find.byType(QuickEditSheet), findsOneWidget);
    await fill(tester, amount: 'abc');
    expect(find.byType(QuickEditSheet), findsOneWidget);
    expect(() => result(), throwsA(isA<TestFailure>()));
  });
}
