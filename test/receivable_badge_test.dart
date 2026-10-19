import 'package:budgetti/core/finance_math.dart' show Receivable;
import 'package:budgetti/features/transactions/widgets/receivable_badge.dart';
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

/// The one function that says what is owed on a shared expense, in both
/// languages. Mirror of the web's `ShareBadge` (`TxRow.tsx`): same words, same
/// half-cent thresholds.
void main() {
  // One formatter for both languages: these cases pin the words, not the locale's
  // currency layout.
  final eur = NumberFormat.simpleCurrency(name: 'EUR', locale: 'en_US');
  final en = lookupAppLocalizations(const Locale('en'));
  final it = lookupAppLocalizations(const Locale('it'));

  Receivable r(double owed, double received, double outstanding) =>
      (owed: owed, received: received, outstanding: outstanding);

  String badge(AppLocalizations l10n, Receivable x) =>
      receivableBadge(l10n, eur, x);

  group('the four states', () {
    test('still owed, nothing back yet', () {
      expect(badge(en, r(75, 0, 75)), '€75.00 to receive');
      expect(badge(it, r(75, 0, 75)), '€75.00 da ricevere');
    });

    test('still owed, something back', () {
      expect(badge(en, r(75, 25, 50)), '€75.00 to receive · €25.00 received');
      expect(
          badge(it, r(75, 25, 50)), '€75.00 da ricevere · €25.00 ricevuti');
    });

    test('settled', () {
      expect(badge(en, r(75, 75, 0)), 'settled');
      expect(badge(it, r(75, 75, 0)), 'saldata');
    });

    test('over-paid', () {
      expect(badge(en, r(75, 80, -5)), 'received €5.00 more');
      expect(badge(it, r(75, 80, -5)), 'ricevuti €5.00 in più');
    });
  });

  group('half-cent thresholds (as the web)', () {
    test('an outstanding of 0.004 either way is settled', () {
      expect(badge(en, r(75, 74.996, 0.004)), 'settled');
      expect(badge(en, r(75, 75.004, -0.004)), 'settled');
    });

    test('0.005 is still owed and -0.005 is over-paid', () {
      expect(badge(en, r(75, 74.995, 0.005)), startsWith('€75.00 to receive'));
      expect(badge(en, r(75, 75.005, -0.005)), startsWith('received'));
    });

    test('less than half a cent back does not count as received', () {
      expect(badge(en, r(75, 0.004, 74.996)), '€75.00 to receive');
    });
  });

  test('the two markers', () {
    expect(reimbursementMarker(en, true), 'pays back');
    expect(reimbursementMarker(en, false), 'pays back · expense missing');
    expect(reimbursementMarker(it, true), 'rimborso');
    expect(reimbursementMarker(it, false), 'rimborso · spesa mancante');
  });
}
