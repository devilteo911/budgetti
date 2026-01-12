import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/models/account.dart' as model_account;
import 'package:budgetti/models/category.dart' as model;
import 'package:budgetti/models/transaction.dart' as model_txn;
import 'package:budgetti/models/tag.dart' as model_tag;
import 'package:budgetti/models/budget.dart' as model_budget;
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

abstract class FinanceService {
  Future<List<model_account.Account>> getAccounts();
  Future<void> addAccount(model_account.Account account);
  Future<void> updateAccount(model_account.Account account);
  Future<void> deleteAccount(String id);
  Future<List<model_txn.Transaction>> getTransactions({
    String? accountId,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? categories,
    List<String>? tags,
    int? limit,
    int? offset,
  });
  Future<void> addTransaction(model_txn.Transaction transaction);
  Future<void> updateTransaction(model_txn.Transaction transaction);
  Future<void> deleteTransactions(List<String> ids);
  Future<List<model.Category>> getCategories();
  Future<void> addCategory(model.Category category);
  Future<void> updateCategory(model.Category category);
  Future<void> deleteCategory(String id);
  Future<List<model_tag.Tag>> getTags();
  Future<void> addTag(model_tag.Tag tag);
  Future<void> updateTag(model_tag.Tag tag);
  Future<void> deleteTag(String id);
  Future<List<model_budget.Budget>> getBudgets();
  Future<void> upsertBudget(model_budget.Budget budget);
  Future<void> deleteBudget(String id);
  Future<void> restoreDefaultCategories();
  Future<void> restoreDefaultTags();
}

class LocalFinanceService implements FinanceService {
  final AppDatabase _db;
  final String _userId;
  bool _initialized = false;

  static const List<({String name, int icon, int color, String type})>
  _defaultCategories = [
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

  static const List<({String name, int color})> _defaultTags = [
    (name: 'Vacation', color: 0xFFE91E63),
    (name: 'Family', color: 0xFF9C27B0),
    (name: 'Work', color: 0xFF3F51B5),
    (name: 'Personal', color: 0xFF00BCD4),
    (name: 'Gift', color: 0xFFFF5722),
  ];

  LocalFinanceService(this._db, this._userId);


  /// Ensures user has default data (account, categories, tags)
  Future<void> _ensureUserDefaults() async {
    if (_initialized) return;
    _initialized = true;

    // Check if user has any accounts
    final accountCount =
        await (_db.select(_db.accounts)
              ..where((tbl) => tbl.userId.equals(_userId))
              ..limit(1))
            .get();

    if (accountCount.isEmpty) {
      // Create Main Wallet for this user
      await _db
          .into(_db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: '${_userId}_main',
              name: 'Main Wallet',
              balance: const Value(0.0),
              currency: const Value('EUR'),
              providerName: const Value('Local'),
              userId: Value(_userId),
              lastUpdated: Value(DateTime.now()),
            ),
            mode: InsertMode.insertOrIgnore,
          );

      // Create default categories for this user
      await _db.batch((batch) {
        batch.insertAll(
          _db.categories,
          _defaultCategories.map((d) {
            return CategoriesCompanion.insert(
              id: '${_userId}_cat_${d.name}',
              name: d.name,
              iconCode: d.icon,
              colorHex: d.color,
              type: d.type,
              userId: Value(_userId),
              lastUpdated: Value(DateTime.now()),
            );
          }),
        );
      });

      // Create default tags for this user
      await _db.batch((batch) {
        batch.insertAll(
          _db.tags,
          _defaultTags.map((d) {
            return TagsCompanion.insert(
              id: '${_userId}_tag_${d.name}',
              name: d.name,
              colorHex: d.color,
              userId: Value(_userId),
              lastUpdated: Value(DateTime.now()),
            );
          }),
        );
      });
    }
  }

  @override
  Future<List<model_account.Account>> getAccounts() async {
    // Ensure user has default data on first access
    await _ensureUserDefaults();

    // 1. Fetch all accounts not deleted for this user
    final accountsDb =
        await (_db.select(_db.accounts)..where(
              (tbl) => tbl.isDeleted.equals(false) & tbl.userId.equals(_userId),
            ))
            .get();

    // 2. Calculate balances dynamically from transactions
    // Fetch all active transactions for this user
    final transactionsDb =
        await (_db.select(_db.transactions)..where(
              (tbl) => tbl.isDeleted.equals(false) & tbl.userId.equals(_userId),
            ))
            .get();
    
    final Map<String, double> transactionSums = {};
    
    for (var t in transactionsDb) {
      final accId = t.accountId ?? '1'; // Default to Main Wallet if null
      transactionSums[accId] = (transactionSums[accId] ?? 0.0) + t.amount;
    }

    return accountsDb.map((acc) {
      final sum = transactionSums[acc.id] ?? 0.0;
      return model_account.Account(
        id: acc.id,
        name: acc.name,
        // db.balance acts as initial balance
        balance: acc.balance + sum, 
        currency: acc.currency,
        providerName: acc.providerName ?? 'Local',
        initialBalance: acc.balance,
      );
    }).toList();
  }

  @override
  Future<void> addAccount(model_account.Account account) async {
    await _db.into(_db.accounts).insert(AccountsCompanion.insert(
      id: account.id.isEmpty ? const Uuid().v4() : account.id,
      name: account.name,
      balance: Value(account.balance), // Storing initial balance
      currency: Value(account.currency),
      providerName: Value(account.providerName),
            userId: Value(_userId),
      lastUpdated: Value(DateTime.now()),
    ));
  }

  @override
  Future<void> updateAccount(model_account.Account account) async {
    await (_db.update(_db.accounts)..where((t) => t.id.equals(account.id))).write(AccountsCompanion(
      name: Value(account.name),
      balance: Value(account.initialBalance), // Update initial balance
      currency: Value(account.currency),
      lastUpdated: Value(DateTime.now()),
    ));
  }

  @override
  Future<void> deleteAccount(String id) async {
    await (_db.update(_db.accounts)..where((t) => t.id.equals(id))).write(AccountsCompanion(
      isDeleted: const Value(true),
      lastUpdated: Value(DateTime.now()),
    ));
  }

  @override
  Future<List<model_txn.Transaction>> getTransactions({
    String? accountId,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? categories,
    List<String>? tags,
    int? limit,
    int? offset,
  }) async {
    var query = _db.select(_db.transactions)
      ..where((tbl) => tbl.isDeleted.equals(false) & tbl.userId.equals(_userId));

    if (accountId != null) {
      query.where((tbl) => tbl.accountId.equals(accountId));
    }

    if (startDate != null || endDate != null) {
      query.where(
        (tbl) => tbl.date.isBetween(
          Constant(startDate ?? DateTime(1900)),
          Constant(endDate ?? DateTime(2100)),
        ),
      );
    }

    if (categories != null && categories.isNotEmpty) {
      query.where((tbl) => tbl.category.isIn(categories));
    }

    // Tag filtering: Since tags are stored as a JSON list in a text column,
    // we use a simple LIKE approach for simplicity if drift doesn't support json_each easily here.
    // However, for better accuracy with JSON, we'd need custom expressions.
    // For now, let's use a basic isIn if we can, but since it's a mapped list,
    // filtering by 'any tag in list' is a bit complex in pure Drift without custom SQL.
    // Let's implement a basic version that filters in memory for tags if needed,
    // or use a more efficient SQL if possible.
    // Actually, SQLite has json_each. Let's see if we can do it.
    // For now, let's keep it simple: if tags are provided, filter the result set.
    // WAIT, better to stay consistent: I'll filter date and category in DB, and tags in memory for now if needed,
    // OR try to use a LIKE based approach which works 99% of the time for simple JSON.
    if (tags != null && tags.isNotEmpty) {
      // Very basic approach: if any of the tags is in the JSON string
      // This is not perfect but works for simple cases.
      // Better approach: filter in-memory after fetching or use custom expression.
    }

    query.orderBy([
      (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
    ]);

    if (limit != null) {
      query.limit(limit, offset: offset);
    }

    final result = await query.get();

    var txns = result
        .map(
          (t) => model_txn.Transaction(
      id: t.id,
      accountId: t.accountId ?? '1',
      amount: t.amount,
      description: t.description,
      category: t.category,
      date: t.date,
      tags: t.tags ?? [],
    )).toList();

    // Secondary filtering for tags if provided
    if (tags != null && tags.isNotEmpty) {
      txns = txns
          .where((t) => t.tags.any((tag) => tags.contains(tag)))
          .toList();
    }

    return txns;
  }

  @override
  Future<void> addTransaction(model_txn.Transaction transaction) async {
    await _db.into(_db.transactions).insert(TransactionsCompanion.insert(
      id: transaction.id.isEmpty ? const Uuid().v4() : transaction.id,
      accountId: Value(transaction.accountId),
      amount: transaction.amount,
      description: transaction.description,
      category: transaction.category,
      date: transaction.date,
      tags: Value(transaction.tags),
            userId: Value(_userId),
      lastUpdated: Value(DateTime.now()),
    ));
  }

  @override
  Future<void> updateTransaction(model_txn.Transaction transaction) async {
    await (_db.update(_db.transactions)..where((t) => t.id.equals(transaction.id))).write(TransactionsCompanion(
      accountId: Value(transaction.accountId),
      amount: Value(transaction.amount),
      description: Value(transaction.description),
      category: Value(transaction.category),
      date: Value(transaction.date),
      tags: Value(transaction.tags),
      lastUpdated: Value(DateTime.now()),
    ));
  }

  @override
  Future<void> deleteTransactions(List<String> ids) async {
    if (ids.isEmpty) return;
    await (_db.update(_db.transactions)..where((t) => t.id.isIn(ids))).write(TransactionsCompanion(
      isDeleted: const Value(true),
      lastUpdated: Value(DateTime.now()),
    ));
  }

  @override
  Future<List<model.Category>> getCategories() async {
    final result = await (_db.select(_db.categories)
              ..where(
                (tbl) =>
                    tbl.isDeleted.equals(false) & tbl.userId.equals(_userId),
              )
      ..orderBy([(t) => OrderingTerm(expression: t.name)])
    ).get();

    return result.map((c) => model.Category(
      id: c.id,
      userId: c.userId ?? 'local',
      name: c.name,
      iconCode: c.iconCode,
      colorHex: c.colorHex,
      type: c.type,
      description: c.description,
    )).toList();
  }

  @override
  Future<void> addCategory(model.Category category) async {
    await _db.into(_db.categories).insert(CategoriesCompanion.insert(
      id: category.id.isEmpty ? const Uuid().v4() : category.id,
      name: category.name,
      iconCode: category.iconCode,
      colorHex: category.colorHex,
      type: category.type,
      description: Value(category.description),
            userId: Value(_userId), 
      lastUpdated: Value(DateTime.now()),
    ));
  }

  @override
  Future<void> updateCategory(model.Category category) async {
    await (_db.update(_db.categories)..where((t) => t.id.equals(category.id))).write(CategoriesCompanion(
      name: Value(category.name),
      iconCode: Value(category.iconCode),
      colorHex: Value(category.colorHex),
      type: Value(category.type),
      description: Value(category.description),
      lastUpdated: Value(DateTime.now()),
    ));
  }

  @override
  Future<void> deleteCategory(String id) async {
    await (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(CategoriesCompanion(
      isDeleted: const Value(true),
      lastUpdated: Value(DateTime.now()),
    ));
  }

  @override
  Future<List<model_tag.Tag>> getTags() async {
    final result = await (_db.select(_db.tags)
      ..where(
              (tbl) => tbl.isDeleted.equals(false) & tbl.userId.equals(_userId),
            )
    ).get();

    return result.map((t) => model_tag.Tag(
      id: t.id,
      userId: t.userId ?? 'local',
      name: t.name,
      colorHex: t.colorHex,
    )).toList();
  }

  @override
  Future<void> addTag(model_tag.Tag tag) async {
    await _db.into(_db.tags).insert(TagsCompanion.insert(
      id: tag.id.isEmpty ? const Uuid().v4() : tag.id,
      name: tag.name,
      colorHex: tag.colorHex,
            userId: Value(_userId),
      lastUpdated: Value(DateTime.now()),
    ));
  }

  @override
  Future<void> updateTag(model_tag.Tag tag) async {
    await (_db.update(_db.tags)..where((t) => t.id.equals(tag.id))).write(TagsCompanion(
      name: Value(tag.name),
      colorHex: Value(tag.colorHex),
      lastUpdated: Value(DateTime.now()),
    ));
  }

  @override
  Future<void> deleteTag(String id) async {
    await (_db.update(_db.tags)..where((t) => t.id.equals(id))).write(TagsCompanion(
      isDeleted: const Value(true),
      lastUpdated: Value(DateTime.now()),
    ));
  }

  @override
  Future<List<model_budget.Budget>> getBudgets() async {
    final result = await (_db.select(_db.budgets)
      ..where(
              (tbl) => tbl.isDeleted.equals(false) & tbl.userId.equals(_userId),
            )
    ).get();

    return result.map((b) => model_budget.Budget(
      id: b.id,
      category: b.category,
      userId: b.userId ?? 'local',
      limit: b.limitAmount,
      period: b.period,
    )).toList();
  }

  @override
  Future<void> upsertBudget(model_budget.Budget budget) async {
    // Check if exists for this user
    final exists = await (_db.select(_db.budgets)
      ..where(
              (tbl) =>
                  tbl.category.equals(budget.category) &
                  tbl.period.equals(budget.period) &
                  tbl.userId.equals(_userId) &
                  tbl.isDeleted.equals(false),
            )
    ).getSingleOrNull();

    if (exists != null) {
        await (_db.update(_db.budgets)..where((t) => t.id.equals(exists.id))).write(BudgetsCompanion(
        limitAmount: Value(budget.limit),
        lastUpdated: Value(DateTime.now()),
      ));
    } else {
      await _db.into(_db.budgets).insert(BudgetsCompanion.insert(
        id: const Uuid().v4(),
        category: budget.category,
        limitAmount: budget.limit,
        period: budget.period,
              userId: Value(_userId),
        lastUpdated: Value(DateTime.now()),
      ));
    }
  }

  @override
  Future<void> deleteBudget(String id) async {
    await (_db.update(_db.budgets)..where((t) => t.id.equals(id))).write(BudgetsCompanion(
      isDeleted: const Value(true),
      lastUpdated: Value(DateTime.now()),
    ));
  }

  @override
  Future<void> restoreDefaultCategories() async {
    await _db.batch((batch) {
      for (final d in _defaultCategories) {
        batch.insert(
          _db.categories,
          CategoriesCompanion.insert(
            id: '${_userId}_cat_${d.name}',
            name: d.name,
            iconCode: d.icon,
            colorHex: d.color,
            type: d.type,
            userId: Value(_userId),
            lastUpdated: Value(DateTime.now()),
          ),
          mode: InsertMode.replace, // Upsert
        );
      }
    });

    // Ensure they are not marked as deleted (in case they were deleted before)
    // The replace defined above might not handle partial updates like un-deleting if the row exists but isDeleted=true?
    // Actually Drift's InsertMode.replace replaces the *whole row*,
    // effectively resetting everything including isDeleted back to false (default).
  }

  @override
  Future<void> restoreDefaultTags() async {
    await _db.batch((batch) {
      for (final d in _defaultTags) {
        batch.insert(
          _db.tags,
          TagsCompanion.insert(
            id: '${_userId}_tag_${d.name}',
            name: d.name,
            colorHex: d.color,
            userId: Value(_userId),
            lastUpdated: Value(DateTime.now()),
          ),
          mode: InsertMode.replace,
        );
      }
    });
  }
}
