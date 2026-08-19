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
Future<AppLocalizations> backgroundL10n() async {
  final prefs = await SharedPreferences.getInstance();
  final code = PersistenceService(prefs).getUiLanguage();
  return lookupAppLocalizations(
      code == 'it' ? const Locale('it') : const Locale('en'));
}
