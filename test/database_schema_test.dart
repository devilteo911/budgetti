import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/models/transaction.dart' as model;
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

  // The declared indexes were dead code: drift's codegen ignores a plain
  // `List<Index>` getter, and the v8 upgrade step passed an ON-clause where
  // a full CREATE statement was required (always a swallowed syntax error).
  // No install ever had an index — v15 creates them for fresh and upgrading
  // databases alike.
  test('fresh install creates every declared index', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    // Touch the database so onCreate runs.
    await db.select(db.accounts).get();

    final names = (await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'index' "
      "AND name LIKE 'idx_%'",
    ).get())
        .map((r) => r.read<String>('name'))
        .toSet();

    expect(names, containsAll([
      'idx_transactions_date',
      'idx_transactions_account',
      'idx_transactions_user',
      'idx_transactions_to_account',
      'idx_pending_gmail',
      'idx_pending_status',
    ]));
  });

  // v17: the inbox needs to remember a duplicate warning the owner dismissed
  // ("No, è diversa") so the approve-time recheck doesn't flag it again. Local
  // table, so the only proof it works is upgrading a real v16-shaped database.
  test('v16 -> v17 adds duplicate_dismissed, false by default, rows intact',
      () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory(setup: (raw) {
      // ponytail: v16's pending_transactions by hand (drift has no "open at
      // version N" without schema-dump tooling); it is the shape that shipped.
      raw.execute('CREATE TABLE pending_transactions ('
          'id TEXT NOT NULL, user_id TEXT NULL, gmail_message_id TEXT NOT NULL, '
          "source TEXT NOT NULL DEFAULT 'widiba', email_subject TEXT NOT NULL, "
          'email_received_at INTEGER NOT NULL, parsed_amount REAL NOT NULL, '
          'parsed_description TEXT NOT NULL, parsed_date INTEGER NOT NULL, '
          "suggested_type TEXT NOT NULL DEFAULT 'expense', "
          'suggested_category TEXT NULL, counterparty TEXT NULL, '
          "raw_snippet TEXT NOT NULL DEFAULT '', "
          "status TEXT NOT NULL DEFAULT 'pending', created_at INTEGER NOT NULL, "
          'duplicate_of_id TEXT NULL, duplicate_score REAL NULL, '
          'PRIMARY KEY (id))');
      raw.execute('INSERT INTO pending_transactions (id, gmail_message_id, '
          'email_subject, email_received_at, parsed_amount, '
          'parsed_description, parsed_date, created_at, duplicate_of_id) '
          "VALUES ('p1', 'g1', 'subj', 1, -10, 'Coffee', 1, 1, 'tx-old')");
      raw.execute('PRAGMA user_version = 16');
    }));
    addTearDown(db.close);

    final rows = await db.customSelect(
      'SELECT id, parsed_description, duplicate_of_id, duplicate_dismissed '
      'FROM pending_transactions',
    ).get();

    expect(rows, hasLength(1));
    expect(rows.single.read<String>('parsed_description'), 'Coffee');
    expect(rows.single.read<String>('duplicate_of_id'), 'tx-old');
    expect(rows.single.read<bool>('duplicate_dismissed'), isFalse);
  });

  // The stale-balance bug: accountsProvider was a FutureProvider that nothing
  // re-ran after sync. watchAccounts must re-emit when a transaction lands —
  // balances derive from transactions, not just the accounts table.
  test('watchAccounts re-emits with the new balance when a transaction lands',
      () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final service = FinanceService(db, 'user-a');

    final accounts = await service.getAccounts(); // seeds Main Wallet
    final walletId = accounts.single.id;

    final balances = <double>[];
    final sub = service.watchAccounts().listen(
          (list) => balances.add(list.single.balance),
        );
    await emitterSettles();
    expect(balances.last, 0.0);

    await service.addTransaction(model.Transaction(
      id: 't1',
      accountId: walletId,
      amount: -42.5,
      date: DateTime(2026, 1, 1),
      description: 'coffee',
      category: 'Dining',
    ));

    await emitterSettles();
    expect(balances.last, -42.5);
    await sub.cancel();
  });
}

/// Drift streams coalesce within a microtask-ish window; give the watch a
/// beat to deliver before assertions.
Future<void> emitterSettles() => Future<void>.delayed(
      const Duration(milliseconds: 250),
    );
