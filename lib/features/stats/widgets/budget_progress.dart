import 'package:budgetti/core/l10n.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class BudgetProgress extends StatelessWidget {
  final double spent;
  final double limit;
  final Color accent;
  final NumberFormat currencyFormatter;

  const BudgetProgress({
    super.key,
    required this.spent,
    required this.limit,
    required this.accent,
    required this.currencyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = limit > 0 ? (spent / limit) : 0.0;
    final over = spent > limit && limit > 0;
    final fillColor = over ? scheme.error : accent;
    final pct = (ratio * 100).clamp(0.0, 9999.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.l10n.statsMonthlyBudget.toUpperCase(),
                style: GoogleFonts.jetBrainsMono(
                  color: scheme.onSurfaceVariant,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.8,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: fillColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${pct.toStringAsFixed(0)}%',
                  style: GoogleFonts.jetBrainsMono(
                    color: fillColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: Stack(
                  children: [
                    Container(color: scheme.surfaceContainerHigh),
                    FractionallySizedBox(
                      widthFactor: t,
                      child: Container(color: fillColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                currencyFormatter.format(spent),
                style: GoogleFonts.jetBrainsMono(
                  color: scheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                ' / ${currencyFormatter.format(limit)}',
                style: GoogleFonts.jetBrainsMono(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              if (over)
                Text(
                  context.l10n
                      .statsOver(currencyFormatter.format(spent - limit))
                      .toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    color: scheme.error,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                )
              else
                Text(
                  context.l10n
                      .statsLeft(
                        currencyFormatter
                            .format((limit - spent).clamp(0, double.infinity)),
                      )
                      .toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    color: scheme.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
