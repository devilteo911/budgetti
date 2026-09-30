import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/bank_sync_service.dart'
    show duplicateThreshold;
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/core/services/pending_transaction_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart' as sqlite3open;

// `flutter test` runs in the VM without sqlite3_flutter_libs' bundled native,
// so point the FFI loader at the system library (.so.0 — no -dev symlink here).
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

final _day = DateTime(2026, 6, 24, 19, 3);

Future<void> _insertDraft(
  AppDatabase db, {
  String id = 'pending_x',
  double amount = -10,
  String description = 'Coffee',
  String type = 'expense',
  String? duplicateOfId,
  double? duplicateScore,
}) =>
    db.into(db.pendingTransactions).insert(
          PendingTransactionsCompanion.insert(
            id: id,
            gmailMessageId: id,
            emailSubject: 'subject',
            emailReceivedAt: _day,
            parsedAmount: amount,
            parsedDescription: description,
            parsedDate: _day,
            createdAt: _day,
            suggestedType: Value(type),
            duplicateOfId: Value(duplicateOfId),
            duplicateScore: Value(duplicateScore),
          ),
        );

Future<PendingTransaction> _draft(AppDatabase db, [String id = 'pending_x']) =>
    (db.select(db.pendingTransactions)..where((t) => t.id.equals(id)))
        .getSingle();

Future<void> _insertTx(
  AppDatabase db, {
  String id = 'tx-existing',
  double amount = -10,
  String description = 'Coffee',
  bool isDeleted = false,
}) =>
    db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: id,
            userId: const Value('user-a'),
            accountId: const Value('wallet'),
            amount: amount,
            description: description,
            category: 'Dining',
            type: const Value('expense'),
            date: _day,
            isDeleted: Value(isDeleted),
          ),
        );

(AppDatabase, PendingTransactionService) _setup() {
  final db = AppDatabase.forExecutor(NativeDatabase.memory());
  addTearDown(db.close);
  return (db, PendingTransactionService(db, FinanceService(db, 'user-a')));
}

void main() {
  setUpAll(_ensureSqlite);

  // The double-booking bug: approve() wrote the transaction and the status
  // as two unguarded writes, so a double-tap (or a crash retried later)
  // booked the same draft twice.
  test('approving the same draft twice books exactly one transaction', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final service =
        PendingTransactionService(db, FinanceService(db, 'user-a'));

    await db.into(db.pendingTransactions).insert(
          PendingTransactionsCompanion.insert(
            id: 'pending_x',
            gmailMessageId: 'x',
            emailSubject: 'Hai pagato 10 €',
            emailReceivedAt: DateTime(2026, 1, 1),
            parsedAmount: -10,
            parsedDescription: 'Coffee',
            parsedDate: DateTime(2026, 1, 1),
            createdAt: DateTime(2026, 1, 1),
            suggestedType: const Value('expense'),
          ),
        );
    final draft = await (db.select(db.pendingTransactions)
          ..where((t) => t.id.equals('pending_x')))
        .getSingle();

    await service.approve(draft, type: 'expense', accountId: 'wallet');
    await service.approve(draft, type: 'expense', accountId: 'wallet');

    expect(await db.select(db.transactions).get(), hasLength(1));
    final status = await (db.select(db.pendingTransactions)
          ..where((t) => t.id.equals('pending_x')))
        .getSingle();
    expect(status.status, 'approved');
  });

  // B4: a capture-time check goes stale — the owner can log the same purchase
  // by hand (or another device can sync it in) between capture and approval.
  group('duplicate recheck at approval', () {
    test('a twin logged after capture is caught: nothing booked, draft flagged',
        () async {
      final (db, service) = _setup();
      await _insertDraft(db); // captured with no twin around
      await _insertTx(db); // ...then the owner logged it by hand

      final tx = await service.approve(await _draft(db),
          type: 'expense', accountId: 'wallet');

      expect(tx, isNull);
      expect(await db.select(db.transactions).get(), hasLength(1)); // untouched
      final d = await _draft(db);
      expect(d.status, 'pending'); // still in the inbox, now with the notice
      expect(d.duplicateOfId, 'tx-existing');
      expect(d.duplicateScore, greaterThan(duplicateThreshold));
    });

    test('a deleted twin does not count', () async {
      final (db, service) = _setup();
      await _insertDraft(db);
      await _insertTx(db, isDeleted: true);

      final tx = await service.approve(await _draft(db),
          type: 'expense', accountId: 'wallet');

      expect(tx, isNotNull);
    });

    test('a dismissed warning is not raised again', () async {
      final (db, service) = _setup();
      await _insertDraft(db, duplicateOfId: 'tx-existing', duplicateScore: 0.9);
      await _insertTx(db);
      await service.clearDuplicateFlag('pending_x'); // "No, è diversa"

      final d = await _draft(db);
      expect(d.duplicateDismissed, isTrue);
      expect(d.duplicateOfId, isNull);

      final tx = await service.approve(d, type: 'expense', accountId: 'wallet');

      expect(tx, isNotNull);
      expect(await db.select(db.transactions).get(), hasLength(2));
    });

    test('an unflagged draft with no twin books, under its real id', () async {
      final (db, service) = _setup();
      await _insertDraft(db);
      await _insertTx(db, amount: -99); // other amount: not a twin

      final tx = await service.approve(await _draft(db),
          type: 'expense', accountId: 'wallet');

      final booked = await (db.select(db.transactions)
            ..where((t) => t.id.equals(tx?.id ?? '')))
          .getSingleOrNull();
      expect(tx?.id, isNotEmpty);
      expect(booked, isNotNull);
      expect(booked!.amount, -10);
      expect((await _draft(db)).status, 'approved');
    });

    test('a draft flagged at capture and approved anyway books as before',
        () async {
      final (db, service) = _setup();
      await _insertTx(db);
      await _insertDraft(db, duplicateOfId: 'tx-existing', duplicateScore: 0.9);

      final tx = await service.approve(await _draft(db),
          type: 'expense', accountId: 'wallet');

      expect(tx, isNotNull);
      expect(await db.select(db.transactions).get(), hasLength(2));
    });

    test('approving twice books once and the second call returns null',
        () async {
      final (db, service) = _setup();
      await _insertDraft(db);
      final draft = await _draft(db);

      final first =
          await service.approve(draft, type: 'expense', accountId: 'wallet');
      final second =
          await service.approve(draft, type: 'expense', accountId: 'wallet');

      expect(first, isNotNull);
      expect(second, isNull); // was a phantom un-booked transaction with id ''
      expect(await db.select(db.transactions).get(), hasLength(1));
    });
  });
}
