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
  static const _pivaRemindersEnabledKey = 'piva_reminders_enabled';
  static const _autoBackupEnabledKey = 'auto_backup_enabled';
  static const _autoBackupTimeKey = 'auto_backup_time';
  static const _lastAutoBackupKey = 'last_auto_backup_timestamp';
  static const _lastAutoBackupErrorKey = 'last_auto_backup_error';
  static const _emailSyncEnabledKey = 'email_sync_enabled';
  static const _emailSyncWindowDaysKey = 'email_sync_window_days';
  static const _revolutSyncEnabledKey = 'revolut_sync_enabled';

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

  /// Partita IVA deadline reminders. On unless switched off; they only count
  /// under the general notifications switch and with a profile.
  bool getPivaRemindersEnabled() =>
      _prefs.getBool(_pivaRemindersEnabledKey) ?? true;
  Future<void> setPivaRemindersEnabled(bool enabled) =>
      _prefs.setBool(_pivaRemindersEnabledKey, enabled);

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

  // Revolut notification capture. Independent of the email sync: it needs no
  // Google account, only Android notification access.
  bool getRevolutSyncEnabled() =>
      _prefs.getBool(_revolutSyncEnabledKey) ?? false;
  Future<void> setRevolutSyncEnabled(bool enabled) =>
      _prefs.setBool(_revolutSyncEnabledKey, enabled);

  // Bank-capture source -> wallet the owner books it into, when the wallet's
  // name can't say so. Only written when the owner chose against the name match
  // (see PendingTransactionService.resolveAccountIdForSource); null clears it.
  static const _sourceWalletKeyPrefix = 'bank_source_wallet_';

  String? getSourceWalletId(String source) =>
      _prefs.getString('$_sourceWalletKeyPrefix$source');
  Future<void> setSourceWalletId(String source, String? id) => id == null
      ? _prefs.remove('$_sourceWalletKeyPrefix$source')
      : _prefs.setString('$_sourceWalletKeyPrefix$source', id);

  /// First line of why the last auto-backup failed; null after a success.
  String? getLastAutoBackupError() => _prefs.getString(_lastAutoBackupErrorKey);
  Future<void> setLastAutoBackupError(String? error) => error == null
      ? _prefs.remove(_lastAutoBackupErrorKey)
      : _prefs.setString(_lastAutoBackupErrorKey, error);

  /// The auto-backup runs in the workmanager isolate, whose prefs writes this
  /// isolate's cache never sees until it re-reads the file.
  Future<void> reload() => _prefs.reload();

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

  // UI language: 'system' | 'en' | 'it'
  static const _uiLanguageKey = 'ui_language';
  String getUiLanguage() => _prefs.getString(_uiLanguageKey) ?? 'system';
  Future<void> setUiLanguage(String l) => _prefs.setString(_uiLanguageKey, l);

  /// The language code the phone last reported to the UI isolate. The
  /// background isolate has no locale, so it reads this when the UI language is
  /// 'system'.
  static const _systemLanguageKey = 'system_language';
  String? getSystemLanguage() => _prefs.getString(_systemLanguageKey);
  Future<void> setSystemLanguage(String code) =>
      _prefs.setString(_systemLanguageKey, code);

  // PocketBase sync
  static const _pbServerUrlKey = 'pb_server_url';
  static const _pbLastSyncAtKey = 'pb_last_sync_at'; // millis since epoch
  static const _pbPullSyncAtKey = 'pb_pull_sync_at'; // millis since epoch
  static const _pbLastSyncSummaryKey = 'pb_last_sync_summary';

  /// Push cursor: the max local `lastUpdated` confirmed pushed. Drives which
  /// local rows a sync pushes.
  DateTime getLastSyncAt() =>
      DateTime.fromMillisecondsSinceEpoch(_prefs.getInt(_pbLastSyncAtKey) ?? 0);
  Future<void> setLastSyncAt(DateTime t) =>
      _prefs.setInt(_pbLastSyncAtKey, t.millisecondsSinceEpoch);

  /// Pull cursor: the max server-stamped `updated` confirmed pulled/pushed.
  /// Its own clock domain (PB's, not the device's) — that split is what keeps
  /// a fast device clock from permanently diverging the pull filter. Starts
  /// at epoch on upgrade, so the first new-code sync re-pulls everything once
  /// (conflict-checked, so it converges without dupes).
  DateTime getPullSyncAt() => DateTime.fromMillisecondsSinceEpoch(
      _prefs.getInt(_pbPullSyncAtKey) ?? 0);
  Future<void> setPullSyncAt(DateTime t) =>
      _prefs.setInt(_pbPullSyncAtKey, t.millisecondsSinceEpoch);

  /// One-shot: has this install re-pulled `piva_profile` from epoch since
  /// `declaredIncome` arrived (schema 20)? The server migration that adds the
  /// field does not touch `updated` on existing rows, so a phone whose pull
  /// cursor is already past the profile would never receive a figure the web
  /// declared until the row changed again. While this is false the sync pulls
  /// that one collection from epoch; only the sync sets it, once that pull ran.
  /// It is a pref and not an `onUpgrade` step because the database cannot reach
  /// the preferences; a fresh install pays one extra pull of a one-row collection.
  static const _pbPivaProfileRepulledKey = 'pb_piva_profile_repulled';
  bool getPivaProfileRepulled() =>
      _prefs.getBool(_pbPivaProfileRepulledKey) ?? false;
  Future<void> setPivaProfileRepulled(bool v) =>
      _prefs.setBool(_pbPivaProfileRepulledKey, v);

  String getServerUrl() => _prefs.getString(_pbServerUrlKey) ?? '';
  Future<void> setServerUrl(String url) =>
      _prefs.setString(_pbServerUrlKey, url);

  String getLastSyncSummary() =>
      _prefs.getString(_pbLastSyncSummaryKey) ?? 'Never synced';
  Future<void> setLastSyncSummary(String s) =>
      _prefs.setString(_pbLastSyncSummaryKey, s);

  /// PocketBase auth blob (token + record), persisted by AsyncAuthStore so a
  /// cold start rehydrates the session without re-prompting login.
  static const _pbAuthKey = 'pb_auth';
  String? getPbAuth() => _prefs.getString(_pbAuthKey);
  Future<void> setPbAuth(String? data) async {
    if (data == null || data.isEmpty) {
      await _prefs.remove(_pbAuthKey);
    } else {
      await _prefs.setString(_pbAuthKey, data);
    }
  }

  // Local profile (username, currency, avatar) — single user, no cloud needed.
  // Replaces the old cloud profiles table.
  static const _usernameKey = 'profile_username';
  static const _currencyKey = 'profile_currency';
  static const _avatarPathKey = 'profile_avatar_path';

  String getUsername() => _prefs.getString(_usernameKey) ?? '';
  Future<void> setUsername(String v) => _prefs.setString(_usernameKey, v);

  String getCurrency() => _prefs.getString(_currencyKey) ?? 'EUR';
  Future<void> setCurrency(String v) => _prefs.setString(_currencyKey, v);

  String? getAvatarPath() => _prefs.getString(_avatarPathKey);
  Future<void> setAvatarPath(String? v) async {
    if (v == null) {
      await _prefs.remove(_avatarPathKey);
    } else {
      await _prefs.setString(_avatarPathKey, v);
    }
  }

  /// Stable per-install user id used as the Drift `userId` filter before the
  /// first PocketBase login, and unified to the PB auth id on login.
  static const _localUserIdKey = 'local_user_id';
  String getLocalUserId() => _prefs.getString(_localUserIdKey) ?? '';
  Future<void> setLocalUserId(String v) => _prefs.setString(_localUserIdKey, v);
}

