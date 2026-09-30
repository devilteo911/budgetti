import 'dart:ffi' show DynamicLibrary;

import 'package:budgetti/core/database/database.dart' show AppDatabase;
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/finance_service.dart';
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

void main() {
  setUpAll(() {
    _ensureSqlite();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final prefill = Transaction(
    id: '',
    accountId: 'w1',
    amount: -10,
    date: DateTime(2026, 6, 24),
    description: 'Coffee',
    category: 'Dining',
  );

  Future<void> pump(
    WidgetTester tester,
    Future<void> Function(Transaction) onSave,
  ) async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    tester.view.physicalSize = const Size(800, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currencyProvider.overrideWithValue(
            NumberFormat.simpleCurrency(name: 'EUR', locale: 'en_US')),
        financeServiceProvider.overrideWithValue(FinanceService(db, 'u')),
        accountsProvider.overrideWith((ref) => Stream.value([
              Account(
                  id: 'w1', name: 'Revolut', balance: 0, currency: 'EUR', providerName: ''),
            ])),
        categoriesProvider.overrideWith((ref) => Stream.value([
              Category(
                  id: 'c1', userId: 'u', name: 'Dining', iconCode: 0, colorHex: 0, type: 'expense'),
            ])),
        tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
        installmentsProvider.overrideWith((ref) => Stream.value(<Installment>[])),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AddTransactionModal(prefill: prefill, onSave: onSave),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  // The save had try/finally and no catch: a service exception escaped the tap
  // handler, the sheet stayed open and nothing on screen said the save failed.
  testWidgets('a failing save says so and leaves the sheet open, ready to retry',
      (tester) async {
    var calls = 0;
    await pump(tester, (_) async {
      calls++;
      throw StateError('disk full');
    });

    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Error'), findsOneWidget);
    expect(find.byType(AddTransactionModal), findsOneWidget);

    // Not stuck "saving": the button works again.
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });
}
