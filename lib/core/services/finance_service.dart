import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/models/account.dart';
import 'package:budgetti/models/category.dart' as model;
import 'package:budgetti/models/transaction.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class FinanceService {
  Future<List<Account>> getAccounts();
  Future<List<Transaction>> getTransactions(String accountId);
  Future<void> addTransaction(Transaction transaction);
  Future<void> deleteTransactions(List<String> ids);
  Future<List<model.Category>> getCategories();
  Future<void> addCategory(model.Category category);
  Future<void> updateCategory(model.Category category);
  Future<void> deleteCategory(String id);
}

class SupabaseFinanceService implements FinanceService {
  final _client = Supabase.instance.client;
  final AppDatabase _db;

  SupabaseFinanceService(this._db);

  @override
  Future<List<Account>> getAccounts() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    // Calculate total balance from transactions
    final List<dynamic> data = await _client
        .from('transactions')
        .select('amount')
        .eq('user_id', user.id);
    
    double total = 0;
    for (var item in data) {
      total += (item['amount'] as num).toDouble();
    }

    // Return a single "Main Wallet" account for now
    return [
      Account(
        id: '1',
        name: 'Main Wallet',
        balance: total,
        currency: 'EUR', // Default currency
        providerName: 'Supabase',
      )
    ];
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
    });
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
    // Seed default categories if table is empty
    await _db.seedIfEmpty();
    
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
    ));
  }

  @override
  Future<void> updateCategory(model.Category category) async {
    await (_db.update(_db.categories)..where((t) => t.id.equals(category.id))).write(CategoriesCompanion(
      name: Value(category.name),
      iconCode: Value(category.iconCode),
      colorHex: Value(category.colorHex),
      type: Value(category.type),
    ));
  }

  @override
  Future<void> deleteCategory(String id) async {
    await (_db.delete(_db.categories)..where((t) => t.id.equals(id))).go();
  }
}
