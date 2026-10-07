import 'dart:async' show Completer;
import 'dart:ffi' show DynamicLibrary;

import 'package:budgetti/core/database/database.dart' show AppDatabase, PivaProfile;
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/features/piva/piva_profile_sheet.dart';
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:budgetti/l10n/app_localizations_en.dart';
import 'package:budgetti/models/category.dart';
import 'package:budgetti/models/piva.dart' show PivaProfileData, PivaProfileInput;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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

/// The real service over an in-memory database, counting the writes the sheet
/// asks for. [fail] makes them throw, as a full disk would; [gate] holds each
/// one until it completes, so a write can be in flight while the test acts.
class _Finance extends FinanceService {
  _Finance(super.db, super.userId, {this.fail = false, this.gate});

  final bool fail;
  final Completer<void>? gate;
  int saves = 0;

  @override
  Future<void> savePivaProfile(PivaProfileInput input) async {
    saves++;
    await gate?.future;
    if (fail) throw StateError('disk full');
    await super.savePivaProfile(input);
  }
}

// The fiscal terms are Dart constants of the sheet, the same in both languages.
const _coefficient = 'Coefficiente di redditività (%)';
const _subjective = 'Contributo soggettivo (%)';
const _integrative = 'Contributo integrativo (%)';
const _minSubjective = 'Minimo soggettivo (€)';
const _minIntegrative = 'Minimo integrativo (€)';
const _reduction = 'Riduzione contributiva 35%';

const _atecoError = 'Enter the ATECO code as digits and dots, like 62.01.00.';

// Made-up profiles, saved before the sheet opens on them.
const _cassa = PivaProfileInput(
  atecoCode: '69.20',
  coefficient: 78,
  startYear: 2019,
  startupRate: true,
  fundType: 'cassa',
  fundName: 'Cassa Test',
  subjectiveRate: 10.5,
  integrativeRate: 4,
  minSubjective: 1234.56,
  minIntegrative: 50,
  inpsReduction: false,
  incomeCategories: ['Freelance', 'Salary'],
);
const _artigiani = PivaProfileInput(
  atecoCode: '43.21.01',
  coefficient: 86,
  startYear: 2021,
  startupRate: false,
  fundType: 'artigiani',
  fundName: '',
  subjectiveRate: 0,
  integrativeRate: 0,
  minSubjective: 0,
  minIntegrative: 0,
  inpsReduction: true,
  incomeCategories: ['Salary'],
);

/// The profile sheet: the first broken rule shown inside it, the fields that
/// follow the fund, the coefficient suggested by the ATECO code, what a save
/// writes (once) and what an untouched one leaves, the failed save and the
/// discard guard. The rules themselves are `parseProfileForm`'s, tested in
/// `piva_test.dart`.
void main() {
  setUpAll(() {
    _ensureSqlite();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final en = AppLocalizationsEn();

  Category category(String name, String type) =>
      Category(id: 'cat_$name', userId: 'u', name: name, iconCode: 0, colorHex: 0, type: type);

  /// Waits for every font asked for so far, then for the frames that follow.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(GoogleFonts.pendingFonts);
    await tester.pumpAndSettle();
    await tester.runAsync(GoogleFonts.pendingFonts);
  }

  /// The sheet as a routed page (its save pops through GoRouter) over an
  /// in-memory database. [stored] is saved first and the sheet opens on it, as
  /// the screen opens it on the profile it reads.
  Future<({AppDatabase db, _Finance finance})> pump(
    WidgetTester tester, {
    PivaProfileInput? stored,
    Locale locale = const Locale('en'),
    bool fail = false,
    Completer<void>? gate,
    Size size = const Size(390, 4000),
  }) async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final finance = _Finance(db, 'u', fail: fail, gate: gate);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    PivaProfileData? existing;
    if (stored != null) {
      final plain = FinanceService(db, 'u');
      existing = await tester.runAsync<PivaProfileData?>(() async {
        await plain.savePivaProfile(stored);
        return plain.getPivaProfile();
      });
    }

    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold()),
      GoRoute(
        path: '/sheet',
        builder: (_, __) => Scaffold(body: PivaProfileSheet(existing: existing)),
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        financeServiceProvider.overrideWithValue(finance),
        categoriesProvider.overrideWith((ref) => Stream.value([
              category('Dining', 'expense'),
              category('Freelance', 'income'),
              category('Salary', 'income'),
            ])),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        // The app's own theme: its filled, borderless inputs float their label
        // over the field's top edge, which the default theme does not.
        theme: AppTheme.buildTheme(palette: AppPalette.values.first, brightness: Brightness.dark),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();
    router.push('/sheet');
    await settle(tester);
    return (db: db, finance: finance);
  }

  final save = find.byType(ElevatedButton);
  Finder field(String label) => find.widgetWithText(TextField, label);
  String textOf(WidgetTester tester, String label) =>
      tester.widget<TextField>(field(label)).controller!.text;

  Future<void> type(WidgetTester tester, String label, String text) async {
    await tester.enterText(field(label), text);
    await tester.pump();
  }

  Future<void> pickFund(WidgetTester tester, String name) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    // The open menu is the last place the name is drawn.
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  /// What a Gestione Separata profile needs: a code (which fills 67), an
  /// opening year and one income category.
  Future<void> fillValid(WidgetTester tester) async {
    await type(tester, en.pivaProfileAtecoLabel, '62.01.00');
    await type(tester, en.pivaProfileStartYearLabel, '2020');
    await tester.tap(find.text('Freelance'));
    await tester.pump();
  }

  Future<List<PivaProfile>> rowsOf(WidgetTester tester, AppDatabase db) async =>
      (await tester.runAsync(() => db.select(db.pivaProfiles).get()))!;

  void expectRow(PivaProfile row, PivaProfileInput want) {
    expect(row.isDeleted, isFalse);
    expect(row.atecoCode, want.atecoCode);
    expect(row.coefficient, want.coefficient);
    expect(row.startYear, want.startYear);
    expect(row.startupRate, want.startupRate);
    expect(row.fundType, want.fundType);
    expect(row.fundName, want.fundName);
    expect(row.subjectiveRate, want.subjectiveRate);
    expect(row.integrativeRate, want.integrativeRate);
    expect(row.minSubjective, want.minSubjective);
    expect(row.minIntegrative, want.minIntegrative);
    expect(row.inpsReduction, want.inpsReduction);
    expect(row.incomeCategories, want.incomeCategories);
  }

  testWidgets('an empty form shows the first broken rule inside the sheet; the next edit clears it',
      (tester) async {
    final h = await pump(tester);

    await tester.tap(save);
    await tester.pump();

    expect(find.text(_atecoError), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing); // it would be drawn under the sheet
    expect(h.finance.saves, 0);
    expect(find.byType(PivaProfileSheet), findsOneWidget);

    await type(tester, en.pivaProfileAtecoLabel, '6');

    expect(find.text(_atecoError), findsNothing);
  });

  // A floating label rides ~6 dp above its field's top edge, over whatever is
  // above: it must clear the heading and the switch row, and every field above it.
  Future<void> expectClearLabels(WidgetTester tester, {required bool cassa}) async {
    Rect r(Finder f) => tester.getRect(f.first);
    final labels = <(String, Rect)>[
      ('SET UP YOUR PARTITA IVA', r(find.text('SET UP YOUR PARTITA IVA'))),
      ('startup switch', r(find.textContaining('Aliquota startup'))),
    ];
    final fields = tester
        .widgetList<InputDecorator>(find.byType(InputDecorator))
        .map((d) => tester.getRect(find.byWidget(d)))
        .toList()
      ..sort((a, b) => a.top.compareTo(b.top));
    // Heading → first field, switch row → the fund dropdown: 12 dp of air beyond
    // the label's own rise at the least.
    final first = fields.first;
    final fund = fields.firstWhere((f) => f.top > labels[1].$2.bottom);
    expect(first.top - 6 - labels[0].$2.bottom, greaterThanOrEqualTo(12), reason: 'heading → first field');
    expect(fund.top - 6 - labels[1].$2.bottom, greaterThanOrEqualTo(12), reason: 'switch row → fund');
    // Each field to the one above it (a row of two counts as one line).
    for (var i = 1; i < fields.length; i++) {
      final above = fields.sublist(0, i).where((f) => f.bottom <= fields[i].top + 1);
      if (above.isEmpty) continue;
      final gap = fields[i].top - 6 - above.map((f) => f.bottom).reduce((a, b) => a > b ? a : b);
      expect(gap, greaterThanOrEqualTo(4), reason: 'field ${fields[i]} touches the one above');
    }
    expect(fields.length, cassa ? greaterThan(6) : lessThan(6));
  }

  testWidgets('no floating label touches the heading, the switch row or a field above (any fund)',
      (tester) async {
    await pump(tester, size: const Size(390, 1400));
    await type(tester, 'ATECO code', '62.01.00');
    await type(tester, 'Opened in', '2023');
    await expectClearLabels(tester, cassa: false);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await settle(tester);
    await tester.tap(find.text('Cassa professionale').last);
    await settle(tester);
    for (final label in ['Fund name', _subjective, _integrative, _minSubjective, _minIntegrative]) {
      await type(tester, label, '1');
    }
    await expectClearLabels(tester, cassa: true);
  });

  testWidgets('Save and the error stay on screen on a phone-sized sheet, whatever the form length',
      (tester) async {
    // 390 × 700, not 4000: the form scrolls, the button and the message must not.
    await pump(tester, size: const Size(390, 700));
    final screen = tester.view.physicalSize;

    expect(tester.getRect(save).bottom, lessThanOrEqualTo(screen.height));
    await tester.tap(save);
    await tester.pump();
    await tester.pump();

    expect(find.text('Enter the ATECO code as digits and dots, like 62.01.00.'), findsOneWidget);
    final button = tester.getRect(save);
    expect(button.bottom, lessThanOrEqualTo(screen.height));
    // The message sits right above the button, in view.
    final message = tester.getRect(find.text('Enter the ATECO code as digits and dots, like 62.01.00.'));
    expect(message.bottom, lessThanOrEqualTo(button.top));
    expect(message.top, greaterThan(0));
  });

  testWidgets('the same message in Italian', (tester) async {
    await pump(tester, locale: const Locale('it'));

    await tester.tap(save);
    await tester.pump();

    expect(find.text('Inserisci il codice ATECO con cifre e punti, come 62.01.00.'), findsOneWidget);
  });

  testWidgets('the cassa fields and the INPS reduction follow the fund', (tester) async {
    await pump(tester);
    final cassaOnly = [_subjective, _integrative, _minSubjective, _minIntegrative, en.pivaProfileFundNameLabel];

    for (final label in [...cassaOnly, _reduction]) {
      expect(find.text(label), findsNothing, reason: label);
    }
    expect(find.text(en.pivaProfileIntegrativoNote), findsNothing);

    await pickFund(tester, 'Cassa professionale');

    for (final label in cassaOnly) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text(en.pivaProfileIntegrativoNote), findsOneWidget);
    expect(find.text(_reduction), findsNothing);

    await pickFund(tester, 'Artigiani INPS');

    for (final label in cassaOnly) {
      expect(find.text(label), findsNothing, reason: label);
    }
    expect(find.text(en.pivaProfileIntegrativoNote), findsNothing);
    expect(find.text(_reduction), findsOneWidget);
  });

  testWidgets('the ATECO code fills the coefficient, a typed one stays, "Use it" takes the suggestion',
      (tester) async {
    await pump(tester);

    await type(tester, en.pivaProfileAtecoLabel, '62.01.00');
    expect(textOf(tester, _coefficient), '67');

    await type(tester, _coefficient, '50');
    await type(tester, en.pivaProfileAtecoLabel, '69.20');
    expect(textOf(tester, _coefficient), '50');
    expect(find.text('Ministerial group: 78%'), findsOneWidget);

    await tester.tap(find.text('Use it'));
    await tester.pump();

    expect(textOf(tester, _coefficient), '78');
  });

  testWidgets('the ATECO field turns a comma into a point', (tester) async {
    await pump(tester);

    await type(tester, en.pivaProfileAtecoLabel, '62,01');

    expect(textOf(tester, en.pivaProfileAtecoLabel), '62.01');
  });

  testWidgets('only income categories are offered', (tester) async {
    await pump(tester);

    expect(find.widgetWithText(CheckboxListTile, 'Freelance'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'Salary'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'Dining'), findsNothing);
  });

  testWidgets('on edit, a category the profile holds that no longer exists is listed and ticked',
      (tester) async {
    await pump(
      tester,
      stored: const PivaProfileInput(
        atecoCode: '62.01',
        coefficient: 67,
        startYear: 2020,
        startupRate: false,
        fundType: 'gestione_separata',
        fundName: '',
        subjectiveRate: 0,
        integrativeRate: 0,
        minSubjective: 0,
        minIntegrative: 0,
        inpsReduction: false,
        incomeCategories: ['Freelance', 'Retired'],
      ),
    );

    bool? ticked(String name) =>
        tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, name)).value;
    expect(ticked('Retired'), isTrue);
    expect(ticked('Freelance'), isTrue);
    expect(ticked('Salary'), isFalse);
  });

  testWidgets('two quick taps on Save write once, close the sheet and leave the typed values',
      (tester) async {
    final gate = Completer<void>();
    final h = await pump(tester, gate: gate);
    await fillValid(tester);
    await type(tester, _coefficient, '78,5');

    await tester.tap(save);
    await tester.pump();
    // The write is in flight and the button a disabled spinner: this tap is lost.
    await tester.tap(save);
    await tester.pump();
    expect(h.finance.saves, 1);

    gate.complete();
    await tester.pumpAndSettle();

    expect(h.finance.saves, 1);
    expect(find.byType(PivaProfileSheet), findsNothing);
    final rows = await rowsOf(tester, h.db);
    expect(rows, hasLength(1));
    expectRow(
      rows.single,
      const PivaProfileInput(
        atecoCode: '62.01.00',
        coefficient: 78.5,
        startYear: 2020,
        startupRate: false,
        fundType: 'gestione_separata',
        fundName: '',
        subjectiveRate: 0,
        integrativeRate: 0,
        minSubjective: 0,
        minIntegrative: 0,
        inpsReduction: false,
        incomeCategories: ['Freelance'],
      ),
    );
  });

  testWidgets('a cassa filled in and then switched back to Gestione Separata saves its fields blank',
      (tester) async {
    final h = await pump(tester);
    await fillValid(tester);
    await pickFund(tester, 'Cassa professionale');
    await type(tester, en.pivaProfileFundNameLabel, 'Cassa Test');
    await type(tester, _subjective, '10');
    await type(tester, _integrative, '4');
    await type(tester, _minSubjective, '100');
    await type(tester, _minIntegrative, '50');
    await pickFund(tester, 'Gestione Separata INPS');

    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(h.finance.saves, 1);
    final row = (await rowsOf(tester, h.db)).single;
    expect(row.fundType, 'gestione_separata');
    expect(row.fundName, '');
    expect(row.subjectiveRate, 0);
    expect(row.integrativeRate, 0);
    expect(row.minSubjective, 0);
    expect(row.minIntegrative, 0);
  });

  for (final (name, want, shown) in [
    ('a cassa', _cassa, {_coefficient: '78', _minSubjective: '1234.56', _subjective: '10.5'}),
    ('an artigiani with the reduction', _artigiani, {_coefficient: '86'}),
  ]) {
    testWidgets('saved untouched, $name keeps every value', (tester) async {
      final h = await pump(tester, stored: want);

      // The numbers come back in their shortest form: `78`, never `78.0`.
      for (final MapEntry(:key, :value) in shown.entries) {
        expect(textOf(tester, key), value, reason: key);
      }
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(h.finance.saves, 1);
      final rows = await rowsOf(tester, h.db);
      expect(rows, hasLength(1));
      expectRow(rows.single, want);
    });
  }

  testWidgets('a failing save says so inside the sheet and leaves it open, ready to retry',
      (tester) async {
    final h = await pump(tester, fail: true);
    await fillValid(tester);

    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Error saving profile: Something went wrong. Try again.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(PivaProfileSheet), findsOneWidget);
    expect(h.finance.saves, 1);

    // Not stuck "saving": the button works again.
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(h.finance.saves, 2);
  });

  testWidgets('closing a form with edits asks first', (tester) async {
    await pump(tester);
    await type(tester, en.pivaProfileAtecoLabel, '62');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.byType(PivaProfileSheet), findsOneWidget);
  });

  testWidgets('an untouched form closes at once', (tester) async {
    await pump(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.byType(PivaProfileSheet), findsNothing);
  });
}
