import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class BudgetHero extends StatelessWidget {
  final double spent;
  final double limit;
  final double utilization;
  final int activeCount;
  final NumberFormat currencyFormatter;

  const BudgetHero({
    super.key,
    required this.spent,
    required this.limit,
    required this.utilization,
    required this.activeCount,
    required this.currencyFormatter,
  });

  Color _statusColor(double pct, ColorScheme scheme) {
    if (pct >= 1.0) return const Color(0xFFFF5C6C);
    if (pct >= 0.75) return const Color(0xFFFFB870);
    return scheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final monthLabel = DateFormat('MMMM yyyy').format(now).toUpperCase();

    final pctNum = (utilization * 100);
    final hasBudget = limit > 0;
    final remaining = (limit - spent);
    final remainingPositive = remaining >= 0;
    final statusColor = _statusColor(utilization, scheme);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Kicker(
            text: hasBudget
                ? 'UTILIZATION  ·  $monthLabel'
                : 'NO BUDGETS SET  ·  $monthLabel',
          ),
          const SizedBox(height: 10),
          _HeroNumber(
            percent: hasBudget ? pctNum.clamp(0, 999).toDouble() : 0,
            accentColor: statusColor,
            baseColor: scheme.onSurface,
            muted: !hasBudget,
          ),
          const SizedBox(height: 8),
          Text(
            hasBudget
                ? '${currencyFormatter.format(spent)}  /  ${currencyFormatter.format(limit)}'
                : 'Tap a category below to set a limit.',
            style: GoogleFonts.jetBrainsMono(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 18),
          _ProgressTrack(
            value: hasBudget ? utilization.clamp(0.0, 1.0) : 0,
            color: statusColor,
            trackColor: scheme.surfaceContainerHigh,
            overflow: hasBudget && utilization > 1.0,
          ),
          const SizedBox(height: 18),
          _SecondaryRow(
            items: [
              _SecondaryStat(
                label: 'SPENT',
                value: currencyFormatter.format(spent),
                valueColor: scheme.onSurface,
              ),
              _SecondaryStat(
                label: 'BUDGETED',
                value: hasBudget ? currencyFormatter.format(limit) : '—',
                valueColor:
                    hasBudget ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
              _SecondaryStat(
                label: remainingPositive ? 'REMAINING' : 'OVER',
                value: hasBudget
                    ? currencyFormatter
                        .format(remainingPositive ? remaining : -remaining)
                    : '—',
                valueColor: !hasBudget
                    ? scheme.onSurfaceVariant
                    : remainingPositive
                        ? scheme.primary
                        : scheme.error,
              ),
              _SecondaryStat(
                label: 'TRACKED',
                value: activeCount.toString().padLeft(2, '0'),
                valueColor: scheme.onSurface,
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
  final double percent;
  final Color accentColor;
  final Color baseColor;
  final bool muted;

  const _HeroNumber({
    required this.percent,
    required this.accentColor,
    required this.baseColor,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.jetBrainsMono(
            color: muted
                ? baseColor.withValues(alpha: 0.35)
                : baseColor,
            fontSize: 56,
            fontWeight: FontWeight.w800,
            letterSpacing: -2.0,
            height: 1.0,
          ),
          children: [
            TextSpan(text: percent.toStringAsFixed(0)),
            TextSpan(
              text: '%',
              style: TextStyle(
                color: muted ? baseColor.withValues(alpha: 0.35) : accentColor,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  final double value;
  final Color color;
  final Color trackColor;
  final bool overflow;

  const _ProgressTrack({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => SizedBox(
        height: 6,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: trackColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            FractionallySizedBox(
              widthFactor: (value * t).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            if (overflow)
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 4,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
          ],
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 10),
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
                fontSize: 15,
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
