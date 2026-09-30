import 'dart:ffi';

import 'package:budgetti/core/database/database.dart' show AppDatabase;
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/features/dashboard/widgets/recent_transactions_panel.dart';
import 'package:budgetti/features/installments/add_installment_modal.dart';
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:budgetti/models/account.dart';
import 'package:budgetti/models/category.dart';
import 'package:budgetti/models/installment.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
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

/// The screens that classified a transaction by its stored `type` instead of
/// its sign (the model's rule: `isIncome` / `isExpense`, transfers neither).
/// Real data holds a legacy row booked as 'expense' with a positive amount.
void main() {
  setUpAll(() {
    _ensureSqlite();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Transaction tx(String id, double amount, String type) => Transaction(
        id: id,
        accountId: 'a1',
        amount: amount,
        date: DateTime.now(),
        description: id,
        category: 'Food',
        type: type,
      );

  final currency = NumberFormat.simpleCurrency(name: 'EUR', locale: 'en_US');

  Future<void> pump(WidgetTester tester, Widget child, List<Override> more) {
    return tester.pumpWidget(ProviderScope(
      overrides: [
        currencyProvider.overrideWithValue(currency),
        categoriesProvider.overrideWith((ref) => Stream.value(<Category>[])),
        ...more,
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ));
  }

  group('RECENTI panel', () {
    Future<void> showRows(WidgetTester tester) => pump(
          tester,
          RecentTransactionsPanel(transactions: [
            tx('legacy-positive-expense', 11.95, 'expense'),
            tx('negative-income', -5, 'income'),
            tx('a-transfer', 500, 'transfer'),
          ]),
          const [],
        );

    testWidgets('a positive row booked as expense shows as money in',
        (tester) async {
      await showRows(tester);
      expect(find.text('+€11.95'), findsOneWidget);
      expect(find.text('−€11.95'), findsNothing);
    });

    testWidgets('a negative row typed income shows as money out',
        (tester) async {
      await showRows(tester);
      expect(find.text('−€5.00'), findsOneWidget);
      expect(find.text('+€5.00'), findsNothing);
    });

    testWidgets('a transfer carries no sign, like the ledger row',
        (tester) async {
      await showRows(tester);
      expect(find.text('€500.00'), findsOneWidget);
      expect(find.text('−€500.00'), findsNothing);
    });
  });

  group('installment attach-a-payment list', () {
    testWidgets('offers unlinked outgoing rows by sign, never a positive one',
        (tester) async {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      final plan = Installment(
        id: 'plan1',
        userId: 'u',
        description: 'Tyres',
        totalAmount: 400,
        installmentCount: 4,
        startDate: DateTime(2026, 1, 10),
      );
      await pump(
        tester,
        AddInstallmentModal(existing: plan),
        [
          financeServiceProvider.overrideWithValue(FinanceService(db, 'u')),
          accountsProvider.overrideWith((ref) => Stream.value(<Account>[])),
          installmentTransactionsProvider.overrideWith((ref) => Stream.value([
                tx('real-expense', -10, 'expense'),
                tx('income-typed-outgoing', -5, 'income'),
                tx('positive-expense', 11.95, 'expense'),
              ])),
        ],
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      expect(find.textContaining('real-expense'), findsWidgets);
      expect(find.textContaining('income-typed-outgoing'), findsWidgets);
      expect(find.textContaining('positive-expense'), findsNothing);
    });
  });
}
