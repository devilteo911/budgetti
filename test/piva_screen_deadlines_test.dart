import 'dart:async' show StreamController;
import 'dart:ffi' show DynamicLibrary;

import 'package:budgetti/core/database/database.dart' show AppDatabase;
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/features/piva/piva_deadline_sheet.dart';
import 'package:budgetti/features/piva/piva_deadlines_section.dart';
import 'package:budgetti/features/piva/piva_format.dart';
import 'package:budgetti/features/piva/piva_income_section.dart' show PivaLine;
import 'package:budgetti/features/piva/piva_screen.dart';
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:budgetti/l10n/app_localizations_en.dart';
import 'package:budgetti/models/piva.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

// Compensi of the current year and of the year before: the second is what the
// deductible contributions of the first are made of (acconti and saldo).
const _thisYear = 30000.0;
const _lastYear = 20000.0;

/// The deadlines section inside the whole Partita IVA screen: that it is mounted
/// under the prospetto and only with a profile, that the prospetto's deducted
/// contributions follow the accountant's official amounts, and that a deadline
/// added from the screen reaches the list through the database's own streams.
/// Made-up profile and ledger only; every expected figure is the engine's.
void main() {
  setUpAll(() {
    _ensureSqlite();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final year = DateTime.now().year;
  final en = AppLocalizationsEn();
  final money = NumberFormat.simpleCurrency(locale: 'en_US', name: 'EUR');

  PivaProfileData profile() => PivaProfileData(
    atecoCode: '62.01',
    coefficient: 67,
    startYear: year - 2,
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

  Transaction income(double amount, DateTime date) => Transaction(
    id: 'invoice-${date.year}',
    accountId: 'a',
    amount: amount,
    date: date,
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

  /// Drift streams answer in real time, not in the test clock: a few real
  /// milliseconds, then a frame, until [finder] is on screen.
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump();
    }
    expect(finder, findsWidgets);
  }

  void phoneView(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// The whole screen over made-up provider values; [payments] is a stream so a
  /// test can add a row while the screen is up.
  Future<void> pump(
    WidgetTester tester, {
    PivaProfileData? profile,
    List<Transaction> txns = const [],
    Stream<List<PivaPaymentData>>? payments,
  }) async {
    phoneView(tester, const Size(390, 4000));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pivaProfileProvider.overrideWith((ref) => Stream.value(profile)),
          pivaPaymentsProvider.overrideWith(
            (ref) => payments ?? Stream.value(const <PivaPaymentData>[]),
          ),
          pivaTransactionsProvider.overrideWith((ref) => Stream.value(txns)),
          // Two years back: last year is covered, so no declared-income banner.
          pivaLedgerStartProvider.overrideWith(
            (ref) => Stream.value(DateTime(year - 2, 6, 1, 12)),
          ),
          currencyProvider.overrideWithValue(money),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PivaScreen(),
        ),
      ),
    );
    // The streams emit on the next frames, and the sections are built — and ask
    // for their fonts — only then.
    await tester.pump();
    await tester.pump();
    await settle(tester);
  }

  /// What a row of the prospetto prints, as a number: the currency symbol, the
  /// separators and the real minus of the deducted contributions come off.
  double shown(WidgetTester tester, String label) {
    final value = tester.widget<PivaLine>(find.widgetWithText(PivaLine, label)).value;
    return double.parse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
  }

  /// The prospetto of the current year as the engine derives it from [payments]:
  /// the same chain the screen runs, written out.
  PivaYear expected(List<Transaction> txns, List<PivaPaymentData> payments, DateTime now) {
    final p = profile();
    return estimateYear(
      p,
      _thisYear,
      year,
      contributionsDeductible(deadlines(p, txns, payments, now), year),
    );
  }

  testWidgets('no profile: the section is not mounted and the empty state stays', (tester) async {
    await pump(tester);

    expect(find.byType(PivaDeadlinesSection), findsNothing);
    expect(find.text(en.pivaEmptyKicker), findsOneWidget);
  });

  testWidgets('with a profile the section sits right under the prospetto', (tester) async {
    await pump(tester, profile: profile());

    expect(find.byType(PivaDeadlinesSection), findsOneWidget);
    final footBottom = tester.getBottomLeft(find.text(en.pivaEstimateFoot)).dy;
    expect(tester.getTopLeft(find.byType(PivaDeadlinesSection)).dy, greaterThanOrEqualTo(footBottom));
  });

  testWidgets('an official contributions row of 1,000 moves "Contributi dedotti" by exactly 1,000 '
      'and the imposta sostitutiva down', (tester) async {
    final now = DateTime.now();
    final txns = [
      income(_lastYear, DateTime(year - 1, 3, 10, 12)),
      income(_thisYear, DateTime(year, 1, 15, 12)),
    ];
    final payments = StreamController<List<PivaPaymentData>>();
    addTearDown(payments.close);
    payments.add(const []);
    await pump(tester, profile: profile(), txns: txns, payments: payments.stream);

    const flatTax = '$pivaFlatTax · 15%';
    final before = expected(txns, const [], now);
    expect(before.contributionsPaid, greaterThan(0), reason: 'the year before leaves something to deduct');
    final paidBefore = shown(tester, pivaContributionsPaid);
    final taxBefore = shown(tester, flatTax);
    expect(paidBefore, closeTo(before.contributionsPaid, 0.005));
    expect(taxBefore, closeTo(before.tax, 0.005));

    // Added by hand (empty key) and due this year: it adds to the estimated rows
    // of the year instead of replacing one, so the deduction grows by its amount.
    final official = PivaPaymentData(
      id: 'official',
      key: '',
      kind: 'contributi',
      label: 'Contributi test',
      dueDate: DateTime(year, 3, 1, 12),
      amount: 1000,
      paidDate: null,
      note: '',
    );
    payments.add([official]);
    await tester.pump();
    await tester.pump();
    await settle(tester);

    final after = expected(txns, [official], now);
    expect(after.contributionsPaid, closeTo(before.contributionsPaid + 1000, 0.005));
    expect(after.tax, lessThan(before.tax));
    final paidAfter = shown(tester, pivaContributionsPaid);
    final taxAfter = shown(tester, flatTax);
    expect(paidAfter, closeTo(after.contributionsPaid, 0.005));
    expect(paidAfter - paidBefore, closeTo(1000, 0.005));
    expect(taxAfter, closeTo(after.tax, 0.005));
    expect(taxAfter, lessThan(taxBefore));
    // The same row is in the list below the prospetto.
    expect(find.text('Contributi test'), findsOneWidget);
  });

  testWidgets('Add deadline from the screen: the row shows up as Official with a zero amount, '
      'with nothing reloaded, and the table holds it', (tester) async {
    phoneView(tester, const Size(390, 2400));
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final finance = FinanceService(db, 'u');
    await tester.runAsync(
      () => finance.savePivaProfile(
        PivaProfileInput(
          atecoCode: '62.01',
          coefficient: 67,
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
          declaredIncome: const {},
        ),
      ),
    );

    // The real providers over the in-memory database; the sheet pops through
    // GoRouter, so the screen is a routed page.
    final router = GoRouter(routes: [GoRoute(path: '/', builder: (_, __) => const PivaScreen())]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeServiceProvider.overrideWithValue(finance),
          currencyProvider.overrideWithValue(money),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          // The app's own theme: its inputs float their label over the field.
          theme: AppTheme.buildTheme(palette: AppPalette.values.first, brightness: Brightness.dark),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await waitFor(tester, find.text(en.pivaDlAdd));
    await settle(tester);
    // No income, so no estimated rows: the list starts empty.
    expect(find.text(en.pivaDlEmpty), findsOneWidget);

    await tester.tap(find.text(en.pivaDlAdd));
    await settle(tester);
    expect(find.byType(PivaDeadlineSheet), findsOneWidget);

    // Kind, label, amount, day.
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    // The open menu is the last place the name is drawn.
    await tester.tap(find.text(pivaContributions).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, en.pivaDlLabel), 'Bollo');
    await tester.enterText(find.widgetWithText(TextField, en.pivaDlAmount), '0');
    await tester.pump();
    await tester.tap(find.text(en.pivaDlPickDate));
    await tester.pumpAndSettle();
    // The picker opens on today's month: the 15th is in every one.
    await tester.tap(find.descendant(of: find.byType(DatePickerDialog), matching: find.text('15')));
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, 15);
    expect(find.text(DateFormat.yMMMd().format(day)), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, en.commonSave));
    await waitFor(tester, find.text(en.pivaDlChipOfficial));
    await settle(tester);

    expect(find.byType(PivaDeadlineSheet), findsNothing);
    expect(find.text(en.pivaDlEmpty), findsNothing);
    final row = find.ancestor(of: find.text('Bollo'), matching: find.byType(InkWell)).first;
    expect(find.descendant(of: row, matching: find.text(en.pivaDlChipOfficial)), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text(money.format(0))), findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.text('${DateFormat.yMMMd().format(day)} · $pivaContributions')),
      findsOneWidget,
    );

    final rows = (await tester.runAsync(() => db.select(db.pivaPayments).get()))!;
    expect(rows, hasLength(1));
    final saved = rows.single;
    expect(saved.key, '');
    expect(saved.kind, 'contributi');
    expect(saved.label, 'Bollo');
    expect(saved.amount, 0);
    expect(saved.dueDate, DateTime(day.year, day.month, day.day, 12));
    expect(saved.paidDate, isNull);
    expect(saved.isDeleted, isFalse);

    // Let go of the streams before the database closes.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(seconds: 1));
  });
}
