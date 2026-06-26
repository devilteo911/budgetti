import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/core/services/notification_service.dart';
import 'package:budgetti/core/services/persistence_service.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:workmanager/workmanager.dart';

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
  static const String AUTO_BACKUP_TASK = "auto_backup_task";
  static const String GMAIL_SYNC_TASK = "gmail_sync_task";

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
    final transactions = await _financeService.getTransactions();
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

  Future<void> updateAutoBackupSchedule() async {
    final enabled = _persistenceService.getAutoBackupEnabled();
    
    // Always cancel existing to be safe
    await Workmanager().cancelByUniqueName(AUTO_BACKUP_TASK);
    
    if (!enabled) return;

    final timeStr = _persistenceService.getAutoBackupTime();
    final bits = timeStr.split(":");
    if (bits.length != 2) return;

    final hour = int.tryParse(bits[0]) ?? 2;
    final minute = int.tryParse(bits[1]) ?? 0;

    final now = DateTime.now();
    // Use a canonical "today at HH:mm" for comparison
    var scheduleTime = DateTime(now.year, now.month, now.day, hour, minute);
    
    // If that time is already passed today, schedule for tomorrow
    if (scheduleTime.isBefore(now)) {
      scheduleTime = scheduleTime.add(const Duration(days: 1));
    }

    final initialDelay = scheduleTime.difference(now);
    
    print('📅 Auto-backup scheduled to run in ${initialDelay.inMinutes} minutes at $scheduleTime');

    await Workmanager().registerPeriodicTask(
      AUTO_BACKUP_TASK,
      AUTO_BACKUP_TASK,
      frequency: const Duration(days: 1),
      initialDelay: initialDelay,
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: false,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  /// Registers (or cancels) the periodic background poll of Widiba emails.
  /// 15 minutes is the Android minimum for periodic work.
  Future<void> updateGmailSyncSchedule() async {
    await Workmanager().cancelByUniqueName(GMAIL_SYNC_TASK);

    if (!_persistenceService.getEmailSyncEnabled()) return;

    await Workmanager().registerPeriodicTask(
      GMAIL_SYNC_TASK,
      GMAIL_SYNC_TASK,
      frequency: const Duration(minutes: 15),
      initialDelay: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );

    print('📧 Gmail sync scheduled every 15 minutes');
  }
}

final notificationLogicProvider = Provider<NotificationLogic>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  final financeService = ref.watch(financeServiceProvider);
  final persistenceService = ref.watch(persistenceServiceProvider);
  return NotificationLogic(notificationService, financeService, persistenceService);
});
