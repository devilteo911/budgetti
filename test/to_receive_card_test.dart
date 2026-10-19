import 'dart:ffi' show DynamicLibrary;

import 'package:budgetti/core/database/database.dart' show AppDatabase;
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/features/dashboard/widgets/to_receive_card.dart';
import 'package:budgetti/features/transactions/add_transaction_modal.dart';
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:budgetti/models/account.dart';
import 'package:budgetti/models/category.dart';
import 'package:budgetti/models/installment.dart';
import 'package:budgetti/models/tag.dart';
import 'package:budgetti/models/transaction.dart';
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

typedef _Open = ({double total, List<Transaction> expenses});

/// The dashboard's "To receive" card: absent while nothing is owed, the total
/// and one row per open shared expense otherwise, newest first, a tap opening
/// the expense in the editor, and no overflow on a narrow phone. The providers
/// are overridden with plain values (mirror: the web's `ToReceive.tsx`). Made-up
/// ledger only.
void main() {
  setUpAll(() {
    _ensureSqlite();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Transaction expense(
    String id,
    String description, {
    required DateTime date,
    String category = 'Eating out',
    double amount = -100,
    double othersShare = 75,
  }) =>
      Transaction(
        id: id,
        accountId: 'w1',
        amount: amount,
        date: date,
        description: description,
        category: category,
        othersShare: othersShare,
      );

  Receivable figures(double owed, double received) =>
      (owed: owed, received: received, outstanding: owed - received);

  // The 100 € dinner of which the others owe 75, 25 already paid back.
  final dinner = expense('dinner', 'Dinner', date: DateTime(2026, 6, 24));
  final dinnerOwed = {'dinner': figures(75, 25)};
  final dinnerOpen = (total: 50.0, expenses: [dinner]);

  /// Waits for every font asked for so far, then for the frames that follow.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(GoogleFonts.pendingFonts);
    await tester.pumpAndSettle();
    await tester.runAsync(GoogleFonts.pendingFonts);
  }

  /// The card in a column like the dashboard's. The providers the editor reads
  /// are overridden too, for the test that opens it.
  Future<void> pump(
    WidgetTester tester, {
    AsyncValue<_Open>? open,
    Map<String, Receivable> byId = const {},
    Size size = const Size(390, 800),
    double textScale = 1,
  }) async {
    SharedPreferences.setMockInitialValues({'notifications_enabled': false});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [ToReceiveCard()],
            ),
          ),
        ),
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        toReceiveProvider.overrideWithValue(
            open ?? const AsyncData((total: 0.0, expenses: <Transaction>[]))),
        receivablesProvider.overrideWithValue(AsyncData(byId)),
        shareTransactionsProvider
            .overrideWith((ref) => Stream.value(const <Transaction>[])),
        transactionsProvider(null)
            .overrideWith((ref) => Stream.value(const <Transaction>[])),
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        financeServiceProvider.overrideWithValue(FinanceService(db, 'u')),
        currencyProvider.overrideWithValue(
            NumberFormat.simpleCurrency(name: 'EUR', locale: 'en_US')),
        accountsProvider.overrideWith((ref) => Stream.value([
              Account(
                  id: 'w1',
                  name: 'Revolut',
                  balance: 0,
                  currency: 'EUR',
                  providerName: ''),
            ])),
        categoriesProvider.overrideWith((ref) => Stream.value([
              Category(
                  id: 'cat_Eating out',
                  userId: 'u',
                  name: 'Eating out',
                  iconCode: 0,
                  colorHex: 0,
                  type: 'expense'),
            ])),
        tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
        installmentsProvider
            .overrideWith((ref) => Stream.value(<Installment>[])),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ));
    // The streams emit on the next frames, and the card asks for its fonts only
    // then; a font request nobody waits for would hang the next test's wait.
    await tester.pump();
    await tester.pump();
    await settle(tester);
  }

  group('hidden', () {
    final nothing = <String, AsyncValue<_Open>>{
      'no open expense': const AsyncData((total: 0.0, expenses: <Transaction>[])),
      'still loading': const AsyncLoading(),
      'on error': AsyncError(Exception('disk full'), StackTrace.empty),
    };
    for (final MapEntry(key: name, value: open) in nothing.entries) {
      testWidgets(name, (tester) async {
        await pump(tester, open: open);

        expect(tester.getSize(find.byType(ToReceiveCard)).height, 0);
        expect(
            find.descendant(
                of: find.byType(ToReceiveCard), matching: find.byType(Text)),
            findsNothing);
      });
    }
  });

  testWidgets('the dinner: label, total, one row with what is owed and back',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, open: AsyncData(dinnerOpen), byId: dinnerOwed);

    expect(find.text('TO RECEIVE'), findsOneWidget);
    // The total, then the row's outstanding: the same 50 twice.
    final fifty = find.text('€50.00');
    expect(fifty, findsNWidgets(2));
    expect(tester.widget<Text>(fifty.first).style?.fontSize, 34);
    expect(find.byType(InkWell), findsOneWidget);
    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text('Jun 24 · €75.00 owed · €25.00 received'), findsOneWidget);
    // A row is at least a touch target tall, and says what a tap does.
    expect(tester.getSize(find.byType(InkWell)).height, greaterThanOrEqualTo(48));
    expect(find.bySemanticsLabel('Open Dinner, €50.00 to receive'),
        findsOneWidget);
    handle.dispose();
  });

  testWidgets('two open expenses are listed in the order given, newest first',
      (tester) async {
    final newer = expense('newer', 'Newer', date: DateTime(2026, 6, 24));
    // No description: the category names it.
    final older = expense('older', '  ',
        date: DateTime(2026, 5, 2), category: 'Holiday', othersShare: 40);
    await pump(
      tester,
      open: AsyncData((total: 90.0, expenses: [newer, older])),
      byId: {'newer': figures(75, 25), 'older': figures(40, 0)},
    );

    expect(find.byType(InkWell), findsNWidgets(2));
    expect(find.text('€90.00'), findsOneWidget);
    expect(find.text('Holiday'), findsOneWidget);
    expect(find.text('May 2 · €40.00 owed · €0.00 received'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Newer')).dy,
        lessThan(tester.getTopLeft(find.text('Holiday')).dy));
  });

  for (final scale in [1.0, 1.5]) {
    testWidgets('320 wide at text scale $scale: nothing overflows',
        (tester) async {
      await pump(
        tester,
        open: AsyncData(dinnerOpen),
        byId: dinnerOwed,
        size: const Size(320, 640),
        textScale: scale,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Jun 24 · €75.00 owed · €25.00 received'),
          findsOneWidget);
      for (final text in ['Dinner', 'Jun 24 · €75.00 owed · €25.00 received']) {
        expect(tester.getRect(find.text(text)).right, lessThanOrEqualTo(320));
      }
      expect(tester.getRect(find.text('€50.00').last).right,
          lessThanOrEqualTo(320));
    });
  }

  testWidgets('a tap opens the expense in the editor', (tester) async {
    await pump(
      tester,
      open: AsyncData(dinnerOpen),
      byId: dinnerOwed,
      size: const Size(800, 2400),
    );
    expect(find.byType(AddTransactionModal), findsNothing);

    await tester.tap(find.byType(InkWell));
    await tester.pump();
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(AddTransactionModal), findsOneWidget);
    expect(
        tester.widget<AddTransactionModal>(find.byType(AddTransactionModal))
            .transaction
            ?.id,
        'dinner');
  });
}
