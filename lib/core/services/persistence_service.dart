import 'package:shared_preferences/shared_preferences.dart';


class PersistenceService {
  final SharedPreferences _prefs;

  PersistenceService(this._prefs);

  static const _balanceVisibilityKey = 'balance_visibility';

  bool getBalanceVisibility() {
    return _prefs.getBool(_balanceVisibilityKey) ?? true;
  }

  Future<void> setBalanceVisibility(bool visible) async {
    await _prefs.setBool(_balanceVisibilityKey, visible);
  }

  // Notification Settings
  static const _notificationsEnabledKey = 'notifications_enabled';
  static const _budgetAlertsEnabledKey = 'budget_alerts_enabled';
  static const _dailyReminderEnabledKey = 'daily_reminder_enabled';
  static const _dailyReminderTimeKey = 'daily_reminder_time';

  bool getNotificationsEnabled() =>
      _prefs.getBool(_notificationsEnabledKey) ?? true;
  Future<void> setNotificationsEnabled(bool enabled) =>
      _prefs.setBool(_notificationsEnabledKey, enabled);

  bool getBudgetAlertsEnabled() =>
      _prefs.getBool(_budgetAlertsEnabledKey) ?? true;
  Future<void> setBudgetAlertsEnabled(bool enabled) =>
      _prefs.setBool(_budgetAlertsEnabledKey, enabled);

  bool getDailyReminderEnabled() =>
      _prefs.getBool(_dailyReminderEnabledKey) ?? false;
  Future<void> setDailyReminderEnabled(bool enabled) =>
      _prefs.setBool(_dailyReminderEnabledKey, enabled);

  String getDailyReminderTime() =>
      _prefs.getString(_dailyReminderTimeKey) ?? "20:00";
  Future<void> setDailyReminderTime(String time) =>
      _prefs.setString(_dailyReminderTimeKey, time);

  // Budget Alert Flags
  String _getBudgetAlertKey(String category, int threshold, DateTime date) {
    return 'budget_alert_${threshold}_${category}_${date.year}_${date.month}';
  }

  bool hasNotifiedBudget(String category, int threshold, DateTime date) {
    return _prefs.getBool(_getBudgetAlertKey(category, threshold, date)) ??
        false;
  }

  Future<void> setNotifiedBudget(
    String category,
    int threshold,
    DateTime date,
  ) async {
    await _prefs.setBool(_getBudgetAlertKey(category, threshold, date), true);
  }
}

