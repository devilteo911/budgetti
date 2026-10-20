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

/// The split columns of `transactions` (`others_share`, `reimburses_id`): every
/// write path of the service stores them only where the type can carry them,
/// and never a negative share or one above the amount — the server rejects a
/// negative `othersShare`, which would dead-letter the row.
void main() {
  setUpAll(_ensureSqlite);

  late AppDatabase db;
  late FinanceService service;

  setUp(() {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    service = FinanceService(db, 'user-a');
  });
  tearDown(() => db.close());

  model.Transaction expense({
    double amount = -100,
    double othersShare = 0,
  }) =>
      model.Transaction(
        id: 'exp',
        accountId: 'a1',
        amount: amount,
        date: DateTime(2026, 6, 24),
        description: 'Dinner',
        category: 'Dining',
        othersShare: othersShare,
      );

  model.Transaction reimbursement({String? reimbursesId = 'exp'}) =>
      model.Transaction(
        id: 'inc',
        accountId: 'a1',
        amount: 75,
        date: DateTime(2026, 6, 25),
        description: 'Back',
        category: 'Dining',
        type: 'income',
        reimbursesId: reimbursesId,
      );

  Future<Transaction> row(String id) =>
      (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();

  group('othersShare', () {
    test('an expense written with a share reads it back', () async {
      await service.addTransaction(expense(othersShare: 75));

      expect((await row('exp')).othersShare, 75);
    });

    test('the same row re-saved as an income (the quick edit) loses it',
        () async {
      await service.addTransaction(expense(othersShare: 75));
      final saved = expense(othersShare: 75);

      // transaction_page.dart changes the type through copyWith, behind the editor.
      await service.updateTransaction(saved.copyWith(type: 'income'));

      expect((await row('exp')).othersShare, 0);
    });

    test('a negative share is written as 0', () async {
      await service.addTransaction(expense(othersShare: -5));

      expect((await row('exp')).othersShare, 0);
    });

    test('a share above the amount is written as the amount', () async {
      await service.addTransaction(expense(othersShare: 150));

      expect((await row('exp')).othersShare, 100);
    });

    test('lowering the amount on update re-clamps the share', () async {
      await service.addTransaction(expense(othersShare: 75));

      await service.updateTransaction(expense(amount: -60, othersShare: 75));

      expect((await row('exp')).othersShare, 60);
    });
  });

  group('reimbursesId', () {
    test('an income written with one reads it back', () async {
      await service.addTransaction(reimbursement());

      expect((await row('inc')).reimbursesId, 'exp');
    });

    test('the same row re-saved as an expense loses it', () async {
      await service.addTransaction(reimbursement());

      await service.updateTransaction(reimbursement().copyWith(type: 'expense'));

      expect((await row('inc')).reimbursesId, isNull);
    });

    test('an income that is not positive, or names no expense, stores null',
        () async {
      await service.addTransaction(
          reimbursement().copyWith(amount: -75)); // the sign says expense
      expect((await row('inc')).reimbursesId, isNull);

      await service.updateTransaction(reimbursement());
      expect((await row('inc')).reimbursesId, 'exp');

      await service.updateTransaction(reimbursement(reimbursesId: ''));
      expect((await row('inc')).reimbursesId, isNull);
    });
  });

  group('linkReimbursement', () {
    Future<void> seedIncome() =>
        db.into(db.transactions).insert(TransactionsCompanion.insert(
              id: 'inc',
              userId: const Value('user-a'),
              accountId: const Value('a1'),
              amount: 75,
              description: 'Back',
              category: 'Dining',
              type: const Value('income'),
              date: DateTime(2026, 6, 25),
              lastUpdated: Value(DateTime(2020)),
            ));

    /// Every column the link must not touch.
    Map<String, Object?> rest(Transaction t) => t.toJson()
      ..remove('reimbursesId')
      ..remove('lastUpdated');

    test('links, stamps lastUpdated, unlinks, and touches nothing else',
        () async {
      await seedIncome();
      final before = await row('inc');

      await service.linkReimbursement('inc', 'exp');
      final linked = await row('inc');
      expect(linked.reimbursesId, 'exp');
      expect(linked.lastUpdated!.isAfter(before.lastUpdated!), isTrue);
      expect(rest(linked), rest(before));

      // Back in the past, so the unlink's stamp is a move too.
      await (db.update(db.transactions)..where((t) => t.id.equals('inc')))
          .write(TransactionsCompanion(lastUpdated: Value(DateTime(2020))));
      await service.linkReimbursement('inc', null);
      final unlinked = await row('inc');
      expect(unlinked.reimbursesId, isNull);
      expect(unlinked.lastUpdated!.isAfter(DateTime(2020)), isTrue);
      expect(rest(unlinked), rest(before));
    });

    test('an empty id unlinks too, stored as null', () async {
      await seedIncome();
      await service.linkReimbursement('inc', 'exp');

      await service.linkReimbursement('inc', '');

      expect((await row('inc')).reimbursesId, isNull);
    });
  });
}
