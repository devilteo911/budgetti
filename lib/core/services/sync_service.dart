import 'package:budgetti/core/database/database.dart';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SyncService {
  final AppDatabase _db;
  final SupabaseClient _client = Supabase.instance.client;

  SyncService(this._db);

  Future<void> importFromCloud() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    
    try {
      await _importCategories(user.id);
      await _importTags(user.id);
      await _importAccounts(user.id); // Wallets
      await _importTransactions(user.id);
      await _importBudgets(user.id);
    } catch (e) {
      // ignore: avoid_print
      print('Import Error: $e');
      rethrow;
    }
  }

  Future<void> exportToCloud() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    
    try {
      await _exportCategories(user.id);
      await _exportTags(user.id);
      await _exportAccounts(user.id); // Wallets
      await _exportTransactions(user.id);
      await _exportBudgets(user.id);
    } catch (e) {
      // ignore: avoid_print
      print('Export Error: $e');
      rethrow;
    }
  }

  // --- Categories ---
  Future<void> _importCategories(String userId) async {
    try {
      final remoteData = await _client.from('categories').select().eq('user_id', userId);
      await _db.batch((batch) {
        for (final item in remoteData) {
          batch.insert(
            _db.categories,
            CategoriesCompanion.insert(
              id: item['id'],
              userId: Value(userId),
              name: item['name'],
              iconCode: item['iconCode'] ?? item['icon_code'] ?? 0, 
              colorHex: item['colorHex'] ?? item['color_hex'] ?? 0,
              type: item['type'],
              description: Value(item['description']),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
    } on PostgrestException catch (e) {
      // Ignore table not found error, but rethrow others
      if (e.code != 'PGRST205' && e.code != '42P01') { 
        rethrow;
      }
      print('Categories table not found, skipping sync.');
    }
  }

  Future<void> _exportCategories(String userId) async {
    try {
      // Upsert local
      final localData = await (_db.select(_db.categories)..where((t) => t.isDeleted.equals(false))).get();
      for (final item in localData) {
        await _client.from('categories').upsert({
          'id': item.id,
          'user_id': userId,
          'name': item.name,
          'iconCode': item.iconCode,
          'colorHex': item.colorHex,
          'type': item.type,
          'description': item.description,
        });
      }

      // Process Deletions
      final deletedLocal = await (_db.select(_db.categories)..where((t) => t.isDeleted.equals(true))).get();
      for (final item in deletedLocal) {
        await _client.from('categories').delete().eq('id', item.id);
      }
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST205' && e.code != '42P01') {
        rethrow;
      }
      print('Categories table not found, skipping sync.');
    }
  }

  // --- Tags ---
  Future<void> _importTags(String userId) async {
    try {
      final remoteData = await _client.from('tags').select().eq('user_id', userId);
      await _db.batch((batch) {
        for (final item in remoteData) {
          batch.insert(
            _db.tags,
            TagsCompanion.insert(
              id: item['id'],
              userId: Value(userId),
              name: item['name'],
              colorHex: item['colorHex'] ?? item['color_hex'] ?? 0,
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST205' && e.code != '42P01') {
        rethrow;
      }
      print('Tags table not found, skipping sync.');
    }
  }

  Future<void> _exportTags(String userId) async {
    try {
      final localData = await (_db.select(_db.tags)..where((t) => t.isDeleted.equals(false))).get();
      for (final item in localData) {
        await _client.from('tags').upsert({
          'id': item.id,
          'user_id': userId,
          'name': item.name,
          'colorHex': item.colorHex,
        });
      }

      final deletedLocal = await (_db.select(_db.tags)..where((t) => t.isDeleted.equals(true))).get();
      for (final item in deletedLocal) {
        await _client.from('tags').delete().eq('id', item.id);
      }
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST205' && e.code != '42P01') {
        rethrow;
      }
      print('Tags table not found, skipping sync.');
    }
  }

   // --- Accounts (Wallets) ---
  Future<void> _importAccounts(String userId) async {
    final remoteData = await _client.from('wallets').select().eq('user_id', userId);
    await _db.batch((batch) {
      for (final item in remoteData) {
        batch.insert(
          _db.accounts,
          AccountsCompanion.insert(
            id: item['id'],
            userId: Value(userId),
            name: item['name'],
            balance: Value((item['initialBalance'] ?? item['balance'] ?? 0).toDouble()),
            currency: Value(item['currency'] ?? 'EUR'),
            providerName: Value(item['providerName']),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<void> _exportAccounts(String userId) async {
    final localData = await (_db.select(_db.accounts)..where((t) => t.isDeleted.equals(false))).get();
    for (final item in localData) {
      if (item.id == '1') continue; 

      await _client.from('wallets').upsert({
        'id': item.id,
        'user_id': userId,
        'name': item.name,
        'initialBalance': item.balance,
        'currency': item.currency,
        'providerName': item.providerName,
      });
    }
    
    final deletedLocal = await (_db.select(_db.accounts)..where((t) => t.isDeleted.equals(true))).get();
    for (final item in deletedLocal) {
        if (item.id == '1') continue; 
        await _client.from('wallets').delete().eq('id', item.id);
    }
  }

  // --- Transactions ---
  Future<void> _importTransactions(String userId) async {
    final remoteData = await _client.from('transactions').select().eq('user_id', userId);
    await _db.batch((batch) {
      for (final item in remoteData) {
        batch.insert(
          _db.transactions,
          TransactionsCompanion.insert(
            id: item['id'],
            userId: Value(userId),
            accountId: Value(item['account_id']),
            amount: (item['amount'] as num).toDouble(),
            description: item['description'],
            category: item['category'],
            date: DateTime.parse(item['date']),
            tags: Value(List<String>.from(item['tags'] ?? [])),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<void> _exportTransactions(String userId) async {
    final localData = await (_db.select(_db.transactions)..where((t) => t.isDeleted.equals(false))).get();
    for (final item in localData) {
      final accId = item.accountId == '1' ? null : item.accountId;

      await _client.from('transactions').upsert({
        'id': item.id,
        'user_id': userId,
        'account_id': accId,
        'amount': item.amount,
        'description': item.description,
        'category': item.category,
        'date': item.date.toIso8601String(),
        'tags': item.tags,
      });
    }

    final deletedLocal = await (_db.select(_db.transactions)..where((t) => t.isDeleted.equals(true))).get();
    for (final item in deletedLocal) {
      await _client.from('transactions').delete().eq('id', item.id);
    }
  }

  // --- Budgets ---
  Future<void> _importBudgets(String userId) async {
    final remoteData = await _client.from('budgets').select().eq('user_id', userId);
    await _db.batch((batch) {
      for (final item in remoteData) {
        batch.insert(
          _db.budgets,
          BudgetsCompanion.insert(
            id: item['id'],
            userId: Value(userId),
            category: item['category'],
            limitAmount: (item['limit_amount'] ?? 0).toDouble(),
            period: item['period'],
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<void> _exportBudgets(String userId) async {
    final localData = await (_db.select(_db.budgets)..where((t) => t.isDeleted.equals(false))).get();
    for (final item in localData) {
      await _client.from('budgets').upsert({
        'id': item.id,
        'user_id': userId,
        'category': item.category,
        'limit_amount': item.limitAmount,
        'period': item.period,
      });
    }

    final deletedLocal = await (_db.select(_db.budgets)..where((t) => t.isDeleted.equals(true))).get();
    for (final item in deletedLocal) {
      await _client.from('budgets').delete().eq('id', item.id);
    }
  }
}
