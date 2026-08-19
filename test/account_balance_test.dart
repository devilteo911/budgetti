import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
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
  setUpAll(_ensureSqlite);

  // The real case this came from: a Revolut wallet created at 21:47 on the day
  // it was opened. Its own first day's movements — a top-up transfer stamped
  // midnight, a card payment at noon — fell before the stored timestamp and
  // vanished from the balance, which read -87.66 instead of +87.74.
  test('a wallet counts its whole starting day, not just after the hour it '
      'was created', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    await db.into(db.accounts).insert(AccountsCompanion.insert(
          id: 'widiba',
          userId: const Value('user-a'),
          name: 'Widiba',
        ));
    await db.into(db.accounts).insert(AccountsCompanion.insert(
          id: 'revolut',
          userId: const Value('user-a'),
          name: 'Revolut',
          balance: const Value(0),
          initialBalanceDate: Value(DateTime(2026, 6, 23, 21, 47, 1)),
        ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: 'tx-topup',
          userId: const Value('user-a'),
          accountId: const Value('widiba'),
          toAccountId: const Value('revolut'),
          amount: 100,
          description: 'Ricarica',
          category: 'Transfer',
          type: const Value('transfer'),
          date: DateTime(2026, 6, 23),
        ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: 'tx-conad',
          userId: const Value('user-a'),
          accountId: const Value('revolut'),
          amount: -12.26,
          description: 'Conad',
          category: 'Groceries',
          type: const Value('expense'),
          date: DateTime(2026, 6, 23, 12),
        ));

    final accounts = await FinanceService(db, 'user-a').getAccounts();
    final revolut = accounts.firstWhere((a) => a.id == 'revolut');

    expect(revolut.balance, closeTo(87.74, 0.001));
  });

  test('movements before the starting day stay out of the balance', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    await db.into(db.accounts).insert(AccountsCompanion.insert(
          id: 'revolut',
          userId: const Value('user-a'),
          name: 'Revolut',
          balance: const Value(50),
          initialBalanceDate: Value(DateTime(2026, 6, 23, 21, 47, 1)),
        ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: 'tx-old',
          userId: const Value('user-a'),
          accountId: const Value('revolut'),
          amount: -30,
          description: 'Vecchia spesa',
          category: 'Other',
          type: const Value('expense'),
          date: DateTime(2026, 6, 22, 23, 59),
        ));

    final accounts = await FinanceService(db, 'user-a').getAccounts();

    expect(accounts.firstWhere((a) => a.id == 'revolut').balance, 50);
  });
}
