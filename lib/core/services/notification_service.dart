import 'package:budgetti/core/l10n.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  /// Invoked when the user taps a notification, with its payload (e.g. a
  /// pending-transaction id). Wired by the app once the router is ready.
  void Function(String payload)? onNotificationTap;

  Future<void> init() async {
    // Initialize timezone data
    tz.initializeTimeZones();
    // Set local timezone to Europe/Rome (Italy)
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Rome'));
      debugPrint('Timezone set to Europe/Rome');
    } catch (e) {
      debugPrint('Error setting timezone: $e');
      // Fallback to UTC if Europe/Rome is not available
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint("Notification tapped: ${response.payload}");
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          onNotificationTap?.call(payload);
        }
      },
    );
  }

  /// Payload of the notification that cold-launched the app, if any.
  Future<String?> getLaunchPayload() async {
    final details = await _notificationsPlugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      return details!.notificationResponse?.payload;
    }
    return null;
  }

  Future<bool> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final bool? result = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      final bool? granted = await androidImplementation?.requestNotificationsPermission();
      
      // Also request exact alarm permission for Android 13+ if using exact alarms
      await androidImplementation?.requestExactAlarmsPermission();
      
      return (granted ?? false);
    }
    return true;
  }

  Future<bool> isPermissionGranted() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      final bool? enabled = await androidImplementation
          ?.areNotificationsEnabled();
      return enabled ?? false;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      // For iOS, checkPermissions is more involved, usually handled via requestPermissions returning current status
      // Simple approach: we'll assume it's granted if we don't have a better check for now
      return true;
    }
    return true;
  }

  Future<void> showBudgetAlert({
    required int id,
    required String category,
    required double percentage,
  }) async {
    final l10n = await backgroundL10n();
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'budget_alerts',
      'Budget Alerts',
      channelDescription: 'Notifications for budget limits',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    String message = percentage >= 1.0
      ? l10n.notifBudgetReached(category)
      : l10n.notifBudgetUsedPct((percentage * 100).toStringAsFixed(0), category);

    await _notificationsPlugin.show(
      id,
      l10n.notifBudgetAlertTitle,
      message,
      details,
    );
  }

  Future<void> scheduleDailyReminder({
    required int id,
    required int hour,
    required int minute,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_reminders',
      'Daily Reminders',
      channelDescription: 'Daily reminders to track expenses',
          importance: Importance.max,
          priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final scheduledTime = _nextInstanceOfTime(hour, minute);
    debugPrint(
      '🔔 Scheduling daily reminder for $scheduledTime (hour: $hour, minute: $minute)',
    );

    final l10n = await backgroundL10n();
    await _notificationsPlugin.zonedSchedule(
      id,
      l10n.notifDailyTitle,
      l10n.notifDailyBody,
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    debugPrint('✅ Daily reminder scheduled successfully with ID: $id');
  }

  Future<void> showBackupNotification({
    required bool success,
    String? message,
    bool isProgress = false,
  }) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'backup_status',
      'Backup Status',
      channelDescription: 'Notifications for automatic backup status',
      importance: isProgress ? Importance.low : Importance.max,
      priority: isProgress ? Priority.low : Priority.high,
      showWhen: true,
      onlyAlertOnce: isProgress,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    final l10n = await backgroundL10n();
    final String title = isProgress
        ? l10n.notifBackupProgressTitle
        : (success ? l10n.notifBackupSuccessTitle : l10n.notifBackupFailedTitle);

    final String body = message ?? (isProgress
        ? l10n.notifBackupProgressBody
        : (success ? l10n.notifBackupSuccessBody : l10n.notifBackupErrorBody));

    await _notificationsPlugin.show(
      888, // Unique ID for backup notifications
      title,
      body,
      details,
    );
  }

  /// Fires a notification for a transaction parsed from a bank email.
  /// [pendingId] is carried as the payload so a tap can deep-link to the
  /// review inbox. [type] is income/expense/undecided.
  Future<void> showEmailTransactionNotification({
    required String pendingId,
    required double amount,
    required String description,
    required String type,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'email_transactions',
      'Bank Email Transactions',
      channelDescription: 'New transactions detected from bank emails',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final l10n = await backgroundL10n();
    final String title = switch (type) {
      'income' => l10n.notifEmailIncome,
      'undecided' => l10n.notifEmailReview,
      _ => l10n.notifEmailExpense,
    };

    final String formattedAmount =
        '${amount < 0 ? '-' : '+'}${amount.abs().toStringAsFixed(2).replaceAll('.', ',')} €';

    await _notificationsPlugin.show(
      pendingId.hashCode & 0x7fffffff,
      title,
      '$formattedAmount · $description',
      details,
      payload: pendingId,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    debugPrint('Current time: $now');
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
      debugPrint(
        'Scheduled time was in the past, moving to next day: $scheduledDate',
      );
    } else {
      debugPrint('Scheduled time for today: $scheduledDate');
    }
    return scheduledDate;
  }
}
