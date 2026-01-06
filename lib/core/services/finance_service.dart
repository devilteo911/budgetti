import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/models/account.dart';
import 'package:budgetti/models/category.dart' as model;
import 'package:budgetti/models/transaction.dart';
import 'package:budgetti/models/tag.dart' as model_tag;
import 'package:budgetti/models/budget.dart' as model_budget;
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

abstract class FinanceService {
  Future<List<Account>> getAccounts();
  Future<void> addAccount(Account account);
  Future<void> updateAccount(Account account);
  Future<void> deleteAccount(String id);
  Future<List<Transaction>> getTransactions(String? accountId);
  Future<void> addTransaction(Transaction transaction);
  Future<void> updateTransaction(Transaction transaction);
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
}

class SupabaseFinanceService implements FinanceService {
  final _client = Supabase.instance.client;
  final AppDatabase _db;

  SupabaseFinanceService(this._db);

  @override
  Future<List<Account>> getAccounts() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      // Fetch wallets
      final List<dynamic> walletsData = await _client
          .from('wallets')
          .select()
          .eq('user_id', user.id);

      final accounts = walletsData.map((json) => Account.fromJson(json)).toList();

      if (accounts.isNotEmpty) {
        // Fetch all transaction amounts to calculate live balances
        final List<dynamic> transData = await _client
            .from('transactions')
            .select('account_id, amount')
            .eq('user_id', user.id);
        
        // Group sums by account_id
        final Map<String, double> transactionSums = {};
        bool hasOrphanedTransactions = false;
        double orphanedSum = 0;

        for (var item in transData) {
          final rawAccId = item['account_id'];
          final amt = (item['amount'] as num).toDouble();
          
          if (rawAccId == null) {
            hasOrphanedTransactions = true;
            orphanedSum += amt;
          } else {
            final accId = rawAccId.toString();
            transactionSums[accId] = (transactionSums[accId] ?? 0.0) + amt;
          }
        }

        final List<Account> resultAccounts = accounts.map((acc) {
          final sum = transactionSums[acc.id] ?? 0.0;
          return acc.copyWith(balance: acc.initialBalance + sum);
        }).toList();

        // If there are orphaned transactions, we MUST include the "Main Wallet" (ID '1')
        // so that the DropdownButton doesn't crash in AddTransactionModal
        if (hasOrphanedTransactions) {
          // Check if '1' is already in accounts (unlikely if they came from 'wallets' table)
          if (!resultAccounts.any((a) => a.id == '1')) {
            resultAccounts.add(Account(
              id: '1',
              name: 'Main Wallet',
              balance: orphanedSum,
              currency: 'EUR',
              providerName: 'Supabase',
            ));
          }
        }

        return resultAccounts;
      }

      // Fallback if no specific accounts are defined: calculate from transactions
      final List<dynamic> transData = await _client
          .from('transactions')
          .select('amount')
          .eq('user_id', user.id);

      double total = 0;
      for (var item in transData) {
        total += (item['amount'] as num).toDouble();
      }

      return [
        Account(
          id: '1',
          name: 'Main Wallet',
          balance: total,
          currency: 'EUR',
          providerName: 'Supabase',
        ),
      ];
    } catch (e) {
      // If table missing or offline, fallback to a safe state
      return [
        Account(
          id: '1',
          name: 'Main Wallet (Offline)',
          balance: 0.0,
          currency: 'EUR',
          providerName: 'Local Cache',
        ),
      ];
    }
  }

  @override
  Future<void> addAccount(Account account) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    await _client.from('wallets').insert({
      ...account.toJson(),
      'user_id': user.id,
    });
  }

  @override
  Future<void> updateAccount(Account account) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    if (account.id == '1') {
      // "Main Wallet" is a client-side fallback. If the user edits it, we "realize" it into a persistent wallet.
      final newId = const Uuid().v4();
      
      // 1. Create the new wallet
      await _client.from('wallets').insert({
        ...account.toJson(),
        'id': newId, // Override '1' with real UUID
        'user_id': user.id,
      });

      // 2. Migrate all legacy transactions to this new wallet
      await _client
          .from('transactions')
          .update({'account_id': newId})
          .eq('user_id', user.id)
          .filter('account_id', 'is', null);
          
      return;
    }

    await _client
        .from('wallets')
        .update({...account.toJson()})
        .eq('id', account.id);
  }

  @override
  Future<void> deleteAccount(String id) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    if (id == '1') {
      // Cannot delete the fallback wallet directly as it doesn't exist.
      // We could delete all unassigned transactions, but that's risky.
      // For now, just ignore or throw.
      return;
    }

    await _client.from('wallets').delete().eq('id', id);
  }

  @override
  Future<List<Transaction>> getTransactions(String? accountId) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    var query = _client
        .from('transactions')
        .select()
        .eq('user_id', user.id);

    if (accountId != null) {
      if (accountId == '1') {
        // '1' is the local fallback ID, which maps to NULL in Supabase UUID column
        query = query.filter('account_id', 'is', null);
      } else {
        query = query.eq('account_id', accountId);
      }
    }

    final List<dynamic> data = await query.order('date', ascending: false);

    return data.map((json) => Transaction.fromJson(json)).toList();
  }

  @override
  Future<void> addTransaction(Transaction transaction) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    await _client.from('transactions').insert({
      'user_id': user.id,
      'account_id': transaction.accountId == '1' ? null : transaction.accountId,
      'amount': transaction.amount,
      'description': transaction.description,
      'category': transaction.category,
      'date': transaction.date.toIso8601String(),
      'tags': transaction.tags,
    });
  }

  @override
  Future<void> updateTransaction(Transaction transaction) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    await _client.from('transactions').update({
      'account_id': transaction.accountId == '1' ? null : transaction.accountId,
      'amount': transaction.amount,
      'description': transaction.description,
      'category': transaction.category,
      'date': transaction.date.toIso8601String(),
      'tags': transaction.tags,
    }).eq('id', transaction.id);
  }

  @override
  Future<void> deleteTransactions(List<String> ids) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    if (ids.isEmpty) return;

    await _client.from('transactions').delete().filter('id', 'in', ids);
  }

  @override
  Future<List<model.Category>> getCategories() async {
    final driftCategories = await _db.select(_db.categories).get();
    
    // Sort manually or via query. Query order is better.
    // .get() returns List<Category> (drift)
    // Map to model.Category
    driftCategories.sort((a, b) => a.name.compareTo(b.name));

    return driftCategories.map((c) => model.Category(
      id: c.id,
      userId: 'local', 
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
      id: category.id,
      name: category.name,
      iconCode: category.iconCode,
      colorHex: category.colorHex,
      type: category.type,
            description: Value(category.description),
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
    ));
  }

  @override
  Future<void> deleteCategory(String id) async {
    await (_db.delete(_db.categories)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<List<model_tag.Tag>> getTags() async {
    final driftTags = await _db.select(_db.tags).get();
    
    return driftTags.map((t) => model_tag.Tag(
      id: t.id,
      name: t.name,
      colorHex: t.colorHex,
    )).toList();
  }

  @override
  Future<void> addTag(model_tag.Tag tag) async {
    await _db.into(_db.tags).insert(TagsCompanion.insert(
      id: tag.id,
      name: tag.name,
      colorHex: tag.colorHex,
    ));
  }

  @override
  Future<void> updateTag(model_tag.Tag tag) async {
    await (_db.update(_db.tags)..where((t) => t.id.equals(tag.id))).write(TagsCompanion(
      name: Value(tag.name),
      colorHex: Value(tag.colorHex),
    ));
  }

  @override
  Future<void> deleteTag(String id) async {
    await (_db.delete(_db.tags)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<List<model_budget.Budget>> getBudgets() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final List<dynamic> data = await _client
        .from('budgets')
        .select()
        .eq('user_id', user.id);

    return data.map((json) => model_budget.Budget.fromJson(json)).toList();
  }

  @override
  Future<void> upsertBudget(model_budget.Budget budget) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    await _client.from('budgets').upsert({
      'user_id': user.id,
      'category': budget.category,
      'limit_amount': budget.limit,
      'period': budget.period,
    }, onConflict: 'user_id, category, period');
  }

  @override
  Future<void> deleteBudget(String id) async {
    await _client.from('budgets').delete().eq('id', id);
  }
}
