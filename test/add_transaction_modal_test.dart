import 'dart:ffi' show DynamicLibrary;

import 'package:budgetti/core/database/database.dart'
    show AppDatabase, CategoriesCompanion, TransactionsCompanion;
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/features/transactions/add_transaction_modal.dart';
import 'package:budgetti/features/transactions/widgets/amount_hero_field.dart';
import 'package:budgetti/features/transactions/widgets/ledger_field_row.dart';
import 'package:budgetti/features/transactions/widgets/type_selector.dart';
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
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

void main() {
  setUpAll(() {
    _ensureSqlite();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final day = DateTime(2026, 6, 24);

  Category category(String name, String type) => Category(
        id: 'cat_$name',
        userId: 'u',
        name: name,
        iconCode: 0,
        colorHex: 0,
        type: type,
      );

  Transaction tx({
    String accountId = 'w1',
    double amount = -10,
    String type = 'expense',
    String category = 'Dining',
    double othersShare = 0,
    String? reimbursesId,
  }) =>
      Transaction(
        id: 't1',
        accountId: accountId,
        amount: amount,
        date: day,
        description: 'Coffee',
        category: category,
        type: type,
        othersShare: othersShare,
        reimbursesId: reimbursesId,
      );

  /// The sheet as a routed page (its save pops through GoRouter), over the real
  /// providers except the data streams. [onSave] intercepts what the sheet
  /// built, so the tests read exactly what would have been written.
  Future<GoRouter> pump(
    WidgetTester tester, {
    Transaction? transaction,
    Transaction? prefill,
    List<Transaction> history = const [],
    List<Transaction> shared = const [],
    // Read the shared rows from the database (seed them) instead of [shared],
    // for the cases that write a link and watch the sheet follow.
    bool liveShare = false,
    List<Account>? accounts,
    Future<void> Function(AppDatabase db)? seed,
    Future<void> Function(Transaction)? onSave,
  }) async {
    SharedPreferences.setMockInitialValues({'notifications_enabled': false});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    tester.view.physicalSize = const Size(800, 2400);
    addTearDown(tester.view.reset);
    if (seed != null) await tester.runAsync(() => seed(db));

    final router = GoRouter(routes: [
      // Watches what the sheet reads, so those providers are warm (as they are
      // in the app, behind the dashboard) when the sheet opens.
      GoRoute(
        path: '/',
        builder: (_, __) => Consumer(builder: (context, ref, _) {
          ref.watch(categoriesProvider);
          ref.watch(accountsProvider);
          ref.watch(transactionsProvider(null));
          return const Scaffold();
        }),
      ),
      GoRoute(
        path: '/edit',
        builder: (_, __) => Scaffold(
          body: AddTransactionModal(
            transaction: transaction,
            prefill: prefill,
            onSave: onSave ?? (_) async {},
          ),
        ),
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        transactionsProvider(null)
            .overrideWith((ref) => Stream.value(history)),
        if (!liveShare)
          shareTransactionsProvider
              .overrideWith((ref) => Stream.value(shared)),
        currencyProvider.overrideWithValue(
            NumberFormat.simpleCurrency(name: 'EUR', locale: 'en_US')),
        financeServiceProvider.overrideWithValue(FinanceService(db, 'u')),
        accountsProvider.overrideWith((ref) => Stream.value(accounts ??
            [
              Account(
                  id: 'w1',
                  name: 'Revolut',
                  balance: 0,
                  currency: 'EUR',
                  providerName: ''),
            ])),
        categoriesProvider.overrideWith((ref) => Stream.value([
              category('Dining', 'expense'),
              category('Spesa', 'expense'),
              category('Treats', 'expense'),
              category('Freelance', 'income'),
              category('Salary', 'income'),
            ])),
        tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
        installmentsProvider
            .overrideWith((ref) => Stream.value(<Installment>[])),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();
    router.push('/edit');
    await tester.pumpAndSettle();
    return router;
  }

  // The label has to be what will be saved. A row whose category is not among
  // the options (deleted, the "Uncategorized" placeholder) used to show the FIRST
  // option while an untouched save kept the stored name: the label lied.
  group('the category row of an existing transaction shows what is stored', () {
    Finder categoryRow(String name) => find.descendant(
        of: find.byType(AddTransactionModal), matching: find.text(name));

    testWidgets('a deleted category', (tester) async {
      await pump(tester, transaction: tx(category: 'Groceries'));

      expect(categoryRow('Groceries'), findsOneWidget);
      expect(categoryRow('Dining'), findsNothing); // the first option
    });

    testWidgets('the Uncategorized placeholder', (tester) async {
      await pump(tester, transaction: tx(category: 'Uncategorized'));

      expect(categoryRow('Uncategorized'), findsOneWidget);
      expect(categoryRow('Dining'), findsNothing);
    });

    testWidgets('a category in the list is shown as before', (tester) async {
      await pump(tester, transaction: tx(category: 'Treats'));

      expect(categoryRow('Treats'), findsOneWidget);
    });

    testWidgets('picking from the list still replaces it', (tester) async {
      Transaction? saved;
      await pump(tester,
          transaction: tx(category: 'Groceries'), onSave: (t) async => saved = t);

      await tester.tap(categoryRow('Groceries'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Treats'));
      await tester.pumpAndSettle();
      expect(categoryRow('Treats'), findsOneWidget);
      await tester.tap(find.text('UPDATE'));
      await tester.pumpAndSettle();

      expect(saved?.category, 'Treats');
    });

    testWidgets('a new sheet still starts on the default', (tester) async {
      await pump(tester);

      expect(categoryRow('Dining'), findsOneWidget);
    });
  });

  // Every field row is closed by a hairline. The transfer layout instead put a
  // thin one-sided stub between FROM and TO and no line under FROM, so the pair
  // looked unfinished next to every other row.
  group('the transfer layout', () {
    testWidgets('has a divider between its two wallet rows, like every other row',
        (tester) async {
      await pump(tester);
      await tester.tap(find.text('TRANSFER'));
      await tester.pumpAndSettle();

      final from = tester.getCenter(find.text('FROM')).dy;
      final to = tester.getCenter(find.text('TO')).dy;
      final between = [
        for (final e in tester.elementList(find.byType(LedgerDivider)))
          tester.getCenter(find.byWidget(e.widget)).dy,
      ].where((y) => y > from && y < to);

      expect(between, hasLength(1));
    });

    testWidgets('closes the note, both wallets and the date the same way',
        (tester) async {
      await pump(tester);
      await tester.tap(find.text('TRANSFER'));
      await tester.pumpAndSettle();

      // note | FROM | TO | date — one hairline under each.
      expect(find.byType(LedgerDivider), findsNWidgets(4));
    });
  });

  /// A message drawn inside the sheet. A SnackBar is not an option while the
  /// sheet is open: the root ScaffoldMessenger draws it BEHIND the sheet, so the
  /// owner only sees the sheet refusing to close.
  Finder inlineMessage(String text) =>
      find.descendant(of: find.byType(AddTransactionModal), matching: find.text(text));

  // The save had try/finally and no catch: a service exception escaped the tap
  // handler, the sheet stayed open and nothing on screen said the save failed.
  testWidgets('a failing save says so and leaves the sheet open, ready to retry',
      (tester) async {
    var calls = 0;
    await pump(tester, prefill: tx(), onSave: (_) async {
      calls++;
      throw StateError('disk full');
    });

    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(inlineMessage('Error: Something went wrong. Try again.'),
        findsOneWidget);
    expect(find.byType(SnackBar), findsNothing); // it would be under the sheet
    expect(find.byType(AddTransactionModal), findsOneWidget);

    // Not stuck "saving": the button works again.
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  group('validation errors are shown inside the sheet', () {
    const noDestination = 'Please select a different destination wallet';

    Transaction transfer({String? to}) => Transaction(
          id: 't2',
          accountId: 'w1',
          toAccountId: to,
          amount: 30,
          date: day,
          description: 'Move',
          category: 'Transfer',
          type: 'transfer',
        );

    testWidgets('a new transfer with no destination', (tester) async {
      var saves = 0;
      await pump(tester, onSave: (_) async => saves++);
      await tester.tap(find.text('TRANSFER'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), '5');
      await tester.enterText(find.byType(TextFormField).at(1), 'Move');

      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      expect(inlineMessage(noDestination), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(AddTransactionModal), findsOneWidget);
      expect(saves, 0);
    });

    testWidgets('a transfer into its own source wallet', (tester) async {
      var saves = 0;
      await pump(tester,
          transaction: transfer(to: 'w1'), onSave: (_) async => saves++);

      await tester.tap(find.text('UPDATE'));
      await tester.pumpAndSettle();

      expect(inlineMessage(noDestination), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(AddTransactionModal), findsOneWidget);
      expect(saves, 0);
    });

    // The form's own validators already draw under their fields; pinned here so
    // "every path shows its error inside the sheet" stays true for all of them.
    testWidgets('an empty form shows its field errors', (tester) async {
      await pump(tester);

      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      expect(inlineMessage('Enter amount'), findsOneWidget);
      expect(inlineMessage('Enter description'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('no wallet to book into', (tester) async {
      await pump(tester, accounts: const []);
      await tester.enterText(find.byType(TextFormField).at(0), '5');
      await tester.enterText(find.byType(TextFormField).at(1), 'Coffee');

      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      expect(inlineMessage('Please select a wallet'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(AddTransactionModal), findsOneWidget);
    });

    testWidgets('the message goes away on the next edit', (tester) async {
      await pump(tester, transaction: transfer(to: 'w1'));
      await tester.tap(find.text('UPDATE'));
      await tester.pumpAndSettle();
      expect(inlineMessage(noDestination), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(1), 'Moved');
      await tester.pump();

      expect(inlineMessage(noDestination), findsNothing);
    });

    testWidgets('and on the next tap of Save', (tester) async {
      await pump(tester, transaction: transfer(to: 'w1'));
      await tester.tap(find.text('UPDATE'));
      await tester.pumpAndSettle();

      // Nothing fixed: it is raised again, not stacked or left stale.
      await tester.tap(find.text('UPDATE'));
      await tester.pumpAndSettle();

      expect(inlineMessage(noDestination), findsOneWidget);
    });
  });

  // Opening an existing transaction and saving it untouched must never rewrite
  // it. Real ledgers hold rows the sheet's own lists don't describe: legacy
  // rows whose type and sign disagree, whose category is of the other kind or
  // was deleted, or that have none.
  group('an existing transaction saved untouched keeps its own values', () {
    Future<Transaction> saveUntouched(
        WidgetTester tester, Transaction existing) async {
      Transaction? saved;
      await pump(tester, transaction: existing, onSave: (t) async => saved = t);

      await tester.tap(find.text('UPDATE'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull, reason: 'the untouched save should go through');
      expect(find.byType(AddTransactionModal), findsNothing); // and close
      return saved!;
    }

    testWidgets('a category of the other kind (legacy +11,95 "expense")',
        (tester) async {
      final saved = await saveUntouched(
          tester, tx(amount: 11.95, type: 'expense', category: 'Salary'));

      expect(saved.category, 'Salary'); // an income category on an expense row
    });

    testWidgets('a category that was deleted', (tester) async {
      final saved = await saveUntouched(tester, tx(category: 'Gone'));

      expect(saved.category, 'Gone');
    });

    testWidgets('no category at all', (tester) async {
      final saved = await saveUntouched(tester, tx(category: ''));

      expect(saved.category, '');
    });

    testWidgets('a row with no wallet', (tester) async {
      final saved = await saveUntouched(tester, tx(accountId: ''));

      expect(saved.accountId, '');
    });
  });

  // The ledger classifies a row by its sign (RECENTI, the list, the totals); the
  // sheet used to start from the STORED type. On a legacy row where the two
  // disagree, an untouched save then re-signed the amount from the stale type
  // (+11,95 "expense" became −11,95). The web editor derives the type from the
  // sign; so does this one, for any existing row that is not a transfer.
  group('an existing transaction opens as what its sign says it is', () {
    Future<(Transaction, String)> openAndSave(
        WidgetTester tester, Transaction existing) async {
      Transaction? saved;
      await pump(tester, transaction: existing, onSave: (t) async => saved = t);
      final shown = tester.widget<TypeSelector>(find.byType(TypeSelector)).selected;

      await tester.tap(find.text('UPDATE'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      return (saved!, shown);
    }

    /// Every value the owner did not touch, in one record: amount, sign (in the
    /// amount), category, wallet and date.
    (double, String, String, DateTime) untouched(Transaction t) =>
        (t.amount, t.category, t.accountId, t.date);

    testWidgets('a positive row stored as "expense" (legacy +11,95 "Ali")',
        (tester) async {
      final (saved, shown) = await openAndSave(
          tester, tx(amount: 11.95, type: 'expense', category: 'Groceries'));

      // Untouched: the sign survives (the bug flipped it to −11,95), the type
      // heals to match, nothing else moves.
      expect(saved.amount, 11.95);
      expect(untouched(saved), (11.95, 'Groceries', 'w1', day));
      expect(saved.type, 'income');
      expect(shown, 'income');
    });

    testWidgets('a negative row stored as "income"', (tester) async {
      final (saved, shown) = await openAndSave(
          tester, tx(amount: -5, type: 'income', category: 'Groceries'));

      expect(untouched(saved), (-5.0, 'Groceries', 'w1', day));
      expect(saved.type, 'expense');
      expect(shown, 'expense');
    });

    testWidgets('a normal expense round-trips unchanged', (tester) async {
      final (saved, shown) = await openAndSave(tester, tx(amount: -10.5));

      expect(shown, 'expense');
      expect(untouched(saved), (-10.5, 'Dining', 'w1', day));
      expect(saved.type, 'expense');
    });

    testWidgets('a normal income round-trips unchanged', (tester) async {
      final (saved, shown) = await openAndSave(
          tester, tx(amount: 100, type: 'income', category: 'Salary'));

      expect(shown, 'income');
      expect(untouched(saved), (100.0, 'Salary', 'w1', day));
      expect(saved.type, 'income');
    });

    testWidgets('a transfer stays a transfer', (tester) async {
      final existing = Transaction(
        id: 't2',
        accountId: 'w1',
        toAccountId: 'w2',
        amount: 30,
        date: day,
        description: 'Move',
        category: 'Transfer',
        type: 'transfer',
      );

      final (saved, shown) = await openAndSave(tester, existing);

      expect(shown, 'transfer');
      expect(untouched(saved), (30.0, 'Transfer', 'w1', day));
      expect((saved.type, saved.toAccountId), ('transfer', 'w2'));
    });
  });

  // An edit builds a brand-new Transaction from the form, which would write
  // othersShare 0 over a split marked on the web. The editor holds the split in
  // its own state, seeded from the row, and writes it back unchanged.
  group('editing a split row keeps its split', () {
    Future<Transaction> editDescription(
        WidgetTester tester, Transaction existing) async {
      Transaction? saved;
      await pump(tester, transaction: existing, onSave: (t) async => saved = t);
      await tester.enterText(find.byType(TextFormField).at(1), 'Dinner, edited');
      await tester.tap(find.text('UPDATE'));
      await tester.pumpAndSettle();
      return saved!;
    }

    testWidgets('a shared expense keeps its othersShare', (tester) async {
      final saved = await editDescription(
          tester, tx(amount: -100, othersShare: 75, category: 'Dining'));

      expect(saved.description, 'Dinner, edited');
      expect((saved.amount, saved.othersShare, saved.reimbursesId),
          (-100.0, 75.0, null));
    });

    testWidgets('a reimbursement keeps its reimbursesId', (tester) async {
      final saved = await editDescription(
          tester,
          tx(
              amount: 75,
              type: 'income',
              category: 'Salary',
              reimbursesId: 'exp'));

      expect(saved.description, 'Dinner, edited');
      expect((saved.amount, saved.othersShare, saved.reimbursesId),
          (75.0, 0.0, 'exp'));
    });
  });

  // The SHARED row and its sheet: what the others owe, typed or split in N.
  group('marking an expense as shared', () {
    final sharedField = find.widgetWithText(TextField, 'Shared — others owe');
    const tooMuch = "The others can't owe more than the whole expense.";

    Future<void> openSharedSheet(WidgetTester tester) async {
      await tester.tap(find.text('SHARED'));
      await tester.pumpAndSettle();
    }

    /// The sheet's own Save is the last one on screen (the editor has one too).
    Future<void> applySharedSheet(WidgetTester tester) async {
      await tester.tap(find.text('SAVE').last);
      await tester.pumpAndSettle();
    }

    Future<void> splitIn(WidgetTester tester, int n) async {
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('$n').last);
      await tester.pumpAndSettle();
    }

    String sharedFieldText(WidgetTester tester) =>
        tester.widget<TextField>(sharedField).controller!.text;

    Future<void> typeAmount(WidgetTester tester, String amount) async {
      await tester.enterText(find.byType(TextFormField).at(0), amount);
      await tester.enterText(find.byType(TextFormField).at(1), 'Dinner');
    }

    /// A new expense of [amount], shared through [fill] (which drives the sheet),
    /// saved: what the editor handed to `onSave`.
    Future<Transaction> saveShared(
      WidgetTester tester,
      String amount,
      Future<void> Function() fill,
    ) async {
      Transaction? saved;
      await pump(tester, onSave: (t) async => saved = t);
      await typeAmount(tester, amount);
      await openSharedSheet(tester);
      await fill();
      await applySharedSheet(tester);
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      return saved!;
    }

    testWidgets('the row is offered for an expense only', (tester) async {
      await pump(tester);

      expect(find.text('SHARED'), findsOneWidget);
      expect(find.text('Not shared'), findsOneWidget);

      await tester.tap(find.text('INCOME'));
      await tester.pumpAndSettle();
      expect(find.text('SHARED'), findsNothing);

      await tester.tap(find.text('TRANSFER'));
      await tester.pumpAndSettle();
      expect(find.text('SHARED'), findsNothing);
    });

    testWidgets('and not in the inbox approval (a prefill)', (tester) async {
      await pump(tester, prefill: tx());

      expect(find.text('SHARED'), findsNothing);
    });

    testWidgets('100 split in 4 saves 75 and the row says so', (tester) async {
      Transaction? saved;
      await pump(tester, onSave: (t) async => saved = t);
      await typeAmount(tester, '100');
      await openSharedSheet(tester);
      await splitIn(tester, 4);

      expect(sharedFieldText(tester), '75.00');

      await applySharedSheet(tester);
      expect(find.text('others owe €75.00'), findsOneWidget);

      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      expect((saved?.amount, saved?.othersShare), (-100.0, 75.0));
    });

    testWidgets('10 split in 3 saves 6.67', (tester) async {
      final saved = await saveShared(tester, '10', () => splitIn(tester, 3));

      expect(saved.othersShare, 6.67);
    });

    testWidgets('a typed figure is saved as typed', (tester) async {
      final saved = await saveShared(tester, '100',
          () => tester.enterText(sharedField, '30'));

      expect(saved.othersShare, 30);
    });

    testWidgets('a comma works as the decimal separator', (tester) async {
      final saved = await saveShared(tester, '100',
          () => tester.enterText(sharedField, '12,5'));

      expect(saved.othersShare, 12.5);
    });

    testWidgets('an emptied field is "not shared"', (tester) async {
      Transaction? saved;
      await pump(tester,
          transaction: tx(amount: -100, othersShare: 75),
          onSave: (t) async => saved = t);
      await openSharedSheet(tester);
      expect(sharedFieldText(tester), '75.00');

      await tester.enterText(sharedField, '');
      await applySharedSheet(tester);
      expect(find.text('Not shared'), findsOneWidget);

      await tester.tap(find.text('UPDATE'));
      await tester.pumpAndSettle();
      expect(saved?.othersShare, 0);
    });

    testWidgets('more than the whole expense is refused in the sheet',
        (tester) async {
      await pump(tester);
      await typeAmount(tester, '100');
      await openSharedSheet(tester);
      await tester.enterText(sharedField, '120');

      await applySharedSheet(tester);

      expect(find.text(tooMuch), findsOneWidget);
      expect(sharedField, findsOneWidget); // still open
      expect(find.text('Not shared'), findsOneWidget); // nothing was applied
    });

    testWidgets('something that is not an amount is refused in the sheet',
        (tester) async {
      await pump(tester);
      await typeAmount(tester, '100');
      await openSharedSheet(tester);
      await tester.enterText(sharedField, 'abc');

      await applySharedSheet(tester);

      expect(
          find.text(
              'Enter what the others owe as an amount, or leave it empty.'),
          findsOneWidget);
      expect(sharedField, findsOneWidget);
    });

    testWidgets('"Split in" with no amount asks for it and writes nothing',
        (tester) async {
      await pump(tester);
      await openSharedSheet(tester);

      await splitIn(tester, 4);

      expect(find.text('Enter the amount first.'), findsOneWidget);
      expect(sharedFieldText(tester), '');
    });

    testWidgets('an amount lowered below the share is refused at save',
        (tester) async {
      var saves = 0;
      await pump(tester,
          transaction: tx(amount: -100, othersShare: 75),
          onSave: (_) async => saves++);

      await tester.enterText(find.byType(TextFormField).at(0), '50');
      await tester.tap(find.text('UPDATE'));
      await tester.pumpAndSettle();

      expect(inlineMessage(tooMuch), findsOneWidget);
      expect(find.byType(AddTransactionModal), findsOneWidget);
      expect(saves, 0);
    });

    testWidgets('an edited shared expense switched to income saves no share',
        (tester) async {
      Transaction? saved;
      await pump(tester,
          transaction: tx(amount: -100, othersShare: 75),
          onSave: (t) async => saved = t);

      await tester.tap(find.text('INCOME'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('UPDATE'));
      await tester.pumpAndSettle();

      expect((saved?.amount, saved?.othersShare), (100.0, 0.0));
    });

    testWidgets('an unsaved split makes the sheet ask before it closes',
        (tester) async {
      await pump(tester);
      await openSharedSheet(tester);
      await tester.enterText(sharedField, '30');
      await applySharedSheet(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
    });
  });

  // The two ends of one link: an income's PAYS BACK row (saved with the form) and
  // the reimbursements of a shared expense (written to the other row at once).
  group('linking a reimbursement', () {
    Transaction dinner() => Transaction(
          id: 'dinner',
          accountId: 'w1',
          amount: -100,
          date: DateTime(2026, 6, 10),
          description: 'Dinner',
          category: 'Dining',
          othersShare: 75,
        );

    Transaction back(
      double amount, {
      String id = 'back',
      String description = 'Back',
      String? reimbursesId = 'dinner',
    }) =>
        Transaction(
          id: id,
          accountId: 'w1',
          amount: amount,
          date: DateTime(2026, 6, 11),
          description: description,
          category: 'Salary',
          type: 'income',
          reimbursesId: reimbursesId,
        );

    late AppDatabase db;

    /// Seeds [rows] as the owner's, and keeps the database for [linkOf].
    Future<void> Function(AppDatabase) seedRows(List<Transaction> rows) =>
        (d) async {
          db = d;
          for (final t in rows) {
            await d.into(d.transactions).insert(TransactionsCompanion.insert(
                  id: t.id,
                  userId: const Value('u'),
                  accountId: Value(t.accountId),
                  amount: t.amount,
                  description: t.description,
                  category: t.category,
                  type: Value(t.type),
                  date: t.date,
                  othersShare: Value(t.othersShare),
                  reimbursesId: Value(t.reimbursesId),
                ));
          }
        };

    /// The `reimbursesId` the database holds for [id].
    Future<String?> linkOf(WidgetTester tester, String id) async =>
        (await tester.runAsync(() =>
                (db.select(db.transactions)..where((t) => t.id.equals(id)))
                    .getSingle()))!
            .reimbursesId;

    String amountText(WidgetTester tester) => tester
        .widget<EditableText>(find.descendant(
            of: find.byType(AmountHeroField),
            matching: find.byType(EditableText)))
        .controller
        .text;

    /// A live (database) stream closes on a zero-length timer once its widgets
    /// go away; unmounting by hand runs it before the framework looks for
    /// timers still pending at the end of the test.
    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      // A duration, or the fake clock does not move and the timer stays queued.
      await tester.pump(const Duration(milliseconds: 1));
    }

    Future<void> openPicker(WidgetTester tester) async {
      await tester.tap(find.text('PAYS BACK'));
      await tester.pumpAndSettle();
    }

    group('from the income', () {
      testWidgets('the picker lists the shared expense, a blank amount takes '
          'what is left and saving writes the link', (tester) async {
        Transaction? saved;
        await pump(tester,
            shared: [dinner(), back(25)], onSave: (t) async => saved = t);
        await tester.tap(find.text('INCOME'));
        await tester.pumpAndSettle();
        expect(find.text('Not a reimbursement'), findsOneWidget); // the row

        await openPicker(tester);
        expect(find.text('Dinner'), findsOneWidget);
        expect(find.text('Jun 10 · €75.00 to receive · €25.00 received'),
            findsOneWidget);
        await tester.tap(find.text('Dinner'));
        await tester.pumpAndSettle();

        expect(amountText(tester), '50.00');
        await tester.enterText(find.byType(TextFormField).at(1), 'Back');
        await tester.tap(find.text('SAVE'));
        await tester.pumpAndSettle();
        expect((saved?.type, saved?.amount, saved?.reimbursesId),
            ('income', 50.0, 'dinner'));
      });

      testWidgets('a typed amount is kept', (tester) async {
        await pump(tester, shared: [dinner()]);
        await tester.tap(find.text('INCOME'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).at(0), '10');

        await openPicker(tester);
        await tester.tap(find.text('Dinner'));
        await tester.pumpAndSettle();

        expect(amountText(tester), '10');
      });

      testWidgets('the same income switched to expense saves no link',
          (tester) async {
        Transaction? saved;
        await pump(tester,
            transaction: back(25),
            shared: [dinner()],
            onSave: (t) async => saved = t);
        expect(find.text('Dinner'), findsOneWidget); // the row names it

        await tester.tap(find.text('EXPENSE'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('UPDATE'));
        await tester.pumpAndSettle();

        expect((saved?.amount, saved?.reimbursesId), (-25.0, null));
      });

      testWidgets('a link to an expense that is not there says so and '
          '"Not a reimbursement" drops it', (tester) async {
        Transaction? saved;
        await pump(tester,
            transaction: back(25, reimbursesId: 'gone'),
            onSave: (t) async => saved = t);
        expect(find.text('Linked to an expense that is not there'),
            findsOneWidget);

        await openPicker(tester);
        await tester.tap(find.text('Not a reimbursement'));
        await tester.pumpAndSettle();
        expect(find.text('Linked to an expense that is not there'),
            findsNothing);
        await tester.tap(find.text('UPDATE'));
        await tester.pumpAndSettle();

        expect(saved?.reimbursesId, isNull);
      });

      testWidgets('the row is offered only when there is something to pay back',
          (tester) async {
        await pump(tester);
        await tester.tap(find.text('INCOME'));
        await tester.pumpAndSettle();

        expect(find.text('PAYS BACK'), findsNothing);
      });

      testWidgets('and never the expense being edited', (tester) async {
        await pump(tester, transaction: dinner(), shared: [dinner()]);

        await tester.tap(find.text('INCOME'));
        await tester.pumpAndSettle();

        expect(find.text('PAYS BACK'), findsNothing);
      });

      testWidgets('and not in the inbox approval (a prefill)', (tester) async {
        await pump(tester,
            prefill: back(25, reimbursesId: null), shared: [dinner()]);

        expect(find.text('PAYS BACK'), findsNothing);
      });
    });

    group('from the expense', () {
      testWidgets('a new expense has no reimbursements yet', (tester) async {
        await pump(tester, shared: [dinner(), back(25)]);

        await tester.tap(find.text('SHARED'));
        await tester.pumpAndSettle();

        expect(find.text('REIMBURSEMENTS'), findsNothing);
      });

      testWidgets('lists the linked income and Unlink clears the link in the '
          'database', (tester) async {
        await pump(tester,
            transaction: dinner(),
            liveShare: true,
            seed: seedRows([dinner(), back(25)]));
        await tester.tap(find.text('SHARED'));
        await tester.pumpAndSettle();

        expect(find.text('REIMBURSEMENTS'), findsOneWidget);
        expect(find.text('€75.00 to receive · €25.00 received'),
            findsOneWidget);
        expect(find.text('Jun 11, 2026 · €25.00 · Back'), findsOneWidget);

        await tester.tap(find.byTooltip('Unlink'));
        await tester.pumpAndSettle();

        expect(await linkOf(tester, 'back'), isNull);
        expect(find.text('Jun 11, 2026 · €25.00 · Back'), findsNothing);
        expect(find.text('€75.00 to receive'), findsOneWidget);
        await unmount(tester);
      });

      testWidgets('choosing an income writes nothing, Attach writes the link',
          (tester) async {
        final spare = back(25,
            id: 'spare', description: 'Refund', reimbursesId: null);
        await pump(tester,
            transaction: dinner(),
            history: [spare],
            liveShare: true,
            seed: seedRows([dinner(), spare]));
        await tester.tap(find.text('SHARED'));
        await tester.pumpAndSettle();
        final attach = find.widgetWithText(TextButton, 'Attach');
        expect(tester.widget<TextButton>(attach).onPressed, isNull);

        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Jun 11, 2026 · €25.00 · Refund').last);
        await tester.pumpAndSettle();

        expect(await linkOf(tester, 'spare'), isNull);
        expect(tester.widget<TextButton>(attach).onPressed, isNotNull);

        await tester.tap(attach);
        await tester.pumpAndSettle();

        expect(await linkOf(tester, 'spare'), 'dinner');
        expect(find.text('€75.00 to receive · €25.00 received'),
            findsOneWidget);
        expect(find.byTooltip('Unlink'), findsOneWidget);
        await unmount(tester);
      });

      testWidgets('with no unlinked income there is nothing to attach',
          (tester) async {
        await pump(tester, transaction: dinner(), shared: [dinner()]);

        await tester.tap(find.text('SHARED'));
        await tester.pumpAndSettle();

        expect(find.text('No unlinked incomes to attach.'), findsOneWidget);
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      });

      testWidgets('an expense whose share was lowered to 0 still lists its '
          'reimbursements, but offers none to attach', (tester) async {
        await pump(tester,
            transaction: dinner().copyWith(othersShare: 0),
            shared: [back(25)],
            history: [back(10, id: 'spare', reimbursesId: null)]);

        await tester.tap(find.text('SHARED'));
        await tester.pumpAndSettle();

        expect(find.byTooltip('Unlink'), findsOneWidget);
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        expect(find.text('No unlinked incomes to attach.'), findsNothing);
      });
    });
  });

  bool amountFocused(WidgetTester tester) => tester
      .widget<EditableText>(find.descendant(
          of: find.byType(AmountHeroField), matching: find.byType(EditableText)))
      .focusNode
      .hasFocus;

  // The common case is a fresh amount to type: the keyboard should already be up.
  group('the amount field takes focus only on a blank new sheet', () {
    testWidgets('a new sheet', (tester) async {
      await pump(tester);

      expect(amountFocused(tester), isTrue);
    });

    testWidgets('an existing transaction being edited', (tester) async {
      await pump(tester, transaction: tx());

      expect(amountFocused(tester), isFalse);
    });

    testWidgets('a prefill that already has its amount', (tester) async {
      await pump(tester, prefill: tx());

      expect(amountFocused(tester), isFalse);
    });

    testWidgets('a prefill without one (an unrecognised message)',
        (tester) async {
      await pump(tester, prefill: tx(amount: 0));

      expect(amountFocused(tester), isTrue);
    });
  });

  group('the category a new sheet starts on', () {
    Future<Transaction> saveNew(WidgetTester tester,
        {List<Transaction> history = const []}) async {
      Transaction? saved;
      await pump(tester, history: history, onSave: (t) async => saved = t);
      await tester.enterText(find.byType(TextFormField).at(0), '5');
      await tester.enterText(find.byType(TextFormField).at(1), 'Something');
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      return saved!;
    }

    testWidgets('is the last one used for that kind of movement',
        (tester) async {
      final saved = await saveNew(tester, history: [
        tx(amount: 100, type: 'income', category: 'Salary'), // newest, income
        tx(category: 'Treats'),
        tx(category: 'Dining'),
      ]);

      expect(saved.category, 'Treats');
    });

    testWidgets('with no history it is the first', (tester) async {
      expect((await saveNew(tester)).category, 'Dining');
    });

    testWidgets('switching kind re-picks it for the new kind', (tester) async {
      Transaction? saved;
      await pump(tester,
          history: [tx(category: 'Treats'), tx(amount: 100, type: 'income', category: 'Salary')],
          onSave: (t) async => saved = t);

      await tester.tap(find.text('INCOME'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), '5');
      await tester.enterText(find.byType(TextFormField).at(1), 'Pay');
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      expect((saved?.type, saved?.category), ('income', 'Salary'));
    });
  });

  // Typing "Conad" should file it where the owner filed Conad before — but only
  // while the owner has not decided, and never on a transaction being edited.
  group('the description suggests a category from the ledger', () {
    Future<void> seedConad(AppDatabase db) async {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'c_spesa', name: 'Spesa', iconCode: 0, colorHex: 0, type: 'expense'));
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: 'old',
          amount: -20,
          description: 'CONAD ADRIATICO',
          category: 'Spesa',
          type: const Value('expense'),
          date: DateTime(2026, 1, 5)));
    }

    Future<Transaction> typeAndSave(
      WidgetTester tester,
      String description, {
      Transaction? transaction,
      Future<void> Function()? beforeTyping,
    }) async {
      Transaction? saved;
      await pump(tester,
          transaction: transaction,
          seed: seedConad,
          onSave: (t) async => saved = t);
      await beforeTyping?.call();
      await tester.enterText(find.byType(TextFormField).at(1), description);
      await tester.pump(const Duration(milliseconds: 600)); // the debounce
      await tester.pumpAndSettle();
      if (transaction == null) {
        await tester.enterText(find.byType(TextFormField).at(0), '5');
      }
      await tester.tap(find.text(transaction == null ? 'SAVE' : 'UPDATE'));
      await tester.pumpAndSettle();
      return saved!;
    }

    testWidgets('a merchant the ledger knows fills the category',
        (tester) async {
      expect((await typeAndSave(tester, 'Conad')).category, 'Spesa');
    });

    testWidgets('a merchant it does not know leaves the default',
        (tester) async {
      expect((await typeAndSave(tester, 'Lidl')).category, 'Dining');
    });

    testWidgets('a category the owner picked is not overridden', (tester) async {
      final saved = await typeAndSave(tester, 'Conad', beforeTyping: () async {
        await tester.tap(find.text('Dining')); // the category row
        await tester.pumpAndSettle();
        await tester.tap(find.text('Treats'));
        await tester.pumpAndSettle();
      });

      expect(saved.category, 'Treats');
    });

    testWidgets('an existing transaction keeps its own category',
        (tester) async {
      final saved =
          await typeAndSave(tester, 'Conad', transaction: tx(category: 'Treats'));

      expect(saved.category, 'Treats');
    });
  });

  // A prefill is a NEW transaction: unknown or dead values are for the sheet to
  // default, so the owner never saves a name the category row doesn't show.
  group('a prefill defaults what it does not know', () {
    Future<Transaction> save(WidgetTester tester, Transaction prefill) async {
      Transaction? saved;
      await pump(tester, prefill: prefill, onSave: (t) async => saved = t);
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      return saved!;
    }

    testWidgets('a deleted suggested category becomes the first live one',
        (tester) async {
      expect((await save(tester, tx(category: 'Gone'))).category, 'Dining');
    });

    testWidgets('an empty category and wallet become the defaults',
        (tester) async {
      final saved = await save(tester, tx(category: '', accountId: ''));

      expect((saved.category, saved.accountId), ('Dining', 'w1'));
    });

    testWidgets('a live suggested category is kept', (tester) async {
      expect((await save(tester, tx(category: 'Dining'))).category, 'Dining');
    });
  });
}
