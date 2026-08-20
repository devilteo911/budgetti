import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:meta/meta.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

part 'database.g.dart';

// Converters
class ListStringConverter extends TypeConverter<List<String>, String> {
  const ListStringConverter();
  @override
  List<String> fromSql(String fromDb) {
    try {
      if (fromDb.isEmpty) return [];
      return List<String>.from(json.decode(fromDb));
    } catch (e) {
      return [];
    }
  }

  @override
  String toSql(List<String> value) {
    return json.encode(value);
  }
}

// Tables

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get name => text()();
  IntColumn get iconCode => integer()();
  IntColumn get colorHex => integer()();
  TextColumn get type => text()(); // 'income' or 'expense'
  TextColumn get description => text().nullable()();
  
  // Sync fields
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastUpdated => dateTime().nullable()();
  
  @override
  Set<Column> get primaryKey => {id};
}

class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get name => text()();
  IntColumn get colorHex => integer()();

  // Sync fields
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastUpdated => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get name => text()();
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  TextColumn get currency => text().withDefault(const Constant('EUR'))();
  TextColumn get providerName => text().nullable()();

  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get initialBalanceDate => dateTime().nullable()();

  // Sync fields
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastUpdated => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get accountId => text().nullable()();
  TextColumn get toAccountId => text().nullable()();
  RealColumn get amount => real()();
  TextColumn get description => text()();
  TextColumn get category => text()();
  TextColumn get type => text().withDefault(
    const Constant('expense'),
  )(); // 'income', 'expense', or 'transfer'
  DateTimeColumn get date => dateTime()();
  TextColumn get tags => text().map(const ListStringConverter()).nullable()();

  /// Id of the [Installments] plan this charge pays a rate of, null otherwise.
  /// Not a real FK: rows arrive from sync in any order, so referential
  /// integrity is enforced nowhere and a dangling id just reads as unlinked.
  TextColumn get installmentId => text().nullable()();

  // Sync fields
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastUpdated => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get category => text()();
  RealColumn get limitAmount => real()();
  TextColumn get period => text()(); // 'monthly', 'weekly', etc.

  // Sync fields
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastUpdated => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// An installment plan ("pagamento a rate"): a fixed total split over N equal
/// monthly charges starting at [startDate].
///
/// ponytail: the schedule is derived, not stored — no per-rate row and no
/// generated transactions. The real charges already arrive from bank capture,
/// so materialising them here would double-count. See `models/installment.dart`
/// for the derivation (paid / remaining / next due). Monthly only; add a
/// `period` column if a non-monthly plan ever shows up.
class Installments extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get description => text()();
  RealColumn get totalAmount => real()();
  IntColumn get installmentCount => integer()();
  DateTimeColumn get startDate => dateTime()(); // date of the first rate
  TextColumn get category => text().nullable()();
  TextColumn get accountId => text().nullable()();

  // Sync fields
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastUpdated => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Draft transactions awaiting review — captured from Widiba bank emails or
/// Revolut Android notifications. [source] distinguishes them so the inbox
/// resolves the correct wallet on approval. The row is kept after
/// approval/rejection so [gmailMessageId] acts as a permanent
/// de-duplication ledger across re-syncs.
class PendingTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get gmailMessageId => text()();
  TextColumn get source =>
      text().withDefault(const Constant('widiba'))(); // widiba | revolut
  TextColumn get emailSubject => text()();
  DateTimeColumn get emailReceivedAt => dateTime()();

  RealColumn get parsedAmount => real()(); // signed: negative = expense
  TextColumn get parsedDescription => text()();
  DateTimeColumn get parsedDate => dateTime()();
  TextColumn get suggestedType =>
      text().withDefault(const Constant('expense'))(); // income/expense/transfer/undecided
  TextColumn get suggestedCategory => text().nullable()();
  TextColumn get counterparty => text().nullable()();
  TextColumn get rawSnippet => text().withDefault(const Constant(''))();

  TextColumn get status =>
      text().withDefault(const Constant('pending'))(); // pending/approved/rejected
  DateTimeColumn get createdAt => dateTime()();

  // Possible-duplicate flag: id of the existing transaction this draft seems
  // to repeat, with the heuristic confidence. Cleared when the user says
  // "it's a different one".
  TextColumn get duplicateOfId => text().nullable()();
  RealColumn get duplicateScore => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cross-isolate mutex for PocketBase sync (one row, id `pb_sync`).
/// `PocketBaseSyncService._isSyncing` is instance-local, but the workmanager
/// task builds its own service instance — a background and a foreground sync
/// can then interleave, with the stale body clobbering newer server rows and
/// the slower run overwriting the fresh cursor. The claim is a guarded
/// `UPDATE … WHERE running = 0 OR acquired_at < now − 15 min`, so a crashed
/// holder is taken over rather than deadlocking syncs until reinstall.
class SyncLocks extends Table {
  TextColumn get id => text()();
  BoolColumn get running => boolean().withDefault(const Constant(false))();
  DateTimeColumn get acquiredAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-row push failure ledger feeding dead-lettering (roadmap batch 3,
/// item 5): after [PocketBaseSyncService._maxPushAttempts] attempts a row the
/// server will never accept is set aside so the cursor can pass it, instead of
/// re-pushing everything newer than it on every sync, forever. Keyed by
/// (collection, record id); the lastUpdated it failed at rides along, so an
/// edit that restamps the row clears its slate (the counter resets on
/// mismatch) — a dead-letter is about the row *version*, not the row.
class SyncFailures extends Table {
  TextColumn get collection => text()();
  TextColumn get recordId => text()();
  IntColumn get lastUpdatedMs => integer().withDefault(const Constant(0))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().withDefault(const Constant(''))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {collection, recordId};
}

@DriftDatabase(
  tables: [
    Categories,
    Tags,
    Accounts,
    Transactions,
    Budgets,
    Installments,
    PendingTransactions,
    SyncLocks,
    SyncFailures,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// In-memory executor for tests (no file I/O, no platform plugins).
  @visibleForTesting
  AppDatabase.forExecutor(super.e);

  @override
  int get schemaVersion => 16; // v16: sync lock + push-failure ledger

  /// Every index the schema declares, as full CREATE statements. Drift's
  /// codegen only picks up `@TableIndex` annotations — the plain
  /// `List<Index> get indexes` getters these used to live in were ignored, so
  /// fresh installs had none. (The old v8 upgrade step never created them
  /// either: `Index()` takes a full CREATE statement, but it was handed only
  /// the `ON …` tail, which is a syntax error that the swallow-all catch
  /// around it hid — no install ever had these.)
  static const List<(String, String)> _indexes = [
    (
      'idx_transactions_date',
      'CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions (date DESC)',
    ),
    (
      'idx_transactions_account',
      'CREATE INDEX IF NOT EXISTS idx_transactions_account ON transactions (account_id)',
    ),
    (
      'idx_transactions_user',
      'CREATE INDEX IF NOT EXISTS idx_transactions_user ON transactions (user_id)',
    ),
    // Transfer-destination balance aggregation filters on to_account_id.
    (
      'idx_transactions_to_account',
      'CREATE INDEX IF NOT EXISTS idx_transactions_to_account ON transactions (to_account_id)',
    ),
    (
      'idx_pending_gmail',
      'CREATE INDEX IF NOT EXISTS idx_pending_gmail ON pending_transactions (gmail_message_id)',
    ),
    (
      'idx_pending_status',
      'CREATE INDEX IF NOT EXISTS idx_pending_status ON pending_transactions (status)',
    ),
  ];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    // No seeding here. Defaults are owned by FinanceService._ensureUserDefaults,
    // which stamps `userId` and derives ids from it. The seeders that used to
    // live here wrote userId-less rows under a different id scheme, so the two
    // sets never deduped against each other and every default showed up twice.
    onCreate: (Migrator m) async {
      await m.createAll();
      for (final (name, stmt) in _indexes) {
        await m.createIndex(Index(name, stmt));
      }
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(tags);
      }
      if (from < 3) {
        try {
          await m.addColumn(categories, categories.description);
        } catch (e) {
          // Ignore: column might already exist
        }
      }
      if (from < 4) {
        try {
          await m.addColumn(categories, categories.userId);
          await m.addColumn(tags, tags.userId);
        } catch (e) {
          // Ignore: column might already exist
        }
      }
      if (from < 5) {
        // Add new tables
        await m.createTable(accounts);
        await m.createTable(transactions);
        await m.createTable(budgets);

        // Add sync columns to existing tables
        // Categories
        try {
          await m.addColumn(categories, categories.isDeleted);
        } catch (e) {
          // Ignore
        }
        try {
          await m.addColumn(categories, categories.lastUpdated);
        } catch (e) {
          // Ignore
        }

        // Tags
        try {
          await m.addColumn(tags, tags.isDeleted);
        } catch (e) {
          // Ignore
        }
        try {
          await m.addColumn(tags, tags.lastUpdated);
        } catch (e) {
          // Ignore
        }
      }
      if (from < 6) {
        try {
          await m.addColumn(accounts, accounts.isDefault);
          await m.addColumn(accounts, accounts.initialBalanceDate);
        } catch (e) {
          // Ignore: column might already exist
        }
      }
      if (from < 7) {
        try {
          await m.addColumn(transactions, transactions.toAccountId);
          await m.addColumn(transactions, transactions.type);
        } catch (e) {
          // Ignore: column might already exist
        }
      }
      // (v8's index creation never worked — see [_indexes]; v15 creates them.)
      if (from < 9) {
        await m.createTable(pendingTransactions);
      }
      if (from < 10) {
        try {
          await m.addColumn(
              pendingTransactions, pendingTransactions.duplicateOfId);
          await m.addColumn(
              pendingTransactions, pendingTransactions.duplicateScore);
        } catch (_) {}
      }
      if (from < 11) {
        try {
          await m.addColumn(pendingTransactions, pendingTransactions.source);
        } catch (_) {}
      }
      if (from < 12) {
        await _dedupeSeededDefaults();
      }
      if (from < 13) {
        await m.createTable(installments);
      }
      if (from < 14) {
        try {
          await m.addColumn(transactions, transactions.installmentId);
        } catch (_) {}
      }
      if (from < 15) {
        for (final (name, stmt) in _indexes) {
          await m.createIndex(Index(name, stmt));
        }
      }
      if (from < 16) {
        await m.createTable(syncLocks);
        await m.createTable(syncFailures);
      }
    },
  );

  /// One-off cleanup for the duplicate defaults two seeders used to create:
  /// this class seeded userId-less rows keyed `<timestamp><name>`, while
  /// FinanceService seeded `<userId>_cat_<name>`, so neither deduped the other
  /// and every default existed twice. Keeps the oldest row per name (lowest
  /// rowid = first inserted) and soft-deletes the newer copies.
  ///
  /// Safe against transactions: they reference categories and tags by NAME,
  /// not by id, so the surviving row keeps matching. Soft delete (rather than
  /// DELETE) is what the sync layer expects — a hard delete would come back on
  /// the next pull.
  @visibleForTesting
  Future<void> dedupeForTest() => _dedupeSeededDefaults();

  Future<void> _dedupeSeededDefaults() async {
    // Categories group by (name, type): the same name can legitimately exist
    // as both an income and an expense category.
    const keys = {'categories': 'name, type', 'tags': 'name'};
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (final entry in keys.entries) {
      await customStatement(
        'UPDATE ${entry.key} SET is_deleted = 1, last_updated = ? '
        'WHERE is_deleted = 0 AND rowid NOT IN ('
        '  SELECT MIN(rowid) FROM ${entry.key} WHERE is_deleted = 0'
        '  GROUP BY ${entry.value}'
        ')',
        [now],
      );
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
