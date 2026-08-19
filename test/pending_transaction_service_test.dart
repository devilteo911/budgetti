import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
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
}
