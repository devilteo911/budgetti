import 'dart:ffi';
import 'dart:io';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/models/transaction.dart' as model;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart' as sqlite3open;
import 'package:sqlite3/sqlite3.dart' as sqlite;

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
      // A real v16 database also has categories (v17 shape: no color_slot), which
      // the v18 step alters.
      raw.execute('CREATE TABLE categories ('
          'id TEXT NOT NULL, user_id TEXT NULL, name TEXT NOT NULL, '
          'icon_code INTEGER NOT NULL, color_hex INTEGER NOT NULL, '
          'type TEXT NOT NULL, description TEXT NULL, '
          'is_deleted INTEGER NOT NULL DEFAULT 0, last_updated INTEGER NULL, '
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

  // v18: a category keeps the palette slot it was given. The column is nullable
  // and starts NULL, so every existing row renders through the id hash until the
  // backfill assigns one.
  test('v17 -> v18 adds color_slot, NULL for every existing row, rows intact',
      () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory(setup: (raw) {
      raw.execute('CREATE TABLE categories ('
          'id TEXT NOT NULL, user_id TEXT NULL, name TEXT NOT NULL, '
          'icon_code INTEGER NOT NULL, color_hex INTEGER NOT NULL, '
          'type TEXT NOT NULL, description TEXT NULL, '
          'is_deleted INTEGER NOT NULL DEFAULT 0, last_updated INTEGER NULL, '
          'PRIMARY KEY (id))');
      raw.execute('INSERT INTO categories (id, name, icon_code, color_hex, type) '
          "VALUES ('c1', 'Groceries', 1, 2, 'expense')");
      raw.execute('PRAGMA user_version = 17');
    }));
    addTearDown(db.close);

    final rows =
        await db.customSelect('SELECT id, name, color_slot FROM categories').get();

    expect(rows, hasLength(1));
    expect(rows.single.read<String>('name'), 'Groceries');
    expect(rows.single.read<int?>('color_slot'), isNull);
  });

  // v19: the Partita IVA profile and its payments live in two tables of their
  // own. Both start empty; every column but the id has a default, because the
  // server sends zeros and empty strings for what was never set.
  test('v18 -> v19 crea piva_profiles e piva_payments, righe esistenti intatte',
      () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory(setup: (raw) {
      raw.execute('CREATE TABLE categories ('
          'id TEXT NOT NULL, user_id TEXT NULL, name TEXT NOT NULL, '
          'icon_code INTEGER NOT NULL, color_hex INTEGER NOT NULL, '
          'type TEXT NOT NULL, description TEXT NULL, '
          'is_deleted INTEGER NOT NULL DEFAULT 0, last_updated INTEGER NULL, '
          'color_slot INTEGER NULL, PRIMARY KEY (id))');
      raw.execute('INSERT INTO categories (id, name, icon_code, color_hex, type, '
          "color_slot) VALUES ('c1', 'Groceries', 1, 2, 'expense', 3)");
      raw.execute('PRAGMA user_version = 18');
    }));
    addTearDown(db.close);

    final cats =
        await db.customSelect('SELECT id, name, color_slot FROM categories').get();
    final tables = (await db
            .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
            .get())
        .map((r) => r.read<String>('name'))
        .toSet();

    expect(tables, containsAll(['piva_profiles', 'piva_payments']));
    expect(await db.select(db.pivaProfiles).get(), isEmpty);
    expect(await db.select(db.pivaPayments).get(), isEmpty);
    expect(cats, hasLength(1));
    expect(cats.single.read<String>('name'), 'Groceries');
    expect(cats.single.read<int?>('color_slot'), 3);

    // The id alone is a valid row: every other column falls back to its default.
    await db.customStatement("INSERT INTO piva_profiles (id) VALUES ('p')");
    await db.customStatement("INSERT INTO piva_payments (id) VALUES ('y')");
    final profile = (await db.select(db.pivaProfiles).get()).single;
    final payment = (await db.select(db.pivaPayments).get()).single;
    expect((
      profile.userId,
      profile.atecoCode,
      profile.coefficient,
      profile.startYear,
      profile.startupRate,
      profile.fundType,
      profile.fundName,
      profile.subjectiveRate,
      profile.integrativeRate,
      profile.minSubjective,
      profile.minIntegrative,
      profile.inpsReduction,
      profile.incomeCategories,
      profile.isDeleted,
      profile.lastUpdated,
    ), (null, '', 0.0, 0, false, '', '', 0.0, 0.0, 0.0, 0.0, false, null, false, null));
    expect((
      payment.userId,
      payment.key,
      payment.kind,
      payment.label,
      payment.dueDate,
      payment.amount,
      payment.paidDate,
      payment.note,
      payment.isDeleted,
      payment.lastUpdated,
    ), (null, '', '', '', null, 0.0, null, '', false, null));
  });

  // An older build opens a NEWER database without complaint — it only rewrites
  // user_version — and leaves the newer schema in place. Installing the newer
  // build again then re-runs its upgrade steps over columns and tables that are
  // already there: "duplicate column name" and a database that never opens. Every
  // `from < N` step has to be safe to run twice.
  group('re-upgrading a database an older build had opened', () {
    /// A current (v19) database file holding one row of everything the upgrade
    /// steps touch, closed and ready to be tampered with.
    Future<File> currentDb() async {
      final dir = await Directory.systemTemp.createTemp('budgetti_downgrade_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/db.sqlite');
      final db = AppDatabase.forExecutor(NativeDatabase(file));
      await db.into(db.accounts).insert(AccountsCompanion.insert(
          id: 'acc', userId: const Value('u'), name: 'Widiba'));
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'cat', name: 'Dining', iconCode: 1, colorHex: 2, type: 'expense'));
      await db.into(db.tags).insert(
          TagsCompanion.insert(id: 'tag', name: 'Trip', colorHex: 3));
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: 'tx',
          userId: const Value('u'),
          accountId: const Value('acc'),
          amount: -12.5,
          description: 'Coffee',
          category: 'Dining',
          date: DateTime(2026, 6, 24)));
      for (final (id, dismissed) in [('kept', true), ('plain', false)]) {
        await db.into(db.pendingTransactions).insert(
              PendingTransactionsCompanion.insert(
                id: id,
                gmailMessageId: id,
                emailSubject: 's',
                emailReceivedAt: DateTime(2026, 6, 24),
                parsedAmount: -10,
                parsedDescription: 'Coffee',
                parsedDate: DateTime(2026, 6, 24),
                createdAt: DateTime(2026, 6, 24),
                duplicateOfId: const Value('tx'),
                duplicateScore: const Value(0.8),
                duplicateDismissed: Value(dismissed),
              ),
            );
      }
      await db.into(db.pivaProfiles).insert(PivaProfilesCompanion.insert(
          id: 'prof',
          userId: const Value('u'),
          incomeCategories: Value(['Consulting', 'Services'])));
      await db.into(db.pivaPayments).insert(PivaPaymentsCompanion.insert(
          id: 'pay',
          userId: const Value('u'),
          key: const Value('imposta_saldo'),
          dueDate: Value(DateTime(2026, 6, 30, 12)),
          paidDate: const Value(null)));
      await db.close();
      return file;
    }

    void tamper(File file, void Function(sqlite.Database raw) f) {
      final raw = sqlite.sqlite3.open(file.path);
      f(raw);
      raw.dispose();
    }

    /// Opens [file] with the current build (its upgrade runs) and reads back
    /// what the steps must not have disturbed.
    Future<Map<String, Object?>> reopen(File file) async {
      final db = AppDatabase.forExecutor(NativeDatabase(file));
      final out = <String, Object?>{
        'accounts': [for (final a in await db.select(db.accounts).get()) a.name],
        'categories': [for (final c in await db.select(db.categories).get()) c.name],
        'tags': [for (final t in await db.select(db.tags).get()) t.name],
        'transactions': [
          for (final t in await db.select(db.transactions).get())
            (t.description, t.amount)
        ],
        'pending': {
          for (final p in await db.select(db.pendingTransactions).get())
            p.id: (p.duplicateOfId, p.duplicateScore, p.duplicateDismissed),
        },
        'pivaProfiles': [
          for (final p in await db.select(db.pivaProfiles).get()) p.id
        ],
        // Apart from the profile record: a list inside a record compares by
        // identity, a list in a list is compared by `expect` element by element.
        'incomeCategories': [
          for (final p in await db.select(db.pivaProfiles).get())
            p.incomeCategories
        ],
        'pivaPayments': [
          for (final p in await db.select(db.pivaPayments).get())
            (p.id, p.key, p.dueDate, p.paidDate)
        ],
      };
      await db.close();
      return out;
    }

    final intact = {
      'accounts': ['Widiba'],
      'categories': ['Dining'],
      'tags': ['Trip'],
      'transactions': [('Coffee', -12.5)],
      'pending': {'kept': ('tx', 0.8, true), 'plain': ('tx', 0.8, false)},
      'pivaProfiles': ['prof'],
      'incomeCategories': [
        ['Consulting', 'Services']
      ],
      'pivaPayments': [
        ('pay', 'imposta_saldo', DateTime(2026, 6, 30, 12), null)
      ],
    };

    int userVersion(File file) {
      final raw = sqlite.sqlite3.open(file.path);
      final v = raw.select('PRAGMA user_version').first.values.first as int;
      raw.dispose();
      return v;
    }

    test('v19 schema, user_version 16 (the QA-4 brick): opens, data intact',
        () async {
      final file = await currentDb();
      tamper(file, (raw) => raw.execute('PRAGMA user_version = 16'));

      expect(await reopen(file), intact);
      expect(userVersion(file), 19);
    });

    test('v19 schema, user_version 1: every step re-runs over what exists',
        () async {
      final file = await currentDb();
      tamper(file, (raw) => raw.execute('PRAGMA user_version = 1'));

      expect(await reopen(file), intact);
      expect(userVersion(file), 19);
    });

    // The old steps wrapped their addColumn pairs in one swallow-all try: the
    // first column already existing skipped the second, silently. A half-applied
    // step (or a downgrade past it) left the second column missing for good.
    test('a step whose first column exists still adds its second', () async {
      final file = await currentDb();
      tamper(file, (raw) {
        // duplicate_of_id stays; duplicate_score (its v10 partner) goes. So does
        // duplicate_dismissed, so that v17 is not what this test is about.
        raw.execute('ALTER TABLE pending_transactions DROP COLUMN duplicate_score');
        raw.execute(
            'ALTER TABLE pending_transactions DROP COLUMN duplicate_dismissed');
        raw.execute('PRAGMA user_version = 9');
      });

      final db = AppDatabase.forExecutor(NativeDatabase(file));
      final pending = await db.select(db.pendingTransactions).get();
      await db.close();

      final raw = sqlite.sqlite3.open(file.path);
      final columns = raw
          .select('PRAGMA table_info(pending_transactions)')
          .map((r) => r['name'] as String)
          .toSet();
      raw.dispose();
      expect(columns, containsAll(['duplicate_of_id', 'duplicate_score']));
      expect(pending.map((p) => p.id), unorderedEquals(['kept', 'plain']));
      expect(pending.map((p) => p.duplicateOfId), everyElement('tx'));
    });

    // The other side of the same change: the steps no longer swallow every error,
    // so a genuinely old database must still get each column added for real.
    test('a v2-shaped database still gets every column the old steps add',
        () async {
      final dir = await Directory.systemTemp.createTemp('budgetti_v2_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/db.sqlite');
      tamper(file, (raw) {
        raw.execute('CREATE TABLE categories (id TEXT NOT NULL, name TEXT NOT NULL, '
            'icon_code INTEGER NOT NULL, color_hex INTEGER NOT NULL, '
            'type TEXT NOT NULL, PRIMARY KEY (id))');
        raw.execute('CREATE TABLE tags (id TEXT NOT NULL, name TEXT NOT NULL, '
            'color_hex INTEGER NOT NULL, PRIMARY KEY (id))');
        raw.execute("INSERT INTO categories VALUES ('c', 'Dining', 1, 2, 'expense')");
        raw.execute("INSERT INTO tags VALUES ('t', 'Trip', 3)");
        raw.execute('PRAGMA user_version = 2');
      });

      final db = AppDatabase.forExecutor(NativeDatabase(file));
      final cats = await db.select(db.categories).get();
      final tagRows = await db.select(db.tags).get();
      await db.close();

      expect((cats.single.name, cats.single.isDeleted, cats.single.userId),
          ('Dining', false, null));
      expect((tagRows.single.name, tagRows.single.isDeleted), ('Trip', false));
      final raw = sqlite.sqlite3.open(file.path);
      Set<String> columns(String table) => raw
          .select('PRAGMA table_info($table)')
          .map((r) => r['name'] as String)
          .toSet();
      expect(columns('categories'),
          containsAll(['description', 'user_id', 'is_deleted', 'last_updated']));
      expect(columns('tags'), containsAll(['user_id', 'is_deleted', 'last_updated']));
      expect(columns('accounts'), containsAll(['is_default', 'initial_balance_date']));
      expect(columns('transactions'),
          containsAll(['to_account_id', 'type', 'installment_id']));
      expect(columns('pending_transactions'), containsAll(
          ['duplicate_of_id', 'duplicate_score', 'source', 'duplicate_dismissed']));
      raw.dispose();
    });

    test('the tables and indexes steps create survive a re-run', () async {
      final file = await currentDb();
      tamper(file, (raw) => raw.execute('PRAGMA user_version = 1'));
      await reopen(file);

      final raw = sqlite.sqlite3.open(file.path);
      final names = raw
          .select("SELECT name FROM sqlite_master WHERE type IN ('table','index')")
          .map((r) => r['name'] as String)
          .toSet();
      raw.dispose();
      expect(names, containsAll([
        'tags', 'accounts', 'transactions', 'budgets', 'pending_transactions',
        'installments', 'sync_locks', 'sync_failures',
        'piva_profiles', 'piva_payments',
        'idx_transactions_date', 'idx_pending_status',
      ]));
    });
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
