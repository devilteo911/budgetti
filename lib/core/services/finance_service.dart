import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/models/account.dart';
import 'package:budgetti/models/category.dart' as model;
import 'package:budgetti/models/transaction.dart';
import 'package:budgetti/models/tag.dart' as model_tag;
import 'package:budgetti/models/budget.dart' as model_budget;
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class FinanceService {
  Future<List<Account>> getAccounts();
  Future<void> addAccount(Account account);
  Future<void> updateAccount(Account account);
  Future<void> deleteAccount(String id);
  Future<List<Transaction>> getTransactions(String accountId);
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

      final List<dynamic> data = await _client
          .from('wallets')
          .select()
          .eq('user_id', user.id);

      final accounts = data.map((json) => Account.fromJson(json)).toList();

      if (accounts.isNotEmpty) return accounts;

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

    await _client
        .from('wallets')
        .update({...account.toJson()})
        .eq('id', account.id);
  }

  @override
  Future<void> deleteAccount(String id) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    await _client.from('wallets').delete().eq('id', id);
  }

  @override
  Future<List<Transaction>> getTransactions(String accountId) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final List<dynamic> data = await _client
        .from('transactions')
        .select()
        .eq('user_id', user.id)
        .order('date', ascending: false);

    return data.map((json) => Transaction.fromJson(json)).toList();
  }

  @override
  Future<void> addTransaction(Transaction transaction) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    await _client.from('transactions').insert({
      'user_id': user.id,
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
