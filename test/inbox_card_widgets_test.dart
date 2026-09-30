import 'dart:ffi' show DynamicLibrary;

import 'package:budgetti/core/database/database.dart'
    show
        AppDatabase,
        PendingTransaction,
        PendingTransactionsCompanion,
        TransactionsCompanion;
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/core/services/pending_transaction_service.dart';
import 'package:budgetti/features/transactions/add_transaction_modal.dart';
import 'package:budgetti/features/transactions/email_inbox_screen.dart';
import 'package:budgetti/features/transactions/widgets/amount_hero_field.dart';
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:budgetti/models/account.dart';
import 'package:budgetti/models/category.dart';
import 'package:budgetti/models/installment.dart';
import 'package:budgetti/models/tag.dart';
import 'package:budgetti/models/transaction.dart';
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
    String description = 'Coffee',
    String? duplicateOfId,
    List<Account> accounts = const [],
    Future<void> Function(AppDatabase db)? seed,
  }) async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    if (seed != null) await tester.runAsync(() => seed(db));
    await tester.runAsync(() => db.into(db.pendingTransactions).insert(
          PendingTransactionsCompanion.insert(
            id: 'pending_x',
            gmailMessageId: gmailMessageId,
            source: Value(source),
            rawSnippet: Value(rawSnippet),
            emailSubject: 'Hai pagato',
            emailReceivedAt: day,
            parsedAmount: amount,
            parsedDescription: description,
            parsedDate: day,
            createdAt: day,
            status: Value(status),
            suggestedType: Value(type),
            suggestedCategory: Value(suggestedCategory),
            duplicateOfId: Value(duplicateOfId),
            duplicateScore: Value(duplicateOfId == null ? null : 0.45),
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
        accountsProvider.overrideWith((ref) => Stream.value(accounts)),
        // What the add sheet opened by the pencil reads.
        financeServiceProvider.overrideWithValue(FinanceService(db, 'u')),
        transactionsProvider(null)
            .overrideWith((ref) => Stream.value(<Transaction>[])),
        tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
        installmentsProvider.overrideWith((ref) => Stream.value(<Installment>[])),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // The compare sheet reads the wallets without watching them, as in the
        // app, where the dashboard keeps them warm.
        home: Consumer(builder: (context, ref, _) {
          ref.watch(accountsProvider);
          return const EmailInboxScreen();
        }),
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

  // The stored amount of a non-euro push is the foreign figure read as if it
  // were euros. Showing it as euros, and booking it on a plain Approva, would put
  // a wrong amount in the ledger.
  group('a draft in a foreign currency', () {
    const foreign = 'Starbucks · 12,50 USD';

    testWidgets('shows its original currency in the header', (tester) async {
      await pumpInbox(tester, amount: -12.5, description: foreign);

      expect(find.text('−12,50 USD'), findsOneWidget);
      expect(find.textContaining('€'), findsNothing);
    });

    testWidgets('a euro draft is still shown in euros', (tester) async {
      await pumpInbox(tester, amount: -12.5, description: 'Starbucks');

      expect(find.text('-€12.50'), findsOneWidget);
    });

    testWidgets('plain Approve opens the edit sheet instead of booking',
        (tester) async {
      final db =
          await pumpInbox(tester, amount: -12.5, description: foreign);

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      expect(find.byType(AddTransactionModal), findsOneWidget);
      expect(amountField(tester), isEmpty); // the owner types the euro amount
      expect(find.widgetWithText(TextFormField, foreign), findsOneWidget);
      final rows = (await tester.runAsync(() async => (
            await db.select(db.transactions).get(),
            await db.select(db.pendingTransactions).get(),
          )))!;
      expect(rows.$1, isEmpty); // nothing booked
      expect(rows.$2.single.status, 'pending'); // and still to review
    });

    testWidgets('the pencil opens the same empty-amount sheet', (tester) async {
      await pumpInbox(tester, amount: -12.5, description: foreign);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(amountField(tester), isEmpty);
    });
  });

  // The twin of a Revolut top-up can be the owner's own Widiba -> Revolut
  // transfer: its amount is positive, its wallet is the SOURCE, and it names two
  // wallets. The notice and the compare sheet must read sensibly for it.
  group('a draft flagged against a transfer', () {
    Account wallet(String id, String name) => Account(
        id: id, name: name, balance: 0, currency: 'EUR', providerName: '');

    Future<AppDatabase> pumpFlagged(WidgetTester tester) => pumpInbox(
          tester,
          amount: 100,
          type: 'income',
          description: 'Pagamento da ROSSI MARIO',
          duplicateOfId: 'tr',
          accounts: [wallet('wid', 'Widiba'), wallet('rev', 'Revolut')],
          seed: (db) => db.into(db.transactions).insert(
                TransactionsCompanion.insert(
                  id: 'tr',
                  accountId: const Value('wid'),
                  toAccountId: const Value('rev'),
                  amount: 100,
                  description: 'Giroconto verso conto secondario',
                  category: 'Transfer',
                  type: const Value('transfer'),
                  date: DateTime(2026, 6, 21, 9),
                ),
              ),
        );

    testWidgets('shows the notice with the transfer, unsigned', (tester) async {
      await pumpFlagged(tester);

      expect(find.text('Possibly already recorded'), findsOneWidget);
      expect(find.textContaining('"Giroconto verso conto secondario"'),
          findsOneWidget);
      expect(find.textContaining('€100.00'), findsWidgets);
    });

    testWidgets('the compare sheet names both wallets of the transfer',
        (tester) async {
      await pumpFlagged(tester);

      await tester.tap(find.text('Possibly already recorded'));
      await tester.pumpAndSettle();

      expect(find.text('Already in the account'), findsOneWidget);
      expect(find.textContaining('Widiba → Revolut'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('"Yes, it\'s the same" rejects the draft', (tester) async {
      final db = await pumpFlagged(tester);
      await tester.tap(find.text('Possibly already recorded'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yes, it\'s the same'));
      await tester.pumpAndSettle();

      final status = (await tester.runAsync(
              () => db.select(db.pendingTransactions).getSingle()))!
          .status;
      expect(status, 'rejected');
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
