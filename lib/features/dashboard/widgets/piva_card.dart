import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/features/piva/piva_deadlines_section.dart' show nextPivaDeadline;
import 'package:budgetti/features/piva/piva_format.dart';
import 'package:budgetti/models/piva.dart' show PivaDeadline, deadlines;

// The short word of the card; [pivaFlatTax] ("Imposta sostitutiva") is the
// prospetto's line. Same in both languages, so a constant, not an ARB key.
const _pivaTax = 'Imposta';

/// Dashboard read for the partita IVA: this year's compensi and estimated net
/// on the left, what to set aside (tax, contributions) on the right. Same
/// bordered-strip language as `InstallmentsCard`, which it sits under. Hidden
/// until there is a profile — the persistent entry point is Settings → Data, so
/// the home never advertises an unused feature.
///
/// Below those, one line with the next deadline (see [nextPivaDeadline]); with
/// none, the card is exactly what it was without the line.
///
/// Always the current year: it watches `pivaViewProvider(now.year)`, not
/// `pivaYearProvider` (the year picked inside the screen).
class PivaCard extends ConsumerWidget {
  const PivaCard({super.key, this.now});

  /// The day of "today", for the year of the figures and for the next deadline;
  /// the clock when null, read once per build. A test pins it.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = now ?? DateTime.now();
    final view = ref.watch(pivaViewProvider(today.year)).value;
    // Loading, error and "no profile" all look the same: no card.
    if (view == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final currency = ref.watch(currencyProvider);
    final estimate = view.estimate;

    // The view exists only once the three sources have emitted, so none of these
    // is null here; the guard just keeps a bang out of it.
    final profile = ref.watch(pivaProfileProvider).value;
    final payments = ref.watch(pivaPaymentsProvider).value;
    final txns = ref.watch(pivaTransactionsProvider).value;
    // ponytail: derived again on every build of the card (a pass over the ledger
    // per year of the calendar); a family provider next to `pivaViewProvider` if
    // the dashboard ever rebuilds it often.
    final next = profile == null || payments == null || txns == null
        ? null
        : nextPivaDeadline(deadlines(profile, txns, payments, today), today);

    final border = BorderSide(color: scheme.outline.withValues(alpha: 0.12));
    final boxBorder = Border(bottom: border, left: border, right: border);

    final summary = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _KLabel('$pivaCompensi ${view.year}'.toUpperCase()),
              const SizedBox(height: 10),
              // A five-figure amount shrinks instead of wrapping.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  currency.format(view.total),
                  style: GoogleFonts.bricolageGrotesque(
                    color: scheme.onSurface,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.4,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.pivaCardNet(currency.format(estimate.net)),
                style: GoogleFonts.jetBrainsMono(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _KLabel(context.l10n.pivaCardSetAside.toUpperCase()),
              const SizedBox(height: 10),
              _SetAsideRow(_pivaTax, currency.format(estimate.tax)),
              _SetAsideRow(
                pivaContributions,
                currency.format(estimate.contributions),
              ),
            ],
          ),
        ),
      ],
    );

    return InkWell(
      onTap: () => context.push('/piva'),
      child: Container(
        decoration: BoxDecoration(border: boxBorder),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        // No next deadline: the tree is the one the card always had.
        child: next == null
            ? summary
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [summary, _NextLine(next, currency)],
              ),
      ),
    );
  }
}

/// "Next deadline" over one line, "label · day · amount", and a small tag when the
/// amount is still an estimate. Under a hairline, in the card's own kicker type.
/// The line wraps and ends in dots after two lines, never overflows; the tag drops
/// under it when there is no room beside it. Quiet colours: it is a reminder, not
/// an alarm.
class _NextLine extends StatelessWidget {
  const _NextLine(this.next, this.currency);
  final PivaDeadline next;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    // `nextPivaDeadline` only returns a row with a day.
    final day = DateFormat.yMMMd().format(next.dueDate!);
    final ink = GoogleFonts.jetBrainsMono(
      color: scheme.onSurface,
      fontSize: 11,
      fontWeight: FontWeight.w500,
    );
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outline.withValues(alpha: 0.12))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _KLabel(l10n.pivaDlNext),
          const SizedBox(height: 6),
          // Three runs of a Wrap, not one string: a long label is cut with dots on its
          // own, and the day and the amount (what the owner acts on) drop to the next
          // line whole instead of being the part that gets cut.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                next.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ink,
              ),
              Text('$day · ${currency.format(next.amount)}', style: ink),
              if (next.estimated) _Tag(l10n.pivaDlChipEstimate.toLowerCase()),
            ],
          ),
        ],
      ),
    );
  }
}

// ponytail: a copy of piva_deadlines_section.dart's private _Chip in its quiet
// ink, which that file keeps private; share it when a third place needs it.
class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: ink.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          text,
          style: GoogleFonts.jetBrainsMono(
            color: ink,
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

/// "IMPOSTA        €1,005.00": the label keeps its width, the amount takes
/// what is left and shrinks to fit it.
class _SetAsideRow extends StatelessWidget {
  const _SetAsideRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      // A Wrap, not a Row with a FittedBox: when label and amount no longer fit
      // side by side (large system font), the amount drops to its own line at full
      // size instead of shrinking next to its sibling's.
      child: SizedBox(
        width: double
            .infinity, // spaceBetween needs the full column to push the amount right
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            Text(
              label.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                color: scheme.onSurfaceVariant,
                fontSize: 11,
                letterSpacing: 0.6,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                color: scheme.onSurface,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ponytail: a copy of installments_card.dart's private _KLabel, which that file
// keeps private and this phase may not touch; share it when a third card needs it.
class _KLabel extends StatelessWidget {
  const _KLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: GoogleFonts.jetBrainsMono(
        color: scheme.onSurfaceVariant,
        fontSize: 11,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
