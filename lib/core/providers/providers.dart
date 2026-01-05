import 'package:budgetti/core/database/database.dart' hide Category;
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/models/account.dart';
import 'package:budgetti/models/category.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final financeServiceProvider = Provider<FinanceService>((ref) {
  final db = ref.watch(databaseProvider);
  return SupabaseFinanceService(db);
});

final accountsProvider = FutureProvider<List<Account>>((ref) async {
  final service = ref.watch(financeServiceProvider);
  return service.getAccounts();
});

final transactionsProvider = FutureProvider.family<List<Transaction>, String>((ref, accountId) async {
  final service = ref.watch(financeServiceProvider);
  return service.getTransactions(accountId);
});

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final service = ref.watch(financeServiceProvider);
  return service.getCategories();
});

final userProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;
  
  try {
    final data = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();
    return data;
  } catch (e) {
    return null; // Profile doesn't exist yet
  }
});

final currencyProvider = Provider<NumberFormat>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  final currencyCode = profileAsync.value?['currency'] as String? ?? 'EUR';
  
  return NumberFormat.simpleCurrency(name: currencyCode);
});

class BalanceVisibility extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final balanceVisibilityProvider = NotifierProvider<BalanceVisibility, bool>(BalanceVisibility.new);
