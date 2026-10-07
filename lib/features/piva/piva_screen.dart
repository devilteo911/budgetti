import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/features/piva/piva_format.dart';
import 'package:budgetti/features/piva/piva_income_section.dart';
import 'package:budgetti/features/piva/piva_view.dart';
import 'package:budgetti/features/stats/widgets/section_label.dart';
import 'package:budgetti/models/piva.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Partita IVA, read-only: the profile, the compensi of the chosen year against
/// the year before, and the estimate of its tax and contributions. The figures
/// are the web's, to the cent — they come out of the same engine
/// (`models/piva.dart`), derived once per change of the data in
/// [pivaViewProvider].
class PivaScreen extends ConsumerWidget {
  const PivaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final viewAsync = ref.watch(pivaViewProvider(ref.watch(pivaYearProvider)));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.pivaTitle,
          style: GoogleFonts.jetBrainsMono(
            color: scheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: viewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text('$err', style: TextStyle(color: scheme.error)),
          ),
        ),
        data: (view) {
          final profile = ref.watch(pivaProfileProvider).value;
          if (view == null || profile == null) {
            // #19: pass here the opening of `PivaProfileSheet` (and change the
            // button's text); until then there is no button, and the hint sends
            // the user to the web.
            return const _EmptyState(onSetup: null);
          }
          return ListView(
            padding: EdgeInsets.only(bottom: MediaQuery.viewPaddingOf(context).bottom + 32),
            children: [
              // #19: pass here the opening of `PivaProfileSheet` in edit mode.
              _ProfileSummary(profile: profile, onEdit: null),
              PivaIncomeSection(profile: profile, view: view),
              _Estimate(profile: profile, view: view, currency: ref.watch(currencyProvider)),
              // #20: PivaDeadlinesSection goes here, below the prospetto.
            ],
          );
        },
      ),
    );
  }
}

/// No profile yet. Same shape as the installments' empty state; the button
/// exists only when [onSetup] does.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onSetup});

  final VoidCallback? onSetup;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '—',
            style: GoogleFonts.jetBrainsMono(
              color: scheme.onSurfaceVariant,
              fontSize: 72,
              fontWeight: FontWeight.w300,
              height: 0.8,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.pivaEmptyKicker,
            style: GoogleFonts.jetBrainsMono(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.pivaEmptyHint,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
          if (onSetup != null) ...[
            const SizedBox(height: 20),
            // ponytail: borrows pivaTitle; #19 gives the button its own key.
            OutlinedButton(onPressed: onSetup, child: Text(context.l10n.pivaTitle)),
          ],
        ],
      ),
    );
  }
}

/// What the profile says, in one block: the ATECO code and coefficient as the
/// title, the fund, the opening year and the income categories under it.
/// (`web/src/components/Piva.tsx`)
class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.profile, required this.onEdit});

  final PivaProfileData profile;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A fund type the table does not know has no name to show.
    final fund = pivaFundLabels[profile.fundType];
    final note = [
      if (fund != null) fund + (profile.fundName.isEmpty ? '' : ' · ${profile.fundName}'),
      context.l10n.pivaSince('${profile.startYear}'),
      profile.incomeCategories.join(', '),
    ].where((s) => s.isNotEmpty).join(' · ');

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, onEdit == null ? 20 : 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.pivaProfileLabel,
                  style: GoogleFonts.jetBrainsMono(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  // U+00A0: on a narrow phone "67%" must not wrap alone under the title.
                  '$pivaAteco ${profile.atecoCode} · $pivaCoefficient\u00A0${pivaNumber(profile.coefficient)}%',
                  style: GoogleFonts.bricolageGrotesque(
                    color: scheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  note,
                  style: GoogleFonts.jetBrainsMono(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                    letterSpacing: 0.3,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          // #19: the tooltip needs its own key.
          if (onEdit != null)
            IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
        ],
      ),
    );
  }
}

/// The prospetto of the year: from the compensi down to the net, line by line
/// (`web/src/components/PivaForecast.tsx`, the "Estimate" card). Nothing is
/// computed here — every figure is [PivaYearView.estimate].
class _Estimate extends StatelessWidget {
  const _Estimate({required this.profile, required this.view, required this.currency});

  final PivaProfileData profile;
  final PivaYearView view;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final e = view.estimate;
    final fund = profile.fundName.isNotEmpty ? profile.fundName : pivaFundLabels[profile.fundType];
    final rule = Divider(height: 1, thickness: 1, color: scheme.outline.withValues(alpha: 0.12));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(text: l10n.pivaEstimateLabel('${view.year}')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                PivaLine(label: '$pivaCompensi ${view.year}', value: currency.format(e.revenue)),
                PivaLine(
                  label: '$pivaGrossIncome ${pivaNumber(profile.coefficient)}%',
                  value: currency.format(e.grossIncome),
                ),
                PivaLine(
                  label: pivaContributionsPaid,
                  // U+2212, the real minus, as in the dashboard's compact amounts.
                  value: '${e.contributionsPaid > 0 ? '−' : ''}${currency.format(e.contributionsPaid)}',
                ),
                PivaLine(label: pivaTaxable, value: currency.format(e.taxable)),
                PivaLine(
                  label: '$pivaFlatTax · ${pivaNumber(view.ratePct)}%',
                  value: currency.format(e.tax),
                ),
                PivaLine(
                  label: fund == null ? pivaContributions : '$pivaContributions · $fund',
                  value: currency.format(e.contributions),
                ),
                rule,
                PivaLine(label: l10n.pivaNet, value: currency.format(e.net), bold: true),
                if (view.carved) ...[
                  rule,
                  PivaLine(
                    label: l10n.pivaReconIntegrativo,
                    note: l10n.pivaPassThroughNote,
                    value: currency.format(view.toRemit),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Text(
            l10n.pivaEstimateFoot,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12, height: 1.4),
          ),
        ),
      ],
    );
  }
}
