import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize sharedPreferencesProvider in main.dart');
});

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
}

final persistenceServiceProvider = Provider<PersistenceService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PersistenceService(prefs);
});
