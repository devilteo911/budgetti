import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
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

  // Sync fields
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastUpdated => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  // List of indexes for this table
  List<Index> get indexes => [
    Index('idx_transactions_date', 'ON transactions (date DESC)'),
    Index('idx_transactions_account', 'ON transactions (account_id)'),
    Index('idx_transactions_user', 'ON transactions (user_id)'),
  ];
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

/// Draft transactions parsed from bank (Widiba) emails, awaiting user review.
/// The row is kept after approval/rejection so [gmailMessageId] acts as a
/// permanent de-duplication ledger across re-syncs.
class PendingTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get gmailMessageId => text()();
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

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
    Index('idx_pending_gmail', 'ON pending_transactions (gmail_message_id)'),
    Index('idx_pending_status', 'ON pending_transactions (status)'),
  ];
}

@DriftDatabase(
  tables: [Categories, Tags, Accounts, Transactions, Budgets, PendingTransactions],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 9; // Incremented from 8

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _seedCategories();
      await _seedTags();
      await _seedMainAccount();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(tags);
        await _seedTags();
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

        await _seedMainAccount();
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
      if (from < 8) {
        try {
          await m.createIndex(
            Index('idx_transactions_date', 'ON transactions (date DESC)'),
          );
        } catch (_) {}
        try {
          await m.createIndex(
            Index('idx_transactions_account', 'ON transactions (account_id)'),
          );
        } catch (_) {}
        try {
          await m.createIndex(
            Index('idx_transactions_user', 'ON transactions (user_id)'),
          );
        } catch (_) {}
      }
      if (from < 9) {
        await m.createTable(pendingTransactions);
      }
    },
    beforeOpen: (details) async {
      await _seedIfEmpty();
    },
  );

  Future<void> _seedCategories() async {
    final defaults = [
      // Expenses
      (name: 'Groceries', icon: 57954, color: 0xFF4CAF50, type: 'expense'),
      (name: 'Transport', icon: 57675, color: 0xFF2196F3, type: 'expense'),
      (name: 'Dining', icon: 57924, color: 0xFFFF9800, type: 'expense'),
      (name: 'Shopping', icon: 59600, color: 0xFF9C27B0, type: 'expense'),
      (name: 'Entertainment', icon: 58022, color: 0xFFFF5722, type: 'expense'),
      (name: 'Health', icon: 58009, color: 0xFFF44336, type: 'expense'),
      (name: 'Bills', icon: 59469, color: 0xFF607D8B, type: 'expense'), 
      
      // Income
      (name: 'Salary', icon: 57357, color: 0xFF009688, type: 'income'),
      (name: 'Freelance', icon: 59647, color: 0xFF3F51B5, type: 'income'),
      (name: 'Investments', icon: 60232, color: 0xFF673AB7, type: 'income'), 
    ];

    await batch((batch) {
      batch.insertAll(categories, defaults.map((d) {
        return CategoriesCompanion.insert(
            id: DateTime.now().millisecondsSinceEpoch.toString() + d.name, 
          name: d.name,
          iconCode: d.icon,
          colorHex: d.color,
          type: d.type,
        );
      }));
    });
  }

  Future<void> _seedTags() async {
    final defaults = [
      (name: 'Vacation', color: 0xFFE91E63),
      (name: 'Family', color: 0xFF9C27B0),
      (name: 'Work', color: 0xFF3F51B5),
      (name: 'Personal', color: 0xFF00BCD4),
      (name: 'Gift', color: 0xFFFF5722),
    ];

    await batch((batch) {
      batch.insertAll(tags, defaults.map((d) {
        return TagsCompanion.insert(
          id: DateTime.now().millisecondsSinceEpoch.toString() + d.name,
          name: d.name,
          colorHex: d.color,
        );
      }));
    });
  }
  
  Future<void> _seedMainAccount() async {
    // Only insert if no accounts exist
    final count = await (select(accounts)..limit(1)).get();
    if (count.isEmpty) {
      await into(accounts).insert(
        AccountsCompanion.insert(
          id: '1',
          name: 'Main Wallet',
          balance: const Value(0.0),
          currency: const Value('EUR'),
          providerName: const Value('Local'),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
  }

  /// Seeds default categories if the table is empty
  Future<void> _seedIfEmpty() async {
    final count = await (select(categories)..limit(1)).get();
    if (count.isEmpty) {
      await _seedCategories();
    }
    
    final tagCount = await (select(tags)..limit(1)).get();
    if (tagCount.isEmpty) {
      await _seedTags();
    }
    
    await _seedMainAccount();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
