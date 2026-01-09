import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/core/services/notification_service.dart';
import 'package:budgetti/core/services/persistence_service.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgetti/core/providers/providers.dart';

class NotificationLogic {
  final NotificationService _notificationService;
  final FinanceService _financeService;
  final PersistenceService _persistenceService;

  NotificationLogic(
    this._notificationService,
    this._financeService,
    this._persistenceService,
  );

  static const int DAILY_REMINDER_ID = 999;

  Future<void> checkBudgetAlerts(Transaction newTransaction) async {
    if (!_persistenceService.getNotificationsEnabled() ||
        !_persistenceService.getBudgetAlertsEnabled()) {
      return;
    }

    final categoryName = newTransaction.category;
    final now = DateTime.now();
    
    // 1. Get all budgets
    final budgets = await _financeService.getBudgets();
    final budget = budgets.where((b) => b.category == categoryName).firstOrNull;

    if (budget == null || budget.limit <= 0) return;

    // 2. Calculate current month spending for this category
    final transactions = await _financeService.getTransactions(null);
    final currentMonthSpending = transactions
        .where((t) =>
            t.category == categoryName &&
            t.date.year == now.year &&
            t.date.month == now.month &&
            t.amount < 0)
        .fold(0.0, (sum, t) => sum + t.amount.abs());

    final utilization = currentMonthSpending / budget.limit;

    // 3. Check thresholds (100% and 80%)
    if (utilization >= 1.0) {
      if (!_persistenceService.hasNotifiedBudget(categoryName, 100, now)) {
        await _notificationService.showBudgetAlert(
          id: categoryName.hashCode + 100,
          category: categoryName,
          percentage: 1.0,
        );
        await _persistenceService.setNotifiedBudget(categoryName, 100, now);
      }
    } else if (utilization >= 0.8) {
      if (!_persistenceService.hasNotifiedBudget(categoryName, 80, now)) {
        await _notificationService.showBudgetAlert(
          id: categoryName.hashCode + 80,
          category: categoryName,
          percentage: utilization,
        );
        await _persistenceService.setNotifiedBudget(categoryName, 80, now);
      }
    }
  }

  Future<void> updateDailyReminder() async {
    if (!_persistenceService.getNotificationsEnabled() ||
        !_persistenceService.getDailyReminderEnabled()) {
      await _notificationService.cancelNotification(DAILY_REMINDER_ID);
      return;
    }

    final timeStr = _persistenceService.getDailyReminderTime(); // "HH:mm"
    final bits = timeStr.split(":");
    if (bits.length != 2) return;

    final hour = int.tryParse(bits[0]) ?? 20;
    final minute = int.tryParse(bits[1]) ?? 0;

    await _notificationService.scheduleDailyReminder(
      id: DAILY_REMINDER_ID,
      hour: hour,
      minute: minute,
    );
  }

  // Test method for debugging - sends immediate notification
  Future<void> sendTestNotification() async {
    await _notificationService.showTestNotification();
  }
}

final notificationLogicProvider = Provider<NotificationLogic>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  final financeService = ref.watch(financeServiceProvider);
  final persistenceService = ref.watch(persistenceServiceProvider);
  return NotificationLogic(notificationService, financeService, persistenceService);
});
