import 'package:budgetti/core/error_text.dart';
import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/widgets/app_sheet.dart';
import 'package:budgetti/features/piva/piva_deadlines_section.dart';
import 'package:budgetti/features/piva/piva_format.dart';
import 'package:budgetti/features/piva/piva_income_section.dart';
import 'package:budgetti/features/piva/piva_profile_sheet.dart';
import 'package:budgetti/features/piva/piva_view.dart';
import 'package:budgetti/features/stats/widgets/section_label.dart';
import 'package:budgetti/models/piva.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Partita IVA: the profile (set up and edited in [PivaProfileSheet]), the
/// compensi of the chosen year against the year before, the estimate of its tax
/// and contributions, and the deadlines ([PivaDeadlinesSection]). The figures are
/// the web's, to the cent — they come out of the same engine (`models/piva.dart`),
/// derived once per change of the data in [pivaViewProvider].
class PivaScreen extends ConsumerStatefulWidget {
  const PivaScreen({super.key, this.openDeadlines = false});

  /// Scroll the deadlines into view, once, as soon as the data is on screen: set
  /// when the screen is opened by a reminder's tap (`/piva?section=deadlines`).
  final bool openDeadlines;

  @override
  ConsumerState<PivaScreen> createState() => _PivaScreenState();
}

class _PivaScreenState extends ConsumerState<PivaScreen> {
  final _scroll = ScrollController();
  final _deadlinesKey = GlobalKey();

  /// The scroll is done (or given up) once per screen: the streams re-emit and
  /// rebuild it, and the user must not be pulled back down every time.
  bool _scrolled = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Brings the deadlines to the top of the list. The list is lazy, so the section
  /// has no context until the scroll gets near it: jump to the foot to have it
  /// built, then align it on the next frame. [tries] bounds the jumps.
  void _revealDeadlines(int tries) {
    if (!mounted || !_scroll.hasClients) return;
    final target = _deadlinesKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(target, alignment: 0);
      return;
    }
    if (tries == 0) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealDeadlines(tries - 1));
  }

  void _openProfileSheet(BuildContext context, {PivaProfileData? existing, bool focusDeclared = false}) {
    showAppSheet(
      context,
      isScrollControlled: true,
      builder: (_) => PivaProfileSheet(existing: existing, focusDeclared: focusDeclared),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          // The deadlines' "today": the year view has no clock of its own to share
          // (the provider reads one per derivation), so the screen reads one per build.
          final now = DateTime.now();
          final profile = ref.watch(pivaProfileProvider).value;
          if (view == null || profile == null) {
            return _EmptyState(onSetup: () => _openProfileSheet(context));
          }
          if (widget.openDeadlines && !_scrolled) {
            _scrolled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => _revealDeadlines(3));
          }
          // Only once the ledger has answered: a start still loading is not "no
          // start". `hasValue` is true for a `null` start too (the empty ledger).
          final ledgerStart = ref.watch(pivaLedgerStartProvider);
          final askYear = ledgerStart.hasValue
              ? askDeclaredIncome(profile, ledgerStart.value, now)
              : null;
          return ListView(
            controller: _scroll,
            padding: EdgeInsets.only(bottom: MediaQuery.viewPaddingOf(context).bottom + 32),
            children: [
              if (askYear != null)
                _DeclaredBanner(
                  profile: profile,
                  year: askYear,
                  ledgerStart: ledgerStart.value,
                  onEnter: () => _openProfileSheet(context, existing: profile, focusDeclared: true),
                ),
              _ProfileSummary(
                profile: profile,
                onEdit: () => _openProfileSheet(context, existing: profile),
              ),
              PivaIncomeSection(profile: profile, view: view),
              _Estimate(profile: profile, view: view, currency: ref.watch(currencyProvider)),
              // The view is data, so all three sources have emitted: `value` is the list.
              PivaDeadlinesSection(
                key: _deadlinesKey,
                profile: profile,
                payments: ref.watch(pivaPaymentsProvider).value ?? const [],
                txns: ref.watch(pivaTransactionsProvider).value ?? const [],
                now: now,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// No profile yet. Same shape as the installments' empty state: a kicker, one
/// line on what the section gives, and the button that opens the profile sheet.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onSetup});

  final VoidCallback onSetup;

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
          const SizedBox(height: 20),
          OutlinedButton(onPressed: onSetup, child: Text(context.l10n.pivaProfileSetUp)),
        ],
      ),
    );
  }
}

/// The ledger does not reach back to 1 January of [year] (the previous one), and
/// the estimates of this year rest on what was collected in it: ask for the gross
/// ("Enter it" opens the profile sheet on that field), or let the ledger's figure
/// stand ("Derive it from the ledger"). Either answer lands in the profile's
/// `declaredIncome`, and the banner goes by itself once the key exists
/// (`askDeclaredIncome`). (`DeclaredBanner` in `web/src/components/Piva.tsx`)
class _DeclaredBanner extends ConsumerStatefulWidget {
  const _DeclaredBanner({
    required this.profile,
    required this.year,
    required this.ledgerStart,
    required this.onEnter,
  });

  final PivaProfileData profile;
  final int year;

  /// The ledger's first transaction; null = it has none yet.
  final DateTime? ledgerStart;
  final VoidCallback onEnter;

  @override
  ConsumerState<_DeclaredBanner> createState() => _DeclaredBannerState();
}

class _DeclaredBannerState extends ConsumerState<_DeclaredBanner> {
  /// The write is in flight: both buttons wait.
  bool _busy = false;

  /// Saves `{'<year>': null}` — "from the ledger" — on top of the declared years
  /// the profile already holds: a write replaces the whole map, so it goes out
  /// whole. [_DeclaredBanner.profile] is the live row (the screen rebuilds on
  /// every emission of its stream), so a sync's answer is already in it.
  Future<void> _deriveFromLedger() async {
    final p = widget.profile;
    setState(() => _busy = true);
    try {
      await ref.read(financeServiceProvider).savePivaProfile(
            _inputOf(p, {...p.declaredIncome, '${widget.year}': null}),
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pivaProfileSaveError(errorText(context, e)))),
      );
    } finally {
      // On success the profile stream takes the banner away; if it does not (yet),
      // the buttons must not stay dead.
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final year = widget.year;
    final start = widget.ledgerStart;
    final inLedger = ref.watch(currencyProvider).format(
          compensiForYear(widget.profile, ref.watch(pivaTransactionsProvider).value ?? const [], year),
        );
    const touch = ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(48, 48)));

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.pivaDeclBannerTitle('$year'),
              style: GoogleFonts.bricolageGrotesque(
                color: scheme.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            start == null
                ? l10n.pivaDeclBannerEmpty('$year', '${year + 1}')
                : l10n.pivaDeclBannerStart(DateFormat.yMMMd().format(start), '$year', '${year + 1}'),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 8),
          // A Wrap: at a large font the buttons stack instead of overflowing.
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                style: touch,
                onPressed: _busy ? null : widget.onEnter,
                child: Text(l10n.pivaDeclEnter),
              ),
              TextButton(
                style: touch,
                onPressed: _busy ? null : _deriveFromLedger,
                child: Text(l10n.pivaDeclFromLedger),
              ),
              Text(
                l10n.pivaDeclBannerLedger(inLedger),
                style: GoogleFonts.jetBrainsMono(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// [p] as the input the write takes, with [declaredIncome] in place of its own:
/// every other field exactly as it is.
PivaProfileInput _inputOf(PivaProfileData p, Map<String, double?> declaredIncome) => PivaProfileInput(
      atecoCode: p.atecoCode,
      coefficient: p.coefficient,
      startYear: p.startYear,
      startupRate: p.startupRate,
      fundType: p.fundType,
      fundName: p.fundName,
      subjectiveRate: p.subjectiveRate,
      integrativeRate: p.integrativeRate,
      minSubjective: p.minSubjective,
      minIntegrative: p.minIntegrative,
      inpsReduction: p.inpsReduction,
      incomeCategories: p.incomeCategories,
      declaredIncome: declaredIncome,
    );

/// What the profile says, in one block: the ATECO code and coefficient as the
/// title, the fund, the opening year and the income categories under it.
/// (`web/src/components/Piva.tsx`)
class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.profile, required this.onEdit});

  final PivaProfileData profile;
  final VoidCallback onEdit;

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
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
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
                _ProfileTitle(profile: profile),
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
          IconButton(
            onPressed: onEdit,
            tooltip: context.l10n.pivaProfileEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }
}

/// "ATECO 62.20.10 · coefficiente 67%" on one line when it fits; when it does not,
/// two lines without the separator — a break at the dot would leave it dangling
/// at the end of the first line, and a plain wrap would orphan "67%".
class _ProfileTitle extends StatelessWidget {
  const _ProfileTitle({required this.profile});

  final PivaProfileData profile;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.bricolageGrotesque(
      color: Theme.of(context).colorScheme.onSurface,
      fontSize: 22,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
      height: 1.1,
    );
    final code = '$pivaAteco ${profile.atecoCode}';
    final coefficient = '$pivaCoefficient ${pivaNumber(profile.coefficient)}%';
    final oneLine = '$code · $coefficient';
    return LayoutBuilder(
      builder: (context, box) {
        final painter = TextPainter(
          text: TextSpan(text: oneLine, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final fits = painter.width <= box.maxWidth;
        painter.dispose();
        if (fits) return Text(oneLine, style: style);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(code, style: style), Text(coefficient, style: style)],
        );
      },
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
