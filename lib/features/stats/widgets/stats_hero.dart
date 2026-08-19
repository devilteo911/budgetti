import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/providers/providers.dart';
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
        ? DateFormat('MMMM yyyy')
            .format(DateTime(period.year, period.month!))
            .toUpperCase()
        : '${period.year}';

    final totalExpenses = stats?.totalExpenses ?? 0.0;
    final totalEarned = stats?.monthlyBreakdown.values
            .fold<double>(0, (s, m) => s + (m['earned'] ?? 0.0)) ??
        0.0;
    final netFlow = totalEarned - totalExpenses;

    final daysToDivide = isMonthly
        ? (period.year == now.year && period.month == now.month
            ? now.day
            : DateTime(period.year, period.month! + 1, 0).day)
        : 365;
    final dailyAvg = totalExpenses / daysToDivide;

    final monthKey = DateFormat('yyyy-MM').format(now);
    final currentMonthSpent =
        stats?.monthlyBreakdown[monthKey]?['spent'] ?? 0.0;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final predictedTotal = period.year == now.year && currentMonthSpent > 0
        ? (currentMonthSpent / now.day) * daysInMonth
        : 0.0;
    final showPrediction = period.year == now.year &&
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
      StatsScope.all => totalEarned + totalExpenses,
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
          _SecondaryRow(
            items: [
              _SecondaryStat(
                label: context.l10n.statsDailyAvg.toUpperCase(),
                value: currency.format(dailyAvg),
                valueColor: scheme.onSurface,
              ),
              _SecondaryStat(
                label: context.l10n.statsNetFlow.toUpperCase(),
                value: (netFlow >= 0 ? '+' : '') + currency.format(netFlow),
                valueColor:
                    netFlow >= 0 ? scheme.primary : scheme.error,
              ),
              if (showPrediction)
                _SecondaryStat(
                  label: context.l10n.statsPredicted.toUpperCase(),
                  value: currency.format(predictedTotal),
                  valueColor: scheme.tertiary,
                )
              else if (totalEarned > 0)
                _SecondaryStat(
                  label: context.l10n.statsSavings.toUpperCase(),
                  value:
                      '${(netFlow / totalEarned * 100).toStringAsFixed(0)}%',
                  valueColor: netFlow >= 0
                      ? scheme.primary
                      : scheme.error,
                )
              else
                _SecondaryStat(
                  label: context.l10n.statsSavings.toUpperCase(),
                  value: '—',
                  valueColor: scheme.onSurfaceVariant,
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
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 2.2,
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

class _SecondaryRow extends StatelessWidget {
  final List<_SecondaryStat> items;
  const _SecondaryRow({required this.items});

  @override
  Widget build(BuildContext context) {
    final divider = Theme.of(context).colorScheme.outlineVariant.withValues(
          alpha: 0.35,
        );
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      children.add(Expanded(child: items[i]));
      if (i < items.length - 1) {
        children.add(Container(width: 1, height: 34, color: divider));
      }
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: children);
  }
}

class _SecondaryStat extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _SecondaryStat({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              color: scheme.onSurfaceVariant,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                color: valueColor,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
