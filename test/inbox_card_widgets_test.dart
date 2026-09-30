import 'dart:ffi' show DynamicLibrary;

import 'package:budgetti/core/database/database.dart'
    show AppDatabase, PendingTransaction, PendingTransactionsCompanion;
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/core/services/pending_transaction_service.dart';
import 'package:budgetti/features/transactions/email_inbox_screen.dart';
import 'package:budgetti/features/transactions/widgets/amount_hero_field.dart';
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:budgetti/models/account.dart';
import 'package:budgetti/models/category.dart';
import 'package:budgetti/models/installment.dart';
import 'package:budgetti/models/tag.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
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

/// The inbox card as the owner meets it: the category chip and the
/// edit-and-approve pencil. Rendering only — booking is covered against the
/// service in pending_transaction_service_test.dart.
void main() {
  setUpAll(() {
    _ensureSqlite();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final currency = NumberFormat.simpleCurrency(name: 'EUR', locale: 'en_US');
  final day = DateTime(2026, 6, 24, 19, 3);

  Category category(String name) => Category(
        id: 'cat_$name',
        userId: 'u',
        name: name,
        iconCode: 0,
        colorHex: 0,
        type: 'expense',
      );

  /// One draft in the inbox, backed by a real in-memory database so taps that
  /// write (the chip) land somewhere the test can read back.
  Future<AppDatabase> pumpInbox(
    WidgetTester tester, {
    String status = 'pending',
    double amount = -10,
    String type = 'expense',
    String? suggestedCategory,
    String source = 'revolut',
    String gmailMessageId = 'x',
    String rawSnippet = '',
  }) async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.runAsync(() => db.into(db.pendingTransactions).insert(
          PendingTransactionsCompanion.insert(
            id: 'pending_x',
            gmailMessageId: gmailMessageId,
            source: Value(source),
            rawSnippet: Value(rawSnippet),
            emailSubject: 'Hai pagato',
            emailReceivedAt: day,
            parsedAmount: amount,
            parsedDescription: 'Coffee',
            parsedDate: day,
            createdAt: day,
            status: Value(status),
            suggestedType: Value(type),
            suggestedCategory: Value(suggestedCategory),
          ),
        ));
    final row = (await tester.runAsync(
            () => db.select(db.pendingTransactions).getSingle()))!;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        currencyProvider.overrideWithValue(currency),
        pendingTransactionServiceProvider.overrideWithValue(
            PendingTransactionService(db, FinanceService(db, 'u'))),
        pendingTransactionsProvider.overrideWith((ref) =>
            Stream.value(status == 'pending' ? [row] : <PendingTransaction>[])),
        skippedEmailsProvider.overrideWith((ref) =>
            Stream.value(status == 'skipped' ? [row] : <PendingTransaction>[])),
        categoriesProvider.overrideWith((ref) =>
            Stream.value([category('Spesa'), category('Treats')])),
        accountsProvider.overrideWith((ref) => Stream.value(<Account>[])),
        // What the add sheet opened by the pencil reads.
        financeServiceProvider.overrideWithValue(FinanceService(db, 'u')),
        tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
        installmentsProvider.overrideWith((ref) => Stream.value(<Installment>[])),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const EmailInboxScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    return db;
  }

  String amountField(WidgetTester tester) => tester
      .widget<TextField>(find.descendant(
          of: find.byType(AmountHeroField), matching: find.byType(TextField)))
      .controller!
      .text;

  Future<String?> storedCategory(WidgetTester tester, AppDatabase db) async =>
      (await tester.runAsync(() => db.select(db.pendingTransactions).getSingle()))!
          .suggestedCategory;

  group('category chip', () {
    testWidgets('a suggested category shows on the chip', (tester) async {
      await pumpInbox(tester, suggestedCategory: 'Spesa');

      expect(find.text('Spesa'), findsOneWidget);
    });

    testWidgets('with nothing suggested the chip is still there to tap',
        (tester) async {
      await pumpInbox(tester);

      expect(find.text('Category'), findsOneWidget);
    });

    testWidgets('tapping it opens the picker; the pick is stored on the draft',
        (tester) async {
      final db = await pumpInbox(tester, suggestedCategory: 'Spesa');

      await tester.tap(find.text('Spesa'));
      await tester.pumpAndSettle();
      expect(find.text('Treats'), findsOneWidget); // the picker's other row

      await tester.tap(find.text('Treats'));
      await tester.pumpAndSettle();

      expect(await storedCategory(tester, db), 'Treats');
    });
  });

  // What the push actually said, so a wrong merchant or amount is visible
  // without opening anything — but only where the snippet is readable: a Widiba
  // draft's snippet is the email greeting, a statement row's is a CSV line.
  // A message the parser couldn't read is the owner's only source for teaching
  // it the template: the text has to be copyable.
  testWidgets('the unreadable-message dialog shows selectable text',
      (tester) async {
    await pumpInbox(tester,
        status: 'skipped',
        amount: 0,
        type: 'undecided',
        rawSnippet: 'Revolut ⟂ Pagamento in elaborazione');

    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    final text = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(text.data, 'Revolut ⟂ Pagamento in elaborazione');
  });

  group('raw text under the description', () {
    const push = 'Revolut ⟂ Hai speso €12,50 presso LO CHEF';

    testWidgets('a Revolut notification shows its text, joined with dots',
        (tester) async {
      await pumpInbox(tester, gmailMessageId: 'rev_ab12', rawSnippet: push);

      expect(find.text('Revolut · Hai speso €12,50 presso LO CHEF'),
          findsOneWidget);
      expect(find.textContaining('⟂'), findsNothing);
    });

    testWidgets('it is capped at two lines', (tester) async {
      await pumpInbox(tester,
          gmailMessageId: 'rev_ab12', rawSnippet: 'Revolut ⟂ ${'lungo ' * 80}');

      final text = tester.widget<Text>(find.textContaining('Revolut · lungo'));
      expect((text.maxLines, text.overflow), (2, TextOverflow.ellipsis));
    });

    testWidgets('a statement row shows no snippet', (tester) async {
      await pumpInbox(tester,
          gmailMessageId: 'revcsv_ab12', rawSnippet: '24 giu 2026,Conad,-12,26€');

      expect(find.textContaining('Conad'), findsNothing);
    });

    testWidgets('a Widiba draft shows no snippet', (tester) async {
      await pumpInbox(tester,
          source: 'widiba', gmailMessageId: 'g1', rawSnippet: 'Ciao Matteo, hai');

      expect(find.textContaining('Ciao Matteo'), findsNothing);
    });
  });

  group('edit-and-approve pencil', () {
    testWidgets('a draft offers it between Ignore and Approve', (tester) async {
      await pumpInbox(tester);

      expect(find.byTooltip('Edit and approve'), findsOneWidget);
      final pencil = tester.getCenter(find.byIcon(Icons.edit_outlined));
      expect(tester.getCenter(find.text('Ignore')).dx, lessThan(pencil.dx));
      expect(pencil.dx, lessThan(tester.getCenter(find.text('Approve')).dx));
    });

    testWidgets('the three actions fit a narrow phone without overflowing',
        (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await pumpInbox(tester, suggestedCategory: 'Spesa');

      // A RenderFlex overflow would have failed the pump above.
      expect(tester.takeException(), isNull);
      expect(find.text('Approve'), findsOneWidget);
    });

    testWidgets('an unrecognised message offers it too', (tester) async {
      await pumpInbox(tester, status: 'skipped', amount: 0, type: 'undecided');

      expect(find.byTooltip('Edit and approve'), findsOneWidget);
    });

    testWidgets('it opens the add sheet already filled from the draft',
        (tester) async {
      await pumpInbox(tester);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Coffee'), findsOneWidget);
      expect(amountField(tester), '10.00');
    });

    testWidgets('an unrecognised message opens with an empty amount',
        (tester) async {
      await pumpInbox(tester, status: 'skipped', amount: 0, type: 'undecided');

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(amountField(tester), isEmpty);
      expect(find.widgetWithText(TextFormField, 'Coffee'), findsOneWidget);
    });
  });
}
