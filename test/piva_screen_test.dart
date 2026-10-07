import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/features/piva/piva_deadlines_section.dart';
import 'package:budgetti/features/piva/piva_format.dart';
import 'package:budgetti/features/piva/piva_income_section.dart' show PivaLine;
import 'package:budgetti/features/piva/piva_profile_sheet.dart';
import 'package:budgetti/features/piva/piva_screen.dart';
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:budgetti/l10n/app_localizations_en.dart';
import 'package:budgetti/l10n/app_localizations_it.dart';
import 'package:budgetti/models/category.dart';
import 'package:budgetti/models/piva.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// The Partita IVA screen: what it shows for a profile, for none, and for a year
/// with no income; the stepper's ends; the narrow phone; both languages. Made-up
/// profiles and ledger only. All the income is in the current year, so the
/// deductible contributions of the estimate are 0 (they come from the year
/// before) and the figures below are derived by hand: 10,000 of compensi at
/// coefficient 67 → gross 6,700 → tax 15% = 1,005.00, Gestione Separata 26.07%
/// = 1,746.69 → net 7,248.31.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final year = DateTime.now().year;
  final en = AppLocalizationsEn();

  PivaProfileData profile({
    String fundType = 'gestione_separata',
    int? startYear,
    double integrativeRate = 0,
    List<String> categories = const ['Freelance'],
  }) =>
      PivaProfileData(
        atecoCode: '62.01',
        coefficient: 67.0,
        startYear: startYear ?? year - 1,
        startupRate: false,
        fundType: fundType,
        fundName: '',
        subjectiveRate: fundType == 'cassa' ? 10 : 0,
        integrativeRate: integrativeRate,
        minSubjective: fundType == 'cassa' ? 100 : 0,
        minIntegrative: fundType == 'cassa' ? 50 : 0,
        inpsReduction: false,
        incomeCategories: categories,
      );

  Transaction income(double amount) => Transaction(
        id: 'invoice',
        accountId: 'a',
        amount: amount,
        date: DateTime(year, 6, 15, 12),
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

  /// Tall by default so the lazy list builds every section; the narrow-phone
  /// tests pass 320×640 and scroll instead.
  Future<void> pump(
    WidgetTester tester, {
    PivaProfileData? profile,
    List<Transaction> txns = const [],
    Locale locale = const Locale('en'),
    Size size = const Size(390, 3000),
    double textScale = 1,
    bool openDeadlines = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        pivaProfileProvider.overrideWith((ref) => Stream.value(profile)),
        pivaPaymentsProvider.overrideWith((ref) => Stream.value(const <PivaPaymentData>[])),
        pivaTransactionsProvider.overrideWith((ref) => Stream.value(txns)),
        // What the profile sheet reads when the screen opens it.
        categoriesProvider.overrideWith((ref) => Stream.value(const <Category>[])),
        currencyProvider.overrideWithValue(
            NumberFormat.simpleCurrency(locale: 'en_US', name: 'EUR')),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: PivaScreen(openDeadlines: openDeadlines),
      ),
    ));
    // The streams emit on the next frames, and the sections are built — and ask
    // for their fonts — only then. A font request nobody waits for stays pending
    // in google_fonts' static list, and the next test's wait on it never returns.
    await tester.pump();
    await tester.pump();
    await settle(tester);
  }

  IconButton arrow(WidgetTester tester, String tooltip) => tester.widget<IconButton>(
      find.ancestor(of: find.byTooltip(tooltip), matching: find.byType(IconButton)));

  test('pivaNumber prints the shortest form', () {
    expect(pivaNumber(67.0), '67');
    expect(pivaNumber(5.000000000000001), '5');
    Intl.defaultLocale = 'it';
    addTearDown(() => Intl.defaultLocale = null);
    expect(pivaNumber(26.07), '26,07');
  });

  testWidgets('no profile: the empty state, and the button that sets it up', (tester) async {
    await pump(tester);

    expect(find.text('NO PROFILE'), findsOneWidget);
    expect(find.text(en.pivaEmptyHint), findsOneWidget);
    expect(en.pivaEmptyHint.split('. ').length, 1, reason: 'one sentence');
    expect(find.widgetWithText(OutlinedButton, en.pivaProfileSetUp), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
  });

  testWidgets('the setup button opens the profile sheet, empty', (tester) async {
    await pump(tester);

    await tester.tap(find.text(en.pivaProfileSetUp));
    await settle(tester);

    expect(find.byType(PivaProfileSheet), findsOneWidget);
    expect(tester.widget<PivaProfileSheet>(find.byType(PivaProfileSheet)).existing, isNull);
  });

  testWidgets('the edit action opens the sheet on the profile shown', (tester) async {
    await pump(tester, profile: profile());

    await tester.tap(find.byTooltip(en.pivaProfileEdit));
    await settle(tester);

    final sheet = tester.widget<PivaProfileSheet>(find.byType(PivaProfileSheet));
    expect(sheet.existing?.atecoCode, '62.01');
    expect(sheet.existing?.coefficient, 67.0);
  });

  testWidgets('gestione separata: the estimate to the cent, and no integrativo line',
      (tester) async {
    await pump(tester, profile: profile(), txns: [income(10000)]);

    // 390 wide: the title does not fit on one line, so it is two lines.
    expect(find.text('ATECO 62.01'), findsOneWidget);
    expect(find.text('coefficiente 67%'), findsOneWidget);
    expect(find.text('Imponibile'), findsOneWidget);
    expect(find.text('Imposta sostitutiva · 15%'), findsOneWidget);
    expect(find.text('Contributi · Gestione Separata INPS'), findsOneWidget);
    expect(find.text('€7,248.31'), findsOneWidget);
    expect(find.text(en.pivaReconIntegrativo), findsNothing);
    // The tiles: the year is new (nothing the year before), the best month is June.
    expect(find.text('${en.pivaNew} ${en.pivaVsYear('${year - 1}')}'), findsOneWidget);
    expect(find.text(DateFormat('MMMM yyyy').format(DateTime(year, 6))), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets('a cassa with an integrativo: the line is there twice, once as '
      'reconciliation and once in the estimate', (tester) async {
    await pump(
      tester,
      profile: profile(fundType: 'cassa', integrativeRate: 4),
      txns: [income(10400)],
    );

    expect(find.text(en.pivaReconIntegrativo), findsNWidgets(2));
    expect(find.text(en.pivaPassThroughNote), findsOneWidget);
    expect(find.text(en.pivaReconBank), findsOneWidget);
    expect(find.text('€10,400.00'), findsOneWidget); // the bank amount
    // The integrativo to remit. Under PivaLine: the deadlines below can hold an
    // estimated row of the same amount, depending on the day the test runs.
    expect(find.descendant(of: find.byType(PivaLine), matching: find.text('€400.00')), findsNWidgets(2));
  });

  testWidgets('the profile title is one line when it fits', (tester) async {
    await pump(tester, profile: profile(), size: const Size(1200, 3000));

    expect(find.text('ATECO 62.01 · coefficiente 67%'), findsOneWidget);
    expect(find.text('ATECO 62.01'), findsNothing);
  });

  testWidgets('the profile title is two lines without the dot when it does not', (tester) async {
    await pump(tester, profile: profile(), size: const Size(320, 3000));

    expect(find.text('ATECO 62.01'), findsOneWidget);
    expect(find.text('coefficiente 67%'), findsOneWidget);
    expect(find.textContaining('ATECO 62.01 ·'), findsNothing);
  });

  for (final (locale, l10n) in [
    (const Locale('it'), AppLocalizationsIt()),
    (const Locale('en'), AppLocalizationsEn()),
  ]) {
    testWidgets('$locale: the row labels of both boxes are in sentence case', (tester) async {
      await pump(
        tester,
        profile: profile(fundType: 'cassa', integrativeRate: 4),
        txns: [income(10400)],
        locale: locale,
      );

      for (final label in [pivaCompensi, l10n.pivaReconIntegrativo, l10n.pivaReconBank]) {
        expect(label[0], label[0].toUpperCase(), reason: label);
        expect(find.text(label), findsWidgets, reason: label);
      }
      // The note under the pass-through row is a note: it stays lowercase.
      expect(l10n.pivaPassThroughNote[0], l10n.pivaPassThroughNote[0].toLowerCase());
    });
  }

  testWidgets('a year with no income says so, and the tiles stay', (tester) async {
    await pump(tester, profile: profile());

    expect(find.text(en.pivaNoIncome('$year')), findsOneWidget);
    expect(find.text(en.pivaNoIncomeHint('Freelance')), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
    expect(find.text('PAYMENTS COUNTED'), findsOneWidget);
    expect(find.text('Imponibile'), findsOneWidget);
  });

  testWidgets('a profile with no categories asks for them', (tester) async {
    await pump(tester, profile: profile(categories: const []));

    expect(find.text(en.pivaNoIncomeNoCategories), findsOneWidget);
  });

  testWidgets('the year stepper stops at the opening year and at the current one',
      (tester) async {
    await pump(tester, profile: profile(startYear: year - 1));

    expect(arrow(tester, en.pivaNextYear).onPressed, isNull);
    expect(arrow(tester, en.pivaPrevYear).onPressed, isNotNull);

    await tester.tap(find.byTooltip(en.pivaPrevYear));
    await tester.pumpAndSettle();

    expect(find.text('${year - 1}'), findsOneWidget);
    expect(arrow(tester, en.pivaPrevYear).onPressed, isNull);
    expect(arrow(tester, en.pivaNextYear).onPressed, isNotNull);
  });

  testWidgets('an opening year in the future leaves only the current year',
      (tester) async {
    await pump(tester, profile: profile(startYear: year + 2));

    expect(arrow(tester, en.pivaNextYear).onPressed, isNull);
    expect(arrow(tester, en.pivaPrevYear).onPressed, isNull);
  });

  testWidgets('a screen reader reads each estimate row as label and amount, and the '
      'chart as one sentence', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, profile: profile(), txns: [income(10000)]);

    final row = tester.getSemantics(find.text('Imponibile')).label;
    expect(row, contains('Imponibile'));
    expect(row, contains('€6,700.00'));
    expect(tester.getSemantics(find.byType(BarChart)).label,
        en.pivaChartSemantics('$year', '€10,000.00', '${year - 1}'));
    handle.dispose();
  });

  for (final scale in [1.0, 1.5]) {
    testWidgets('320 × 640 at text scale $scale: nothing overflows', (tester) async {
      await pump(
        tester,
        profile: profile(fundType: 'cassa', integrativeRate: 4),
        txns: [income(10400)],
        size: const Size(320, 640),
        textScale: scale,
      );
      // The list is lazy: scroll to the foot so every section has been laid out.
      await tester.scrollUntilVisible(find.text(en.pivaEstimateFoot), 300);
      await settle(tester);
      // ...and the deadlines below it, tiles and rows.
      await tester.scrollUntilVisible(find.byType(PivaDeadlinesSection), 300);
      await settle(tester);

      expect(tester.takeException(), isNull);
    });
  }

  /// How far the screen's list is scrolled: the first Scrollable under the app bar.
  double scrolled(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;

  // A short phone: the deadlines sit below the prospetto, outside the viewport
  // (and outside the lazy list's cache), so the scroll has to build them first.
  const shortPhone = Size(390, 600);

  testWidgets('opened on the deadlines: they are scrolled into view', (tester) async {
    await pump(
      tester,
      profile: profile(),
      txns: [income(10000)],
      size: shortPhone,
      openDeadlines: true,
    );

    expect(scrolled(tester), greaterThan(0));
    final top = tester.getTopLeft(find.byType(PivaDeadlinesSection)).dy;
    expect(top, greaterThanOrEqualTo(0));
    expect(top, lessThan(shortPhone.height));
    expect(tester.takeException(), isNull);
  });

  testWidgets('not asked to open the deadlines: the screen stays at the top', (tester) async {
    await pump(tester, profile: profile(), txns: [income(10000)], size: shortPhone);

    expect(scrolled(tester), 0);
    expect(find.byType(PivaDeadlinesSection).hitTestable(), findsNothing);
  });

  for (final (locale, net) in [(const Locale('it'), 'Netto'), (const Locale('en'), 'Net')]) {
    testWidgets('$locale: the net is "$net", the fiscal terms do not translate',
        (tester) async {
      await pump(tester, profile: profile(), txns: [income(10000)], locale: locale);

      expect(find.text(net), findsOneWidget);
      // The whole label: the deadlines below name the same tax ("Imposta
      // sostitutiva · Saldo …").
      expect(find.text('Imposta sostitutiva · 15%'), findsOneWidget);
    });
  }
}
