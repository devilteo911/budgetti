import 'package:flutter/material.dart';
import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/color_slots.dart';
import 'package:budgetti/models/account.dart' as model_account;
import 'package:budgetti/models/category.dart' as model;
import 'package:budgetti/models/transaction.dart' as model_txn;
import 'package:budgetti/models/tag.dart' as model_tag;
import 'package:budgetti/models/budget.dart' as model_budget;
import 'package:budgetti/models/installment.dart' as model_installment;
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
    // Give every expense category without a palette slot one, once. A sync runs
    // it again after its pull (PocketBaseSyncService.afterCategoriesPull), which is
    // where a slot another device assigned is learned first; see color_slots.dart
    // for why two devices that backfill apart still converge.
    await backfillColorSlots(_db, _userId);
  }

  static DateTime? _startOfDay(DateTime? d) =>
      d == null ? null : DateTime(d.year, d.month, d.day);

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
      // Truncated to midnight: the wallet sheet shows a *date* ("From Jun 23,
      // 2026") but stores a timestamp — a wallet created at 21:47 would drop
      // that same day's movements, and a transfer stamped 00:00 is exactly
      // what lands there.
      final startDate = _startOfDay(acc.initialBalanceDate);

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

  /// Live accounts with derived balances. Balances fold in transactions, so
  /// the pulse watches both tables — a synced transaction must move the
  /// balance even when the accounts table itself didn't change.
  Stream<List<model_account.Account>> watchAccounts() {
    final pulse = _db
        .customSelect(
          'SELECT (SELECT COUNT(*) FROM accounts) + '
          '(SELECT COUNT(*) FROM transactions) AS rows',
          readsFrom: {_db.accounts, _db.transactions},
        )
        .watch();
    return pulse.asyncMap((_) => getAccounts());
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

    // A transfer belongs to both wallets: filtering on the source alone hid
    // the incoming leg from the destination's own history. Only a real
    // transfer counts as incoming, the same rule getAccounts() uses for the
    // balance, so a row retyped away from 'transfer' (the old category chip)
    // that still carries toAccountId doesn't show up where it moved no money.
    if (accountId != null) {
      query.where((tbl) =>
          tbl.accountId.equals(accountId) |
          (tbl.toAccountId.equals(accountId) & tbl.type.equals('transfer')));
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

    // Filtering in SQL (not in memory after LIMIT): an in-memory filter
    // shrinks each page, so pagination's hasMore flips false early and
    // matching rows beyond the first short page go missing.
    if (tags != null && tags.isNotEmpty) {
      query.where((tbl) => _hasAnyTag(tags));
    }

    query.orderBy([
      (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
      (t) => OrderingTerm(expression: t.lastUpdated, mode: OrderingMode.desc),
    ]);

    if (limit != null) {
      query.limit(limit, offset: offset);
    }

    final result = await query.get();
    return result.map(_toModelTx).toList();
  }

  /// Fires after any write to the transactions table — this isolate's, a sync
  /// pull's, an import's, and the resume-time `markTablesUpdated`. For a
  /// snapshot list (pagination) that can't use [watchTransactions].
  Stream<void> transactionUpdates() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.transactions));

  /// Drift row → domain model, shared by every transactions read.
  model_txn.Transaction _toModelTx(Transaction t) => model_txn.Transaction(
        id: t.id,
        accountId: t.accountId ?? '1',
        toAccountId: t.toAccountId,
        amount: t.amount,
        description: t.description,
        category: t.category,
        type: t.type,
        date: t.date,
        tags: t.tags ?? [],
        installmentId: t.installmentId,
      );

  Stream<List<model_txn.Transaction>> watchTransactions({
    String? accountId,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? categories,
    List<String>? tags,
  }) {
    var query = _db.select(_db.transactions)
      ..where((tbl) => tbl.isDeleted.equals(false) & tbl.userId.equals(_userId));

    // A transfer belongs to both wallets: filtering on the source alone hid
    // the incoming leg from the destination's own history. Only a real
    // transfer counts as incoming, the same rule getAccounts() uses for the
    // balance, so a row retyped away from 'transfer' (the old category chip)
    // that still carries toAccountId doesn't show up where it moved no money.
    if (accountId != null) {
      query.where((tbl) =>
          tbl.accountId.equals(accountId) |
          (tbl.toAccountId.equals(accountId) & tbl.type.equals('transfer')));
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

    if (tags != null && tags.isNotEmpty) {
      query.where((tbl) => _hasAnyTag(tags));
    }

    query.orderBy([
      (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
      (t) => OrderingTerm(expression: t.lastUpdated, mode: OrderingMode.desc),
    ]);

    return query.watch().map((result) => result.map(_toModelTx).toList());
  }

  /// The rows the installment screens filter client-side: charges linked to
  /// any plan, plus unlinked expenses (attach-a-payment candidates). Replaces
  /// their full-ledger watch — unlinked income and transfers are noise there.
  /// An expense is a non-transfer with a negative amount (the model's rule),
  /// not whatever `type` says.
  Stream<List<model_txn.Transaction>> watchInstallmentRelevant() {
    final query = _db.select(_db.transactions)
      ..where((tbl) =>
          tbl.isDeleted.equals(false) &
          tbl.userId.equals(_userId) &
          (tbl.installmentId.isNotNull() |
              (tbl.type.equals('transfer').not() &
                  tbl.amount.isSmallerThanValue(0))))
      ..orderBy([
        (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.lastUpdated, mode: OrderingMode.desc),
      ]);
    return query.watch().map((result) => result.map(_toModelTx).toList());
  }

  /// Totals over exactly the filter the ledger page queries — a SQL
  /// aggregate watched on the transactions table, instead of re-watching and
  /// re-mapping the whole ledger on the UI isolate. Classification mirrors
  /// the model: income/expense = non-transfer by sign, transfers excluded.
  Stream<(double, double, int)> watchTotals({
    String? accountId,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? categories,
    List<String>? tags,
  }) {
    final where = <String>['is_deleted = 0', 'user_id = ?'];
    final vars = <Variable>[Variable(_userId)];
    if (accountId != null) {
      where.add('account_id = ?');
      vars.add(Variable(accountId));
    }
    if (startDate != null || endDate != null) {
      where.add('date BETWEEN ? AND ?');
      vars.add(Variable(startDate ?? DateTime(1900)));
      vars.add(Variable(endDate ?? DateTime(2100)));
    }
    if (categories != null && categories.isNotEmpty) {
      where.add('category IN (${List.filled(categories.length, '?').join(', ')})');
      vars.addAll([for (final c in categories) Variable(c)]);
    }
    if (tags != null && tags.isNotEmpty) {
      // Same whole-element json_each match as _hasAnyTag — escaped literals,
      // the only form customSelect can embed.
      final literals = [for (final t in tags) "'${t.replaceAll("'", "''")}'"];
      where.add(
          'json_valid(tags) AND EXISTS (SELECT 1 FROM json_each(transactions.tags) WHERE value IN (${literals.join(', ')}))');
    }
    return _db
        .customSelect(
          'SELECT '
          'COALESCE(SUM(CASE WHEN type != \'transfer\' AND amount > 0 THEN amount ELSE 0 END), 0) AS income, '
          'COALESCE(SUM(CASE WHEN type != \'transfer\' AND amount < 0 THEN -amount ELSE 0 END), 0) AS expense, '
          // COALESCE all three: SUM over no rows is NULL, and an unwrapped
          // count threw on an empty filter, leaving the UI on stale totals.
          'COALESCE(SUM(CASE WHEN type != \'transfer\' THEN 1 ELSE 0 END), 0) AS count '
          'FROM transactions WHERE ${where.join(' AND ')}',
          variables: vars,
          readsFrom: {_db.transactions},
        )
        .watch()
        .map((rows) {
      final r = rows.single;
      return (
        r.read<double>('income'),
        r.read<double>('expense'),
        r.read<int>('count'),
      );
    });
  }

  /// SQL-level tag membership: the tags column is a JSON array, so match via
  /// json_each — an exact element compare, where a LIKE on the raw text would
  /// also hit substrings ("Gift" matching "Gifts"). json_valid guards legacy
  /// rows that might not hold JSON at all. CustomExpression is raw SQL only,
  /// so tags are embedded as escaped string literals ('' is the only SQLite
  /// string escape — nothing else can break out of the quotes).
  Expression<bool> _hasAnyTag(List<String> tags) {
    final literals = [for (final t in tags) "'${t.replaceAll("'", "''")}'"];
    return CustomExpression<bool>(
      'json_valid(tags) AND EXISTS (SELECT 1 FROM json_each(transactions.tags) '
      'WHERE value IN (${literals.join(', ')}))',
    );
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
            installmentId: Value(transaction.installmentId),
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
      installmentId: Value(transaction.installmentId),
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

  MultiSelectable<Category> _categoriesQuery() =>
      _db.select(_db.categories)
        ..where(
          (tbl) => tbl.isDeleted.equals(false) & tbl.userId.equals(_userId),
        )
        ..orderBy([
          (t) => OrderingTerm(expression: t.name),
          (t) => OrderingTerm(expression: const CustomExpression<int>('rowid')),
        ]);

  /// Two seeders once gave every default a twin, and the upgrade that used to
  /// soft-delete the twins hid real data, so the twins now just stay out of the
  /// lists: one row per [key], the first of [rows] (oldest, by the query order).
  static List<T> _onePerKey<T>(Iterable<T> rows, String Function(T) key) {
    final seen = <String>{};
    return [for (final r in rows) if (seen.add(key(r))) r];
  }

  // Same name + type = the same category (an income and an expense may share one).
  static String _categoryKey(Category c) => '${c.name}\u0000${c.type}';

  Future<List<model.Category>> getCategories() async {
    final rows = await _categoriesQuery().get();
    return _onePerKey(rows, _categoryKey).map(_toCategory).toList();
  }

  Stream<List<model.Category>> watchCategories() => _categoriesQuery()
      .watch()
      .map((rows) => _onePerKey(rows, _categoryKey).map(_toCategory).toList());

  model.Category _toCategory(Category c) => model.Category(
        id: c.id,
        userId: c.userId ?? 'local',
        name: c.name,
        iconCode: c.iconCode,
        colorHex: c.colorHex,
        type: c.type,
        description: c.description,
        colorSlot: c.colorSlot,
      );

  Future<void> addCategory(model.Category category) async {
    // An expense takes its palette slot now and keeps it (see color_slots.dart).
    final slot = category.type == 'expense'
        ? (category.colorSlot ?? await nextColorSlot(_db, _userId))
        : category.colorSlot;
    await _db.into(_db.categories).insert(CategoriesCompanion.insert(
      id: category.id.isEmpty ? const Uuid().v4() : category.id,
      name: category.name,
      iconCode: category.iconCode,
      colorHex: category.colorHex,
      type: category.type,
      description: Value(category.description),
      colorSlot: Value(slot),
            userId: Value(_userId), 
      lastUpdated: Value(DateTime.now()),
    ));
  }

  Future<void> updateCategory(model.Category category) async {
    final old = await (_db.select(_db.categories)
          ..where((t) => t.id.equals(category.id)))
        .getSingle();
    await _db.transaction(() async {
      // A category turned into an expense gets a slot on the spot; one turned into
      // income keeps its slot (unused while income, back if the type flips back).
      final slot = category.colorSlot ??
          old.colorSlot ??
          (category.type == 'expense' && old.type != 'expense'
              ? await nextColorSlot(_db, _userId)
              : null);
      await (_db.update(_db.categories)..where(_sameCategory(old))).write(CategoriesCompanion(
        name: Value(category.name),
        iconCode: Value(category.iconCode),
        colorHex: Value(category.colorHex),
        type: Value(category.type),
        description: Value(category.description),
        colorSlot: slot == null ? const Value.absent() : Value(slot),
        lastUpdated: Value(DateTime.now()),
      ));
      // A rename follows into every row that stores the label by name —
      // otherwise history stays on the old name and fragments.
      if (old.name != category.name) {
        final now = DateTime.now();
        await (_db.update(_db.transactions)
              ..where((t) =>
                  t.category.equals(old.name) & t.userId.equals(_userId)))
            .write(TransactionsCompanion(
          category: Value(category.name),
          lastUpdated: Value(now),
        ));
        await (_db.update(_db.budgets)
              ..where((t) =>
                  t.category.equals(old.name) & t.userId.equals(_userId)))
            .write(BudgetsCompanion(
          category: Value(category.name),
          lastUpdated: Value(now),
        ));
        await (_db.update(_db.installments)
              ..where((t) =>
                  t.category.equals(old.name) & t.userId.equals(_userId)))
            .write(InstallmentsCompanion(
          category: Value(category.name),
          lastUpdated: Value(now),
        ));
        await (_db.update(_db.pendingTransactions)
              ..where((t) =>
                  t.suggestedCategory.equals(old.name) &
                  t.userId.equals(_userId)))
            .write(PendingTransactionsCompanion(
          suggestedCategory: Value(category.name),
        ));
      }
    });
  }

  /// The live rows one list entry stands for: [row] and every twin with its name
  /// and type (the lists show one per key — see [_onePerKey]). Editing or deleting
  /// the visible row has to reach them all, or a hidden twin takes its place.
  Expression<bool> Function(Categories) _sameCategory(Category row) =>
      (t) =>
          t.id.equals(row.id) |
          (t.isDeleted.equals(false) &
              t.userId.equals(_userId) &
              t.name.equals(row.name) &
              t.type.equals(row.type));

  Expression<bool> Function(Tags) _sameTag(Tag row) => (t) =>
      t.id.equals(row.id) |
      (t.isDeleted.equals(false) &
          t.userId.equals(_userId) &
          t.name.equals(row.name));

  Future<void> deleteCategory(String id) async {
    final row = await (_db.select(_db.categories)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    await (_db.update(_db.categories)
          ..where(row == null ? (t) => t.id.equals(id) : _sameCategory(row)))
        .write(CategoriesCompanion(
      isDeleted: const Value(true),
      lastUpdated: Value(DateTime.now()),
    ));
  }

  MultiSelectable<Tag> _tagsQuery() => _db.select(_db.tags)
    ..where((tbl) => tbl.isDeleted.equals(false) & tbl.userId.equals(_userId))
    ..orderBy([
      (t) => OrderingTerm(expression: const CustomExpression<int>('rowid')),
    ]);

  Future<List<model_tag.Tag>> getTags() async =>
      _onePerKey(await _tagsQuery().get(), (t) => t.name).map(_toTag).toList();

  Stream<List<model_tag.Tag>> watchTags() => _tagsQuery()
      .watch()
      .map((rows) => _onePerKey(rows, (t) => t.name).map(_toTag).toList());

  model_tag.Tag _toTag(Tag t) => model_tag.Tag(
        id: t.id,
        userId: t.userId ?? 'local',
        name: t.name,
        colorHex: t.colorHex,
      );

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
    final old = await (_db.select(_db.tags)..where((t) => t.id.equals(tag.id)))
        .getSingle();
    await _db.transaction(() async {
      await (_db.update(_db.tags)..where(_sameTag(old))).write(TagsCompanion(
        name: Value(tag.name),
        colorHex: Value(tag.colorHex),
        lastUpdated: Value(DateTime.now()),
      ));
      if (old.name != tag.name) {
        // tags is a JSON array — rewrite only exact element matches, so a
        // rename of "Gift" never touches a hypothetical "Gifts".
        final now = DateTime.now();
        final rows = await (_db.select(_db.transactions)
              ..where((t) =>
                  t.tags.isNotNull() & t.userId.equals(_userId)))
            .get();
        for (final row in rows) {
          final tags = row.tags ?? const <String>[];
          if (!tags.contains(old.name)) continue;
          await (_db.update(_db.transactions)
                ..where((t) => t.id.equals(row.id)))
              .write(TransactionsCompanion(
            tags: Value([...tags.where((t) => t != old.name), tag.name]),
            lastUpdated: Value(now),
          ));
        }
      }
    });
  }

  Future<void> deleteTag(String id) async {
    final row = await (_db.select(_db.tags)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    await (_db.update(_db.tags)
          ..where(row == null ? (t) => t.id.equals(id) : _sameTag(row)))
        .write(TagsCompanion(
      isDeleted: const Value(true),
      lastUpdated: Value(DateTime.now()),
    ));
  }

  // A zero limit is "no budget": the old Clear saved one, and the web app can
  // still sync them in, and either made the overview card look populated.
  MultiSelectable<Budget> _budgetsQuery() => _db.select(_db.budgets)
    ..where((tbl) =>
        tbl.isDeleted.equals(false) &
        tbl.userId.equals(_userId) &
        tbl.limitAmount.isBiggerThanValue(0));

  Future<List<model_budget.Budget>> getBudgets() async =>
      (await _budgetsQuery().get()).map(_toBudget).toList();

  Stream<List<model_budget.Budget>> watchBudgets() =>
      _budgetsQuery().watch().map((rows) => rows.map(_toBudget).toList());

  model_budget.Budget _toBudget(Budget b) => model_budget.Budget(
        id: b.id,
        category: b.category,
        userId: b.userId ?? 'local',
        limit: b.limitAmount,
        period: b.period,
      );

  Future<void> upsertBudget(model_budget.Budget budget) async {
    // Newest first, not getSingleOrNull(): two devices can each create a
    // budget for the same category while offline (the web app could too), and
    // two live rows made that throw, so the budget could never be set again.
    final live = await (_db.select(_db.budgets)
          ..where((tbl) =>
              tbl.category.equals(budget.category) &
              tbl.period.equals(budget.period) &
              tbl.userId.equals(_userId) &
              tbl.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.lastUpdated,
                  mode: OrderingMode.desc,
                  nulls: NullsOrder.last,
                ),
          ]))
        .get();

    if (live.isEmpty) {
      await _db.into(_db.budgets).insert(BudgetsCompanion.insert(
        id: const Uuid().v4(),
        category: budget.category,
        limitAmount: budget.limit,
        period: budget.period,
        userId: Value(_userId),
        lastUpdated: Value(DateTime.now()),
      ));
      return;
    }

    await _db.transaction(() async {
      await (_db.update(_db.budgets)..where((t) => t.id.equals(live.first.id)))
          .write(BudgetsCompanion(
        limitAmount: Value(budget.limit),
        lastUpdated: Value(DateTime.now()),
      ));
      // Retire the stale duplicates (stamped, so the delete syncs): left live
      // they'd show as a second row for the category with the old limit.
      if (live.length > 1) {
        await (_db.update(_db.budgets)
              ..where((t) => t.id.isIn(live.skip(1).map((r) => r.id))))
            .write(BudgetsCompanion(
          isDeleted: const Value(true),
          lastUpdated: Value(DateTime.now()),
        ));
      }
    });
  }

  /// Clears the budget for [category]: soft-deletes every live row for it, not
  /// one — duplicates (two devices creating it offline) would otherwise leave
  /// the budget on screen after Clear. Stamped so the delete syncs.
  Future<void> deleteBudget(String category, {String period = 'monthly'}) async {
    await (_db.update(_db.budgets)
          ..where((t) =>
              t.category.equals(category) &
              t.period.equals(period) &
              t.userId.equals(_userId) &
              t.isDeleted.equals(false)))
        .write(BudgetsCompanion(
      isDeleted: const Value(true),
      lastUpdated: Value(DateTime.now()),
    ));
  }

  /// Installment plans, newest first. Progress is derived per-plan (see
  /// [model_installment.Installment]) — nothing here tracks paid rates.
  Stream<List<model_installment.Installment>> watchInstallments() {
    final query = _db.select(_db.installments)
      ..where((t) => t.isDeleted.equals(false) & t.userId.equals(_userId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.desc),
      ]);
    return query.watch().map(
          (rows) => rows
              .map((r) => model_installment.Installment(
                    id: r.id,
                    userId: r.userId ?? 'local',
                    description: r.description,
                    totalAmount: r.totalAmount,
                    installmentCount: r.installmentCount,
                    startDate: r.startDate,
                    category: r.category,
                    accountId: r.accountId,
                  ))
              .toList(),
        );
  }

  Future<void> upsertInstallment(model_installment.Installment plan) async {
    await _db.into(_db.installments).insert(
          InstallmentsCompanion.insert(
            id: plan.id.isEmpty ? const Uuid().v4() : plan.id,
            description: plan.description,
            totalAmount: plan.totalAmount,
            installmentCount: plan.installmentCount,
            startDate: plan.startDate,
            category: Value(plan.category),
            accountId: Value(plan.accountId),
            userId: Value(_userId),
            isDeleted: const Value(false),
            lastUpdated: Value(DateTime.now()),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Attach [transactionId] to an installment plan, or detach it with a null
  /// [installmentId]. One field, so the whole link/unlink flow on both clients
  /// is this call.
  Future<void> linkTransactionToInstallment(
    String transactionId,
    String? installmentId,
  ) async {
    await (_db.update(_db.transactions)
          ..where((t) => t.id.equals(transactionId)))
        .write(TransactionsCompanion(
      installmentId: Value(installmentId),
      lastUpdated: Value(DateTime.now()),
    ));
  }

  Future<void> deleteInstallment(String id) async {
    await (_db.update(_db.installments)..where((t) => t.id.equals(id)))
        .write(InstallmentsCompanion(
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

  /// Which soft-deleted row of the default [name] should come back, or null when
  /// none should. [rows] are the owner's rows of one table in rowid order; [seed]
  /// is the infix FinanceService puts in its ids (`_cat_`, `_tag_`), [type] is
  /// null for tags.
  ///
  /// Nothing comes back when the default still has a live copy, or has a live row
  /// with its seeded id under a new name (the owner renamed Dining to "Eating
  /// out": reviving Dining would be a duplicate). Otherwise the owner's own
  /// `<userId><seed><name>` copy, then any seeded copy, then the oldest row.
  static String? _reviveTarget(
    List<({String id, String name, String? type, bool deleted})> rows,
    String userId,
    String seed,
    String name,
    String? type,
  ) {
    bool slot(({String id, String name, String? type, bool deleted}) r) =>
        r.name == name && r.type == type;
    if (rows.any((r) => !r.deleted && (slot(r) || r.id.endsWith('$seed$name')))) {
      return null;
    }
    final dead = rows.where((r) => r.deleted && slot(r)).toList();
    for (final want in <bool Function(String)>[
      (id) => id == '$userId$seed$name',
      (id) => id.endsWith('$seed$name'),
      (_) => true,
    ]) {
      for (final r in dead) {
        if (want(r.id)) return r.id;
      }
    }
    return null;
  }

  /// Brings back the default categories the owner lost, in place: each comes back
  /// as the soft-deleted row it was (same id, icon and colour), stamped now so
  /// last-write-wins carries it to the server. It never inserts, so it cannot add
  /// a duplicate, and a second call finds nothing to do. Returns how many came back.
  Future<int> restoreDefaultCategories() async {
    final rows = [
      for (final c in await (_db.select(_db.categories)
            ..where((t) => t.userId.equals(_userId))
            ..orderBy([
              (t) => OrderingTerm(expression: const CustomExpression<int>('rowid')),
            ]))
          .get())
        (id: c.id, name: c.name, type: c.type as String?, deleted: c.isDeleted)
    ];
    final ids = {
      for (final d in _defaultCategories)
        ?_reviveTarget(rows, _userId, '_cat_', d.name, d.type),
    };
    if (ids.isEmpty) return 0;
    await (_db.update(_db.categories)..where((t) => t.id.isIn(ids))).write(
      CategoriesCompanion(
        isDeleted: const Value(false),
        lastUpdated: Value(DateTime.now()),
      ),
    );
    return ids.length;
  }

  /// Same rule for the default tags: revive, never insert. See
  /// [restoreDefaultCategories].
  Future<int> restoreDefaultTags() async {
    final rows = [
      for (final t in await (_db.select(_db.tags)
            ..where((t) => t.userId.equals(_userId))
            ..orderBy([
              (t) => OrderingTerm(expression: const CustomExpression<int>('rowid')),
            ]))
          .get())
        (id: t.id, name: t.name, type: null as String?, deleted: t.isDeleted)
    ];
    final ids = {
      for (final d in _defaultTags)
        ?_reviveTarget(rows, _userId, '_tag_', d.name, null),
    };
    if (ids.isEmpty) return 0;
    await (_db.update(_db.tags)..where((t) => t.id.isIn(ids))).write(
      TagsCompanion(
        isDeleted: const Value(false),
        lastUpdated: Value(DateTime.now()),
      ),
    );
    return ids.length;
  }
}
