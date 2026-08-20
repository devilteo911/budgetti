import 'package:flutter/material.dart';
import 'package:budgetti/core/database/database.dart'
    hide Category, Tag, Account, Transaction, Budget, Installment;
import 'package:budgetti/core/database/database.dart' as db show Transaction;
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/models/account.dart';
import 'package:budgetti/models/category.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:budgetti/models/tag.dart';
import 'package:budgetti/models/budget.dart';
import 'package:budgetti/models/installment.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:budgetti/core/services/persistence_service.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/core/theme/ledger_style.dart';

import 'package:budgetti/core/services/backup_service.dart';
import 'package:budgetti/core/services/notification_service.dart';
import 'package:budgetti/core/services/google_auth_service.dart';
import 'package:budgetti/core/services/google_drive_service.dart';
import 'package:budgetti/core/services/sheets_sync_service.dart';
import 'package:budgetti/core/services/pocketbase_sync_service.dart';
import 'package:budgetti/core/services/auth_service.dart';
import 'package:budgetti/core/services/ocr_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocketbase/pocketbase.dart' as pb;
import 'package:budgetti/core/services/import_service.dart';
import 'package:budgetti/core/services/gmail_service.dart';
import 'package:budgetti/core/services/bank_sync_service.dart';
import 'package:budgetti/core/services/notification_listener_service.dart';
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

final sheetsSyncServiceProvider = Provider<SheetsSyncService>((ref) {
  final authService = ref.watch(googleAuthServiceProvider);
  final persistence = ref.watch(persistenceServiceProvider);
  return SheetsSyncService(authService, persistence);
});

/// Perform a full bidirectional sync with Google Sheets.
/// Safe to call from anywhere — no-ops if not signed in or already syncing.
Future<SyncResult> performSheetsSync(WidgetRef ref) async {
  final syncService = ref.read(sheetsSyncServiceProvider);
  final financeService = ref.read(financeServiceProvider);

  final accounts = await financeService.getAccounts();
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

// ── PocketBase sync + auth ─────────────────────────────────────────────────
final pocketbaseInstanceProvider = Provider<pb.PocketBase>((ref) {
  final persistence = ref.watch(persistenceServiceProvider);
  final store = pb.AsyncAuthStore(
    save: persistence.setPbAuth,
    initial: persistence.getPbAuth(),
  );
  return pb.PocketBase(persistence.getServerUrl(), authStore: store);
});

final pocketbaseClientProvider = Provider<PocketBaseSyncClient>((ref) {
  return PocketBaseSyncClient(ref.watch(pocketbaseInstanceProvider));
});

final pocketBaseSyncServiceProvider = Provider<PocketBaseSyncService>((ref) {
  final client = ref.watch(pocketbaseClientProvider);
  final db = ref.watch(databaseProvider);
  final persistence = ref.watch(persistenceServiceProvider);
  // currentUserIdProvider (not client.userId captured once): a service built
  // before login held userId '' and stamped every pulled row invisible.
  final userId = ref.watch(currentUserIdProvider);
  return PocketBaseSyncService(client, db, persistence, userId);
});

/// Runs a PocketBase sync. No-ops (returns null) when no server is configured.
/// [full] + [pull]/[push] select the git-style variants (pull/push everything).
Future<SyncSummary?> performPocketBaseSync(
  WidgetRef ref, {
  bool full = false,
  bool pull = true,
  bool push = true,
}) async {
  if (ref.read(persistenceServiceProvider).getServerUrl().isEmpty) {
    return null;
  }
  return ref
      .read(pocketBaseSyncServiceProvider)
      .sync(full: full, pull: pull, push: push);
}

/// Watches the local DB and pushes to PocketBase on every change (debounced),
/// so edits reach the backend immediately without a manual "Sync now". Started
/// once at launch; kept alive for the app's lifetime.
final pocketBaseAutoSyncProvider = Provider<PocketBaseAutoSync>((ref) {
  final persistence = ref.watch(persistenceServiceProvider);
  final auto = PocketBaseAutoSync(
    db: ref.watch(databaseProvider),
    isEnabled: () => persistence.getServerUrl().isNotEmpty,
    runSync: () => ref.read(pocketBaseSyncServiceProvider).sync(),
  );
  ref.onDispose(auto.dispose);
  return auto;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    ref.watch(pocketbaseInstanceProvider),
    ref.watch(persistenceServiceProvider),
    ref.watch(databaseProvider),
  );
});

// Emits on login/logout so auth-dependent providers + the router rebuild.
final authStateProvider = StreamProvider<void>((ref) {
  return ref.watch(authServiceProvider).changes;
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final ocrServiceProvider = Provider<OcrService>((ref) {
  return OcrService();
});

final importServiceProvider = Provider<ImportService>((ref) {
  return ImportService();
});

// Current user id: the PocketBase auth id once logged in (read from the
// persisted store, so it's available offline), else the stable per-install
// local id resolved at startup. Rebuilds on login/logout.
final currentUserIdProvider = Provider<String>((ref) {
  ref.watch(authStateProvider);
  final pbId = ref.watch(authServiceProvider).pbUserId;
  if (pbId != null && pbId.isNotEmpty) return pbId;
  return ref.watch(persistenceServiceProvider).getLocalUserId();
});

final financeServiceProvider = Provider<FinanceService>((ref) {
  final db = ref.watch(databaseProvider);
  // Watch currentUserIdProvider so this recreates when user changes
  final userId = ref.watch(currentUserIdProvider);
  return FinanceService(db, userId);
});

final gmailServiceProvider = Provider<GmailService>((ref) {
  final authService = ref.watch(googleAuthServiceProvider);
  return GmailService(authService);
});

/// Bridge to the Android notification listener: permission check and the
/// deep-link to the system screen that grants it.
final notificationListenerProvider =
    Provider<NotificationListenerService>((ref) {
  return const NotificationListenerService();
});

final bankSyncServiceProvider = Provider<BankSyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final gmail = ref.watch(gmailServiceProvider);
  final userId = ref.watch(currentUserIdProvider);
  return BankSyncService(db, gmail, userId);
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

/// Transaction-looking emails the parser couldn't read, for the inbox notice.
final skippedEmailsProvider = StreamProvider<List<PendingTransaction>>((ref) {
  return ref.watch(pendingTransactionServiceProvider).watchSkipped();
});

/// The existing transaction a flagged draft may duplicate, for the compare UI.
final duplicateSourceTxProvider =
    FutureProvider.family<db.Transaction?, String>((ref, txId) {
  return ref.watch(pendingTransactionServiceProvider).getTransactionById(txId);
});

// Watched, not Future-cached: rows also arrive from PocketBase sync (launch,
// pull-to-refresh, background task + resume), and a FutureProvider only
// re-ran on manual invalidation — the dashboard balance went stale after
// every sync while the transaction list beside it updated.
final accountsProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(financeServiceProvider).watchAccounts();
});

/// Rolling 12-month window — the unbounded full-table watch fed six
/// aggregators, and every emission re-mapped every row on the UI isolate.
/// Everything these aggregators compute looks at the last 12 months at most;
/// the stats year picker and the installment screens have their own scoped
/// variants ([periodTransactionsProvider], [installmentTransactionsProvider]).
final transactionsProvider = StreamProvider.family<List<Transaction>, String?>((
  ref,
  accountId,
) {
  final service = ref.watch(financeServiceProvider);
  final now = DateTime.now();
  return service.watchTransactions(
    accountId: accountId,
    startDate: DateTime(now.year, now.month - 11, 1),
  );
});

/// Stats periods can reach further back than the rolling window — this
/// family scopes the watch to exactly the selected year (month filtering
/// happens client-side, as before).
final periodTransactionsProvider =
    StreamProvider.family<List<Transaction>, StatsPeriod>((ref, period) {
  final service = ref.watch(financeServiceProvider);
  return service.watchTransactions(
    startDate: DateTime(period.year, 1, 1),
    endDate: DateTime(period.year, 12, 31, 23, 59, 59, 999),
  );
});

/// Linked payments + attach-a-payment candidates for the installment screens,
/// without watching (and re-mapping) the whole ledger.
final installmentTransactionsProvider =
    StreamProvider<List<Transaction>>((ref) {
  return ref.watch(financeServiceProvider).watchInstallmentRelevant();
});

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(financeServiceProvider).watchCategories();
});

final tagsProvider = StreamProvider<List<Tag>>((ref) {
  return ref.watch(financeServiceProvider).watchTags();
});

final budgetsProvider = StreamProvider<List<Budget>>((ref) {
  return ref.watch(financeServiceProvider).watchBudgets();
});

/// Live installment plans (all of them — active/settled is derived per plan).
final installmentsProvider = StreamProvider<List<Installment>>((ref) {
  return ref.watch(financeServiceProvider).watchInstallments();
});

/// Total still owed across the plans that aren't settled yet — the figure the
/// dashboard card and the screen header both show.
final installmentsOwedProvider = Provider<double>((ref) {
  final plans = ref.watch(installmentsProvider).value ?? const [];
  return plans.fold<double>(0, (s, p) => s + p.remainingAmount());
});

/// Local profile (username, currency, avatar, email). Single user — no cloud.
/// Kept as a FutureProvider so existing `.when`/`.value` callers keep working.
final userProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  ref.watch(authStateProvider);
  final persistence = ref.watch(persistenceServiceProvider);
  final auth = ref.watch(authServiceProvider);
  return {
    'username': persistence.getUsername(),
    'email': auth.email,
    'currency': persistence.getCurrency(),
    'avatar_url': persistence.getAvatarPath(),
  };
});

final currencyProvider = Provider<NumberFormat>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  // Watch the UI language so decimal separators follow it (1.234,56 vs 1,234.56).
  final language = ref.watch(localeSettingsProvider).language;
  return NumberFormat.simpleCurrency(
      name: profileAsync.value?['currency'] ?? 'EUR',
      locale: language == 'system' ? null : language);
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

/// UI language: 'system' follows the OS, otherwise a supported locale.
/// [resolve] maps to the `Locale` handed to MaterialApp (null = system).
class LocaleSettings {
  final String language; // 'system' | 'en' | 'it'
  const LocaleSettings(this.language);

  Locale? resolve() =>
      language == 'system' ? null : Locale(language);
}

class LocaleSettingsNotifier extends Notifier<LocaleSettings> {
  @override
  LocaleSettings build() =>
      LocaleSettings(ref.read(persistenceServiceProvider).getUiLanguage());

  Future<void> setLanguage(String v) async {
    state = LocaleSettings(v);
    await ref.read(persistenceServiceProvider).setUiLanguage(v);
  }
}

final localeSettingsProvider =
    NotifierProvider<LocaleSettingsNotifier, LocaleSettings>(
  LocaleSettingsNotifier.new,
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
        end: DateTime(now.year, 12, 31, 23, 59, 59, 999),
      ),
    );
  }

  void setDateRange(DateTimeRange? range) {
    // Filter ranges are calendar dates. Entries carry a time-of-day (bank
    // drafts, same-day manual entries), so an end at midnight would drop the
    // range's last day everywhere the range is applied.
    final normalized = range == null
        ? null
        : DateTimeRange(
            start: DateTime(
                range.start.year, range.start.month, range.start.day),
            end: DateTime(range.end.year, range.end.month, range.end.day, 23,
                59, 59, 999),
          );
    state = state.copyWith(dateRange: () => normalized);
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

/// SQL aggregate over the same filter as the ledger page query — the hero
/// totals used to re-filter the full 12-month watch in memory on every
/// emission. (income, expense, count) with the model's classifier: non-transfer
/// by sign, transfers excluded.
final filteredTotalsProvider = StreamProvider<FilteredTotals>((ref) {
  final filters = ref.watch(transactionFiltersProvider);
  final walletId = ref.watch(selectedWalletIdProvider);
  return ref.watch(financeServiceProvider).watchTotals(
        accountId: walletId,
        startDate: filters.dateRange?.start,
        endDate: filters.dateRange?.end,
        categories: filters.categories,
        tags: filters.tags,
      ).map((t) => FilteredTotals(income: t.$1, expense: t.$2, count: t.$3));
});

final categoryMapProvider = Provider<Map<String, Category>>((ref) {
  final categories = ref.watch(categoriesProvider).value ?? [];
  return {for (var c in categories) c.name: c};
});

final tagMapProvider = Provider<Map<String, Tag>>((ref) {
  final tags = ref.watch(tagsProvider).value ?? [];
  return {for (var t in tags) t.name: t};
});

final accountMapProvider = Provider<Map<String, Account>>((ref) {
  final accounts = ref.watch(accountsProvider).value ?? [];
  return {for (var a in accounts) a.id: a};
});

// Cache providers for colors and icons to avoid per-frame allocations.
// Both resolve through core/theme/ledger_style.dart rather than the stored
// colorHex/iconCode — see that file for why.
final categoryColorCacheProvider =
    Provider.family<Map<String, Color>, Brightness>((ref, brightness) {
  final categories = ref.watch(categoriesProvider).value ?? [];
  return buildCategoryColors(
    [for (final c in categories) (name: c.name, type: c.type)],
    brightness,
  );
});

final categoryIconCacheProvider = Provider<Map<String, IconData>>((ref) {
  final categories = ref.watch(categoriesProvider).value ?? [];
  return {
    for (var c in categories)
      c.name: categoryIcon(
        c.name,
        iconCode: c.iconCode,
        isIncome: c.type == 'income',
      )
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
            if (t.isIncome) {
              monthlyIncome += t.amount;
            } else if (t.isExpense) {
              monthlyExpenses += t.amount.abs();
            }
          }

          // Transfers excluded: a wallet-to-wallet move isn't income/expense,
          // and transfers are stored positive — summing them raw would show
          // self-transfers as a positive trend.
          final netFlow = transactions
              .where((t) => t.date.isAfter(last30Days) && t.type != 'transfer')
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
          t.isExpense) {
        categorySpending[t.category] =
            (categorySpending[t.category] ?? 0) + t.amount.abs();
      }
    }
    return categorySpending;
  });
});

class StatsData {
  final Map<String, double> categoryTotals;
  // Tag totals can sum above totalExpenses: a transaction may carry several
  // tags and counts once per tag.
  final Map<String, double> tagTotals;
  final Map<String, Map<String, double>> monthlyBreakdown;
  final double totalExpenses;

  StatsData({
    required this.categoryTotals,
    required this.tagTotals,
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
  final transactionsAsync = ref.watch(periodTransactionsProvider(period));

  return transactionsAsync.whenData((allTransactions) {
    final transactions = allTransactions.where((t) {
      if (t.date.year != period.year) return false;
      if (period.month != null && t.date.month != period.month) return false;
      return true;
    }).toList();
    final categoryTotals = <String, double>{};
    final tagTotals = <String, double>{};
    final monthlyBreakdown = <String, Map<String, double>>{};
    double totalExpenses = 0.0;

    final monthFmt = DateFormat('yyyy-MM');
    for (var t in transactions) {
      // Distribution & Total — transfers are neither income nor expense.
      if (t.isExpense) {
        categoryTotals[t.category] =
            (categoryTotals[t.category] ?? 0) + t.amount.abs();
        for (final tag in t.tags) {
          tagTotals[tag] = (tagTotals[tag] ?? 0) + t.amount.abs();
        }
        totalExpenses += t.amount.abs();
      }

      // Breakdown
      final monthKey = monthFmt.format(t.date);
      if (!monthlyBreakdown.containsKey(monthKey)) {
        monthlyBreakdown[monthKey] = {'earned': 0.0, 'spent': 0.0};
      }

      if (t.isIncome) {
        monthlyBreakdown[monthKey]!['earned'] =
            monthlyBreakdown[monthKey]!['earned']! + t.amount;
      } else if (t.isExpense) {
        monthlyBreakdown[monthKey]!['spent'] =
            monthlyBreakdown[monthKey]!['spent']! + t.amount.abs();
      }
    }

    return StatsData(
      categoryTotals: categoryTotals,
      tagTotals: tagTotals,
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

/// Per-bucket trend series, split by sign. Scoped stats modes plot one of
/// the two; "all" overlays both — a single abs() series would mash income
/// and expenses into "money moved", which says nothing.
class ChartSeries {
  final List<ChartDataPoint> expenses;
  final List<ChartDataPoint> income;

  ChartSeries({required this.expenses, required this.income});

  bool get isEmpty => expenses.isEmpty && income.isEmpty;
}

final chartsDataProvider = Provider<AsyncValue<ChartSeries>>((ref) {
  final granularity = ref.watch(chartGranularityProvider);
  final period = ref.watch(selectedStatsPeriodProvider);
  final transactionsAsync = ref.watch(periodTransactionsProvider(period));

  return transactionsAsync.whenData((allTransactions) {
    if (allTransactions.isEmpty) return ChartSeries(expenses: [], income: []);

    final transactions = allTransactions.where((t) {
      if (t.date.year != period.year) return false;
      if (period.month != null && t.date.month != period.month) return false;
      return true;
    }).toList();

    if (transactions.isEmpty) return ChartSeries(expenses: [], income: []);

    final expenseBuckets = <DateTime, double>{};
    final incomeBuckets = <DateTime, double>{};

    for (var t in transactions) {
      // Transfers are stored positive and would land in the income series.
      if (t.amount == 0 || t.type == 'transfer') continue;
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
      final buckets = t.amount < 0 ? expenseBuckets : incomeBuckets;
      buckets[key] = (buckets[key] ?? 0) + t.amount.abs();
    }

    List<ChartDataPoint> sorted(Map<DateTime, double> buckets) {
      final keys = buckets.keys.toList()..sort();
      return keys.map((k) => ChartDataPoint(k, buckets[k]!)).toList();
    }

    return ChartSeries(expenses: sorted(expenseBuckets), income: sorted(incomeBuckets));
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
    // Claim the in-flight flag synchronously: loadMore's guard reads it, and
    // without this two rapid calls both fetched from the same offset and
    // appended the same page twice.
    state = state.copyWith(isLoading: true);
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
