import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/finance_service.dart' show FinanceService;
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/features/piva/piva_deadline_sheet.dart';
import 'package:budgetti/features/piva/piva_deadlines_section.dart';
import 'package:budgetti/features/piva/piva_format.dart';
import 'package:budgetti/features/piva/piva_income_section.dart' show PivaTile;
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:budgetti/l10n/app_localizations_en.dart';
import 'package:budgetti/models/piva.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// What the section asked `savePivaPayment` to write.
typedef _Saved = ({
  String? id,
  String key,
  String kind,
  String label,
  DateTime? dueDate,
  double amount,
  DateTime? paidDate,
  String note,
});

/// Records the one-tap writes; [fail] makes them throw, as a full disk would.
/// Nothing else of the service is reachable from the section.
class _Finance extends Fake implements FinanceService {
  _Finance({this.fail = false});

  final bool fail;
  final saved = <_Saved>[];

  @override
  Future<void> savePivaPayment({
    String? id,
    required String key,
    required String kind,
    required String label,
    required DateTime? dueDate,
    required double amount,
    DateTime? paidDate,
    String note = '',
  }) async {
    saved.add((
      id: id,
      key: key,
      kind: kind,
      label: label,
      dueDate: dueDate,
      amount: amount,
      paidDate: paidDate,
      note: note,
    ));
    if (fail) throw StateError('disk full');
  }
}

// "Today" of every test: a Wednesday in mid-June.
final _now = DateTime(2026, 6, 10);

/// A made-up artigiani profile with no income in the ledger. That makes the
/// calendar the twelve fixed quarterly rates of 2025, 2026 and 2027 (the saldo,
/// the acconti and the tax are all zero, so they make no row): 2025 and the first
/// two rates of 2026 are past, the rest is ahead. Every amount below is read back
/// from the engine, never written by hand.
PivaProfileData _profile({int startYear = 2020, String fundType = 'artigiani'}) => PivaProfileData(
  atecoCode: '62.01',
  coefficient: 67,
  startYear: startYear,
  startupRate: false,
  fundType: fundType,
  fundName: '',
  subjectiveRate: 0,
  integrativeRate: 0,
  minSubjective: 0,
  minIntegrative: 0,
  inpsReduction: false,
  incomeCategories: const ['Freelance'],
);

/// A saved row. `dated: false` is one with no day; `key` empty is a hand-made one.
PivaPaymentData _payment(
  String id, {
  String key = '',
  String kind = 'contributi',
  String label = 'Rata',
  DateTime? due,
  bool dated = true,
  double amount = 100,
  DateTime? paid,
  String note = '',
}) => PivaPaymentData(
  id: id,
  key: key,
  kind: kind,
  label: label,
  dueDate: dated ? (due ?? DateTime(2026, 7, 1)) : null,
  amount: amount,
  paidDate: paid,
  note: note,
);

// Official, past, unpaid: overdue. It replaces the estimate of the May rate.
final _overdue = _payment(
  'p-over',
  key: '2026:contributi_fissi1',
  label: 'Rata di maggio',
  due: DateTime(2026, 5, 18),
  amount: 700,
  note: 'Dal commercialista',
);
// Official and paid. It replaces the estimate of the February rate.
final _paid = _payment(
  'p-paid',
  key: '2026:contributi_fissi4',
  label: 'Rata di febbraio',
  due: DateTime(2026, 2, 16),
  amount: 500,
  paid: DateTime(2026, 2, 10),
);
// The cassa's pass-through slot, last day of the year.
final _integrativo = _payment(
  'p-int',
  key: '2026:contributi_integrativo',
  label: 'Contributo integrativo 2025',
  due: DateTime(2026, 12, 31),
  amount: 40,
);
// Falls due today: it counts as ahead.
final _today = _payment('p-today', kind: 'imposta', label: 'Bollo di oggi', due: _now, amount: 60);
// No day at all, as the admin UI can leave it.
final _noDate = _payment('p-nodate', kind: 'imposta', label: 'Cartella senza data', dated: false, amount: 250);

/// A calendar row for the pure helpers; `due` null is a row with no day.
PivaDeadline _row(
  String label, {
  DateTime? due,
  bool estimated = true,
  DateTime? paid,
  String? paymentId,
  String key = '',
}) => PivaDeadline(
  key: key,
  kind: 'contributi',
  label: label,
  dueDate: due,
  amount: 10,
  estimated: estimated,
  paidDate: paid,
  paymentId: paymentId,
  note: '',
);

/// The deadlines section: how it groups the calendar, what the three tiles say,
/// the two writes of a tap, going back to the estimate, a row with no day, and the
/// narrow phone with a large font. The engine's rules are `piva_test.dart`'s.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final en = AppLocalizationsEn();
  final currency = NumberFormat.simpleCurrency(name: 'EUR', locale: 'en_US');

  /// Waits for every font asked for so far, then for the frames that follow.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(GoogleFonts.pendingFonts);
    await tester.pumpAndSettle();
    await tester.runAsync(GoogleFonts.pendingFonts);
  }

  /// The section alone, in the scroll the screen gives it. [textScale] is the
  /// system's font scale.
  Future<_Finance> pump(
    WidgetTester tester, {
    PivaProfileData? profile,
    List<PivaPaymentData> payments = const [],
    Size size = const Size(390, 4000),
    double textScale = 1,
    bool fail = false,
  }) async {
    final finance = _Finance(fail: fail);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [financeServiceProvider.overrideWithValue(finance), currencyProvider.overrideWithValue(currency)],
        child: MaterialApp(
          theme: AppTheme.buildTheme(palette: AppPalette.values.first, brightness: Brightness.dark),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: PivaDeadlinesSection(profile: profile ?? _profile(), payments: payments, txns: const [], now: _now),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await settle(tester);
    return finance;
  }

  ColorScheme scheme(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(PivaDeadlinesSection))).colorScheme;

  // A row is found by its key: the paymentId of a saved row, the `key` of an estimate.
  Finder row(String key) => find.byKey(ValueKey(key));
  Finder inRow(String key, Finder what) => find.descendant(of: row(key), matching: what);
  Finder button(String key) => inRow(key, find.byType(TextButton));
  double top(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

  Finder tile(String label) => find.ancestor(of: find.text(label), matching: find.byType(PivaTile));
  Finder inTile(String label, Finder what) => find.descendant(of: tile(label), matching: what);

  List<PivaDeadline> calendar([List<PivaPaymentData> payments = const [], PivaProfileData? profile]) =>
      deadlines(profile ?? _profile(), const [], payments, _now);

  String amountField(WidgetTester tester) =>
      tester.widget<TextField>(find.widgetWithText(TextField, en.pivaDlAmount)).controller!.text;

  testWidgets('the calendar is split by state, each row with the chips of its own', (tester) async {
    await pump(tester, payments: [_overdue, _paid, _integrativo]);
    final colors = scheme(tester);

    // Open ones first (the official overdue one is the earliest day), then the past
    // estimates under their label, then the paid ones under theirs.
    final unrecorded = find.text(en.pivaDlGroupUnrecorded);
    final paid = find.text(en.pivaDlGroupPaid);
    expect(unrecorded, findsOneWidget);
    expect(paid, findsOneWidget);
    expect(top(tester, row('p-over')), lessThan(top(tester, row('2026:contributi_fissi2'))));
    expect(top(tester, row('2026:contributi_fissi2')), lessThan(top(tester, unrecorded)));
    expect(top(tester, unrecorded), lessThan(top(tester, row('2025:contributi_fissi2'))));
    expect(top(tester, row('2025:contributi_fissi2')), lessThan(top(tester, paid)));
    expect(top(tester, paid), lessThan(top(tester, row('p-paid'))));

    // A future estimate: "Estimate".
    expect(inRow('2026:contributi_fissi2', find.text(en.pivaDlChipEstimate)), findsOneWidget);
    expect(inRow('2026:contributi_fissi2', find.text(en.pivaDlOverdue)), findsNothing);

    // A past estimate: "Not recorded", and nothing about it is red.
    expect(inRow('2025:contributi_fissi2', find.text(en.pivaDlChipNotRecorded)), findsOneWidget);
    expect(inRow('2025:contributi_fissi2', find.text(en.pivaDlChipEstimate)), findsNothing);
    expect(inRow('2025:contributi_fissi2', find.text(en.pivaDlOverdue)), findsNothing);
    for (final t in tester.widgetList<Text>(inRow('2025:contributi_fissi2', find.byType(Text)))) {
      expect(t.style?.color, isNot(colors.error), reason: t.data);
    }

    // A past official one that nobody paid: "Official", and "Overdue" in red.
    expect(tester.widget<Text>(inRow('p-over', find.text(en.pivaDlChipOfficial))).style!.color, colors.primary);
    expect(tester.widget<Text>(inRow('p-over', find.text(en.pivaDlOverdue))).style!.color, colors.error);
    expect(inRow('p-over', find.text('Dal commercialista')), findsOneWidget);
    expect(inRow('p-over', find.widgetWithText(TextButton, en.pivaDlMarkPaid)), findsOneWidget);

    // A paid one: "Paid" and the day, "Undo", its text muted.
    expect(inRow('p-paid', find.text(en.pivaDlPaidOn('Feb 10, 2026'))), findsOneWidget);
    expect(inRow('p-paid', find.widgetWithText(TextButton, en.pivaDlUndoPaid)), findsOneWidget);
    expect(tester.widget<Text>(inRow('p-paid', find.text('Rata di febbraio'))).style!.color, colors.onSurfaceVariant);

    // The integrativo says what it is, on the line of the day and the kind.
    expect(inRow('p-int', find.textContaining(en.pivaDlTypePassThrough)), findsOneWidget);
    expect(inRow('p-over', find.textContaining(pivaContributions)), findsOneWidget);
  });

  testWidgets('the paid ones are by payment day, latest first; the same day by due day; no day last', (tester) async {
    await pump(
      tester,
      payments: [
        _payment('a', paid: DateTime(2026, 2, 10), due: DateTime(2026, 2, 16)),
        _payment('b', paid: DateTime(2026, 3, 5), due: DateTime(2026, 3, 16)),
        _payment('c', paid: DateTime(2026, 3, 5), due: DateTime(2026, 4, 20)),
        _payment('d', paid: DateTime(2026, 3, 5), dated: false),
      ],
    );

    final order = ['c', 'b', 'd', 'a'];
    for (var i = 1; i < order.length; i++) {
      expect(top(tester, row(order[i - 1])), lessThan(top(tester, row(order[i]))), reason: '${order[i - 1]} before ${order[i]}');
    }
  });

  testWidgets('a group with nothing in it has no heading, and no deadlines says so', (tester) async {
    // Ahead only: nothing past, nothing paid.
    await pump(tester, profile: _profile(startYear: 2027));
    expect(find.text(en.pivaDlGroupUnrecorded), findsNothing);
    expect(find.text(en.pivaDlGroupPaid), findsNothing);
    // One "Mark paid" per row (`TextButton.icon` is a subclass: `byType` skips it).
    expect(find.byType(TextButton), findsNWidgets(calendar([], _profile(startYear: 2027)).length));

    // No rows at all: the text instead of the list, the heading and its button stay.
    expect(calendar([], _profile(fundType: 'gestione_separata')), isEmpty);
    await pump(tester, profile: _profile(fundType: 'gestione_separata'));
    expect(find.text(en.pivaDlEmpty), findsOneWidget);
    expect(find.text(en.pivaDlTitle.toUpperCase()), findsOneWidget);
    expect(find.text(en.pivaDlAdd), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
    expect(inTile(en.pivaDlOverdue.toUpperCase(), find.text(en.pivaDlNothingOverdue)), findsOneWidget);
    expect(inTile(en.pivaDlNext.toUpperCase(), find.text(en.pivaDlNothingUpcoming)), findsOneWidget);
  });

  testWidgets('only past estimates: the second tile is "Not recorded", in a neutral tone', (tester) async {
    await pump(tester);
    final colors = scheme(tester);
    final totals = deadlineTotals(calendar(), _now);
    expect(totals.overdue, 0);
    expect(totals.unrecorded, greaterThan(0));

    final label = en.pivaDlNotRecorded.toUpperCase();
    expect(find.text(en.pivaDlOverdue.toUpperCase()), findsNothing);
    expect(inTile(label, find.text(currency.format(totals.unrecorded))), findsOneWidget);
    final hint = tester.widget<Text>(inTile(label, find.text(en.pivaDlNotRecordedHint(totals.count.unrecorded))));
    expect(hint.style!.color, colors.onSurfaceVariant);
  });

  testWidgets('an official one past its day: the second tile is "Overdue", in red, with its amount', (tester) async {
    await pump(tester, payments: [_overdue]);
    final colors = scheme(tester);

    final label = en.pivaDlOverdue.toUpperCase();
    expect(inTile(label, find.text(currency.format(700))), findsOneWidget);
    expect(tester.widget<Text>(inTile(label, find.text(en.pivaDlOverdueCount(1)))).style!.color, colors.error);
    // The estimates past their day are still there, in the group and nowhere else.
    expect(find.text(en.pivaDlNotRecorded.toUpperCase()), findsNothing);
    expect(find.text(en.pivaDlGroupUnrecorded), findsOneWidget);
  });

  testWidgets('nothing past: "Overdue" at zero in a neutral tone; next year does not count as due this year', (tester) async {
    // Opened in 2027: every row is next year's.
    final rows = calendar([], _profile(startYear: 2027));
    expect(rows, isNotEmpty);
    expect(rows.every((r) => r.dueDate!.year == 2027), isTrue);
    await pump(tester, profile: _profile(startYear: 2027));
    final colors = scheme(tester);

    expect(inTile(en.pivaDlDueByDec(2026).toUpperCase(), find.text(currency.format(0))), findsOneWidget);
    expect(inTile(en.pivaDlDueByDec(2026).toUpperCase(), find.text(en.pivaDlCount(0))), findsOneWidget);
    final label = en.pivaDlOverdue.toUpperCase();
    expect(inTile(label, find.text(currency.format(0))), findsOneWidget);
    expect(tester.widget<Text>(inTile(label, find.text(en.pivaDlNothingOverdue))).style!.color, colors.onSurfaceVariant);
    // The next deadline is still the first of 2027.
    final next = rows.first;
    final nextLabel = en.pivaDlNext.toUpperCase();
    expect(inTile(nextLabel, find.text(DateFormat.yMMMd().format(next.dueDate!))), findsOneWidget);
    expect(inTile(nextLabel, find.text('${next.label} · ${currency.format(next.amount)}')), findsOneWidget);
  });

  testWidgets('"Due by Dec" sums what is unpaid from today to 31 December; the next one can fall today', (tester) async {
    final payments = [_overdue, _paid, _integrativo, _today];
    final rows = calendar(payments);
    final totals = deadlineTotals(rows, _now);
    // The two estimates still ahead in 2026, the one due today and the one due on
    // 31 December. The 2027 ones are due too, and are not in the sum.
    expect(totals.count.upcoming, 4);
    expect(rows.any((r) => r.dueDate!.year == 2027 && deadlineState(r, _now) == DeadlineState.due), isTrue);
    await pump(tester, payments: payments);

    final due = en.pivaDlDueByDec(2026).toUpperCase();
    expect(inTile(due, find.text(currency.format(totals.upcoming))), findsOneWidget);
    expect(inTile(due, find.text(en.pivaDlCount(4))), findsOneWidget);
    // Today is not past: the third tile is that one, not the August estimate.
    final next = en.pivaDlNext.toUpperCase();
    expect(inTile(next, find.text('Jun 10, 2026')), findsOneWidget);
    expect(inTile(next, find.text('Bollo di oggi · ${currency.format(60)}')), findsOneWidget);
  });

  test('nextPivaDeadline: the nearest unpaid day from today on, never a past, undated or paid one', () {
    final today = DateTime(2026, 6, 10);
    final overdue = _row('overdue', due: DateTime(2026, 6, 1), estimated: false, paymentId: 'a');
    final unrecorded = _row('unrecorded', due: DateTime(2026, 6, 5));
    final undated = _row('undated', estimated: false, paymentId: 'b');
    final paid = _row('paid', due: DateTime(2026, 6, 20), estimated: false, paid: DateTime(2026, 6, 2), paymentId: 'c');
    final later = _row('later', due: DateTime(2026, 9, 1));
    final dueToday = _row('today', due: DateTime(2026, 6, 10, 18));
    final nextYear = _row('next year', due: DateTime(2027, 1, 10));

    // Not in day order: the nearest wins, today included.
    final rows = [overdue, unrecorded, undated, paid, later, nextYear, dueToday];
    expect(nextPivaDeadline(rows, today), same(dueToday));
    expect(nextPivaDeadline([overdue, unrecorded, undated, paid, later, nextYear], today), same(later));
    expect(nextPivaDeadline([overdue, unrecorded, undated, paid], today), isNull);
    expect(nextPivaDeadline(const [], today), isNull);
    // Two on the same day: the first of the list.
    final twin = _row('twin', due: DateTime(2026, 9, 1));
    expect(nextPivaDeadline([twin, later], today), same(twin));
  });

  testWidgets('"Mark paid" on an estimate opens the sheet on its amount with "Paid" on, and writes nothing',
      (tester) async {
    final finance = await pump(tester, payments: [_overdue]);
    final estimate = calendar([_overdue]).firstWhere((r) => r.key == '2026:contributi_fissi2');

    await tester.tap(button('2026:contributi_fissi2'));
    await settle(tester);

    expect(find.byType(PivaDeadlineSheet), findsOneWidget);
    final sheet = tester.widget<PivaDeadlineSheet>(find.byType(PivaDeadlineSheet));
    expect(sheet.markPaid, isTrue);
    expect(sheet.deadline!.key, '2026:contributi_fissi2');
    expect(sheet.canRevert, isFalse); // an estimate has no saved row to take back
    expect(amountField(tester), pivaNumber(estimate.amount));
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
    expect(find.text('Jun 10, 2026'), findsOneWidget); // paid on: today
    expect(finance.saved, isEmpty);
  });

  testWidgets('"Mark paid" on an official one writes at once, paid today, and opens nothing', (tester) async {
    final finance = await pump(tester, payments: [_overdue]);

    await tester.tap(button('p-over'));
    await settle(tester);

    final s = finance.saved.single;
    expect(s.id, 'p-over');
    expect(s.key, '2026:contributi_fissi1');
    expect(s.kind, 'contributi');
    expect(s.label, 'Rata di maggio');
    expect(s.dueDate, DateTime(2026, 5, 18));
    expect(s.amount, 700);
    expect(s.paidDate, _now);
    expect(s.note, 'Dal commercialista');
    expect(find.byType(PivaDeadlineSheet), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('"Undo" writes the same row with no payment day, and opens nothing', (tester) async {
    final finance = await pump(tester, payments: [_paid]);

    await tester.tap(button('p-paid'));
    await settle(tester);

    final s = finance.saved.single;
    expect(s.id, 'p-paid');
    expect(s.key, '2026:contributi_fissi4');
    expect(s.kind, 'contributi');
    expect(s.label, 'Rata di febbraio');
    expect(s.dueDate, DateTime(2026, 2, 16));
    expect(s.amount, 500);
    expect(s.paidDate, isNull);
    expect(s.note, '');
    expect(find.byType(PivaDeadlineSheet), findsNothing);
  });

  testWidgets('a failing write says so in a SnackBar, never the exception, and the list stays', (tester) async {
    final finance = await pump(tester, payments: [_overdue], fail: true);

    await tester.tap(button('p-over'));
    await settle(tester);

    expect(finance.saved, hasLength(1));
    expect(find.text(en.pivaDlSaveError(en.errUnexpected)), findsOneWidget);
    expect(find.textContaining('disk full'), findsNothing);
    expect(row('p-over'), findsOneWidget);
    expect(find.widgetWithText(TextButton, en.pivaDlMarkPaid), findsWidgets);
  });

  testWidgets('the add button opens the sheet on a new deadline', (tester) async {
    await pump(tester);

    await tester.tap(find.text(en.pivaDlAdd));
    await settle(tester);

    expect(tester.widget<PivaDeadlineSheet>(find.byType(PivaDeadlineSheet)).deadline, isNull);
    expect(find.text(en.pivaDlNew), findsOneWidget);
  });

  for (final (id, canRevert) in [('p-over', true), ('p-int', false)]) {
    testWidgets('a tap on the row opens the sheet; "$id" ${canRevert ? 'can' : 'cannot'} go back to an estimate',
        (tester) async {
      await pump(tester, payments: [_overdue, _integrativo]);
      final label = id == 'p-over' ? 'Rata di maggio' : 'Contributo integrativo 2025';

      await tester.tap(inRow(id, find.text(label)));
      await settle(tester);

      final sheet = tester.widget<PivaDeadlineSheet>(find.byType(PivaDeadlineSheet));
      expect(sheet.deadline!.paymentId, id);
      expect(sheet.markPaid, isFalse);
      expect(sheet.canRevert, canRevert);
    });
  }

  test('canRevertToEstimate: only a saved row that replaces an estimate', () {
    final profile = _profile();
    bool canRevert(PivaPaymentData p) {
      final d = calendar([p]).firstWhere((r) => r.paymentId == p.id);
      return canRevertToEstimate(profile, const [], [p], d, _now);
    }

    // A saved row on the key of an estimate: take it away and the estimate is back.
    expect(canRevert(_payment('p1', key: '2026:contributi_fissi2', amount: 100)), isTrue);
    // Added by hand: no key, nothing to go back to.
    expect(canRevert(_payment('p2', label: 'Bollo')), isFalse);
    // A key the calendar no longer generates (four years back).
    expect(canRevert(_payment('p3', key: '2022:contributi_fissi2', due: DateTime(2022, 8, 22))), isFalse);
    // The integrativo of a profile that has none.
    expect(canRevert(_payment('p4', key: '2026:contributi_integrativo')), isFalse);
    // An estimate has no saved row.
    final estimate = calendar().firstWhere((r) => r.estimated);
    expect(estimate.paymentId, isNull);
    expect(canRevertToEstimate(profile, const [], const [], estimate, _now), isFalse);
  });

  testWidgets('a saved row with no day: "No date", last of the open ones, "Mark paid" writes, a tap opens it empty',
      (tester) async {
    final payments = [_noDate, _overdue, _integrativo];
    final finance = await pump(tester, payments: payments);
    final rows = calendar(payments);

    // Its place: after every open row that has a day, before the past estimates.
    expect(inRow('p-nodate', find.textContaining(en.pivaDlNoDate)), findsOneWidget);
    expect(top(tester, row('p-nodate')), greaterThan(top(tester, row('2027:contributi_fissi3'))));
    expect(top(tester, row('p-nodate')), lessThan(top(tester, find.text(en.pivaDlGroupUnrecorded))));
    // And nothing else went missing: one button per row.
    final buttons = find.widgetWithText(TextButton, en.pivaDlMarkPaid).evaluate().length +
        find.widgetWithText(TextButton, en.pivaDlUndoPaid).evaluate().length;
    expect(buttons, rows.length);

    await tester.tap(button('p-nodate'));
    await settle(tester);
    final s = finance.saved.single;
    expect(s.id, 'p-nodate');
    expect(s.key, '');
    expect(s.dueDate, isNull);
    expect(s.amount, 250);
    expect(s.paidDate, _now);
    expect(find.byType(PivaDeadlineSheet), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(inRow('p-nodate', find.text('Cartella senza data')));
    await settle(tester);
    expect(find.byType(PivaDeadlineSheet), findsOneWidget);
    expect(find.text(en.pivaDlPickDate), findsOneWidget); // the day field is empty
    expect(tester.widget<TextField>(find.widgetWithText(TextField, en.pivaDlLabel)).controller!.text, 'Cartella senza data');
  });

  testWidgets('a screen reader hears which deadline each button is for', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, payments: [_overdue, _paid]);

    expect(tester.getSemantics(button('p-over')).label, '${en.pivaDlMarkPaid}: Rata di maggio');
    expect(tester.getSemantics(button('p-paid')).label, '${en.pivaDlUndoPaid}: Rata di febbraio');
    final estimate = calendar([_overdue, _paid]).firstWhere((r) => r.key == '2026:contributi_fissi2');
    expect(tester.getSemantics(button('2026:contributi_fissi2')).label, '${en.pivaDlMarkPaid}: ${estimate.label}');
    handle.dispose();
  });

  for (final (width, scale, wide) in [(390.0, 1.0, true), (320.0, 1.0, false), (390.0, 2.0, false), (320.0, 2.0, false)]) {
    testWidgets('$width wide at text scale $scale: nothing overflows, tiles ${wide ? 'in a row' : 'stacked'}, targets of 48',
        (tester) async {
      await pump(
        tester,
        payments: [_overdue, _paid, _integrativo, _noDate],
        size: Size(width, 4000),
        textScale: scale,
      );

      expect(tester.takeException(), isNull);
      final tiles = find.byType(PivaTile);
      expect(tiles, findsNWidgets(3));
      final [a, b, c] = [for (var i = 0; i < 3; i++) tester.getRect(tiles.at(i))];
      if (wide) {
        expect(b.top, a.top);
        expect(c.top, a.top);
        expect(b.left, greaterThan(a.left));
        expect(c.left, greaterThan(b.left));
      } else {
        expect(b.top, greaterThanOrEqualTo(a.bottom));
        expect(c.top, greaterThanOrEqualTo(b.bottom));
      }
      // Every button, the row ones and the add one (a subclass: `is`, not `byType`).
      final buttons = find.byWidgetPredicate((w) => w is TextButton);
      expect(buttons.evaluate().length, greaterThan(1));
      for (var i = 0; i < buttons.evaluate().length; i++) {
        final size = tester.getSize(buttons.at(i));
        expect(size.height, greaterThanOrEqualTo(48), reason: 'button $i');
        expect(size.width, greaterThanOrEqualTo(48), reason: 'button $i');
      }
    });
  }
}
