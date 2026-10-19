import 'package:budgetti/core/finance_math.dart' show Receivable;
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:flutter/material.dart';
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

/// The same three states in a form that always fits a tight line: "€50.00
/// due", "settled", "+€5.00" (the web's `sb-short`).
String receivableBadgeShort(
  AppLocalizations l10n,
  NumberFormat currency,
  Receivable r,
) {
  if (stillOwed(r)) return l10n.txDueShort(currency.format(r.outstanding));
  if (r.outstanding <= -0.005) {
    return l10n.txMoreShort(currency.format(-r.outstanding));
  }
  return l10n.txSettled;
}

/// The tag of an income that pays an expense back; [expenseThere] is whether
/// that expense is known.
String reimbursementMarker(AppLocalizations l10n, bool expenseThere) =>
    expenseThere ? l10n.txPaysBackMarker : l10n.txPaysBackMissing;

/// [reimbursementMarker] in the short form.
String reimbursementMarkerShort(AppLocalizations l10n, bool expenseThere) =>
    expenseThere ? l10n.txPaysBackShort : l10n.txPaysBackMissingShort;

/// What a ledger row says about its share: the text in full and short form,
/// and whether money is still owed (it is drawn in the income ink).
typedef ShareTag = ({String full, String short, bool owed});

/// The tag of [t] from [receivables] (`receivablesProvider`: every shared
/// expense, however old): the badge of a shared expense, the marker of an income
/// that pays one back, null for any other row. The one place a row is read, so
/// the three ledgers cannot disagree.
ShareTag? shareTag(
  AppLocalizations l10n,
  NumberFormat currency,
  Transaction t,
  Map<String, Receivable> receivables,
) {
  final r = receivables[t.id];
  if (r != null) {
    return (
      full: receivableBadge(l10n, currency, r),
      short: receivableBadgeShort(l10n, currency, r),
      owed: stillOwed(r),
    );
  }
  final target = t.reimbursesId;
  if (!t.isIncome || target == null || target.isEmpty) return null;
  // ponytail: "expense missing" is "the id is not a shared expense of the map",
  // so an expense whose share was lowered to 0 reads missing too, where the web
  // looks the id up in the whole ledger. Watching every row to name a rare state
  // is not worth it.
  final there = receivables.containsKey(target);
  return (
    full: reimbursementMarker(l10n, there),
    short: reimbursementMarkerShort(l10n, there),
    owed: false,
  );
}

/// One caption line: [lead] (the category), then [tag] after a "·" (kept in the
/// tag's text, so it is the first thing an ellipsis takes). The full text is the
/// default; when it would not fit the width on offer the short form takes its
/// place (the web's `sb-short`), and only then does anything ellipsize — each
/// part shrinking in proportion to its width, so a long category cannot push
/// what is owed off the row. A screen reader gets the full text either way.
class ShareTagLine extends StatelessWidget {
  const ShareTagLine({
    super.key,
    required this.lead,
    required this.tag,
    required this.style,
    required this.tagColor,
  });

  final String lead;
  final ShareTag tag;
  final TextStyle style;
  final Color tagColor;

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    double measure(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: base),
        maxLines: 1,
        textDirection: direction,
        textScaler: scaler,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    return Semantics(
      label: '$lead · ${tag.full}',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, box) {
          final leadWidth = measure(lead);
          final full = ' · ${tag.full}';
          // 1 px of slack: the shares below are rounded, and a text that fits by
          // a hair must not lose its last letter to an ellipsis.
          final text = leadWidth + measure(full) <= box.maxWidth - 1
              ? full
              : ' · ${tag.short}';
          // Milli-pixels, so the rounding of a share stays far below that px.
          int flex(double width) {
            final milli = (width * 1000).ceil();
            return milli < 1 ? 1 : milli;
          }
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                flex: flex(leadWidth),
                child: Text(
                  lead,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
              Flexible(
                flex: flex(measure(text)),
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style.copyWith(color: tagColor),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
