import 'dart:math' as math;

import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/ledger_style.dart';
import 'package:budgetti/features/piva/piva_format.dart';
import 'package:budgetti/features/piva/piva_view.dart';
import 'package:budgetti/models/piva.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// The compensi of one year: the year stepper, four tiles, and — once there is
/// anything to show — the month-by-month chart against the year before.
/// Mirrors `web/src/components/PivaIncome.tsx`, minus the list of payments.
class PivaIncomeSection extends ConsumerWidget {
  const PivaIncomeSection({super.key, required this.profile, required this.view});

  final PivaProfileData profile;
  final PivaYearView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final currency = ref.watch(currencyProvider);
    final year = view.year;
    final avg = view.average;
    final pct = view.pct;
    // Same thresholds as the web's Delta: within ±0.5 it is flat.
    final up = pct != null && pct > 0.5;
    final down = pct != null && pct < -0.5;
    final vs = l10n.pivaVsYear('${year - 1}');
    final delta = pct == null
        ? '${l10n.pivaNew} $vs'
        : '${up ? '▲' : down ? '▼' : '■'} ${pct.abs().toStringAsFixed(0)}% $vs';
    final cats = profile.incomeCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _YearHeader(year: year, startYear: profile.startYear),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Table(
            border: TableBorder.all(color: scheme.outline.withValues(alpha: 0.12)),
            children: [
              TableRow(children: [
                _Tile(
                  label: '$pivaCompensi $year',
                  value: currency.format(view.total),
                  sub: delta,
                  subInk: up
                      ? incomeInk(scheme.brightness)
                      : down
                          ? expenseInk(scheme.brightness)
                          : null,
                ),
                _Tile(
                  label: l10n.pivaTileAverage,
                  value: avg == null ? '—' : currency.format(avg),
                  sub: avg == null
                      ? l10n.pivaTileFirstMonth
                      : l10n.pivaTileAverageSub(view.concludedMonths),
                ),
              ]),
              TableRow(children: [
                _Tile(
                  label: l10n.pivaTilePayments,
                  value: '${view.count}',
                  sub: view.count > 0
                      ? l10n.pivaTilePaymentsSub(currency.format(view.total / view.count))
                      : l10n.pivaNoneYet,
                ),
                _Tile(
                  label: l10n.pivaTileBest,
                  value: view.best > 0 ? currency.format(view.best) : '—',
                  sub: view.best > 0
                      ? DateFormat('MMMM yyyy').format(DateTime(year, view.bestMonth + 1))
                      : l10n.pivaNoneYet,
                ),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!view.hasData)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.pivaNoIncome('$year'),
                  style: TextStyle(color: scheme.onSurface, fontSize: 15, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  cats.isEmpty
                      ? l10n.pivaNoIncomeNoCategories
                      : l10n.pivaNoIncomeHint(cats.join(', ')),
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          )
        else ...[
          // A cassa that charges an integrativo: what the bank credited is not
          // all income, so say how it splits.
          if (view.carved)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              // The same bordered box as the prospetto below, so the rows share
              // its left edge instead of floating between the tiles and the chart.
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(
                  children: [
                    PivaLine(label: pivaCompensi, value: currency.format(view.total)),
                    PivaLine(label: l10n.pivaReconIntegrativo, value: currency.format(view.toRemit)),
                    PivaLine(label: l10n.pivaReconBank, value: currency.format(view.gross)),
                  ],
                ),
              ),
            ),
          _IncomeChart(view: view, currency: currency),
        ],
      ],
    );
  }
}

/// One label / amount line, read by a screen reader as one thing — label, then
/// amount. Shared with the estimate of the screen.
class PivaLine extends StatelessWidget {
  const PivaLine({
    super.key,
    required this.label,
    required this.value,
    this.note,
    this.bold = false,
  });

  final String label, value;

  /// A small line under the label.
  final String? note;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.bricolageGrotesque(
                      color: scheme.onSurface,
                      fontSize: bold ? 15 : 14,
                      // w600, not w500: only SemiBold/Bold/ExtraBold of Bricolage
                      // are bundled (assets/google_fonts), and with runtime
                      // fetching off a missing weight fails to load.
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  if (note != null)
                    Text(
                      note!,
                      style: GoogleFonts.jetBrainsMono(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                        letterSpacing: 0.3,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.jetBrainsMono(
                color: scheme.onSurface,
                fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "COMPENSI" in the look of a `SectionLabel`, with the year stepper on the
/// right. Both ends are capped to a share of the row, so a large font scale
/// squeezes the rule between them, never the screen.
class _YearHeader extends ConsumerWidget {
  const _YearHeader({required this.year, required this.startYear});

  final int year, startYear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final notifier = ref.read(pivaYearProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
      child: LayoutBuilder(
        builder: (context, box) => Row(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth * 0.45),
              child: Text(
                pivaCompensi.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.jetBrainsMono(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.25),
              ),
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth * 0.45),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      tooltip: l10n.pivaPrevYear,
                      onPressed: year > startYear ? () => notifier.set(year - 1) : null,
                    ),
                    Text(
                      '$year',
                      style: GoogleFonts.jetBrainsMono(
                        color: scheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      tooltip: l10n.pivaNextYear,
                      onPressed:
                          year < DateTime.now().year ? () => notifier.set(year + 1) : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A cell of the 2×2 grid: the label and the amount each on one line (they
/// shrink instead of wrapping, so the two cells of a row stay level), then a
/// small line that may wrap.
class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, required this.sub, this.subInk});

  final String label, value, sub;
  final Color? subInk;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label.toUpperCase(),
                style: GoogleFonts.jetBrainsMono(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: GoogleFonts.bricolageGrotesque(
                  color: scheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              sub,
              style: GoogleFonts.jetBrainsMono(
                color: subInk ?? scheme.onSurfaceVariant,
                fontSize: 11,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The year before and the chosen year, side by side month by month. Built like
/// `CategoryTrendChart` (no left axis, no grid, the value on touch); the bars
/// are sized from the width so twelve groups fit a 320 dp phone.
class _IncomeChart extends StatelessWidget {
  const _IncomeChart({required this.view, required this.currency});

  final PivaYearView view;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final year = view.year;
    final ink = incomeInk(scheme.brightness);
    final priorInk = scheme.onSurfaceVariant.withValues(alpha: 0.45);
    final peak = [...view.months, ...view.priorMonths].reduce(math.max);
    final initial = DateFormat('MMMMM');
    final tipDay = DateFormat('MMMM yyyy');
    final label = GoogleFonts.jetBrainsMono(
      color: scheme.onSurfaceVariant,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
    );

    // The legend and the chart read as one sentence, a node of their own (not
    // merged into the heading's); the bars are not exposed.
    return Semantics(
      container: true,
      label: context.l10n.pivaChartSemantics('$year', currency.format(view.total), '${year - 1}'),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _Key(color: ink, text: '$year'),
                _Key(color: priorInk, text: '${year - 1}'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: LayoutBuilder(
                builder: (context, box) {
                  final width = ((box.maxWidth / 12 - 6) / 2).clamp(3.0, 9.0).toDouble();
                  BarChartRodData rod(double y, Color color) => BarChartRodData(
                        toY: y,
                        color: color,
                        width: width,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                      );
                  return BarChart(
                    BarChartData(
                      maxY: peak > 0 ? peak * 1.2 : 1,
                      alignment: BarChartAlignment.spaceAround,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => scheme.surfaceContainerHigh,
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          getTooltipItem: (group, _, r, rodIndex) => BarTooltipItem(
                            '${tipDay.format(DateTime(rodIndex == 0 ? year - 1 : year, group.x + 1))}\n',
                            label,
                            children: [
                              TextSpan(
                                text: currency.format(r.toY),
                                style: GoogleFonts.jetBrainsMono(
                                  color: scheme.onSurface,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 10 + MediaQuery.textScalerOf(context).scale(18),
                            getTitlesWidget: (value, meta) => SideTitleWidget(
                              meta: meta,
                              space: 10,
                              child: Text(
                                initial.format(DateTime(year, value.toInt() + 1)).toUpperCase(),
                                style: label,
                              ),
                            ),
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < 12; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              rod(view.priorMonths[i], priorInk),
                              // The month in progress is still filling in.
                              rod(view.months[i], ink.withValues(alpha: i == view.currentMonth ? 0.4 : 1)),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.jetBrainsMono(
            color: scheme.onSurfaceVariant,
            fontSize: 11,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}
