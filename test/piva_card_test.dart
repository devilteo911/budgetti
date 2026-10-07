import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/features/dashboard/widgets/piva_card.dart';
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:budgetti/l10n/app_localizations_en.dart';
import 'package:budgetti/models/piva.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// The dashboard's Partita IVA card: absent without a profile, this year's
/// figures with one — whatever year the screen has picked — and no overflow on a
/// narrow phone. Made-up profile and ledger only. The figures are the ones of
/// `piva_screen_test.dart`: 10,000 of compensi at coefficient 67 → gross 6,700 →
/// tax 15% = 1,005.00, Gestione Separata 26.07% = 1,746.69 → net 7,248.31.
///
/// The "next deadline" line has its own group at the end, on a fixed day (the
/// card takes `now`) so that the calendar does not move with the clock.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final year = DateTime.now().year;
  final en = AppLocalizationsEn();

  PivaProfileData profileOf(int startYear) => PivaProfileData(
        atecoCode: '62.01',
        coefficient: 67.0,
        startYear: startYear,
        startupRate: false,
        fundType: 'gestione_separata',
        fundName: '',
        subjectiveRate: 0,
        integrativeRate: 0,
        minSubjective: 0,
        minIntegrative: 0,
        inpsReduction: false,
        incomeCategories: const ['Freelance'],
      );
  final profile = profileOf(year - 1);

  Transaction income(double amount, {int? inYear, String id = 'invoice'}) => Transaction(
        id: id,
        accountId: 'a',
        amount: amount,
        date: DateTime(inYear ?? year, 6, 15, 12),
        description: 'Invoice',
        category: 'Freelance',
        type: 'income',
      );

  /// Waits for every font asked for so far, then for the frames that follow.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(GoogleFonts.pendingFonts);
    await tester.pumpAndSettle();
    await tester.runAsync(GoogleFonts.pendingFonts);
  }

  /// The card in a column like the dashboard's, with a stub for `/piva`.
  Future<void> pump(
    WidgetTester tester, {
    PivaProfileData? profile,
    List<Transaction> txns = const [],
    List<PivaPaymentData> payments = const [],
    DateTime? now,
    Size size = const Size(390, 800),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [PivaCard(now: now)],
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/piva',
        builder: (context, state) => const Scaffold(body: Text('piva route')),
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        pivaProfileProvider.overrideWith((ref) => Stream.value(profile)),
        pivaPaymentsProvider.overrideWith((ref) => Stream.value(payments)),
        pivaTransactionsProvider.overrideWith((ref) => Stream.value(txns)),
        currencyProvider.overrideWithValue(
            NumberFormat.simpleCurrency(locale: 'en_US', name: 'EUR')),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ));
    // The streams emit on the next frames, and the card asks for its fonts only
    // then; a font request nobody waits for would hang the next test's wait.
    await tester.pump();
    await tester.pump();
    await settle(tester);
  }

  testWidgets('no profile: the card is 0 high and holds no text', (tester) async {
    await pump(tester);

    expect(tester.getSize(find.byType(PivaCard)).height, 0);
    expect(find.descendant(of: find.byType(PivaCard), matching: find.byType(Text)),
        findsNothing);
  });

  testWidgets('a profile: this year\'s compensi, net, tax and contributions',
      (tester) async {
    await pump(tester, profile: profile, txns: [income(10000)]);

    expect(find.text('COMPENSI $year'), findsOneWidget);
    expect(find.text('€10,000.00'), findsOneWidget);
    expect(find.text(en.pivaCardNet('€7,248.31')), findsOneWidget);
    expect(find.text(en.pivaCardSetAside.toUpperCase()), findsOneWidget);
    expect(find.text('IMPOSTA'), findsOneWidget);
    expect(find.text('€1,005.00'), findsOneWidget);
    expect(find.text('CONTRIBUTI'), findsOneWidget);
    expect(find.text('€1,746.69'), findsOneWidget);
  });

  testWidgets('the card stays on the current year when the screen picks another',
      (tester) async {
    await pump(
      tester,
      profile: profile,
      txns: [income(10000), income(3000, inYear: year - 1, id: 'last-year')],
    );

    final container = ProviderScope.containerOf(tester.element(find.byType(PivaCard)));
    container.read(pivaYearProvider.notifier).set(year - 1);
    await settle(tester);

    expect(container.read(pivaYearProvider), year - 1);
    expect(find.text('COMPENSI $year'), findsOneWidget);
    expect(find.text('€10,000.00'), findsOneWidget);
    expect(find.text('COMPENSI ${year - 1}'), findsNothing);
    expect(find.text('€3,000.00'), findsNothing);
  });

  testWidgets('a tap opens /piva', (tester) async {
    await pump(tester, profile: profile, txns: [income(10000)]);

    await tester.tap(find.byType(PivaCard));
    await tester.pumpAndSettle();

    expect(find.text('piva route'), findsOneWidget);
  });

  for (final scale in [1.0, 1.5]) {
    testWidgets('320 wide at text scale $scale: nothing overflows', (tester) async {
      await pump(
        tester,
        profile: profile,
        txns: [income(12345.67)],
        size: const Size(320, 640),
        textScale: scale,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('€12,345.67'), findsOneWidget);
    });
  }

  group('next deadline', () {
    // A profile opened in 2025 with 10,000 of compensi in 2025 (tax 1,005.00, as
    // above): from the 10th of March 2026 the first deadline of the calendar is
    // the saldo of the 2025 imposta sostitutiva, 30 June (a Tuesday), still an
    // estimate. The tax rows come before the contributions of the same day.
    final today = DateTime(2026, 3, 10);
    final opened = profileOf(2025);
    final lastYear = [income(10000, inYear: 2025)];
    const estimateLabel = 'Imposta sostitutiva · Saldo 2025';
    const estimateWhen = 'Jun 30, 2026 · €1,005.00';

    /// A row the accountant gave an amount for, added by hand (empty `key`).
    PivaPaymentData official(String label, DateTime? due, double amount, {DateTime? paid}) =>
        PivaPaymentData(
          id: label,
          key: '',
          kind: 'imposta',
          label: label,
          dueDate: due,
          amount: amount,
          paidDate: paid,
          note: '',
        );

    /// The card is there (its compensi) and the line is not.
    void expectNoLine(WidgetTester tester) {
      expect(tester.takeException(), isNull);
      expect(find.text('COMPENSI 2026'), findsOneWidget);
      expect(find.text('Next deadline'), findsNothing);
    }

    testWidgets('an estimate ahead: kicker, label, day, amount and the estimate tag',
        (tester) async {
      await pump(tester, profile: opened, txns: lastYear, now: today);

      expect(find.text('Next deadline'), findsOneWidget);
      expect(find.text(estimateLabel), findsOneWidget);
      expect(find.text(estimateWhen), findsOneWidget);
      expect(find.text('estimate'), findsOneWidget);
    });

    testWidgets('an official row ahead: the same four, no estimate tag', (tester) async {
      // The calendar still holds the estimates of 30 June: the official row is
      // simply the nearer one.
      await pump(
        tester,
        profile: opened,
        txns: lastYear,
        payments: [official('Rottamazione', DateTime(2026, 4, 20, 12), 250)],
        now: today,
      );

      expect(find.text('Next deadline'), findsOneWidget);
      expect(find.text('Rottamazione'), findsOneWidget);
      expect(find.text('Apr 20, 2026 · €250.00'), findsOneWidget);
      expect(find.text('estimate'), findsNothing);
      expect(find.text(estimateLabel), findsNothing);
    });

    testWidgets('of two ahead, the nearer one', (tester) async {
      await pump(
        tester,
        profile: opened,
        payments: [
          official('Later one', DateTime(2026, 9, 1, 12), 100),
          official('Sooner one', DateTime(2026, 5, 10, 12), 75),
        ],
        now: today,
      );

      expect(find.text('Sooner one'), findsOneWidget);
      expect(find.text('May 10, 2026 · €75.00'), findsOneWidget);
      expect(find.textContaining('Later one'), findsNothing);
    });

    testWidgets('only past estimates nobody recorded: no line', (tester) async {
      final day = DateTime(2026, 12, 15);
      // Not vacuous: there is a calendar, and all of it is behind us.
      final rows = deadlines(opened, lastYear, const [], day);
      expect(rows, isNotEmpty);
      expect(rows.map((r) => deadlineState(r, day)), everyElement(DeadlineState.unrecorded));

      await pump(tester, profile: opened, txns: lastYear, now: day);

      expectNoLine(tester);
    });

    testWidgets('only paid rows: no line', (tester) async {
      await pump(
        tester,
        profile: opened,
        payments: [official('Bollo', DateTime(2026, 6, 30, 12), 80, paid: DateTime(2026, 3, 1, 12))],
        now: today,
      );

      expectNoLine(tester);
    });

    testWidgets('a row with no day is never the next: no line', (tester) async {
      await pump(
        tester,
        profile: opened,
        payments: [official('Senza data', null, 120)],
        now: today,
      );

      expectNoLine(tester);
    });

    testWidgets('a profile without income: no line', (tester) async {
      await pump(tester, profile: opened, now: today);

      expectNoLine(tester);
    });

    testWidgets('no line: the card is its summary row and nothing around it',
        (tester) async {
      await pump(tester, profile: opened, now: today);

      final box = tester.widget<Container>(
        find.descendant(of: find.byType(PivaCard), matching: find.byType(Container)).first,
      );
      expect(box.child, isA<Row>());
      // The padding of the card (14 above, 16 below) and the 1 of border below.
      final row = tester.getSize(
        find.descendant(of: find.byType(PivaCard), matching: find.byType(Row)).first,
      );
      expect(tester.getSize(find.byType(PivaCard)).height, closeTo(row.height + 14 + 16 + 1, 0.01));
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('320 wide at text scale $scale: the line and its tag stay inside',
          (tester) async {
        await pump(
          tester,
          profile: opened,
          txns: lastYear,
          now: today,
          size: const Size(320, 640),
          textScale: scale,
        );

        expect(tester.takeException(), isNull);
        expect(tester.getRect(find.text(estimateLabel)).right, lessThanOrEqualTo(320));
        expect(tester.getRect(find.text(estimateWhen)).right, lessThanOrEqualTo(320));
        expect(tester.getRect(find.text('estimate')).right, lessThanOrEqualTo(320));
      });
    }

    testWidgets('a long label is cut with dots at 320 wide and text scale 2', (tester) async {
      const label = 'Rottamazione quinquies · rata straordinaria di saldo e stralcio delle cartelle';
      await pump(
        tester,
        profile: opened,
        payments: [official(label, DateTime(2026, 4, 20, 12), 1234.5)],
        now: today,
        size: const Size(320, 640),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.text(label)).right, lessThanOrEqualTo(320));
      // The day and the amount are never what gets cut, and sit whole in the card.
      expect(tester.getRect(find.text('Apr 20, 2026 · €1,234.50')).right, lessThanOrEqualTo(320));
      final text = tester.widget<Text>(find.text(label));
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });
}
