import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/features/piva/piva_format.dart';

// The short word of the card; [pivaFlatTax] ("Imposta sostitutiva") is the
// prospetto's line. Same in both languages, so a constant, not an ARB key.
const _pivaTax = 'Imposta';

/// Dashboard read for the partita IVA: this year's compensi and estimated net
/// on the left, what to set aside (tax, contributions) on the right. Same
/// bordered-strip language as `InstallmentsCard`, which it sits under. Hidden
/// until there is a profile — the persistent entry point is Settings → Data, so
/// the home never advertises an unused feature.
///
/// Always the current year: it watches `pivaViewProvider(now.year)`, not
/// `pivaYearProvider` (the year picked inside the screen).
class PivaCard extends ConsumerWidget {
  const PivaCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(pivaViewProvider(DateTime.now().year)).value;
    // Loading, error and "no profile" all look the same: no card.
    if (view == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final currency = ref.watch(currencyProvider);
    final estimate = view.estimate;

    final border = BorderSide(color: scheme.outline.withValues(alpha: 0.12));
    final boxBorder = Border(bottom: border, left: border, right: border);

    return InkWell(
      onTap: () => context.push('/piva'),
      child: Container(
        decoration: BoxDecoration(border: boxBorder),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Row(
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
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: GoogleFonts.jetBrainsMono(
                  color: scheme.onSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
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
