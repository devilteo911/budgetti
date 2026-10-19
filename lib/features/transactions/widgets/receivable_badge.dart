import 'package:budgetti/core/finance_math.dart' show Receivable;
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Whether money is still to come back. The web compares with a half-cent
/// threshold (`Math.abs(o) < 0.005`) where [Receivable] is already rounded to
/// the cent, and both clients must say the same word: this is the one place the
/// phone says it. Over-paid is `outstanding <= -0.005`, settled in between.
bool stillOwed(Receivable r) => r.outstanding >= 0.005;

/// What is left to receive on a shared expense, in words: "€75.00 to receive ·
/// €25.00 received", "settled" or "received €5.00 more". The one builder of
/// these texts — rows, the editor and the card all call it (mirror: the web's
/// `ShareBadge` in `TxRow.tsx`).
String receivableBadge(
  AppLocalizations l10n,
  NumberFormat currency,
  Receivable r,
) {
  if (stillOwed(r)) {
    return r.received < 0.005
        ? l10n.txToReceive(currency.format(r.owed))
        : l10n.txToReceiveReceived(
            currency.format(r.owed), currency.format(r.received));
  }
  if (r.outstanding <= -0.005) {
    return l10n.txReceivedMore(currency.format(-r.outstanding));
  }
  return l10n.txSettled;
}

/// The tag of an income that pays an expense back; [expenseThere] is whether
/// that expense is known.
String reimbursementMarker(AppLocalizations l10n, bool expenseThere) =>
    expenseThere ? l10n.txPaysBackMarker : l10n.txPaysBackMissing;
