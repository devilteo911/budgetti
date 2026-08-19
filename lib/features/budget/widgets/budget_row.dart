import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/models/category.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgetti/core/theme/ledger_style.dart';
import 'package:budgetti/core/providers/providers.dart';

class BudgetRow extends ConsumerWidget {
  final int rank;
  final Category category;
  final double spent;
  final double limit;
  final NumberFormat currencyFormatter;
  final VoidCallback onTap;

  const BudgetRow({
    super.key,
    required this.rank,
    required this.category,
    required this.spent,
    required this.limit,
    required this.currencyFormatter,
    required this.onTap,
  });

  static Color statusColor(double pct, ColorScheme scheme) {
    if (pct >= 1.0) return const Color(0xFFFF5C6C);
    if (pct >= 0.75) return const Color(0xFFFFB870);
    return scheme.primary;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final catColor = ref.watch(
            categoryColorCacheProvider(scheme.brightness))[category.name] ??
        unknownCategoryInk(scheme);
    final hasLimit = limit > 0;
    final rawPct = hasLimit ? spent / limit : 0.0;
    final pct = rawPct.clamp(0.0, 1.0);
    final over = rawPct > 1.0;
    final color = hasLimit ? statusColor(rawPct, scheme) : scheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 34,
                  decoration: BoxDecoration(
                    color: catColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 26,
                  child: Text(
                    rank.toString().padLeft(2, '0'),
                    style: GoogleFonts.jetBrainsMono(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  ref.watch(categoryIconCacheProvider)[category.name] ??
                      categoryIcon(category.name, iconCode: category.iconCode),
                  color: catColor,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasLimit
                            ? '${currencyFormatter.format(spent)}  /  ${currencyFormatter.format(limit)}'
                            : context.l10n.budgetNoLimit,
                        style: GoogleFonts.jetBrainsMono(
                          color: scheme.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyFormatter.format(hasLimit ? spent : 0),
                      style: GoogleFonts.jetBrainsMono(
                        color: hasLimit ? scheme.onSurface : scheme.onSurfaceVariant,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (hasLimit)
                      _PctBadge(
                        text: over
                            ? '+${((rawPct - 1) * 100).toStringAsFixed(0)}%'
                            : '${(rawPct * 100).toStringAsFixed(0)}%',
                        color: color,
                      )
                    else
                      Text(
                        context.l10n.budgetSet,
                        style: GoogleFonts.jetBrainsMono(
                          color: scheme.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (hasLimit) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 17),
                child: _RowBar(
                  value: pct,
                  color: color,
                  trackColor: scheme.surfaceContainerHigh,
                  overflow: over,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PctBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _PctBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.jetBrainsMono(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _RowBar extends StatelessWidget {
  final double value;
  final Color color;
  final Color trackColor;
  final bool overflow;

  const _RowBar({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => SizedBox(
        height: 3,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: trackColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            FractionallySizedBox(
              widthFactor: (value * t).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (overflow)
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
