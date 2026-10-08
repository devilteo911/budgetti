import 'dart:async' show Completer, StreamController;
import 'dart:ffi' show DynamicLibrary;

import 'package:budgetti/core/database/database.dart' show AppDatabase;
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/features/piva/piva_deadlines_section.dart';
import 'package:budgetti/features/piva/piva_format.dart';
import 'package:budgetti/features/piva/piva_income_section.dart' show PivaLine, PivaTile;
import 'package:budgetti/features/piva/piva_profile_sheet.dart';
import 'package:budgetti/features/piva/piva_screen.dart';
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:budgetti/l10n/app_localizations_en.dart';
import 'package:budgetti/l10n/app_localizations_it.dart';
import 'package:budgetti/models/category.dart';
import 'package:budgetti/models/piva.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:drift/native.dart' show NativeDatabase;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sqlite3/open.dart' as sqlite3open;

// See finance_service_seed_test.dart for why the FFI loader is overridden.
void _ensureSqlite() {
  try {
    sqlite3open.open.overrideFor(
      sqlite3open.OperatingSystem.linux,
      () => DynamicLibrary.open('/lib/x86_64-linux-gnu/libsqlite3.so.0'),
    );
  } catch (_) {
    // Already overridden or not on Linux — ignore.
  }
}

/// The real service over an in-memory database that only records the profile
/// writes the banner asks for (it never reaches the table). [fail] makes them
/// throw, as a full disk would; [gate] holds each one until it completes, so a
/// write can be in flight while the test acts.
class _Finance extends FinanceService {
  _Finance(super.db, super.userId, {this.fail = false, this.gate});

  final bool fail;
  final Completer<void>? gate;
  final saved = <PivaProfileInput>[];

  @override
  Future<void> savePivaProfile(PivaProfileInput input) async {
    saved.add(input);
    await gate?.future;
    if (fail) throw StateError('disk full');
  }
}

/// The Partita IVA screen: what it shows for a profile, for none, and for a year
/// with no income; the stepper's ends; the narrow phone; both languages; the
/// banner that asks for last year's income when the ledger does not cover it.
/// Made-up profiles and ledger only. All the income is in the current year, so
/// the deductible contributions of the estimate are 0 (they come from the year
/// before) and the figures below are derived by hand: 10,000 of compensi at
/// coefficient 67 → gross 6,700 → tax 15% = 1,005.00, Gestione Separata 26.07%
/// = 1,746.69 → net 7,248.31.
void main() {
  setUpAll(() {
    _ensureSqlite();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final year = DateTime.now().year;
  final en = AppLocalizationsEn();
  final money = NumberFormat.simpleCurrency(locale: 'en_US', name: 'EUR');

  PivaProfileData profile({
    String fundType = 'gestione_separata',
    int? startYear,
    double integrativeRate = 0,
    List<String> categories = const ['Freelance'],
    Map<String, double?> declaredIncome = const {},
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
        declaredIncome: declaredIncome,
      );

  Transaction income(double amount, {DateTime? date}) => Transaction(
        id: 'invoice',
        accountId: 'a',
        amount: amount,
        date: date ?? DateTime(year, 6, 15, 12),
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
  /// tests pass 320×640 and scroll instead. The ledger starts two years back
  /// unless [ledgerStart] says otherwise (or [emptyLedger], or [ledger], a stream
  /// of the test's own), so last year is covered and no case sees the
  /// declared-income banner by accident. [finance] stands in for the real service.
  Future<void> pump(
    WidgetTester tester, {
    PivaProfileData? profile,
    List<Transaction> txns = const [],
    DateTime? ledgerStart,
    bool emptyLedger = false,
    Stream<DateTime?>? ledger,
    FinanceService? finance,
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
        if (finance != null) financeServiceProvider.overrideWithValue(finance),
        pivaProfileProvider.overrideWith((ref) => Stream.value(profile)),
        pivaPaymentsProvider.overrideWith((ref) => Stream.value(const <PivaPaymentData>[])),
        pivaTransactionsProvider.overrideWith((ref) => Stream.value(txns)),
        pivaLedgerStartProvider.overrideWith((ref) =>
            ledger ?? Stream.value(emptyLedger ? null : ledgerStart ?? DateTime(year - 2, 6, 1, 12))),
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

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('320 × 640 at text scale $scale: nothing overflows', (tester) async {
      await pump(
        tester,
        profile: profile(fundType: 'cassa', integrativeRate: 4),
        txns: [income(10400)],
        // The ledger starts this year: the declared-income banner tops the list.
        ledgerStart: DateTime(year, 1, 5),
        size: const Size(320, 640),
        textScale: scale,
      );
      expect(find.text(en.pivaDeclBannerTitle('${year - 1}')), findsOneWidget);
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

  // ── the declared-income banner ────────────────────────────────────────────
  // Whether it shows is `askDeclaredIncome`'s rule (piva_test.dart); what is checked here
  // is the wiring: the clock, the ledger's start, its words, and the two answers.

  final lastYear = year - 1;
  // The ledger starts this year: last year is not covered.
  final startsThisYear = DateTime(year, 1, 5);
  final bannerTitle = find.text(en.pivaDeclBannerTitle('$lastYear'));
  final enterIt = find.widgetWithText(OutlinedButton, en.pivaDeclEnter);
  final fromLedger = find.widgetWithText(TextButton, en.pivaDeclFromLedger);
  String day(DateTime d) => DateFormat.yMMMd().format(d);

  bool enabled(WidgetTester tester, Finder button) =>
      tester.widget<ButtonStyleButton>(button).onPressed != null;

  /// The service that records the writes, over a database nobody reads.
  _Finance recorder({bool fail = false, Completer<void>? gate}) {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    return _Finance(db, 'u', fail: fail, gate: gate);
  }

  testWidgets('a ledger that starts this year: the banner says so, with both answers '
      'and what the ledger holds for last year', (tester) async {
    await pump(tester, profile: profile(startYear: year - 2), ledgerStart: startsThisYear);

    expect(bannerTitle, findsOneWidget);
    expect(find.text(en.pivaDeclBannerStart(day(startsThisYear), '$lastYear', '$year')), findsOneWidget);
    expect(enterIt, findsOneWidget);
    expect(fromLedger, findsOneWidget);
    expect(find.text(en.pivaDeclBannerLedger(money.format(0))), findsOneWidget);
    // It is the first thing on the screen, above the profile.
    expect(tester.getTopLeft(bannerTitle).dy,
        lessThan(tester.getTopLeft(find.byTooltip(en.pivaProfileEdit)).dy));
    for (final button in [enterIt, fromLedger]) {
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('an empty ledger asks as well, in its own words', (tester) async {
    await pump(tester, profile: profile(startYear: year - 2), emptyLedger: true);

    expect(bannerTitle, findsOneWidget);
    expect(find.text(en.pivaDeclBannerEmpty('$lastYear', '$year')), findsOneWidget);
  });

  testWidgets('a ledger that started in March of last year shows what it holds for it, '
      'compensi and not the bank amount', (tester) async {
    // A cassa at 4%: 1,040 banked is 1,000 of compensi and 40 of integrativo.
    await pump(
      tester,
      profile: profile(fundType: 'cassa', integrativeRate: 4, startYear: year - 2),
      txns: [income(1040, date: DateTime(lastYear, 3, 15, 12))],
      ledgerStart: DateTime(lastYear, 3, 1, 12),
    );

    expect(bannerTitle, findsOneWidget);
    expect(find.text(en.pivaDeclBannerLedger(money.format(1000))), findsOneWidget);
  });

  testWidgets('a ledger that reaches back to last year does not ask', (tester) async {
    await pump(tester, profile: profile(startYear: year - 2), ledgerStart: DateTime(year - 2, 6, 1, 12));

    expect(bannerTitle, findsNothing);
    expect(enterIt, findsNothing);
  });

  testWidgets('a partita IVA opened this year has nothing to ask about last year', (tester) async {
    await pump(tester, profile: profile(startYear: year), ledgerStart: startsThisYear);

    expect(bannerTitle, findsNothing);
  });

  // A figure, or "from the ledger" (null): both are answers, and the banner stays away.
  for (final declared in <Map<String, double?>>[
    {'${year - 1}': 30000.0},
    {'${year - 1}': null},
  ]) {
    testWidgets('last year already answered ($declared): no banner', (tester) async {
      await pump(
        tester,
        profile: profile(startYear: year - 2, declaredIncome: declared),
        ledgerStart: startsThisYear,
      );

      expect(bannerTitle, findsNothing);
      expect(find.byTooltip(en.pivaProfileEdit), findsOneWidget, reason: 'the screen itself is up');
    });
  }

  testWidgets('no banner until the ledger has answered, then it shows', (tester) async {
    final ledger = StreamController<DateTime?>();
    addTearDown(ledger.close);
    await pump(tester, profile: profile(startYear: year - 2), ledger: ledger.stream);

    expect(find.byTooltip(en.pivaProfileEdit), findsOneWidget, reason: 'the screen itself is up');
    expect(bannerTitle, findsNothing);

    ledger.add(startsThisYear);
    await tester.pump();
    await tester.pump();
    await settle(tester);

    expect(bannerTitle, findsOneWidget);
  });

  testWidgets('"Derive it from the ledger" saves once, with the whole map and every other '
      'field as it was', (tester) async {
    final p = profile(
      fundType: 'cassa',
      integrativeRate: 4,
      startYear: year - 4,
      declaredIncome: {'${year - 3}': 999.0},
    );
    final finance = recorder();
    await pump(tester, profile: p, ledgerStart: startsThisYear, finance: finance);

    await tester.tap(fromLedger);
    await tester.pump();
    await tester.pump();

    expect(finance.saved, hasLength(1));
    final got = finance.saved.single;
    // Not `{lastYear: null}` alone: a write replaces the whole object on the server.
    expect(got.declaredIncome, {'${year - 3}': 999.0, '$lastYear': null});
    expect(got.declaredIncome.containsKey('$lastYear'), isTrue, reason: 'null is an answer');
    expect(got.atecoCode, p.atecoCode);
    expect(got.coefficient, p.coefficient);
    expect(got.startYear, p.startYear);
    expect(got.startupRate, p.startupRate);
    expect(got.fundType, p.fundType);
    expect(got.fundName, p.fundName);
    expect(got.subjectiveRate, p.subjectiveRate);
    expect(got.integrativeRate, p.integrativeRate);
    expect(got.minSubjective, p.minSubjective);
    expect(got.minIntegrative, p.minIntegrative);
    expect(got.inpsReduction, p.inpsReduction);
    expect(got.incomeCategories, p.incomeCategories);
  });

  testWidgets('while the write is in flight both buttons wait, and a second tap writes nothing',
      (tester) async {
    final gate = Completer<void>();
    final finance = recorder(gate: gate);
    await pump(tester, profile: profile(startYear: year - 2), ledgerStart: startsThisYear, finance: finance);

    await tester.tap(fromLedger);
    await tester.pump();

    expect(enabled(tester, enterIt), isFalse);
    expect(enabled(tester, fromLedger), isFalse);
    await tester.tap(fromLedger, warnIfMissed: false);
    await tester.pump();
    expect(finance.saved, hasLength(1));

    // The recorder writes nothing, so the profile does not change and the banner
    // stays: the buttons must come back.
    gate.complete();
    await tester.pump();
    await tester.pump();

    expect(enabled(tester, enterIt), isTrue);
    expect(enabled(tester, fromLedger), isTrue);
    expect(bannerTitle, findsOneWidget);
  });

  testWidgets('a failing save says so in a SnackBar, and the banner stays with its buttons on',
      (tester) async {
    final finance = recorder(fail: true);
    await pump(tester, profile: profile(startYear: year - 2), ledgerStart: startsThisYear, finance: finance);

    await tester.tap(fromLedger);
    await tester.pump();
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text(en.pivaProfileSaveError(en.errUnexpected)), findsOneWidget);
    expect(finance.saved, hasLength(1));
    expect(bannerTitle, findsOneWidget);
    expect(enabled(tester, enterIt), isTrue);
    expect(enabled(tester, fromLedger), isTrue);
  });

  testWidgets('"Enter it" opens the profile sheet on the profile shown, on last year\'s amount',
      (tester) async {
    final p = profile(startYear: year - 2);
    await pump(tester, profile: p, ledgerStart: startsThisYear);

    await tester.tap(enterIt);
    await settle(tester);

    final sheet = tester.widget<PivaProfileSheet>(find.byType(PivaProfileSheet));
    expect(sheet.existing, same(p));
    expect(sheet.focusDeclared, isTrue);
  });

  testWidgets('the edit action still opens the sheet without that focus', (tester) async {
    await pump(tester, profile: profile(startYear: year - 2), ledgerStart: startsThisYear);

    await tester.tap(find.byTooltip(en.pivaProfileEdit));
    await settle(tester);

    expect(tester.widget<PivaProfileSheet>(find.byType(PivaProfileSheet)).focusDeclared, isFalse);
  });

  testWidgets('in Italian the banner speaks Italian', (tester) async {
    final it = AppLocalizationsIt();
    await pump(
      tester,
      profile: profile(startYear: year - 2),
      ledgerStart: startsThisYear,
      locale: const Locale('it'),
    );

    expect(it.pivaDeclBannerTitle('$lastYear'), isNot(en.pivaDeclBannerTitle('$lastYear')));
    expect(find.text(it.pivaDeclBannerTitle('$lastYear')), findsOneWidget);
    expect(find.text(it.pivaDeclBannerStart(day(startsThisYear), '$lastYear', '$year')), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, it.pivaDeclEnter), findsOneWidget);
    expect(find.widgetWithText(TextButton, it.pivaDeclFromLedger), findsOneWidget);
    expect(find.text(it.pivaDeclBannerLedger(money.format(0))), findsOneWidget);
    expect(bannerTitle, findsNothing);
  });

  testWidgets('a screen reader reads the banner title as a heading', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, profile: profile(startYear: year - 2), ledgerStart: startsThisYear);

    expect(tester.getSemantics(bannerTitle), containsSemantics(isHeader: true));
    handle.dispose();
  });

  // The loop above lays the whole screen out with the banner at 1.0, 1.5 and 2.0; this one
  // adds what it cannot say: at 2.0 the two answers stack and stay inside the screen.
  testWidgets('320 × 640 at text scale 2.0: the banner does not overflow, its buttons stack',
      (tester) async {
    await pump(
      tester,
      profile: profile(startYear: year - 2),
      ledgerStart: startsThisYear,
      size: const Size(320, 640),
      textScale: 2,
    );

    expect(bannerTitle, findsOneWidget);
    expect(tester.takeException(), isNull);
    // Too wide for one line: the second answer is under the first.
    expect(tester.getTopLeft(fromLedger).dy, greaterThan(tester.getTopLeft(enterIt).dy));
    for (final button in [enterIt, fromLedger]) {
      expect(tester.getRect(button).right, lessThanOrEqualTo(320));
    }
  });

  // ── a declared year ───────────────────────────────────────────────────────
  // A cassa at 4% that declared the 41,600 the bank received in last year, with
  // one 1,040 invoice in the ledger for it: the declared figure wins, so
  // compensi 41,600 ÷ 1.04 = 40,000 and 1,600 of integrativo to remit. This year,
  // the same invoice is 1,000 of compensi.
  PivaProfileData declaredCassa() => profile(
        fundType: 'cassa',
        integrativeRate: 4,
        startYear: year - 2,
        declaredIncome: {'$lastYear': 41600.0},
      );
  final declaredLabel = '$pivaCompensi $lastYear · ${en.pivaDeclared}';
  final lastYearInvoice = income(1040, date: DateTime(lastYear, 3, 15, 12));

  /// The tile named [label] (its text is upper-cased on screen), and [text] inside it.
  Finder tile(String label) =>
      find.ancestor(of: find.text(label.toUpperCase()), matching: find.byType(PivaTile));
  Finder inTile(String label, String text) =>
      find.descendant(of: tile(label), matching: find.text(text));

  /// The line of the boxes named [label], and [text] inside it.
  Finder inLine(String label, String text) => find.descendant(
        of: find.ancestor(of: find.text(label), matching: find.byType(PivaLine)),
        matching: find.text(text),
      );

  Future<void> stepBack(WidgetTester tester, [String? tooltip]) async {
    await tester.tap(find.byTooltip(tooltip ?? en.pivaPrevYear));
    await settle(tester);
  }

  testWidgets('a declared year: said so, the same figure in the tile and in the prospetto, '
      'no months and no chart', (tester) async {
    await pump(tester, profile: declaredCassa(), txns: [lastYearInvoice]);
    await stepBack(tester);

    // The tiles.
    expect(inTile(declaredLabel, '€40,000.00'), findsOneWidget);
    for (final label in [en.pivaTileAverage, en.pivaTileBest]) {
      expect(inTile(label, '—'), findsOneWidget, reason: label);
      expect(inTile(label, en.pivaDeclNoMonths), findsOneWidget, reason: label);
    }
    // The payments are the ledger's rows, and the web leaves that tile alone.
    expect(inTile(en.pivaTilePayments, '1'), findsOneWidget);
    expect(inTile(en.pivaTilePayments, en.pivaTilePaymentsSub('€40,000.00')), findsOneWidget);
    // No chart, no zero bars: a note says why.
    expect(find.byType(BarChart), findsNothing);
    expect(
      find.text(en.pivaDeclChartNote('$lastYear', '€41,600.00', '€40,000.00')),
      findsOneWidget,
    );
    // The reconciliation: the bank row is the declared gross, under its plain label.
    expect(inLine(en.pivaReconBank, '€41,600.00'), findsOneWidget);
    expect(find.text('${en.pivaReconBank} · ${en.pivaDeclared}'), findsNothing);
    // The prospetto: the same figure as the tile, and its own foot.
    expect(inLine(declaredLabel, '€40,000.00'), findsOneWidget);
    expect(find.text(en.pivaDeclEstimateFoot('$lastYear')), findsOneWidget);
    expect(find.text(en.pivaEstimateFoot), findsNothing);
  });

  testWidgets('a year that is not declared keeps its plain labels and foot', (tester) async {
    await pump(tester, profile: profile(), txns: [income(10000)]);

    expect(find.text(en.pivaDeclared), findsNothing);
    expect(find.textContaining('· ${en.pivaDeclared}'), findsNothing);
    expect(find.text(en.pivaEstimateFoot), findsOneWidget);
    expect(find.text(en.pivaDeclNoMonths), findsNothing);
    // Two rods a month, this year and the year before, as always.
    final groups = tester.widget<BarChart>(find.byType(BarChart)).data.barGroups;
    expect(groups, hasLength(12));
    expect(groups.every((g) => g.barRods.length == 2), isTrue);
    expect(find.textContaining(en.pivaDeclChartPriorNote('$lastYear')), findsNothing);
  });

  testWidgets('in Italian a declared year says dichiarato', (tester) async {
    final it = AppLocalizationsIt();
    await pump(tester, profile: declaredCassa(), txns: [lastYearInvoice], locale: const Locale('it'));
    await stepBack(tester, it.pivaPrevYear);

    expect(it.pivaDeclared, isNot(en.pivaDeclared));
    final label = '$pivaCompensi $lastYear · ${it.pivaDeclared}';
    expect(inTile(label, '€40,000.00'), findsOneWidget);
    expect(inTile(it.pivaTileAverage, it.pivaDeclNoMonths), findsOneWidget);
    expect(inTile(it.pivaTileBest, it.pivaDeclNoMonths), findsOneWidget);
    expect(find.text(it.pivaDeclChartNote('$lastYear', '€41,600.00', '€40,000.00')), findsOneWidget);
    expect(inLine(label, '€40,000.00'), findsOneWidget);
    expect(find.text(it.pivaDeclEstimateFoot('$lastYear')), findsOneWidget);
  });

  testWidgets('the year after a declared one draws its own rods only, and names the whole '
      'declared year instead of a delta', (tester) async {
    await pump(tester, profile: declaredCassa(), txns: [income(1040)]);

    // This year is not declared: plain label, its own figure, and the year before as declared.
    expect(inTile('$pivaCompensi $year', '€1,000.00'), findsOneWidget);
    expect(inTile('$pivaCompensi $year', en.pivaDeclPrior('$lastYear', '€40,000.00')), findsOneWidget);
    expect(find.textContaining('· ${en.pivaDeclared}'), findsNothing);
    // One rod a month, and the legend says why the other is missing.
    final groups = tester.widget<BarChart>(find.byType(BarChart)).data.barGroups;
    expect(groups, hasLength(12));
    expect(groups.every((g) => g.barRods.length == 1), isTrue);
    expect(find.text(en.pivaDeclChartPriorNote('$lastYear')), findsOneWidget);
    expect(find.textContaining(en.pivaVsYear('$lastYear')), findsNothing, reason: 'no delta');
  });

  testWidgets('the chart of the year after a declared one is read without "against" the year before',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, profile: declaredCassa(), txns: [income(1040)]);

    expect(tester.getSemantics(find.byType(BarChart)).label,
        en.pivaDeclChartSemantics('$year', '€1,000.00'));
    handle.dispose();
  });

  // The year before has nothing: the foot is a delta only when its zero is real.
  for (final (covers, start) in [
    (true, DateTime(lastYear, 1, 1, 12)),
    (false, DateTime(lastYear, 1, 2, 12)),
  ]) {
    testWidgets(
        covers
            ? 'an empty year before that the ledger reaches back to: "new"'
            : 'an empty year before that the ledger reaches a day late: no foot at all',
        (tester) async {
      await pump(tester, profile: profile(), txns: [income(10000)], ledgerStart: start);

      expect(find.text('${en.pivaNew} ${en.pivaVsYear('$lastYear')}'), covers ? findsOneWidget : findsNothing);
      expect(find.textContaining(en.pivaVsYear('$lastYear')), covers ? findsOneWidget : findsNothing);
    });
  }
}
