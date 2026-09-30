import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'dart:ui' as ui show TextDirection;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class StatsHero extends ConsumerWidget {
  const StatsHero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final period = ref.watch(selectedStatsPeriodProvider);
    final scope = ref.watch(statsScopeProvider);
    final statsAsync = ref.watch(statsDataProvider(period));
    final currency = ref.watch(currencyProvider);
    final stats = statsAsync.value;

    final now = DateTime.now();
    final isMonthly = period.month != null;
    final periodLabel = isMonthly
        ? DateFormat(
            'MMMM yyyy',
          ).format(DateTime(period.year, period.month!)).toUpperCase()
        : '${period.year}';

    final totalExpenses = stats?.totalExpenses ?? 0.0;
    final totalEarned =
        stats?.monthlyBreakdown.values.fold<double>(
          0,
          (s, m) => s + (m['earned'] ?? 0.0),
        ) ??
        0.0;
    final netFlow = totalEarned - totalExpenses;

    final dailyAvg = totalExpenses / daysInPeriod(period, now: now);

    final monthKey = DateFormat('yyyy-MM').format(now);
    final currentMonthSpent =
        stats?.monthlyBreakdown[monthKey]?['spent'] ?? 0.0;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final predictedTotal = period.year == now.year && currentMonthSpent > 0
        ? (currentMonthSpent / now.day) * daysInMonth
        : 0.0;
    final showPrediction =
        period.year == now.year &&
        (!isMonthly || period.month == now.month) &&
        predictedTotal > 0;

    final kicker = switch (scope) {
      StatsScope.expenses => context.l10n.statsTotalSpent,
      StatsScope.income => context.l10n.statsTotalEarned,
      StatsScope.all => context.l10n.statsNetActivity,
    }.toUpperCase();
    final heroValue = switch (scope) {
      StatsScope.expenses => totalExpenses,
      StatsScope.income => totalEarned,
      // Net, as the kicker says: earned + spent was gross volume.
      StatsScope.all => netFlow,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Kicker(text: '$kicker  ·  $periodLabel'),
          const SizedBox(height: 10),
          _HeroNumber(
            value: currency.format(heroValue),
            color: scheme.onSurface,
          ),
          const SizedBox(height: 22),
          StatsSecondaryRow(
            items: [
              StatsSecondaryItem(
                label: context.l10n.statsDailyAvg.toUpperCase(),
                value: currency.format(dailyAvg),
                color: scheme.onSurface,
              ),
              // The net-activity hero already is the net flow; show what came
              // in instead of repeating it.
              if (scope == StatsScope.all)
                StatsSecondaryItem(
                  label: context.l10n.statsTotalEarned.toUpperCase(),
                  value: currency.format(totalEarned),
                  color: scheme.primary,
                )
              else
                StatsSecondaryItem(
                  label: context.l10n.statsNetFlow.toUpperCase(),
                  value: (netFlow >= 0 ? '+' : '') + currency.format(netFlow),
                  color: netFlow >= 0 ? scheme.primary : scheme.error,
                ),
              if (showPrediction)
                StatsSecondaryItem(
                  label: context.l10n.statsPredicted.toUpperCase(),
                  value: currency.format(predictedTotal),
                  color: scheme.tertiary,
                )
              else if (totalEarned > 0)
                StatsSecondaryItem(
                  label: context.l10n.statsSavings.toUpperCase(),
                  value: '${(netFlow / totalEarned * 100).toStringAsFixed(0)}%',
                  color: netFlow >= 0 ? scheme.primary : scheme.error,
                )
              else
                StatsSecondaryItem(
                  label: context.l10n.statsSavings.toUpperCase(),
                  value: '—',
                  color: scheme.onSurfaceVariant,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Kicker extends StatelessWidget {
  final String text;
  const _Kicker({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.jetBrainsMono(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _HeroNumber extends StatelessWidget {
  final String value;
  final Color color;
  const _HeroNumber({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        value,
        style: GoogleFonts.jetBrainsMono(
          color: color,
          fontSize: 52,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.8,
          height: 1.0,
        ),
      ),
    );
  }
}

/// One value under the hero number: a label and what it counts.
@visibleForTesting
class StatsSecondaryItem {
  final String label;
  final String value;
  final Color color;
  const StatsSecondaryItem({
    required this.label,
    required this.value,
    required this.color,
  });
}

/// The row of secondary values under the hero.
///
/// All values share one font size — the largest, up to [_baseSize], at which the
/// widest still fits its column — and the columns end on the value. Scaling each
/// value to its own column (a FittedBox apiece) made a long value smaller than a
/// short one, so with bottom-aligned columns the glyph baselines were a few px
/// apart even though the boxes ended together.
@visibleForTesting
class StatsSecondaryRow extends StatelessWidget {
  final List<StatsSecondaryItem> items;
  const StatsSecondaryRow({super.key, required this.items});

  static const double _baseSize = 17;
  static const double _padding = 14; // each side of a column
  static const double _divider = 1;

  TextStyle _style(Color color, double size) => GoogleFonts.jetBrainsMono(
    color: color,
    fontSize: size,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final divider = scheme.outlineVariant.withValues(alpha: 0.35);
    final scaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final column =
            (constraints.maxWidth - _divider * (items.length - 1)) /
                items.length -
            2 * _padding;
        var size = _baseSize;
        for (final item in items) {
          final painter = TextPainter(
            text: TextSpan(
              text: item.value,
              style: _style(item.color, _baseSize),
            ),
            textDirection: ui.TextDirection.ltr,
            textScaler: scaler,
          )..layout();
          if (painter.width > column && column > 0) {
            size = size < _baseSize * column / painter.width
                ? size
                : _baseSize * column / painter.width;
          }
        }

        final children = <Widget>[];
        for (var i = 0; i < items.length; i++) {
          children.add(
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      items[i].label,
                      style: GoogleFonts.jetBrainsMono(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      items[i].value,
                      maxLines: 1,
                      softWrap: false,
                      style: _style(items[i].color, size),
                    ),
                  ],
                ),
              ),
            ),
          );
          if (i < items.length - 1) {
            children.add(
              Container(width: _divider, height: 34, color: divider),
            );
          }
        }
        // End, not center: a label that wraps ('MEDIA GIORNALIERA') makes its column
        // taller, and every column ends with a value — align those.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: children,
        );
      },
    );
  }
}
