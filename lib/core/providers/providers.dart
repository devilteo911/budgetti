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
import 'package:budgetti/core/theme/app_theme.dart';

import 'package:budgetti/core/services/backup_service.dart';
import 'package:budgetti/core/services/notification_service.dart';
import 'package:budgetti/core/services/google_auth_service.dart';
import 'package:budgetti/core/services/google_drive_service.dart';
import 'package:budgetti/core/services/google_sheets_service.dart';
import 'package:budgetti/core/services/sheets_sync_service.dart';
import 'package:budgetti/core/services/ocr_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:budgetti/core/services/import_service.dart';
import 'package:budgetti/core/services/gmail_service.dart';
import 'package:budgetti/core/services/email_sync_service.dart';
import 'package:budgetti/core/services/pending_transaction_service.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final persistenceServiceProvider = Provider<PersistenceService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PersistenceService(prefs);
});

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());



final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService();
});

final googleDriveServiceProvider = Provider<GoogleDriveService>((ref) {
  final authService = ref.watch(googleAuthServiceProvider);
  return GoogleDriveService(authService);
});

final googleSheetsServiceProvider = Provider<GoogleSheetsService>((ref) {
  final authService = ref.watch(googleAuthServiceProvider);
  return GoogleSheetsService(authService);
});

final sheetsSyncServiceProvider = Provider<SheetsSyncService>((ref) {
  final sheetsService = ref.watch(googleSheetsServiceProvider);
  final authService = ref.watch(googleAuthServiceProvider);
  final persistence = ref.watch(persistenceServiceProvider);
  return SheetsSyncService(sheetsService, authService, persistence);
});

/// Perform a full bidirectional sync with Google Sheets.
/// Safe to call from anywhere — no-ops if not signed in or already syncing.
Future<SyncResult> performSheetsSync(WidgetRef ref) async {
  final syncService = ref.read(sheetsSyncServiceProvider);
  final financeService = ref.read(financeServiceProvider);

  final accounts = await ref.read(accountsProvider.future);
  final accountNameToId = <String, String>{};
  final accountIdToName = <String, String>{};
  for (final a in accounts) {
    accountNameToId[a.name] = a.id;
    accountIdToName[a.id] = a.name;
  }

  final appTransactions = await financeService.getTransactions();

  return syncService.sync(
    appTransactions: appTransactions,
    accountNameToId: accountNameToId,
    accountIdToName: accountIdToName,
    onDeleteFromApp: (ids) => financeService.deleteTransactions(ids),
    onImportToApp: (txs) async {
      for (final tx in txs) {
        await financeService.addTransaction(tx);
      }
    },
  );
}

final backupServiceProvider = Provider<BackupService>((ref) {
  final db = ref.watch(databaseProvider);
  final driveService = ref.watch(googleDriveServiceProvider);
  final authService = ref.watch(googleAuthServiceProvider);
  return BackupService(db, driveService, authService);
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

// Stream provider for Supabase auth state changes
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

// Provider that tracks current user ID and updates when auth state changes
final currentUserIdProvider = Provider<String>((ref) {
  // Watch authStateProvider to trigger updates on login/logout
  ref.watch(authStateProvider);
  return Supabase.instance.client.auth.currentUser?.id ?? 'local';
});

final financeServiceProvider = Provider<FinanceService>((ref) {
  final db = ref.watch(databaseProvider);
  // Watch currentUserIdProvider so this recreates when user changes
  final userId = ref.watch(currentUserIdProvider);
  return LocalFinanceService(db, userId);
});

final gmailServiceProvider = Provider<GmailService>((ref) {
  final authService = ref.watch(googleAuthServiceProvider);
  return GmailService(authService);
});

final emailSyncServiceProvider = Provider<EmailSyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final gmail = ref.watch(gmailServiceProvider);
  final userId = ref.watch(currentUserIdProvider);
  return EmailSyncService(db, gmail, userId);
});

final pendingTransactionServiceProvider =
    Provider<PendingTransactionService>((ref) {
  final db = ref.watch(databaseProvider);
  final finance = ref.watch(financeServiceProvider);
  return PendingTransactionService(db, finance);
});

/// Live list of email-derived drafts awaiting review.
final pendingTransactionsProvider =
    StreamProvider<List<PendingTransaction>>((ref) {
  return ref.watch(pendingTransactionServiceProvider).watchPending();
});

/// Count of pending drafts, for the review shortcut banner.
final pendingTransactionsCountProvider = Provider<int>((ref) {
  return ref.watch(pendingTransactionsProvider).maybeWhen(
        data: (list) => list.length,
        orElse: () => 0,
      );
});

final accountsProvider = FutureProvider<List<Account>>((ref) async {
  final service = ref.watch(financeServiceProvider);
  return service.getAccounts();
});

final transactionsProvider = StreamProvider.family<List<Transaction>, String?>((
  ref,
  accountId,
) {
  final service = ref.watch(financeServiceProvider);
  return service.watchTransactions(accountId: accountId);
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
  // Watch authStateProvider so this refreshes on login/logout
  ref.watch(authStateProvider);
  
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

class ThemeSettings {
  final AppPalette palette;
  final ThemeMode mode;
  final bool amoled;
  final bool glass;

  const ThemeSettings({
    required this.palette,
    required this.mode,
    required this.amoled,
    required this.glass,
  });

  ThemeSettings copyWith({
    AppPalette? palette,
    ThemeMode? mode,
    bool? amoled,
    bool? glass,
  }) =>
      ThemeSettings(
        palette: palette ?? this.palette,
        mode: mode ?? this.mode,
        amoled: amoled ?? this.amoled,
        glass: glass ?? this.glass,
      );
}

class ThemeSettingsNotifier extends Notifier<ThemeSettings> {
  @override
  ThemeSettings build() {
    final p = ref.read(persistenceServiceProvider);
    return ThemeSettings(
      palette: AppPalette.values.firstWhere(
        (e) => e.name == p.getThemePalette(),
        orElse: () => AppPalette.mint,
      ),
      mode: switch (p.getThemeBrightness()) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      },
      amoled: p.getThemeAmoled(),
      glass: p.getThemeGlass(),
    );
  }

  Future<void> setPalette(AppPalette v) async {
    state = state.copyWith(palette: v);
    await ref.read(persistenceServiceProvider).setThemePalette(v.name);
  }

  Future<void> setMode(ThemeMode v) async {
    state = state.copyWith(mode: v);
    final s = switch (v) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      ThemeMode.dark => 'dark',
    };
    await ref.read(persistenceServiceProvider).setThemeBrightness(s);
  }

  Future<void> setAmoled(bool v) async {
    state = state.copyWith(amoled: v);
    await ref.read(persistenceServiceProvider).setThemeAmoled(v);
  }

  Future<void> setGlass(bool v) async {
    state = state.copyWith(glass: v);
    await ref.read(persistenceServiceProvider).setThemeGlass(v);
  }
}

final themeSettingsProvider =
    NotifierProvider<ThemeSettingsNotifier, ThemeSettings>(
  ThemeSettingsNotifier.new,
);

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

  // 1. Group by month
  final grouped = <DateTime, List<Transaction>>{};
  for (var t in transactions) {
    // Ensure stable keys using UTC for year/month
    final monthKey = DateTime.utc(t.date.year, t.date.month);
    grouped.putIfAbsent(monthKey, () => []).add(t);
  }

  // 2. Sort months
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

class FilteredTotals {
  final double income;
  final double expense;
  final int count;

  const FilteredTotals({
    required this.income,
    required this.expense,
    required this.count,
  });

  double get net => income - expense;

  static const empty = FilteredTotals(income: 0, expense: 0, count: 0);
}

final filteredTotalsProvider = Provider<FilteredTotals>((ref) {
  final all = ref.watch(transactionsProvider(null)).value ?? [];
  final filters = ref.watch(transactionFiltersProvider);
  final walletId = ref.watch(selectedWalletIdProvider);

  if (all.isEmpty) return FilteredTotals.empty;

  double income = 0;
  double expense = 0;
  int count = 0;

  for (final t in all) {
    if (walletId != null && t.accountId != walletId) continue;
    final range = filters.dateRange;
    if (range != null) {
      if (t.date.isBefore(range.start)) continue;
      if (t.date.isAfter(range.end)) continue;
    }
    if (filters.categories.isNotEmpty &&
        !filters.categories.contains(t.category)) {
      continue;
    }
    if (filters.tags.isNotEmpty &&
        !t.tags.any((tag) => filters.tags.contains(tag))) {
      continue;
    }

    count++;
    if (t.type == 'transfer') continue;
    if (t.amount > 0) {
      income += t.amount;
    } else {
      expense += t.amount.abs();
    }
  }

  return FilteredTotals(income: income, expense: expense, count: count);
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
  final double monthlyIncome;
  final double monthlyExpenses;
  final double netFlow;
  final List<Transaction> recentTransactions;

  DashboardStats({
    required this.totalBalance,
    required this.monthlyIncome,
    required this.monthlyExpenses,
    required this.recentTransactions,
    required this.netFlow,
  });

  double get monthlyNetFlow => monthlyIncome - monthlyExpenses;
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

          double monthlyExpenses = 0.0;
          double monthlyIncome = 0.0;
          for (final t in transactions) {
            if (t.date.month != currentMonth || t.date.year != currentYear) {
              continue;
            }
            if (t.type == 'income') {
              monthlyIncome += t.amount;
            } else if (t.amount < 0 && t.type != 'transfer') {
              monthlyExpenses += t.amount.abs();
            }
          }

          final netFlow = transactions
              .where((t) => t.date.isAfter(last30Days))
              .fold(0.0, (sum, t) => sum + t.amount);

          return AsyncData(
            DashboardStats(
              totalBalance: totalBalance,
              monthlyIncome: monthlyIncome,
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

final monthlyNetFlowHistoryProvider = Provider<List<double>>((ref) {
  final transactions = ref.watch(transactionsProvider(null)).value ?? [];
  final now = DateTime.now();
  final keys = <String>[];
  final buckets = <String, double>{};
  for (int i = 5; i >= 0; i--) {
    final d = DateTime(now.year, now.month - i);
    final k = '${d.year}-${d.month}';
    keys.add(k);
    buckets[k] = 0.0;
  }
  for (final t in transactions) {
    if (t.type == 'transfer') continue;
    final k = '${t.date.year}-${t.date.month}';
    if (buckets.containsKey(k)) {
      buckets[k] = buckets[k]! + t.amount;
    }
  }
  return keys.map((k) => buckets[k]!).toList();
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

class StatsPeriod {
  final int year;
  final int? month;

  StatsPeriod({required this.year, this.month});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatsPeriod &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          month == other.month;

  @override
  int get hashCode => year.hashCode ^ month.hashCode;
}

final statsDataProvider = Provider.family<AsyncValue<StatsData>, StatsPeriod>((
  ref,
  period,
) {
  final transactionsAsync = ref.watch(transactionsProvider(null));

  return transactionsAsync.whenData((allTransactions) {
    final transactions = allTransactions.where((t) {
      if (t.date.year != period.year) return false;
      if (period.month != null && t.date.month != period.month) return false;
      return true;
    }).toList();
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

enum ChartGranularity { daily, weekly, monthly }

class ChartGranularityNotifier extends Notifier<ChartGranularity> {
  @override
  ChartGranularity build() => ChartGranularity.daily;

  void set(ChartGranularity value) => state = value;
}

final chartGranularityProvider =
    NotifierProvider<ChartGranularityNotifier, ChartGranularity>(
      ChartGranularityNotifier.new,
    );

class ChartDataPoint {
  final DateTime label;
  final double amount;

  ChartDataPoint(this.label, this.amount);
}

final chartsDataProvider = Provider<AsyncValue<List<ChartDataPoint>>>((ref) {
  final granularity = ref.watch(chartGranularityProvider);
  final period = ref.watch(selectedStatsPeriodProvider);
  final scope = ref.watch(statsScopeProvider);
  final transactionsAsync = ref.watch(transactionsProvider(null));

  return transactionsAsync.whenData((allTransactions) {
    if (allTransactions.isEmpty) return [];

    final transactions = allTransactions.where((t) {
      if (t.date.year != period.year) return false;
      if (period.month != null && t.date.month != period.month) return false;
      return true;
    }).toList();

    if (transactions.isEmpty) return [];

    final scopedTransactions = transactions.where((t) {
      switch (scope) {
        case StatsScope.expenses:
          return t.amount < 0;
        case StatsScope.income:
          return t.amount > 0;
        case StatsScope.all:
          return t.amount != 0;
      }
    }).toList();
    if (scopedTransactions.isEmpty) return [];

    final Map<DateTime, double> groupedData = {};

    for (var t in scopedTransactions) {
      DateTime key;
      switch (granularity) {
        case ChartGranularity.daily:
          key = DateTime(t.date.year, t.date.month, t.date.day);
          break;
        case ChartGranularity.weekly:
          // Find the beginning of the week (Monday)
          key = DateTime(
            t.date.year,
            t.date.month,
            t.date.day - (t.date.weekday - 1),
          );
          break;
        case ChartGranularity.monthly:
          key = DateTime(t.date.year, t.date.month, 1);
          break;
      }
      groupedData[key] = (groupedData[key] ?? 0) + t.amount.abs();
    }

    final sortedKeys = groupedData.keys.toList()..sort();
    return sortedKeys
        .map((key) => ChartDataPoint(key, groupedData[key]!))
        .toList();
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

class SelectedStatsPeriodNotifier extends Notifier<StatsPeriod> {
  @override
  StatsPeriod build() =>
      StatsPeriod(year: DateTime.now().year, month: DateTime.now().month);

  void setYear(int year) {
    final now = DateTime.now();
    var month = state.month;
    if (year == now.year && month != null && month > now.month) {
      month = now.month;
    }
    state = StatsPeriod(year: year, month: month);
  }

  void setMonth(int? month) {
    final now = DateTime.now();
    var clamped = month;
    if (clamped != null && state.year == now.year && clamped > now.month) {
      clamped = now.month;
    }
    state = StatsPeriod(year: state.year, month: clamped);
  }

  void toggleMode() {
    if (state.month == null) {
      state = StatsPeriod(year: state.year, month: DateTime.now().month);
    } else {
      state = StatsPeriod(year: state.year, month: null);
    }
  }
}

final selectedStatsPeriodProvider =
    NotifierProvider<SelectedStatsPeriodNotifier, StatsPeriod>(
      SelectedStatsPeriodNotifier.new,
    );

enum StatsScope { all, expenses, income }

class StatsScopeNotifier extends Notifier<StatsScope> {
  @override
  StatsScope build() => StatsScope.expenses;

  void set(StatsScope value) => state = value;
}

final statsScopeProvider =
    NotifierProvider<StatsScopeNotifier, StatsScope>(StatsScopeNotifier.new);

final selectedWalletIdProvider = NotifierProvider<SelectedWalletId, String?>(SelectedWalletId.new);
