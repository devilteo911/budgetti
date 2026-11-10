import 'dart:ffi' show DynamicLibrary;

import 'package:budgetti/core/database/database.dart' show AppDatabase;
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/features/budget/budget_screen.dart';
import 'package:budgetti/features/dashboard/dashboard_screen.dart';
import 'package:budgetti/features/transactions/transactions_screen.dart';
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:budgetti/models/account.dart';
import 'package:budgetti/models/budget.dart';
import 'package:budgetti/models/category.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// The screens over the real providers and an in-memory database: a
/// transaction written through [FinanceService] — and nothing else, no
/// `ref.invalidate` — has to reach what is on screen. The write sites (editor,
/// draft approval, quick edit, bulk delete, CSV import) rely on exactly this.
void main() {
  setUpAll(() {
    _ensureSqlite();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late FinanceService service;

  Transaction dinner({double amount = -42, String description = 'Pizzeria'}) =>
      Transaction(
        id: 't1',
        accountId: 'w1',
        amount: amount,
        date: DateTime.now(),
        description: description,
        category: 'Dining',
        type: 'expense',
      );

  /// [screen] over an empty wallet, the Dining category and its budget of 200.
  Future<void> pump(WidgetTester tester, Widget screen) async {
    SharedPreferences.setMockInitialValues({'notifications_enabled': false});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    service = FinanceService(db, 'u');
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await service.addAccount(Account(
        id: 'w1',
        name: 'Revolut',
        balance: 0,
        currency: 'EUR',
        providerName: '',
        isDefault: true,
      ));
      await service.addCategory(Category(
        id: 'cat_Dining',
        userId: 'u',
        name: 'Dining',
        iconCode: 0,
        colorHex: 0,
        type: 'expense',
      ));
      await service.upsertBudget(
          Budget(id: 'b1', userId: 'u', category: 'Dining', limit: 200));
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        financeServiceProvider.overrideWithValue(service),
        currencyProvider.overrideWithValue(
            NumberFormat.simpleCurrency(name: 'EUR', locale: 'en_US')),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
      ),
    ));
    await settle(tester);
  }

  // The three kinds of write, in the order a row lives them. The edit matters
  // on its own: it changes no row count, and the delete is a soft one (an
  // update too).
  Future<void> add(WidgetTester tester) =>
      write(tester, () => service.addTransaction(dinner()));
  Future<void> edit(WidgetTester tester) => write(
      tester,
      () => service.updateTransaction(
          dinner(amount: -50, description: 'Trattoria')));
  Future<void> delete(WidgetTester tester) =>
      write(tester, () => service.deleteTransactions(['t1']));

  testWidgets('the ledger follows an add, an edit and a delete',
      (tester) async {
    await pump(tester, const TransactionsScreen());
    expect(texts(tester), contains('MOVEMENTS | 0'));

    await add(tester);
    expect(texts(tester), contains('Pizzeria | Dining | -€42.00'));
    expect(texts(tester), contains('EXPENSE | €42.00 | MOVEMENTS | 1'));

    await edit(tester);
    expect(texts(tester), contains('Trattoria | Dining | -€50.00'));
    expect(texts(tester), contains('EXPENSE | €50.00 | MOVEMENTS | 1'));

    await delete(tester);
    expect(texts(tester), isNot(contains('Trattoria')));
    expect(texts(tester), contains('EXPENSE | €0.00 | MOVEMENTS | 0'));
    await unmount(tester);
  });

  testWidgets('the dashboard totals follow an add, an edit and a delete',
      (tester) async {
    await pump(tester, const DashboardScreen());
    expect(texts(tester), contains('TOTAL BALANCE | €0.00'));

    await add(tester);
    expect(texts(tester), contains('TOTAL BALANCE | -€42.00'));
    expect(texts(tester), contains('OUT | −42 | NET | −42'));
    expect(texts(tester), contains('Pizzeria | DINING | −€42.00'));

    await edit(tester);
    expect(texts(tester), contains('TOTAL BALANCE | -€50.00'));
    expect(texts(tester), contains('OUT | −50 | NET | −50'));
    expect(texts(tester), contains('Trattoria | DINING | −€50.00'));

    await delete(tester);
    expect(texts(tester), contains('TOTAL BALANCE | €0.00'));
    expect(texts(tester), isNot(contains('Trattoria')));
    await unmount(tester);
  });

  testWidgets('the budgets follow an add, an edit and a delete',
      (tester) async {
    await pump(tester, const BudgetScreen());
    expect(texts(tester), contains('Dining | €0.00  /  €200.00'));

    await add(tester);
    expect(texts(tester), contains('Dining | €42.00  /  €200.00 | €42.00 | 21%'));
    expect(texts(tester), contains('REMAINING | €158.00'));

    await edit(tester);
    expect(texts(tester), contains('Dining | €50.00  /  €200.00 | €50.00 | 25%'));
    expect(texts(tester), contains('REMAINING | €150.00'));

    await delete(tester);
    expect(texts(tester), contains('Dining | €0.00  /  €200.00'));
    expect(texts(tester), contains('REMAINING | €200.00'));
    await unmount(tester);
  });
}

/// Everything written on screen, in paint order.
String texts(WidgetTester tester) => [
      for (final w in tester.widgetList<RichText>(find.byType(RichText)))
        w.text.toPlainText()
    ].join(' | ');

/// The ledger refetches on a short debounce and the skeletons animate
/// forever, so there is no single frame to wait for (and no pumpAndSettle).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

/// Runs [body] on the test's fake clock, like a write started by a tap. Not
/// `runAsync`: with the writes on the real clock and the stream refetches on
/// the fake one, this suite hung about one run in ten.
Future<void> write(WidgetTester tester, Future<void> Function() body) async {
  var done = false;
  body().then((_) => done = true);
  await settle(tester);
  expect(done, isTrue, reason: 'the write never completed');
}

/// A live stream closes on a zero-length timer once its widgets go away;
/// unmounting by hand runs it before the framework looks for pending timers.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  // A duration, or the fake clock does not move and the timer stays queued.
  await tester.pump(const Duration(milliseconds: 1));
}
