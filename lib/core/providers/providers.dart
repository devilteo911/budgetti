import 'package:flutter/material.dart';
import 'package:budgetti/core/database/database.dart'
    hide Category, Tag, Account, Transaction, Budget;
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/models/account.dart';
import 'package:budgetti/models/category.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:budgetti/models/tag.dart';
import 'package:budgetti/models/budget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:budgetti/core/services/persistence_service.dart';

import 'package:budgetti/core/services/backup_service.dart';
import 'package:budgetti/core/services/notification_service.dart';
import 'package:budgetti/core/services/google_drive_service.dart';
import 'package:budgetti/core/services/ocr_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:budgetti/core/services/import_service.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final persistenceServiceProvider = Provider<PersistenceService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PersistenceService(prefs);
});

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());



final googleDriveServiceProvider = Provider<GoogleDriveService>((ref) {
  return GoogleDriveService();
});

final backupServiceProvider = Provider<BackupService>((ref) {
  final db = ref.watch(databaseProvider);
  final driveService = ref.watch(googleDriveServiceProvider);
  return BackupService(db, driveService);
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final ocrServiceProvider = Provider<OcrService>((ref) {
  final persistenceService = ref.watch(persistenceServiceProvider);
  final service = OcrService(persistenceService);
  ref.onDispose(service.dispose);
  return service;
});

final importServiceProvider = Provider<ImportService>((ref) {
  return ImportService();
});

// Provider that tracks current user ID and updates when auth state changes
final currentUserIdProvider = Provider<String>((ref) {
  // Watch userProfileProvider to trigger updates on auth changes
  ref.watch(userProfileProvider);
  return Supabase.instance.client.auth.currentUser?.id ?? 'local';
});

final financeServiceProvider = Provider<FinanceService>((ref) {
  final db = ref.watch(databaseProvider);
  // Watch currentUserIdProvider so this recreates when user changes
  final userId = ref.watch(currentUserIdProvider);
  return LocalFinanceService(db, userId);
});

final accountsProvider = FutureProvider<List<Account>>((ref) async {
  final service = ref.watch(financeServiceProvider);
  return service.getAccounts();
});

final transactionsProvider = FutureProvider.family<List<Transaction>, String?>((ref, accountId) async {
  try {
    final service = ref.watch(financeServiceProvider);
    return await service.getTransactions(accountId: accountId);
  } catch (e) {
    return [];
  }
});

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final service = ref.watch(financeServiceProvider);
  return service.getCategories();
});

final tagsProvider = FutureProvider<List<Tag>>((ref) async {
  final service = ref.watch(financeServiceProvider);
  return service.getTags();
});

final budgetsProvider = FutureProvider<List<Budget>>((ref) async {
  try {
    final service = ref.watch(financeServiceProvider);
    return await service.getBudgets();
  } catch (e) {
    return [];
  }
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
  bool build() {
    final persistenceService = ref.read(persistenceServiceProvider);
    return persistenceService.getBalanceVisibility();
  }

  void toggle() async {
    final newValue = !state;
    state = newValue;
    final persistenceService = ref.read(persistenceServiceProvider);
    await persistenceService.setBalanceVisibility(newValue);
  }
}

final balanceVisibilityProvider = NotifierProvider<BalanceVisibility, bool>(BalanceVisibility.new);

class TransactionFilterState {
  final DateTimeRange? dateRange;
  final List<String> categories;
  final List<String> tags;

  TransactionFilterState({
    this.dateRange,
    this.categories = const [],
    this.tags = const [],
  });

  bool get isEmpty =>
      dateRange == null && categories.isEmpty && tags.isEmpty;

  TransactionFilterState copyWith({
    DateTimeRange? Function()? dateRange,
    List<String>? categories,
    List<String>? tags,
  }) {
    return TransactionFilterState(
      dateRange: dateRange != null ? dateRange() : this.dateRange,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
    );
  }
}

class TransactionFiltersNotifier extends Notifier<TransactionFilterState> {
  @override
  TransactionFilterState build() {
    final now = DateTime.now();
    return TransactionFilterState(
      dateRange: DateTimeRange(
        start: DateTime(now.year, 1, 1),
        end: DateTime(now.year, 12, 31),
      ),
    );
  }

  void setDateRange(DateTimeRange? range) {
    state = state.copyWith(dateRange: () => range);
  }

  void toggleCategory(String category) {
    final categories = List<String>.from(state.categories);
    if (categories.contains(category)) {
      categories.remove(category);
    } else {
      categories.add(category);
    }
    state = state.copyWith(categories: categories);
  }

  void toggleTag(String tag) {
    final tags = List<String>.from(state.tags);
    if (tags.contains(tag)) {
      tags.remove(tag);
    } else {
      tags.add(tag);
    }
    state = state.copyWith(tags: tags);
  }

  void reset() {
    state = TransactionFilterState();
  }
}

final transactionFiltersProvider =
    NotifierProvider<TransactionFiltersNotifier, TransactionFilterState>(
        TransactionFiltersNotifier.new);

final paginatedTransactionsProvider =
    NotifierProvider<PaginatedTransactionsNotifier, PaginatedTransactionsState>(
      PaginatedTransactionsNotifier.new,
    );

class GroupedTransactions {
  final List<dynamic> flatList;
  final Map<int, DateTime> dateIndices;
  final List<DateTime> sortedDates;

  GroupedTransactions({
    required this.flatList,
    required this.dateIndices,
    required this.sortedDates,
  });
}

final groupedTransactionsProvider = Provider<GroupedTransactions>((ref) {
  final transactions = ref.watch(paginatedTransactionsProvider).transactions;

  if (transactions.isEmpty) {
    return GroupedTransactions(flatList: [], dateIndices: {}, sortedDates: []);
  }

  // 1. Group by date
  final grouped = <DateTime, List<Transaction>>{};
  for (var t in transactions) {
    final date = DateTime(t.date.year, t.date.month, t.date.day);
    grouped.putIfAbsent(date, () => []).add(t);
  }

  // 2. Sort dates
  final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

  // 3. Create flat list with headers
  final flatList = <dynamic>[];
  final dateIndices = <int, DateTime>{};

  for (var date in sortedDates) {
    dateIndices[flatList.length] = date;
    flatList.add(date); // We'll use the date itself as a header indicator
    for (var t in grouped[date]!) {
      dateIndices[flatList.length] = date;
      flatList.add(t);
    }
  }

  return GroupedTransactions(
    flatList: flatList,
    dateIndices: dateIndices,
    sortedDates: sortedDates,
  );
});

final categoryMapProvider = Provider<Map<String, Category>>((ref) {
  final categories = ref.watch(categoriesProvider).value ?? [];
  return {for (var c in categories) c.name: c};
});

final tagMapProvider = Provider<Map<String, Tag>>((ref) {
  final tags = ref.watch(tagsProvider).value ?? [];
  return {for (var t in tags) t.name: t};
});

// Cache providers for colors and icons to avoid per-frame allocations
final categoryColorCacheProvider = Provider<Map<String, Color>>((ref) {
  final categories = ref.watch(categoriesProvider).value ?? [];
  return {for (var c in categories) c.name: Color(c.colorHex)};
});

final categoryIconCacheProvider = Provider<Map<String, IconData>>((ref) {
  final categories = ref.watch(categoriesProvider).value ?? [];
  return {
    for (var c in categories)
      c.name: IconData(c.iconCode, fontFamily: 'MaterialIcons')
  };
});

final tagColorCacheProvider = Provider<Map<String, Color>>((ref) {
  final tags = ref.watch(tagsProvider).value ?? [];
  return {for (var t in tags) t.name: Color(t.colorHex)};
});

class DashboardStats {
  final double totalBalance;
  final double monthlyExpenses;
  final double netFlow;
  final List<Transaction> recentTransactions;

  DashboardStats({
    required this.totalBalance,
    required this.monthlyExpenses,
    required this.recentTransactions,
    required this.netFlow,
  });
}

final dashboardStatsProvider = Provider<AsyncValue<DashboardStats>>((ref) {
  final accountsAsync = ref.watch(accountsProvider);
  final transactionsAsync = ref.watch(transactionsProvider(null));

  return transactionsAsync.when(
    loading: () => const AsyncLoading(),
    error: (err, stack) => AsyncError(err, stack),
    data: (transactions) {
      return accountsAsync.when(
        loading: () => const AsyncLoading(),
        error: (err, stack) => AsyncError(err, stack),
        data: (accounts) {
          final now = DateTime.now();
          final currentMonth = now.month;
          final currentYear = now.year;
          final last30Days = now.subtract(const Duration(days: 30));

          final totalBalance = accounts.fold(
            0.0,
            (sum, acc) => sum + acc.balance,
          );

          final monthlyExpenses = transactions
              .where(
                (t) =>
                    t.date.month == currentMonth &&
                    t.date.year == currentYear &&
                    t.amount < 0,
              )
              .fold(0.0, (sum, t) => sum + t.amount.abs());

          final netFlow = transactions
              .where((t) => t.date.isAfter(last30Days))
              .fold(0.0, (sum, t) => sum + t.amount);

          return AsyncData(
            DashboardStats(
              totalBalance: totalBalance,
              monthlyExpenses: monthlyExpenses,
              netFlow: netFlow,
              recentTransactions: transactions.take(10).toList(),
            ),
          );
        },
      );
    },
  );
});

final budgetMapProvider = Provider<Map<String, Budget>>((ref) {
  final budgets = ref.watch(budgetsProvider).value ?? [];
  return {for (var b in budgets) b.category: b};
});

final budgetStatsProvider = Provider<AsyncValue<Map<String, double>>>((ref) {
  final transactionsAsync = ref.watch(transactionsProvider(null));
  final now = DateTime.now();

  return transactionsAsync.whenData((transactions) {
    final categorySpending = <String, double>{};
    for (var t in transactions) {
      if (t.date.year == now.year &&
          t.date.month == now.month &&
          t.amount < 0) {
        categorySpending[t.category] =
            (categorySpending[t.category] ?? 0) + t.amount.abs();
      }
    }
    return categorySpending;
  });
});

class StatsData {
  final Map<String, double> categoryTotals;
  final Map<String, Map<String, double>> monthlyBreakdown;
  final double totalExpenses;

  StatsData({
    required this.categoryTotals,
    required this.monthlyBreakdown,
    required this.totalExpenses,
  });
}

final statsDataProvider = Provider.family<AsyncValue<StatsData>, int>((
  ref,
  year,
) {
  final transactionsAsync = ref.watch(transactionsProvider(null));

  return transactionsAsync.whenData((allTransactions) {
    final transactions = allTransactions
        .where((t) => t.date.year == year)
        .toList();
    final categoryTotals = <String, double>{};
    final monthlyBreakdown = <String, Map<String, double>>{};
    double totalExpenses = 0.0;

    for (var t in transactions) {
      // Distribution & Total
      if (t.amount < 0) {
        categoryTotals[t.category] =
            (categoryTotals[t.category] ?? 0) + t.amount.abs();
        totalExpenses += t.amount.abs();
      }

      // Breakdown
      final monthKey = DateFormat('yyyy-MM').format(t.date);
      if (!monthlyBreakdown.containsKey(monthKey)) {
        monthlyBreakdown[monthKey] = {'earned': 0.0, 'spent': 0.0};
      }

      if (t.amount > 0) {
        monthlyBreakdown[monthKey]!['earned'] =
            monthlyBreakdown[monthKey]!['earned']! + t.amount;
      } else {
        monthlyBreakdown[monthKey]!['spent'] =
            monthlyBreakdown[monthKey]!['spent']! + t.amount.abs();
      }
    }

    return StatsData(
      categoryTotals: categoryTotals,
      monthlyBreakdown: monthlyBreakdown,
      totalExpenses: totalExpenses,
    );
  });
});

class PaginatedTransactionsState {
  final List<Transaction> transactions;
  final bool isLoading;
  final bool hasMore;
  final int offset;
  final bool isRefreshing;
  final String? error;

  PaginatedTransactionsState({
    required this.transactions,
    required this.isLoading,
    required this.hasMore,
    required this.offset,
    this.isRefreshing = false,
    this.error,
  });

  PaginatedTransactionsState copyWith({
    List<Transaction>? transactions,
    bool? isLoading,
    bool? hasMore,
    int? offset,
    bool? isRefreshing,
    String? error,
  }) {
    return PaginatedTransactionsState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      offset: offset ?? this.offset,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error,
    );
  }
}

class PaginatedTransactionsNotifier
    extends Notifier<PaginatedTransactionsState> {
  static const int _limit = 100;

  @override
  PaginatedTransactionsState build() {
    // Watch filters and wallet - this triggers build() when they change
    ref.watch(transactionFiltersProvider);
    ref.watch(selectedWalletIdProvider);

    // Use microtask to avoid side-effects during build
    Future.microtask(() => refresh());
    
    return PaginatedTransactionsState(
      transactions: [],
      isLoading: true,
      hasMore: true,
      offset: 0,
    );
  }

  Future<void> refresh() async {
    state = state.copyWith(
      isRefreshing: true,
      isLoading: true,
      hasMore: true,
      // NOTE: We don't clear transactions here to avoid skeleton flickering
    );
    await _fetchBatch();
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    await _fetchBatch();
  }

  Future<void> _fetchBatch() async {
    final filters = ref.read(transactionFiltersProvider);
    final walletId = ref.read(selectedWalletIdProvider);
    final service = ref.read(financeServiceProvider);

    try {
      final newTxns = await service.getTransactions(
        accountId: walletId,
        startDate: filters.dateRange?.start,
        endDate: filters.dateRange?.end,
        categories: filters.categories,
        tags: filters.tags,
        limit: _limit,
        offset: state.isRefreshing ? 0 : state.offset,
      );

      state = state.copyWith(
        transactions: state.isRefreshing
            ? newTxns
            : [...state.transactions, ...newTxns],
        isLoading: false,
        isRefreshing: false,
        offset: (state.isRefreshing ? 0 : state.offset) + newTxns.length,
        hasMore: newTxns.length == _limit,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        hasMore: false,
        error: e.toString(),
      );
    }
  }
}

class SelectedWalletId extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? id) => state = id;
}

final selectedWalletIdProvider = NotifierProvider<SelectedWalletId, String?>(SelectedWalletId.new);
