import 'dart:ffi' show DynamicLibrary;

import 'package:budgetti/core/database/database.dart'
    show AppDatabase, CategoriesCompanion, TransactionsCompanion;
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/features/transactions/add_transaction_modal.dart';
import 'package:budgetti/features/transactions/widgets/amount_hero_field.dart';
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
  }) =>
      Transaction(
        id: 't1',
        accountId: accountId,
        amount: amount,
        date: day,
        description: 'Coffee',
        category: category,
        type: type,
      );

  /// The sheet as a routed page (its save pops through GoRouter), over the real
  /// providers except the data streams. [onSave] intercepts what the sheet
  /// built, so the tests read exactly what would have been written.
  Future<GoRouter> pump(
    WidgetTester tester, {
    Transaction? transaction,
    Transaction? prefill,
    List<Transaction> history = const [],
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
