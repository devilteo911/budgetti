import 'package:budgetti/l10n/app_localizations_en.dart';
import 'package:budgetti/l10n/app_localizations_it.dart';
import 'package:flutter_test/flutter_test.dart';

/// A captured bank movement is a draft awaiting the owner's review, not a
/// booked transaction: its notification must not say "recorded".
void main() {
  test('titles say the draft is waiting for review (it)', () {
    final it = AppLocalizationsIt();

    expect(it.notifEmailExpense, 'Pagamento da rivedere');
    expect(it.notifEmailIncome, 'Accredito da rivedere');
    expect(it.notifEmailReview, 'Bonifico da rivedere');
  });

  test('titles say the draft is waiting for review (en)', () {
    final en = AppLocalizationsEn();

    expect(en.notifEmailExpense, 'Payment to review');
    expect(en.notifEmailIncome, 'Credit to review');
    expect(en.notifEmailReview, 'Transfer to review');
  });
}
