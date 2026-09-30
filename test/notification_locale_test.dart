import 'package:budgetti/core/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notifications are posted from the workmanager isolate, which has no widget
/// tree and no locale: the app's own language setting has to be resolved from
/// the preferences. The default setting is 'system', which used to fall to
/// English there whatever the phone spoke.
void main() {
  Future<({String expense, String income})> titles(
      Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final l10n = await backgroundL10n();
    return (expense: l10n.notifEmailExpense, income: l10n.notifEmailIncome);
  }

  test('an explicit Italian setting speaks Italian', () async {
    final t = await titles({'ui_language': 'it'});

    expect((t.expense, t.income), ('Pagamento da rivedere', 'Accredito da rivedere'));
  });

  test('an explicit English setting speaks English, whatever the phone does',
      () async {
    final t = await titles({'ui_language': 'en', 'system_language': 'it'});

    expect((t.expense, t.income), ('Payment to review', 'Credit to review'));
  });

  test('the default "system" follows the language the app last saw the phone '
      'report', () async {
    final t = await titles({'ui_language': 'system', 'system_language': 'it'});

    expect((t.expense, t.income), ('Pagamento da rivedere', 'Accredito da rivedere'));
  });

  test('"system" is the setting when none was ever made', () async {
    final t = await titles({'system_language': 'it'});

    expect(t.expense, 'Pagamento da rivedere');
  });

  test('a phone language the app has no translation for gets English',
      () async {
    final t = await titles({'ui_language': 'system', 'system_language': 'de'});

    expect(t.expense, 'Payment to review');
  });

  test('nothing known at all is English', () async {
    final t = await titles({});

    expect(t.expense, 'Payment to review');
  });
}
