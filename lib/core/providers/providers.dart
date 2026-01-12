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
import 'package:budgetti/core/services/sync_service.dart';
import 'package:budgetti/core/services/backup_service.dart';
import 'package:budgetti/core/services/notification_service.dart';
import 'package:budgetti/core/services/google_drive_service.dart';
import 'package:budgetti/core/services/ocr_service.dart';
import 'package:budgetti/core/services/gocardless_service.dart';
import 'package:budgetti/core/services/bank_sync_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final persistenceServiceProvider = Provider<PersistenceService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PersistenceService(prefs);
});

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncService(db);
});

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

final gocardlessServiceProvider = Provider<GocardlessService>((ref) {
  final persistenceService = ref.watch(persistenceServiceProvider);
  return GocardlessService(persistenceService);
});

final bankSyncServiceProvider = Provider<BankSyncService>((ref) {
  final gocardless = ref.watch(gocardlessServiceProvider);
  final db = ref.watch(databaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  return BankSyncService(gocardless, db, userId);
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
    return await service.getTransactions(accountId);
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
  TransactionFilterState build() => TransactionFilterState();

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

final filteredTransactionsProvider =
    FutureProvider.family<List<Transaction>, String?>((ref, accountId) async {
  final transactions = await ref.watch(transactionsProvider(accountId).future);
  final filters = ref.watch(transactionFiltersProvider);

  if (filters.isEmpty) return transactions;

  return transactions.where((t) {
    // Date Filter
    if (filters.dateRange != null) {
      if (t.date.isBefore(filters.dateRange!.start) ||
          t.date.isAfter(filters.dateRange!.end.add(const Duration(days: 1)))) {
        return false;
      }
    }

    // Category Filter
    if (filters.categories.isNotEmpty &&
        !filters.categories.contains(t.category)) {
      return false;
    }

    // Tag Filter
    if (filters.tags.isNotEmpty) {
      if (!t.tags.any((tag) => filters.tags.contains(tag))) {
        return false;
      }
    }

    return true;
  }).toList();
});

class SelectedWalletId extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? id) => state = id;
}

final selectedWalletIdProvider = NotifierProvider<SelectedWalletId, String?>(SelectedWalletId.new);
