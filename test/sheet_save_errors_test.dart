import 'dart:ffi' show DynamicLibrary;

import 'package:budgetti/core/database/database.dart' show AppDatabase;
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/features/budget/set_budget_modal.dart';
import 'package:budgetti/features/installments/add_installment_modal.dart';
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:budgetti/models/account.dart';
import 'package:budgetti/models/budget.dart';
import 'package:budgetti/models/category.dart';
import 'package:budgetti/models/installment.dart';
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

/// A finance service whose writes all fail, as a full disk or a locked
/// database would.
class _FailingFinance extends FinanceService {
  _FailingFinance(super.db, super.userId);

  @override
  Future<void> upsertBudget(Budget budget) async => throw StateError('disk full');

  @override
  Future<void> deleteBudget(String category, {String period = 'monthly'}) async =>
      throw StateError('disk full');

  @override
  Future<void> upsertInstallment(Installment plan) async =>
      throw StateError('disk full');
}

/// These sheets open on the root navigator, over the root ScaffoldMessenger, so
/// a SnackBar raised while they are open is drawn BEHIND them: a failed save
/// looked like a sheet that would not close. The error belongs inside the sheet.
void main() {
  setUpAll(() {
    _ensureSqlite();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pump(WidgetTester tester, Widget sheet) async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    tester.view.physicalSize = const Size(800, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currencyProvider.overrideWithValue(
            NumberFormat.simpleCurrency(name: 'EUR', locale: 'en_US')),
        financeServiceProvider.overrideWithValue(_FailingFinance(db, 'u')),
        categoriesProvider.overrideWith((ref) => Stream.value(<Category>[])),
        accountsProvider.overrideWith((ref) => Stream.value(<Account>[])),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: sheet)),
      ),
    ));
    await tester.pumpAndSettle();
  }

  const failed = 'Something went wrong. Try again.';

  group('budget sheet', () {
    testWidgets('a failed save is shown inside the sheet', (tester) async {
      await pump(tester,
          const SetBudgetModal(categoryName: 'Dining', currentLimit: 0));
      await tester.enterText(find.byType(TextFormField), '200');

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.textContaining(failed), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(SetBudgetModal), findsOneWidget);
    });

    testWidgets('and so is a failed clear', (tester) async {
      await pump(tester,
          const SetBudgetModal(categoryName: 'Dining', currentLimit: 150));

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(find.textContaining(failed), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('the message goes away on the next edit', (tester) async {
      await pump(tester,
          const SetBudgetModal(categoryName: 'Dining', currentLimit: 0));
      await tester.enterText(find.byType(TextFormField), '200');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '250');
      await tester.pump();

      expect(find.textContaining(failed), findsNothing);
    });
  });

  group('installment sheet', () {
    testWidgets('a failed save is shown inside the sheet', (tester) async {
      await pump(tester, const AddInstallmentModal());
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Tyres');
      await tester.enterText(fields.at(1), '400');
      await tester.enterText(fields.at(2), '4');

      await tester.tap(find.text('Add a plan'));
      await tester.pumpAndSettle();

      expect(find.textContaining(failed), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(AddInstallmentModal), findsOneWidget);
    });
  });
}
