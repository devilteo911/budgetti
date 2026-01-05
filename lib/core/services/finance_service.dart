import 'package:budgetti/models/account.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class FinanceService {
  Future<List<Account>> getAccounts();
  Future<List<Transaction>> getTransactions(String accountId);
  Future<void> addTransaction(Transaction transaction);
  Future<void> deleteTransactions(List<String> ids);
}

class SupabaseFinanceService implements FinanceService {
  final _client = Supabase.instance.client;

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
}
