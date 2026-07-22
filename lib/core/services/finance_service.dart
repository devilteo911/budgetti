import 'package:flutter/material.dart';
import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/models/account.dart' as model_account;
import 'package:budgetti/models/category.dart' as model;
import 'package:budgetti/models/transaction.dart' as model_txn;
import 'package:budgetti/models/tag.dart' as model_tag;
import 'package:budgetti/models/budget.dart' as model_budget;
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class FinanceService {
  final AppDatabase _db;
  final String _userId;
  bool _initialized = false;

  // IconData (not raw ints) so the codepoint can never silently drift from
  // the glyph it names — which is how the original seed shipped wrong icons.
  static final List<({String name, IconData icon, int color, String type})>
  _defaultCategories = [
    // Expenses
    (name: 'Groceries', icon: Icons.local_grocery_store, color: 0xFF4CAF50, type: 'expense'),
    (name: 'Transport', icon: Icons.directions_car, color: 0xFF2196F3, type: 'expense'),
    (name: 'Dining', icon: Icons.restaurant, color: 0xFFFF9800, type: 'expense'),
    (name: 'Shopping', icon: Icons.shopping_bag, color: 0xFF9C27B0, type: 'expense'),
    (name: 'Entertainment', icon: Icons.movie, color: 0xFFFF5722, type: 'expense'),
    (name: 'Health', icon: Icons.local_hospital, color: 0xFFF44336, type: 'expense'),
    (name: 'Bills', icon: Icons.receipt_long, color: 0xFF607D8B, type: 'expense'),
    // Income
    (name: 'Salary', icon: Icons.payments, color: 0xFF009688, type: 'income'),
    (name: 'Freelance', icon: Icons.laptop_mac, color: 0xFF3F51B5, type: 'income'),
    (name: 'Investments', icon: Icons.trending_up, color: 0xFF673AB7, type: 'income'),
  ];

  static const List<({String name, int color})> _defaultTags = [
    (name: 'Vacation', color: 0xFFE91E63),
    (name: 'Family', color: 0xFF9C27B0),
    (name: 'Work', color: 0xFF3F51B5),
    (name: 'Personal', color: 0xFF00BCD4),
    (name: 'Gift', color: 0xFFFF5722),
  ];

  FinanceService(this._db, this._userId);


  /// True when the database already holds an account, a category or a tag —
  /// from any user, deleted or not.
  Future<bool> _hasAnyUserData() async {
    for (final rows in [
      await (_db.select(_db.accounts)..limit(1)).get(),
      await (_db.select(_db.categories)..limit(1)).get(),
      await (_db.select(_db.tags)..limit(1)).get(),
    ]) {
      if (rows.isNotEmpty) return true;
    }
    return false;
  }

  /// Ensures user has default data (account, categories, tags)
  Future<void> _ensureUserDefaults() async {
    if (_initialized) return;
    _initialized = true;

    // Seed only a genuinely empty database — never "empty for this user".
    // A per-user check re-seeds whenever the rows are there but attributed to
    // someone else: userId-less legacy rows, or rows _unifyUserId is about to
    // re-stamp onto the PocketBase id. That produced a second copy of every
    // default. Soft-deleted rows count as existing on purpose, so re-seeding
    // can't resurrect something deliberately deleted.
    final hasAny = await _hasAnyUserData();

    if (!hasAny) {
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
              iconCode: d.icon.codePoint,
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

    // Rewrite default-category icons still holding a legacy (broken) codepoint.
    await _repairDefaultCategoryIcons();
  }

  Future<List<model_account.Account>> getAccounts() async {
    // Ensure user has default data on first access
    await _ensureUserDefaults();

    // 1. Fetch all accounts not deleted for this user
    final accountsDb =
        await (_db.select(_db.accounts)..where(
              (tbl) => tbl.isDeleted.equals(false) & tbl.userId.equals(_userId),
            ))
            .get();

    final Map<String, double> transactionSums = {};

    for (final acc in accountsDb) {
      final accId = acc.id;
      final startDate = acc.initialBalanceDate;

      // Calculate source sums (Income/Expense/Transfer Source)
      final sourceSumExpr = _db.transactions.type
          .caseMatch(
            when: {
              const Constant('transfer'):
                  _db.transactions.amount * const Constant(-1.0),
            },
            orElse: _db.transactions.amount,
          )
          .sum();

      final sourceQuery = _db.selectOnly(_db.transactions)
        ..addColumns([sourceSumExpr])
        ..where(
          _db.transactions.isDeleted.equals(false) &
              _db.transactions.userId.equals(_userId) &
              _db.transactions.accountId.equals(accId),
        );

      if (startDate != null) {
        sourceQuery.where(
          _db.transactions.date.isBetween(
            Constant(startDate),
            Constant(DateTime(2100)),
          ),
        );
      }

      final sourceRow = await sourceQuery.getSingle();
      final sourceSum = sourceRow.read(sourceSumExpr) ?? 0.0;

      // Calculate dest sums (Transfer Destination)
      final destSumExpr = _db.transactions.amount.sum();
      final destQuery = _db.selectOnly(_db.transactions)
        ..addColumns([destSumExpr])
        ..where(
          _db.transactions.isDeleted.equals(false) &
              _db.transactions.userId.equals(_userId) &
              _db.transactions.type.equals('transfer') &
              _db.transactions.toAccountId.equals(accId),
        );

      if (startDate != null) {
        destQuery.where(
          _db.transactions.date.isBetween(
            Constant(startDate),
            Constant(DateTime(2100)),
          ),
        );
      }

      final destRow = await destQuery.getSingle();
      final destSum = destRow.read(destSumExpr) ?? 0.0;

      transactionSums[accId] = sourceSum + destSum;
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
        isDefault: acc.isDefault,
        initialBalanceDate: acc.initialBalanceDate,
      );
    }).toList();
  }

  Stream<List<model_account.Account>> watchAccounts() {
    // This will trigger whenever the accounts table changes.
    // To also trigger on transaction changes, we'd need a more complex stream.
    // For now, watching accounts is better than nothing, but let's see if we can do more.
    return _db.select(_db.accounts).watch().asyncMap((_) => getAccounts());
  }

  Future<void> addAccount(model_account.Account account) async {
    final accountId = account.id.isEmpty ? const Uuid().v4() : account.id;

    if (account.isDefault) {
      // Unset other defaults
      await (_db.update(_db.accounts)..where((t) => t.userId.equals(_userId)))
          .write(AccountsCompanion(
            isDefault: const Value(false),
            lastUpdated: Value(DateTime.now()), // must bump so the un-defaulting syncs
          ));
    }

    await _db.into(_db.accounts).insert(AccountsCompanion.insert(
            id: accountId,
      name: account.name,
      balance: Value(account.balance), // Storing initial balance
      currency: Value(account.currency),
      providerName: Value(account.providerName),
            userId: Value(_userId),
            isDefault: Value(account.isDefault),
            initialBalanceDate: Value(account.initialBalanceDate),
      lastUpdated: Value(DateTime.now()),
    ));
  }

  Future<void> updateAccount(model_account.Account account) async {
    if (account.isDefault) {
      // Unset other defaults for this user
      await (_db.update(_db.accounts)..where(
            (t) => t.userId.equals(_userId) & t.id.equals(account.id).not(),
          ))
          .write(AccountsCompanion(
            isDefault: const Value(false),
            lastUpdated: Value(DateTime.now()), // must bump so the un-defaulting syncs
          ));
    }

    await (_db.update(_db.accounts)..where((t) => t.id.equals(account.id))).write(AccountsCompanion(
      name: Value(account.name),
      balance: Value(account.initialBalance), // Update initial balance
      currency: Value(account.currency),
        isDefault: Value(account.isDefault),
        initialBalanceDate: Value(account.initialBalanceDate),
      lastUpdated: Value(DateTime.now()),
    ));
  }

  Future<void> deleteAccount(String id) async {
    await (_db.update(_db.accounts)..where((t) => t.id.equals(id))).write(AccountsCompanion(
      isDeleted: const Value(true),
      lastUpdated: Value(DateTime.now()),
    ));
  }

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
      (t) => OrderingTerm(expression: t.lastUpdated, mode: OrderingMode.desc),
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
            toAccountId: t.toAccountId,
      amount: t.amount,
      description: t.description,
      category: t.category,
            type: t.type,
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

  Stream<List<model_txn.Transaction>> watchTransactions({
    String? accountId,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? categories,
    List<String>? tags,
  }) {
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

    query.orderBy([
      (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
      (t) => OrderingTerm(expression: t.lastUpdated, mode: OrderingMode.desc),
    ]);

    return query.watch().map((result) {
      var txns = result
          .map(
            (t) => model_txn.Transaction(
              id: t.id,
              accountId: t.accountId ?? '1',
              toAccountId: t.toAccountId,
              amount: t.amount,
              description: t.description,
              category: t.category,
              type: t.type,
              date: t.date,
              tags: t.tags ?? [],
            ),
          )
          .toList();

      if (tags != null && tags.isNotEmpty) {
        txns = txns.where((t) => t.tags.any((tag) => tags.contains(tag))).toList();
      }

      return txns;
    });
  }

  Future<void> addTransaction(model_txn.Transaction transaction) async {
    await _db.into(_db.transactions).insert(TransactionsCompanion.insert(
      id: transaction.id.isEmpty ? const Uuid().v4() : transaction.id,
      accountId: Value(transaction.accountId),
            toAccountId: Value(transaction.toAccountId),
      amount: transaction.amount,
      description: transaction.description,
      category: transaction.category,
            type: Value(transaction.type),
      date: transaction.date,
      tags: Value(transaction.tags),
            userId: Value(_userId),
      lastUpdated: Value(DateTime.now()),
    ));
  }

  Future<void> updateTransaction(model_txn.Transaction transaction) async {
    await (_db.update(_db.transactions)..where((t) => t.id.equals(transaction.id))).write(TransactionsCompanion(
      accountId: Value(transaction.accountId),
        toAccountId: Value(transaction.toAccountId),
      amount: Value(transaction.amount),
      description: Value(transaction.description),
      category: Value(transaction.category),
        type: Value(transaction.type),
      date: Value(transaction.date),
      tags: Value(transaction.tags),
      lastUpdated: Value(DateTime.now()),
    ));
  }

  Future<void> deleteTransactions(List<String> ids) async {
    if (ids.isEmpty) return;
    await (_db.update(_db.transactions)..where((t) => t.id.isIn(ids))).write(TransactionsCompanion(
      isDeleted: const Value(true),
      lastUpdated: Value(DateTime.now()),
    ));
  }

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

  Future<void> deleteCategory(String id) async {
    await (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(CategoriesCompanion(
      isDeleted: const Value(true),
      lastUpdated: Value(DateTime.now()),
    ));
  }

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

  Future<void> addTag(model_tag.Tag tag) async {
    await _db.into(_db.tags).insert(TagsCompanion.insert(
      id: tag.id.isEmpty ? const Uuid().v4() : tag.id,
      name: tag.name,
      colorHex: tag.colorHex,
            userId: Value(_userId),
      lastUpdated: Value(DateTime.now()),
    ));
  }

  Future<void> updateTag(model_tag.Tag tag) async {
    await (_db.update(_db.tags)..where((t) => t.id.equals(tag.id))).write(TagsCompanion(
      name: Value(tag.name),
      colorHex: Value(tag.colorHex),
      lastUpdated: Value(DateTime.now()),
    ));
  }

  Future<void> deleteTag(String id) async {
    await (_db.update(_db.tags)..where((t) => t.id.equals(id))).write(TagsCompanion(
      isDeleted: const Value(true),
      lastUpdated: Value(DateTime.now()),
    ));
  }

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

  Future<void> deleteBudget(String id) async {
    await (_db.update(_db.budgets)..where((t) => t.id.equals(id))).write(BudgetsCompanion(
      isDeleted: const Value(true),
      lastUpdated: Value(DateTime.now()),
    ));
  }

  /// One-shot repair: the original seed shipped with wrong Material codepoints,
  /// so default categories rendered as unrelated glyphs (Groceries=fence,
  /// Health=plane…). Rewrite only the icon where it still holds a known-bad value
  /// and bump lastUpdated so the fix push-syncs. Never touches name/colour or a
  /// category the user already re-iconed (its codepoint won't match). Idempotent.
  Future<void> _repairDefaultCategoryIcons() async {
    const legacyBad = <String, int>{
      'Groceries': 57954,
      'Transport': 57675,
      'Dining': 57924,
      'Shopping': 59600,
      'Entertainment': 58022,
      'Health': 58009,
      'Bills': 59469,
      'Salary': 57357,
      'Freelance': 59647,
      'Investments': 60232,
    };
    for (final d in _defaultCategories) {
      final legacy = legacyBad[d.name];
      if (legacy == null) continue;
      final row = await (_db.select(_db.categories)
            ..where((t) => t.id.equals('${_userId}_cat_${d.name}')))
          .getSingleOrNull();
      if (row == null || row.iconCode != legacy) continue;
      await (_db.update(_db.categories)
            ..where((t) => t.id.equals('${_userId}_cat_${d.name}')))
          .write(CategoriesCompanion(
        iconCode: Value(d.icon.codePoint),
        lastUpdated: Value(DateTime.now()),
      ));
    }
  }

  Future<void> restoreDefaultCategories() async {
    await _db.batch((batch) {
      for (final d in _defaultCategories) {
        batch.insert(
          _db.categories,
          CategoriesCompanion.insert(
            id: '${_userId}_cat_${d.name}',
            name: d.name,
            iconCode: d.icon.codePoint,
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
