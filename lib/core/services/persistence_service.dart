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

  // OCR Settings
  static const _ocrEngineKey = 'ocr_engine';

  // 'google_mlkit' or 'mobile_ocr'
  String getOcrEngine() => _prefs.getString(_ocrEngineKey) ?? 'google_mlkit';

  Future<void> setOcrEngine(String engine) =>
      _prefs.setString(_ocrEngineKey, engine);

  // GoCardless Bank Sync Settings
  static const _gocardlessAccessTokenKey = 'gocardless_access_token';
  static const _gocardlessRefreshTokenKey = 'gocardless_refresh_token';
  static const _gocardlessSecretIdKey = 'gocardless_secret_id';
  static const _gocardlessSecretKeyKey = 'gocardless_secret_key';
  static const _syncDaysBackKey = 'sync_days_back';
  static const _autoSyncEnabledKey = 'auto_sync_enabled';

  String? getGocardlessAccessToken() =>
      _prefs.getString(_gocardlessAccessTokenKey);
  Future<void> setGocardlessAccessToken(String token) =>
      _prefs.setString(_gocardlessAccessTokenKey, token);

  String? getGocardlessRefreshToken() =>
      _prefs.getString(_gocardlessRefreshTokenKey);
  Future<void> setGocardlessRefreshToken(String token) =>
      _prefs.setString(_gocardlessRefreshTokenKey, token);

  String? getGocardlessSecretId() => _prefs.getString(_gocardlessSecretIdKey);
  Future<void> setGocardlessSecretId(String id) =>
      _prefs.setString(_gocardlessSecretIdKey, id);

  String? getGocardlessSecretKey() => _prefs.getString(_gocardlessSecretKeyKey);
  Future<void> setGocardlessSecretKey(String key) =>
      _prefs.setString(_gocardlessSecretKeyKey, key);

  int getSyncDaysBack() => _prefs.getInt(_syncDaysBackKey) ?? 90;
  Future<void> setSyncDaysBack(int days) =>
      _prefs.setInt(_syncDaysBackKey, days);

  bool getAutoSyncEnabled() => _prefs.getBool(_autoSyncEnabledKey) ?? false;
  Future<void> setAutoSyncEnabled(bool enabled) =>
      _prefs.setBool(_autoSyncEnabledKey, enabled);

  // Clear all GoCardless settings
  Future<void> clearGocardlessSettings() async {
    await _prefs.remove(_gocardlessAccessTokenKey);
    await _prefs.remove(_gocardlessRefreshTokenKey);
    await _prefs.remove(_gocardlessSecretIdKey);
    await _prefs.remove(_gocardlessSecretKeyKey);
  }
}

