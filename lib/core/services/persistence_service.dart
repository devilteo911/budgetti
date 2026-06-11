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
  static const _autoBackupEnabledKey = 'auto_backup_enabled';
  static const _autoBackupTimeKey = 'auto_backup_time';
  static const _lastAutoBackupKey = 'last_auto_backup_timestamp';
  static const _emailSyncEnabledKey = 'email_sync_enabled';
  static const _emailSyncWindowDaysKey = 'email_sync_window_days';

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

  // Auto Backup Settings
  bool getAutoBackupEnabled() => _prefs.getBool(_autoBackupEnabledKey) ?? false;
  Future<void> setAutoBackupEnabled(bool enabled) =>
      _prefs.setBool(_autoBackupEnabledKey, enabled);

  String getAutoBackupTime() => _prefs.getString(_autoBackupTimeKey) ?? "02:00";
  Future<void> setAutoBackupTime(String time) =>
      _prefs.setString(_autoBackupTimeKey, time);

  // Bank Email Sync (Widiba) Settings
  bool getEmailSyncEnabled() => _prefs.getBool(_emailSyncEnabledKey) ?? false;
  Future<void> setEmailSyncEnabled(bool enabled) =>
      _prefs.setBool(_emailSyncEnabledKey, enabled);

  int getEmailSyncWindowDays() => _prefs.getInt(_emailSyncWindowDaysKey) ?? 7;
  Future<void> setEmailSyncWindowDays(int days) =>
      _prefs.setInt(_emailSyncWindowDaysKey, days);

  int getLastAutoBackupTimestamp() => _prefs.getInt(_lastAutoBackupKey) ?? 0;
  Future<void> setLastAutoBackupTimestamp(int timestamp) =>
      _prefs.setInt(_lastAutoBackupKey, timestamp);

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

  // Google Sheets Sync
  static const _sheetsSpreadsheetIdKey = 'sheets_spreadsheet_id';
  static const _sheetsSheetNameKey = 'sheets_sheet_name';
  static const _sheetsLastSyncKey = 'sheets_last_sync_timestamp';
  static const _defaultSpreadsheetId = '1K1ED_EIpNDsRtMPQz85Q7ZTyfIHsMUNgLqM5-dQgHSA';

  String getSheetsSpreadsheetId() =>
      _prefs.getString(_sheetsSpreadsheetIdKey) ?? _defaultSpreadsheetId;
  Future<void> setSheetsSpreadsheetId(String id) =>
      _prefs.setString(_sheetsSpreadsheetIdKey, id);

  String getSheetsSheetName() =>
      _prefs.getString(_sheetsSheetNameKey) ?? 'Spese';
  Future<void> setSheetsSheetName(String name) =>
      _prefs.setString(_sheetsSheetNameKey, name);

  int getSheetsLastSyncTimestamp() =>
      _prefs.getInt(_sheetsLastSyncKey) ?? 0;
  Future<void> setSheetsLastSyncTimestamp(int timestamp) =>
      _prefs.setInt(_sheetsLastSyncKey, timestamp);

  // Last sync hashes for 3-way sync
  static const _lastSyncHashesKey = 'sheets_last_sync_hashes';

  String? getLastSyncHashesJson() => _prefs.getString(_lastSyncHashesKey);
  Future<void> setLastSyncHashesJson(String json) =>
      _prefs.setString(_lastSyncHashesKey, json);

  // Custom Backup Folder
  static const _customBackupPathKey = 'custom_backup_path';

  String? getCustomBackupPath() => _prefs.getString(_customBackupPathKey);

  Future<void> setCustomBackupPath(String? path) async {
    if (path == null) {
      await _prefs.remove(_customBackupPathKey);
    } else {
      await _prefs.setString(_customBackupPathKey, path);
    }
  }

  // Appearance / Theme
  static const _themePaletteKey = 'theme_palette';
  static const _themeBrightnessKey = 'theme_brightness'; // system|light|dark
  static const _themeAmoledKey = 'theme_amoled';
  static const _themeGlassKey = 'theme_glass';

  String getThemePalette() =>
      _prefs.getString(_themePaletteKey) ?? 'mint';
  Future<void> setThemePalette(String p) =>
      _prefs.setString(_themePaletteKey, p);

  String getThemeBrightness() =>
      _prefs.getString(_themeBrightnessKey) ?? 'dark';
  Future<void> setThemeBrightness(String b) =>
      _prefs.setString(_themeBrightnessKey, b);

  bool getThemeAmoled() => _prefs.getBool(_themeAmoledKey) ?? true;
  Future<void> setThemeAmoled(bool v) => _prefs.setBool(_themeAmoledKey, v);

  bool getThemeGlass() => _prefs.getBool(_themeGlassKey) ?? false;
  Future<void> setThemeGlass(bool v) => _prefs.setBool(_themeGlassKey, v);
}

