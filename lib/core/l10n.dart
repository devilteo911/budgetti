import 'dart:ui' show PlatformDispatcher;

import 'package:budgetti/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budgetti/core/services/persistence_service.dart';

/// Shorthand for localized strings: `context.l10n.transactionsTitle`.
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Localized strings outside the widget tree (background isolate
/// notifications, services). Resolves the persisted language directly —
/// no context, no delegates.
///
/// The setting is the app's own `ui_language`, and its default, 'system', is the
/// case that matters: the workmanager isolate has no locale of its own, so it
/// follows the language the UI last saw the phone report (`system_language`,
/// written on launch and on resume), then the platform's, then English.
Future<AppLocalizations> backgroundL10n() async {
  final prefs = await SharedPreferences.getInstance();
  // The UI isolate may have changed the language since this one read its prefs.
  await prefs.reload();
  final persistence = PersistenceService(prefs);
  final setting = persistence.getUiLanguage();
  final code = setting == 'system'
      ? persistence.getSystemLanguage() ??
          PlatformDispatcher.instance.locale.languageCode
      : setting;
  return lookupAppLocalizations(
      code == 'it' ? const Locale('it') : const Locale('en'));
}
