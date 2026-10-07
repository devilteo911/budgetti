import 'dart:ffi' show DynamicLibrary;

import 'package:budgetti/core/database/database.dart' show AppDatabase;
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/features/piva/piva_deadline_sheet.dart';
import 'package:budgetti/features/piva/piva_format.dart' show pivaNoBreak;
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:budgetti/l10n/app_localizations_en.dart';
import 'package:budgetti/models/piva.dart' show PivaDeadline;
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

/// What the sheet asked `savePivaPayment` to write.
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

/// The real service over an in-memory database, recording the writes the sheet
/// asks for. [fail] makes them throw, as a full disk would.
class _Finance extends FinanceService {
  _Finance(super.db, super.userId, {this.fail = false});

  final bool fail;
  final saved = <_Saved>[];
  final deleted = <String>[];

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
    await super.savePivaPayment(
      id: id,
      key: key,
      kind: kind,
      label: label,
      dueDate: dueDate,
      amount: amount,
      paidDate: paidDate,
      note: note,
    );
  }

  @override
  Future<void> deletePivaPayment(String id) async {
    deleted.add(id);
    if (fail) throw StateError('disk full');
    await super.deletePivaPayment(id);
  }
}

// The sheet's own clock: every date below is relative to it.
final _today = DateTime(2026, 6, 10);

const _saveFailed = "Couldn't save the deadline. Something went wrong. Try again.";
const _deleteFailed = "Couldn't remove the deadline. Something went wrong. Try again.";

/// A made-up calendar row: by default the estimated tax balance due 30 June.
PivaDeadline row({
  String key = '2026:imposta_saldo',
  String kind = 'imposta',
  String label = 'Imposta sostitutiva · Saldo 2025',
  bool dated = true,
  double amount = 1234.5,
  bool estimated = true,
  DateTime? paid,
  String? paymentId,
  String note = '',
}) => PivaDeadline(
  key: key,
  kind: kind,
  label: label,
  dueDate: dated ? DateTime(2026, 6, 30) : null,
  amount: amount,
  estimated: estimated,
  paidDate: paid,
  paymentId: paymentId,
  note: note,
);

/// The deadline sheet: what it shows for an estimate, a saved row and a new
/// deadline, the first broken rule inside it, what a save writes, the
/// destructive button and its confirmation, the failed write and the discard
/// guard. The engine's rules are `piva_test.dart`'s.
void main() {
  setUpAll(() {
    _ensureSqlite();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final en = AppLocalizationsEn();

  /// Waits for every font asked for so far, then for the frames that follow.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(GoogleFonts.pendingFonts);
    await tester.pumpAndSettle();
    await tester.runAsync(GoogleFonts.pendingFonts);
  }

  /// The sheet as a routed page (its save pops through GoRouter) over an
  /// in-memory database. [shown] is what the route builds the sheet from: a test
  /// that sets it plays a sync changing the row under an open sheet.
  Future<({AppDatabase db, _Finance finance, ValueNotifier<PivaDeadline?> shown})> pump(
    WidgetTester tester, {
    PivaDeadline? deadline,
    bool markPaid = false,
    bool canRevert = false,
    bool fail = false,
    Size size = const Size(390, 4000),
  }) async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final finance = _Finance(db, 'u', fail: fail);
    final shown = ValueNotifier<PivaDeadline?>(deadline);
    addTearDown(shown.dispose);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold()),
      GoRoute(
        path: '/sheet',
        builder: (_, __) => Scaffold(
          body: ValueListenableBuilder<PivaDeadline?>(
            valueListenable: shown,
            builder: (_, d, __) => PivaDeadlineSheet(
              deadline: d,
              markPaid: markPaid,
              canRevert: canRevert,
              now: _today,
            ),
          ),
        ),
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        financeServiceProvider.overrideWithValue(finance),
        currencyProvider.overrideWithValue(NumberFormat.simpleCurrency(name: 'EUR', locale: 'en_US')),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        // The app's own theme: its filled, borderless inputs float their label
        // over the field's top edge, which the default theme does not.
        theme: AppTheme.buildTheme(palette: AppPalette.values.first, brightness: Brightness.dark),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();
    router.push('/sheet');
    await settle(tester);
    return (db: db, finance: finance, shown: shown);
  }

  final save = find.byType(ElevatedButton);
  Finder field(String label) => find.widgetWithText(TextField, label);
  String textOf(WidgetTester tester, String label) => tester.widget<TextField>(field(label)).controller!.text;

  Future<void> type(WidgetTester tester, String label, String text) async {
    await tester.enterText(field(label), text);
    await tester.pump();
  }

  testWidgets('an estimate opened to mark paid: its amount, today, no destructive button; saving freezes it',
      (tester) async {
    final h = await pump(tester, deadline: row(), markPaid: true);

    // The shortest form, whether or not it is an estimate: this is what "save
    // freezes it as the official amount" means.
    expect(textOf(tester, en.pivaDlAmount), '1234.5');
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
    expect(find.text(en.pivaDlPaidOnLabel), findsOneWidget);
    expect(find.text('Jun 10, 2026'), findsOneWidget); // paid on: the injected today
    expect(find.text('Jun 30, 2026'), findsOneWidget); // due on
    expect(find.text(en.commonDelete), findsNothing);
    expect(find.text(en.pivaDlBackToEstimate), findsNothing);

    await tester.tap(save);
    await tester.pumpAndSettle();

    final s = h.finance.saved.single;
    expect(s.id, isNull);
    expect(s.key, '2026:imposta_saldo');
    expect(s.kind, 'imposta');
    expect(s.label, 'Imposta sostitutiva · Saldo 2025');
    expect(s.amount, 1234.5);
    expect(s.dueDate, DateTime(2026, 6, 30));
    expect(s.paidDate, DateTime(2026, 6, 10));
    expect(find.byType(PivaDeadlineSheet), findsNothing);

    // The real service wrote it, both days at local noon.
    final rows = (await tester.runAsync(() => h.db.select(h.db.pivaPayments).get()))!;
    expect(rows, hasLength(1));
    expect(rows.single.key, '2026:imposta_saldo');
    expect(rows.single.amount, 1234.5);
    expect(rows.single.paidDate, DateTime(2026, 6, 10, 12));
  });

  for (final text in ['', 'abc', '-5']) {
    testWidgets("the amount '$text' is refused inside the sheet and writes nothing", (tester) async {
      final h = await pump(tester, deadline: row());

      await type(tester, en.pivaDlAmount, text);
      await tester.tap(save);
      await tester.pump();

      expect(find.text(en.pivaDlErrAmount), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing); // it would be drawn under the sheet
      expect(h.finance.saved, isEmpty);
      expect(find.byType(PivaDeadlineSheet), findsOneWidget);

      await type(tester, en.pivaDlAmount, '1');
      expect(find.text(en.pivaDlErrAmount), findsNothing);
    });
  }

  for (final (text, want) in [('0', 0.0), ('1.234,56', 1234.56)]) {
    testWidgets("the amount '$text' is written as $want (zero is an answer)", (tester) async {
      final h = await pump(tester, deadline: row());

      await type(tester, en.pivaDlAmount, text);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(h.finance.saved.single.amount, want);
      expect(find.byType(PivaDeadlineSheet), findsNothing);
    });
  }

  testWidgets('a new deadline asks for the day before it asks for the label, and the amount before both',
      (tester) async {
    final h = await pump(tester);
    expect(find.text(en.pivaDlNew), findsOneWidget);
    expect(find.text(en.pivaDlPickDate), findsOneWidget);

    await tester.tap(save);
    await tester.pump();
    expect(find.text(en.pivaDlErrAmount), findsOneWidget);

    await type(tester, en.pivaDlAmount, '10');
    await tester.tap(save);
    await tester.pump();

    expect(find.text(en.pivaDlErrDue), findsOneWidget);
    expect(find.text(en.pivaDlErrLabel), findsNothing);
    expect(h.finance.saved, isEmpty);
  });

  testWidgets('a saved row with no day opens on the prompt and refuses to save until one is picked',
      (tester) async {
    final h = await pump(tester, deadline: row(dated: false, estimated: false, paymentId: 'p1'));

    expect(find.text(en.pivaDlPickDate), findsOneWidget);
    await tester.tap(save);
    await tester.pump();

    expect(find.text(en.pivaDlErrDue), findsOneWidget);
    expect(h.finance.saved, isEmpty);
  });

  testWidgets('a hand-made deadline with a label of spaces is refused', (tester) async {
    final h = await pump(tester, deadline: row(key: '', label: 'Bollo', estimated: false, paymentId: 'p1'));

    await type(tester, en.pivaDlLabel, '   ');
    await tester.tap(save);
    await tester.pump();

    expect(find.text(en.pivaDlErrLabel), findsOneWidget);
    expect(h.finance.saved, isEmpty);
  });

  testWidgets('a new deadline: the picker sets the day, the row is saved as a hand-made one', (tester) async {
    final h = await pump(tester);
    await type(tester, en.pivaDlLabel, 'Bollo');
    await type(tester, en.pivaDlAmount, '25');

    await tester.tap(find.text(en.pivaDlPickDate));
    await tester.pumpAndSettle();
    // The picker opens on the injected today, in June 2026.
    await tester.tap(find.text('15'));
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Jun 15, 2026'), findsOneWidget);

    await tester.tap(save);
    await tester.pumpAndSettle();

    final s = h.finance.saved.single;
    expect(s.id, isNull);
    expect(s.key, '');
    expect(s.kind, 'imposta');
    expect(s.label, 'Bollo');
    expect(s.amount, 25);
    expect(s.dueDate, DateTime(2026, 6, 15));
    expect(s.paidDate, isNull);
    expect(find.byType(PivaDeadlineSheet), findsNothing);
  });

  for (final (stored, written) in [
    ('', 'imposta'),
    ('imposta', 'imposta'),
    ('contributi', 'contributi'),
    ('rata', 'imposta'),
  ]) {
    testWidgets("a hand-made deadline whose kind is '$stored' is read, and saved, as '$written'", (tester) async {
      final h = await pump(
        tester,
        deadline: row(key: '', kind: stored, label: 'Bollo', estimated: false, paymentId: 'p1'),
      );

      await tester.tap(save);
      await tester.pumpAndSettle();

      final s = h.finance.saved.single;
      expect(s.kind, written);
      expect(s.id, 'p1');
      expect(s.key, '');
      expect(s.label, 'Bollo');
    });
  }

  testWidgets('the kind dropdown decides what is written', (tester) async {
    final h = await pump(tester, deadline: row(key: '', label: 'Bollo', estimated: false, paymentId: 'p1'));

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    // The open menu is the last place the name is drawn.
    await tester.tap(find.text('Contributi').last);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(h.finance.saved.single.kind, 'contributi');
  });

  for (final (key, kind, shown) in [
    ('2026:imposta_saldo', 'imposta', 'Imposta'),
    ('2026:contributi_saldo', 'contributi', 'Contributi'),
    ('2026:contributi_integrativo', 'contributi', 'Integrativo · pass-through, not deductible'),
  ]) {
    testWidgets("a calendar deadline ($key) shows its label and kind as plain text", (tester) async {
      await pump(tester, deadline: row(key: key, kind: kind, label: 'Etichetta del motore'));

      expect(find.text(en.pivaDlEdit), findsOneWidget);
      expect(find.text('Etichetta del motore'), findsOneWidget);
      expect(find.text(shown), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(field(en.pivaDlLabel), findsNothing);
    });
  }

  for (final (PivaDeadline? deadline, bool autofocus) in <(PivaDeadline?, bool)>[
    (null, true),
    (row(key: '', label: 'Bollo', estimated: false, paymentId: 'p1'), false),
  ]) {
    testWidgets('a deadline with no key has the kind dropdown and the label field (autofocus: $autofocus)',
        (tester) async {
      await pump(tester, deadline: deadline);

      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(tester.widget<TextField>(field(en.pivaDlLabel)).autofocus, autofocus);
    });
  }

  testWidgets('an already paid deadline opens with Paid on and its day; switching it off saves it unpaid',
      (tester) async {
    final h = await pump(
      tester,
      deadline: row(estimated: false, paymentId: 'p1', paid: DateTime(2026, 6, 1)),
    );

    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
    expect(find.text('Jun 1, 2026'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.text(en.pivaDlPaidOnLabel), findsNothing);

    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(h.finance.saved.single.id, 'p1');
    expect(h.finance.saved.single.paidDate, isNull);
  });

  for (final (canRevert, action, title) in [
    (true, 'Back to estimate', 'Back to the estimate?'),
    (false, 'Delete', 'Delete this deadline?'),
  ]) {
    testWidgets('a saved row with canRevert: $canRevert has "$action"; Cancel writes nothing, the confirmation deletes',
        (tester) async {
      final h = await pump(tester, deadline: row(estimated: false, paymentId: 'p1'), canRevert: canRevert);
      final button = find.widgetWithText(TextButton, action);
      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);

      await tester.tap(find.text(en.commonCancel));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(PivaDeadlineSheet), findsOneWidget);
      expect(h.finance.deleted, isEmpty);
      expect(h.finance.saved, isEmpty);

      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(action)));
      await tester.pumpAndSettle();

      expect(h.finance.deleted, ['p1']);
      expect(h.finance.saved, isEmpty);
      expect(find.byType(PivaDeadlineSheet), findsNothing);
    });
  }

  testWidgets('a failing save says so inside the sheet, keeps the form and never prints the exception',
      (tester) async {
    final h = await pump(tester, deadline: row(), fail: true);
    await type(tester, en.pivaDlNote, 'keep me');

    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text(_saveFailed), findsOneWidget);
    expect(find.textContaining('disk full'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(PivaDeadlineSheet), findsOneWidget);
    expect(textOf(tester, en.pivaDlNote), 'keep me');
    expect(h.finance.saved, hasLength(1));

    // Not stuck "saving": the button works again.
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(h.finance.saved, hasLength(2));
  });

  testWidgets('a failing delete says so inside the sheet and leaves it open', (tester) async {
    final h = await pump(tester, deadline: row(estimated: false, paymentId: 'p1'), fail: true);

    await tester.tap(find.widgetWithText(TextButton, en.commonDelete));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(en.commonDelete)));
    await tester.pumpAndSettle();

    expect(find.text(_deleteFailed), findsOneWidget);
    expect(find.textContaining('disk full'), findsNothing);
    expect(find.byType(PivaDeadlineSheet), findsOneWidget);
    expect(h.finance.deleted, ['p1']);
  });

  testWidgets('a sync changing the row under an open sheet does not touch what is being typed', (tester) async {
    final h = await pump(tester, deadline: row());
    await type(tester, en.pivaDlAmount, '99');

    h.shown.value = row(amount: 500, note: 'from the server', label: 'Another label');
    await tester.pump();

    expect(textOf(tester, en.pivaDlAmount), '99');
    expect(textOf(tester, en.pivaDlNote), '');
    expect(find.text(pivaNoBreak('Imposta sostitutiva · Saldo 2025')), findsOneWidget);
    expect(find.text('Another label'), findsNothing);
  });

  testWidgets('Save, the destructive button and the error stay on screen on a phone-sized sheet', (tester) async {
    // 390 × 700, not 4000: the form scrolls, the buttons and the message must not.
    await pump(
      tester,
      size: const Size(390, 700),
      deadline: row(estimated: false, paymentId: 'p1'),
      canRevert: true,
    );
    final screen = tester.view.physicalSize;
    final revert = find.widgetWithText(TextButton, en.pivaDlBackToEstimate);

    expect(tester.getRect(save).bottom, lessThanOrEqualTo(screen.height));
    expect(tester.getRect(revert).bottom, lessThanOrEqualTo(screen.height));

    await type(tester, en.pivaDlAmount, 'abc');
    await tester.tap(save);
    await tester.pump();
    await tester.pump();

    expect(find.text(en.pivaDlErrAmount), findsOneWidget);
    final button = tester.getRect(save);
    expect(button.bottom, lessThanOrEqualTo(screen.height));
    expect(tester.getRect(revert).bottom, lessThanOrEqualTo(screen.height));
    // The message sits right above the button, in view.
    final message = tester.getRect(find.text(en.pivaDlErrAmount));
    expect(message.bottom, lessThanOrEqualTo(button.top));
    expect(message.top, greaterThan(0));
    // Touch targets.
    expect(button.height, greaterThanOrEqualTo(48));
    expect(tester.getSize(revert).height, greaterThanOrEqualTo(48));
  });

  // A floating label rides ~6 dp above its field's top edge, over whatever is
  // above: it must clear the heading, the switch row and the field above it.
  testWidgets('no floating label touches the heading, the switch row or a field above it', (tester) async {
    await pump(tester, markPaid: true, size: const Size(390, 1400));

    final heading = tester.getRect(find.text(en.pivaDlNew));
    final switchRow = tester.getRect(find.text(en.pivaDlPaid));
    final fields = tester
        .widgetList<InputDecorator>(find.byType(InputDecorator))
        .map((d) => tester.getRect(find.byWidget(d)))
        .toList()
      ..sort((a, b) => a.top.compareTo(b.top));

    // kind, label, amount, due on, note and the paid-on day.
    expect(fields, hasLength(6));
    expect(fields.first.top - 6 - heading.bottom, greaterThanOrEqualTo(12), reason: 'heading → first field');
    expect(fields.last.top - 6 - switchRow.bottom, greaterThanOrEqualTo(12), reason: 'switch row → paid on');
    for (var i = 1; i < fields.length; i++) {
      expect(fields[i].top - 6 - fields[i - 1].bottom, greaterThanOrEqualTo(4), reason: 'field $i');
    }
  });

  testWidgets('closing a form with edits asks first', (tester) async {
    await pump(tester, deadline: row());
    await type(tester, en.pivaDlNote, 'x');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.byType(PivaDeadlineSheet), findsOneWidget);
  });

  testWidgets('opened to mark paid and left alone, it closes at once', (tester) async {
    await pump(tester, deadline: row(), markPaid: true);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.byType(PivaDeadlineSheet), findsNothing);
  });
}
