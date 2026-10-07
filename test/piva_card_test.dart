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
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final year = DateTime.now().year;
  final en = AppLocalizationsEn();

  final profile = PivaProfileData(
    atecoCode: '62.01',
    coefficient: 67.0,
    startYear: year - 1,
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
    Size size = const Size(390, 800),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [PivaCard()],
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
        pivaPaymentsProvider
            .overrideWith((ref) => Stream.value(const <PivaPaymentData>[])),
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
}
