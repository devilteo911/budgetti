import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/models/transaction.dart' as model;
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

  // The transaction page's category chip did `copyWith(category:, type:
  // amount>0 ? 'income' : 'expense')` on a transfer, keeping toAccountId: the
  // moved amount then counted as income on the source and vanished from the
  // destination. There is no widget test infra, so this pins the money rule
  // the editor's `if (!isTransfer)` guard protects.
  test('a transfer only moves money; retyping it invents some', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    for (final id in ['widiba', 'revolut']) {
      await db.into(db.accounts).insert(AccountsCompanion.insert(
            id: id,
            userId: const Value('user-a'),
            name: id,
            balance: Value(id == 'widiba' ? 1000 : 0),
          ));
    }
    final service = FinanceService(db, 'user-a');
    final transfer = model.Transaction(
      id: 'tx-transfer',
      accountId: 'widiba',
      toAccountId: 'revolut',
      amount: 100,
      date: DateTime(2026, 6, 23),
      description: 'Ricarica',
      category: 'Transfer',
      type: 'transfer',
    );
    await service.addTransaction(transfer);

    Future<double> total() async => (await service.getAccounts())
        .fold<double>(0, (sum, a) => sum + a.balance);
    expect(await total(), 1000);

    await service.updateTransaction(
        transfer.copyWith(category: 'Salary', type: 'income'));
    expect(await total(), 1100);
  });

  // Mirror of web/src/finance.test.ts (case 9, balances): a balance is the money
  // in the bank — the 100 € that left and the 25 € that came back twice both
  // count whole. The split only changes what the analytics read.
  test('transfers and balances stay raw', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    for (final id in ['a1', 'a2']) {
      await db.into(db.accounts).insert(AccountsCompanion.insert(
            id: id,
            userId: const Value('user-a'),
            name: id,
            balance: const Value(0),
          ));
    }
    final service = FinanceService(db, 'user-a');

    model.Transaction tx(
      String id,
      double amount,
      DateTime date, {
      String type = 'expense',
      String? toAccountId,
      double othersShare = 0,
      String? reimbursesId,
    }) =>
        model.Transaction(
          id: id,
          accountId: 'a1',
          toAccountId: toAccountId,
          amount: amount,
          date: date,
          description: id,
          category: 'x',
          type: type,
          othersShare: othersShare,
          reimbursesId: reimbursesId,
        );

    for (final t in [
      tx('pay', 2000, DateTime(2026, 6, 1, 12), type: 'income'),
      tx('food', -50, DateTime(2026, 6, 5, 12)),
      tx('dinner', -100, DateTime(2026, 6, 10, 12), othersShare: 75),
      tx('back1', 25, DateTime(2026, 6, 12, 12),
          type: 'income', reimbursesId: 'dinner'),
      tx('back2', 25, DateTime(2026, 7, 3, 12),
          type: 'income', reimbursesId: 'dinner'),
      tx('move', 300, DateTime(2026, 6, 20, 12),
          type: 'transfer', toAccountId: 'a2'),
    ]) {
      await service.addTransaction(t);
    }

    final balances = {
      for (final a in await service.getAccounts()) a.id: a.balance,
    };
    expect(balances['a1'], 1600); // 2000 - 50 - 100 + 25 + 25 - 300
    expect(balances['a2'], 300);
  });
}
