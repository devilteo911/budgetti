import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/services/piva_reminders.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

/// Every capture notification joins this group, so a busy morning collapses into
/// one stack in the shade instead of a column of separate cards.
/// The stack's summary is posted explicitly, see [bankDraftsSummaryDetails].
const bankDraftsGroupKey = 'bank_drafts';

/// How a captured bank movement is announced.
const bankDraftNotificationDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    'email_transactions',
    'Bank Email Transactions',
    channelDescription: 'New transactions detected from bank emails',
    importance: Importance.max,
    priority: Priority.high,
    groupKey: bankDraftsGroupKey,
  ),
  iOS: DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    threadIdentifier: bankDraftsGroupKey,
  ),
);

/// The summary of the stack of capture notifications. Left to itself Android
/// synthesises one with no intent from us, so tapping the COLLAPSED group only
/// brought the app back on its last screen and cleared every notification. We
/// post our own: same group and channel, and a payload that the tap handler
/// routes to the review inbox like an individual notification's.
const bankDraftsSummaryDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    'email_transactions',
    'Bank Email Transactions',
    channelDescription: 'New transactions detected from bank emails',
    importance: Importance.max,
    priority: Priority.high,
    groupKey: bankDraftsGroupKey,
    setAsGroupSummary: true,
  ),
  iOS: DarwinNotificationDetails(threadIdentifier: bankDraftsGroupKey),
);

/// Any non-empty payload opens the review inbox (see [routeNotificationTap]).
const bankDraftsSummaryPayload = 'bank_drafts';
const _bankDraftsSummaryId = 4001;

/// What a notification tap does: a non-empty payload goes to [onTap]. Pure, so
/// the summary's tap can be shown to take the same road as an individual one.
void routeNotificationTap(String? payload, void Function(String)? onTap) {
  if (payload != null && payload.isNotEmpty) onTap?.call(payload);
}

/// How a Partita IVA reminder is announced. [groupKey] is passed by the caller
/// because it is dynamic (one group per instant): reminders that fire together
/// share it, and the stack's summary is posted explicitly with [summary] set,
/// for the reason given at [bankDraftsSummaryDetails]. Alone, a reminder has no
/// group. [body] is shown whole when the notification is expanded: left to
/// itself the shade clips a plain body at two lines, and "(stima)" at the end of
/// an estimate is exactly what it cut.
NotificationDetails pivaReminderDetails({String? groupKey, bool summary = false, String? body}) =>
    NotificationDetails(
      android: AndroidNotificationDetails(
        'piva_deadlines',
        'Partita IVA deadlines',
        channelDescription: 'Reminders before Partita IVA tax and contributions deadlines',
        importance: Importance.max,
        priority: Priority.high,
        groupKey: groupKey,
        setAsGroupSummary: summary,
        styleInformation: body == null ? null : BigTextStyleInformation(body),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        threadIdentifier: groupKey,
      ),
    );

/// The instant a reminder fires: the year, month, day and hour of [wallClock]
/// (a wall-clock time of Italy, whatever zone its `DateTime` carries) read in
/// [location]. Built from the components rather than from an offset, so a clock
/// change between today and the day cannot move it off 9:00.
tz.TZDateTime pivaFireInstant(DateTime wallClock, tz.Location location) =>
    tz.TZDateTime(location, wallClock.year, wallClock.month, wallClock.day, wallClock.hour);

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
        routeNotificationTap(response.payload, onNotificationTap);
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
      // Inexact: a daily nudge doesn't need the minute, and exact alarms need
      // the SCHEDULE_EXACT_ALARM grant, whose denial made zonedSchedule throw.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
      bankDraftNotificationDetails,
      payload: pendingId,
    );
  }

  /// The one summary for the stack of capture notifications, with static text
  /// (no count: it is reposted under the same id as drafts come in). Call after
  /// the last [showEmailTransactionNotification] of a batch.
  Future<void> showBankDraftsSummary() async {
    final l10n = await backgroundL10n();
    await _notificationsPlugin.show(
      _bankDraftsSummaryId,
      l10n.notifBankDraftsSummary,
      null,
      bankDraftsSummaryDetails,
      payload: bankDraftsSummaryPayload,
    );
  }

  /// Brings the Partita IVA reminders scheduled on the device to [plan], and
  /// nothing else: of the pending notifications only the negative ids are ours
  /// (see [diffPivaReminders]), so one call with an empty plan clears them all
  /// and leaves every other notification alone. Only the differences are
  /// cancelled and scheduled, so calling it when nothing changed costs a read.
  ///
  /// Reminders that fire at the same instant are stacked in a group with a
  /// summary of their own, scheduled for the same instant with the same payload,
  /// so that tapping the closed stack opens the same screen. A reminder whose
  /// instant is not after now is left out: the plugin refuses a past date, and
  /// "in 7 days" shown late would be false.
  ///
  /// Inexact, as the daily reminder: the minute does not matter here, and an
  /// exact alarm needs the SCHEDULE_EXACT_ALARM grant that made `zonedSchedule`
  /// throw. It can still throw (the caller catches), and then the next call
  /// starts again from what is pending.
  Future<void> syncPivaReminders(List<PivaReminder> plan) async {
    final l10n = await backgroundL10n();
    final now = tz.TZDateTime.now(tz.local);

    final byTime = <DateTime, List<PivaReminder>>{};
    for (final r in plan) {
      (byTime[r.fireAt] ??= []).add(r);
    }
    final wanted = <int, ({PivaPending item, tz.TZDateTime at, NotificationDetails details})>{};
    for (final group in byTime.values) {
      final fireAt = group.first.fireAt;
      final at = pivaFireInstant(fireAt, tz.local);
      if (!at.isAfter(now)) continue;
      // ponytail: the diff compares id, title, body and payload, not the group, so
      // a reminder already scheduled keeps the group it was scheduled with when
      // a twin appears or goes away at its instant; put the group in the payload
      // if that stack ever looks wrong.
      final groupKey = group.length > 1 ? 'piva_${fireAt.toIso8601String()}' : null;
      for (final r in group) {
        wanted[r.id] = (
          item: (id: r.id, title: r.title, body: r.body, payload: r.payload),
          at: at,
          details: pivaReminderDetails(groupKey: groupKey, body: r.body),
        );
      }
      if (groupKey != null) {
        final id = pivaReminderId('summary|${fireAt.toIso8601String()}', 0);
        wanted[id] = (
          item: (id: id, title: l10n.pivaRemSummary, body: null, payload: group.first.payload),
          at: at,
          details: pivaReminderDetails(groupKey: groupKey, summary: true),
        );
      }
    }

    final pending = [
      for (final p in await _notificationsPlugin.pendingNotificationRequests())
        (id: p.id, title: p.title, body: p.body, payload: p.payload),
    ];
    final diff = diffPivaReminders(pending, [for (final w in wanted.values) w.item]);
    for (final id in diff.cancel) {
      await _notificationsPlugin.cancel(id);
    }
    for (final item in diff.schedule) {
      final w = wanted[item.id]!;
      await _notificationsPlugin.zonedSchedule(
        item.id,
        item.title,
        item.body,
        w.at,
        w.details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: item.payload,
      );
    }

    // What the on-device proof reads with `adb logcat`: the counts of this round
    // and every reminder the device now holds (not only the ones scheduled now).
    debugPrint(
      '🔔 PIVA reminders: pending=${pending.where((p) => p.id < 0).length} '
      'cancelled=${diff.cancel.length} scheduled=${diff.schedule.length} '
      '[${[for (final e in wanted.entries) '${e.key} @ ${e.value.at}'].join(', ')}]',
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
