import 'package:flutter/foundation.dart';
import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/core/services/notification_service.dart';
import 'package:budgetti/core/services/persistence_service.dart';
import 'package:budgetti/core/services/piva_reminders.dart';
import 'package:budgetti/models/piva.dart' show PivaPaymentData, PivaProfileData, deadlines;
import 'package:budgetti/models/transaction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:timezone/timezone.dart' as tz;
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

  static const int dailyReminderId = 999;
  static const String autoBackupTask = "auto_backup_task";
  static const String gmailSyncTask = "gmail_sync_task";
  static const String pbSyncTask = "pb_sync_task";

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
      await _notificationService.cancelNotification(dailyReminderId);
      return;
    }

    final timeStr = _persistenceService.getDailyReminderTime(); // "HH:mm"
    final bits = timeStr.split(":");
    if (bits.length != 2) return;

    final hour = int.tryParse(bits[0]) ?? 20;
    final minute = int.tryParse(bits[1]) ?? 0;

    // A reminder the OS refuses must not take the caller down with it: main()
    // awaits this before starting backup, bank sync and PocketBase sync, and
    // the Preferences toggles skip their setState after it.
    try {
      await _notificationService.scheduleDailyReminder(
        id: dailyReminderId,
        hour: hour,
        minute: minute,
      );
    } catch (e, s) {
      debugPrint('Daily reminder scheduling failed: $e\n$s');
    }
  }

  /// Puts the Partita IVA deadline reminders on the device for the given inputs:
  /// the plan of [planPivaReminders] when notifications, the Partita IVA
  /// reminders and a [profile] are all there, otherwise an empty plan, which
  /// clears them. The inputs are the ones the Partita IVA screen reads, so the
  /// amount in the notification is the amount on screen.
  ///
  /// Preferences are re-read first: this runs in the workmanager isolate too,
  /// whose cache can be old. "Now" is a plain wall clock of Italy — the clock of
  /// the reminders, wherever the phone is — and so a plain `DateTime`, not a
  /// `TZDateTime`: the engine reads its local components. [now] replaces it, in
  /// the same form, for tests.
  ///
  /// Like [updateDailyReminder] it never throws: what the OS refuses must not
  /// take the caller down.
  Future<void> applyPivaReminders(
    PivaProfileData? profile,
    List<PivaPaymentData> payments,
    List<Transaction> txns, {
    DateTime? now,
  }) async {
    try {
      await _persistenceService.reload();
      if (!_persistenceService.getNotificationsEnabled() ||
          !_persistenceService.getPivaRemindersEnabled() ||
          profile == null) {
        await _notificationService.syncPivaReminders(const []);
        return;
      }
      final today = now ?? _italyWallClock();
      final plan = planPivaReminders(
        deadlines(profile, txns, payments, today),
        today,
        l10n: await backgroundL10n(),
      );
      await _notificationService.syncPivaReminders(plan);
    } catch (e, s) {
      debugPrint('PIVA reminders failed: $e\n$s');
    }
  }

  /// The wall clock of Italy now, as a plain `DateTime` (needs the time zones
  /// initialised, which [NotificationService.init] does). Not read when a test
  /// passes its own.
  static DateTime _italyWallClock() {
    final rome = tz.TZDateTime.now(tz.local);
    return DateTime(rome.year, rome.month, rome.day, rome.hour, rome.minute);
  }

  /// [applyPivaReminders] for callers with no providers (the workmanager
  /// isolate): reads the three inputs from the database, then applies them.
  Future<void> updatePivaReminders({DateTime? now}) async {
    try {
      await applyPivaReminders(
        await _financeService.getPivaProfile(),
        await _financeService.getPivaPayments(),
        await _financeService.getPivaIncome(),
        now: now,
      );
    } catch (e, s) {
      debugPrint('PIVA reminders failed: $e\n$s');
    }
  }

  Future<void> updateAutoBackupSchedule() async {
    final enabled = _persistenceService.getAutoBackupEnabled();
    
    // Always cancel existing to be safe
    await Workmanager().cancelByUniqueName(autoBackupTask);
    
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
    
    debugPrint('📅 Auto-backup scheduled to run in ${initialDelay.inMinutes} minutes at $scheduleTime');

    await Workmanager().registerPeriodicTask(
      autoBackupTask,
      autoBackupTask,
      frequency: const Duration(days: 1),
      initialDelay: initialDelay,
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: false,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  /// Registers (or cancels) the periodic bank-capture poll: Widiba emails over
  /// Gmail and/or the Revolut notification buffer. One task serves both — 15
  /// minutes is the Android minimum for periodic work, and there's no reason to
  /// wake the device twice.
  ///
  /// The task keeps its original unique name so an already-registered schedule
  /// from a previous install still gets cancelled here.
  Future<void> updateBankSyncSchedule() async {
    await Workmanager().cancelByUniqueName(gmailSyncTask);

    final email = _persistenceService.getEmailSyncEnabled();
    final revolut = _persistenceService.getRevolutSyncEnabled();
    if (!email && !revolut) return;

    await Workmanager().registerPeriodicTask(
      gmailSyncTask,
      gmailSyncTask,
      frequency: const Duration(minutes: 15),
      initialDelay: const Duration(minutes: 15),
      constraints: Constraints(
        // Draining notifications is local work, so don't make it wait for a
        // connection; only the Gmail half actually needs one.
        networkType: revolut ? NetworkType.notRequired : NetworkType.connected,
        requiresBatteryNotLow: false,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );

    debugPrint('🏦 Bank sync scheduled every 15 minutes '
        '(email: $email, revolut: $revolut)');
  }

  /// Registers (or cancels) the daily PocketBase sync. Piggybacks the existing
  /// workmanager setup rather than adding a second scheduler. Skipped until a
  /// server URL is configured.
  Future<void> updatePocketBaseSyncSchedule() async {
    await Workmanager().cancelByUniqueName(pbSyncTask);

    if (_persistenceService.getServerUrl().isEmpty) return;

    await Workmanager().registerPeriodicTask(
      pbSyncTask,
      pbSyncTask,
      frequency: const Duration(days: 1),
      initialDelay: const Duration(hours: 6),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );

    debugPrint('☁️ PocketBase sync scheduled daily');
  }
}

final notificationLogicProvider = Provider<NotificationLogic>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  final financeService = ref.watch(financeServiceProvider);
  final persistenceService = ref.watch(persistenceServiceProvider);
  return NotificationLogic(notificationService, financeService, persistenceService);
});
