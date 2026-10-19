import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/features/dashboard/widgets/recent_transactions_panel.dart';
import 'package:budgetti/features/stats/widgets/transaction_ledger_row.dart';
import 'package:budgetti/features/transactions/widgets/receivable_badge.dart';
import 'package:budgetti/features/transactions/widgets/transaction_ledger_item.dart';
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:budgetti/models/account.dart';
import 'package:budgetti/models/category.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// The one function that says what is owed on a shared expense, in both
/// languages. Mirror of the web's `ShareBadge` (`TxRow.tsx`): same words, same
/// half-cent thresholds.
void main() {
  // One formatter for both languages: these cases pin the words, not the locale's
  // currency layout.
  final eur = NumberFormat.simpleCurrency(name: 'EUR', locale: 'en_US');
  final en = lookupAppLocalizations(const Locale('en'));
  final it = lookupAppLocalizations(const Locale('it'));

  Receivable r(double owed, double received, double outstanding) =>
      (owed: owed, received: received, outstanding: outstanding);

  String badge(AppLocalizations l10n, Receivable x) =>
      receivableBadge(l10n, eur, x);

  group('the four states', () {
    test('still owed, nothing back yet', () {
      expect(badge(en, r(75, 0, 75)), '€75.00 to receive');
      expect(badge(it, r(75, 0, 75)), '€75.00 da ricevere');
    });

    test('still owed, something back', () {
      expect(badge(en, r(75, 25, 50)), '€75.00 to receive · €25.00 received');
      expect(
          badge(it, r(75, 25, 50)), '€75.00 da ricevere · €25.00 ricevuti');
    });

    test('settled', () {
      expect(badge(en, r(75, 75, 0)), 'settled');
      expect(badge(it, r(75, 75, 0)), 'saldata');
    });

    test('over-paid', () {
      expect(badge(en, r(75, 80, -5)), 'received €5.00 more');
      expect(badge(it, r(75, 80, -5)), 'ricevuti €5.00 in più');
    });
  });

  group('half-cent thresholds (as the web)', () {
    test('an outstanding of 0.004 either way is settled', () {
      expect(badge(en, r(75, 74.996, 0.004)), 'settled');
      expect(badge(en, r(75, 75.004, -0.004)), 'settled');
    });

    test('0.005 is still owed and -0.005 is over-paid', () {
      expect(badge(en, r(75, 74.995, 0.005)), startsWith('€75.00 to receive'));
      expect(badge(en, r(75, 75.005, -0.005)), startsWith('received'));
    });

    test('less than half a cent back does not count as received', () {
      expect(badge(en, r(75, 0.004, 74.996)), '€75.00 to receive');
    });
  });

  test('the two markers', () {
    expect(reimbursementMarker(en, true), 'pays back');
    expect(reimbursementMarker(en, false), 'pays back · expense missing');
    expect(reimbursementMarker(it, true), 'rimborso');
    expect(reimbursementMarker(it, false), 'rimborso · spesa mancante');
  });

  group('short forms (the web\'s sb-short)', () {
    String short(AppLocalizations l10n, Receivable x) =>
        receivableBadgeShort(l10n, eur, x);

    test('the three states', () {
      expect(short(en, r(75, 25, 50)), '€50.00 due');
      expect(short(it, r(75, 25, 50)), '€50.00 dovuti');
      expect(short(en, r(75, 0, 75)), '€75.00 due');
      expect(short(en, r(75, 75, 0)), 'settled');
      expect(short(it, r(75, 75, 0)), 'saldata');
      expect(short(en, r(75, 80, -5)), '+€5.00');
      expect(short(it, r(75, 80, -5)), '+€5.00');
    });

    test('the same half-cent thresholds as the full form', () {
      expect(short(en, r(75, 74.996, 0.004)), 'settled');
      expect(short(en, r(75, 75.004, -0.004)), 'settled');
      expect(short(en, r(75, 74.995, 0.005)), endsWith('due'));
      expect(short(en, r(75, 75.005, -0.005)), startsWith('+'));
    });

    test('the two markers', () {
      expect(reimbursementMarkerShort(en, true), '↩ pays back');
      expect(reimbursementMarkerShort(en, false), '↩ missing');
      expect(reimbursementMarkerShort(it, true), '↩ rimborso');
      expect(reimbursementMarkerShort(it, false), '↩ mancante');
    });
  });

  group('on a ledger row', () {
    setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

    final dinner = Transaction(
      id: 'dinner',
      accountId: 'w1',
      amount: -100,
      date: DateTime(2026, 6, 24),
      description: 'Dinner',
      category: 'Eating out',
      othersShare: 75,
    );
    Transaction income({String? reimbursesId}) => Transaction(
          id: 'paid',
          accountId: 'w1',
          amount: 25,
          date: DateTime(2026, 6, 25),
          description: 'Anna',
          category: 'Other',
          type: 'income',
          reimbursesId: reimbursesId,
        );
    const full = '€75.00 to receive · €25.00 received';

    /// Tests draw text in the Ahem font (every glyph a full em wide), so a row
    /// that fits on a phone needs a far wider screen here: 1000 for "room to
    /// spare", 320 for "tight".
    Future<void> pumpIn(
      WidgetTester tester,
      Widget child,
      Map<String, Receivable> byId, {
      required double width,
    }) async {
      tester.view.physicalSize = Size(width, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currencyProvider.overrideWithValue(eur),
          categoriesProvider.overrideWith((ref) => Stream.value(<Category>[])),
          accountsProvider.overrideWith((ref) => Stream.value(<Account>[])),
          receivablesProvider.overrideWithValue(AsyncData(byId)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ));
      await tester.pump();
    }

    Future<void> pumpRow(
      WidgetTester tester,
      Transaction t,
      Map<String, Receivable> byId, {
      required double width,
    }) =>
        pumpIn(tester, TransactionLedgerItem(transaction: t), byId,
            width: width);

    /// What a screen reader gets for the row's tag. The handle is released here,
    /// not in an `addTearDown`: the test's leak check runs before those.
    Future<String> spoken(WidgetTester tester) async {
      final handle = tester.ensureSemantics();
      await tester.pump();
      final label = tester.getSemantics(find.byType(ShareTagLine)).label;
      handle.dispose();
      return label;
    }

    Future<void> noOverflowAt64(WidgetTester tester) async {
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(TransactionLedgerItem)).height,
          kLedgerRowHeight);
    }

    testWidgets('the dinner reads in full when the row has room',
        (tester) async {
      await pumpRow(tester, dinner, {'dinner': r(75, 25, 50)}, width: 1000);
      expect(find.textContaining(full), findsOneWidget);
      expect(find.textContaining('due'), findsNothing);
      expect(await spoken(tester), contains(full));
      await noOverflowAt64(tester);
    });

    testWidgets('at 320 wide it falls back to the short form, with no overflow',
        (tester) async {
      await pumpRow(tester, dinner, {'dinner': r(75, 25, 50)}, width: 320);
      expect(find.textContaining('€50.00 due'), findsOneWidget);
      expect(find.textContaining(full), findsNothing);
      // The screen reader still reads the whole sentence.
      expect(await spoken(tester), contains(full));
      await noOverflowAt64(tester);
    });

    testWidgets('a reimbursement whose expense is absent says so',
        (tester) async {
      final paid = income(reimbursesId: 'gone');
      await pumpRow(tester, paid, {}, width: 1000);
      expect(find.textContaining('pays back · expense missing'),
          findsOneWidget);
      await noOverflowAt64(tester);

      await pumpRow(tester, paid, {}, width: 320);
      expect(find.textContaining('↩ missing'), findsOneWidget);
      expect(await spoken(tester), contains('pays back · expense missing'));
      await noOverflowAt64(tester);
    });

    testWidgets('a reimbursement of a known expense reads "pays back"',
        (tester) async {
      await pumpRow(tester, income(reimbursesId: 'dinner'),
          {'dinner': r(75, 25, 50)}, width: 1000);
      expect(find.textContaining('pays back'), findsOneWidget);
      expect(find.textContaining('expense missing'), findsNothing);
    });

    testWidgets('a row without a share looks as before', (tester) async {
      await pumpRow(tester, income(), {'dinner': r(75, 25, 50)}, width: 320);
      expect(find.byType(ShareTagLine), findsNothing);
      await noOverflowAt64(tester);
    });

    testWidgets('the dashboard\'s recent rows say it on the caption line',
        (tester) async {
      final panel = RecentTransactionsPanel(
        transactions: [dinner, income(reimbursesId: 'dinner')],
      );
      final byId = {'dinner': r(75, 25, 50)};
      await pumpIn(tester, panel, byId, width: 1000);
      expect(find.textContaining(full), findsOneWidget);
      expect(find.textContaining('pays back'), findsOneWidget);

      await pumpIn(tester, panel, byId, width: 320);
      expect(find.textContaining('€50.00 due'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a category\'s detail list says it under the description',
        (tester) async {
      final row = TransactionLedgerRow(
        txn: dinner,
        currencyFormatter: eur,
        tagMap: const {},
      );
      await pumpIn(tester, row, {'dinner': r(75, 25, 50)}, width: 320);
      expect(find.text(full), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
