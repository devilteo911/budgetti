import 'dart:math' as math;
import 'package:budgetti/core/l10n.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class MonthlyRow extends StatelessWidget {
  final String month;
  final double earned;
  final double spent;
  final NumberFormat currencyFormatter;

  const MonthlyRow({
    super.key,
    required this.month,
    required this.earned,
    required this.spent,
    required this.currencyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final net = earned - spent;
    final netPositive = net >= 0;
    final netColor = netPositive ? scheme.primary : scheme.error;
    final max = math.max(earned, spent);
    final earnedRatio = max > 0 ? earned / max : 0.0;
    final spentRatio = max > 0 ? spent / max : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  month.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    color: scheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Text(
                (netPositive ? '+' : '') + currencyFormatter.format(net),
                style: GoogleFonts.jetBrainsMono(
                  color: netColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _InlineStat(
                  label: context.l10n.statsEarned.toUpperCase(),
                  value: currencyFormatter.format(earned),
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _InlineStat(
                  label: context.l10n.statsSpent.toUpperCase(),
                  value: currencyFormatter.format(spent),
                  color: spent > earned
                      ? scheme.error
                      : scheme.onSurfaceVariant,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _LedgerBar(
            earnedRatio: earnedRatio,
            spentRatio: spentRatio,
            earnedColor: scheme.primary,
            spentColor: spent > earned ? scheme.error : scheme.onSurfaceVariant,
            trackColor: scheme.surfaceContainerHigh,
          ),
        ],
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool alignEnd;

  const _InlineStat({
    required this.label,
    required this.value,
    required this.color,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            color: scheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _LedgerBar extends StatelessWidget {
  final double earnedRatio;
  final double spentRatio;
  final Color earnedColor;
  final Color spentColor;
  final Color trackColor;

  const _LedgerBar({
    required this.earnedRatio,
    required this.spentRatio,
    required this.earnedColor,
    required this.spentColor,
    required this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => SizedBox(
        height: 4,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: trackColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            FractionallySizedBox(
              widthFactor: (earnedRatio * t).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: earnedColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: FractionallySizedBox(
                widthFactor: (spentRatio * t).clamp(0.0, 1.0),
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: spentColor.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
