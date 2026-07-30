import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:budgetti/core/providers/providers.dart';

/// Brutalist monthly budget panel: left = giant % with mono subline,
/// right = segmented bar for top-3 category spends + mono legend.
class BudgetOverviewCard extends ConsumerWidget {
  const BudgetOverviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final currency = ref.watch(currencyProvider);
    final budgets = ref.watch(budgetsProvider).value ?? const [];
    final spending = ref.watch(budgetStatsProvider).value ?? const {};
    final catColors = ref.watch(categoryColorCacheProvider(Theme.of(context).colorScheme.brightness));

    final border = BorderSide(color: scheme.outline.withValues(alpha: 0.12));
    final boxBorder = Border(bottom: border, left: border, right: border);

    if (budgets.isEmpty) {
      return InkWell(
        onTap: () => context.push('/budgets'),
        child: Container(
          decoration: BoxDecoration(border: boxBorder),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined,
                  color: scheme.primary, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Set up budgets',
                        style: GoogleFonts.bricolageGrotesque(
                          color: scheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 2),
                    Text('Track category spending each month',
                        style: GoogleFonts.jetBrainsMono(
                          color: scheme.onSurfaceVariant,
                          fontSize: 10,
                          letterSpacing: 0.6,
                        )),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward, color: scheme.onSurfaceVariant, size: 16),
            ],
          ),
        ),
      );
    }

    final totalBudgeted = budgets.fold<double>(0, (s, b) => s + b.limit);
    final totalSpent = budgets.fold<double>(
        0, (s, b) => s + (spending[b.category] ?? 0));
    final pct = totalBudgeted == 0 ? 0.0 : totalSpent / totalBudgeted;
    final pctClamped = pct.clamp(0.0, 1.5);
    final over = pct > 1.0;

    // Top 3 categories by spend for the segmented bar.
    final sorted = budgets.toList()
      ..sort((a, b) =>
          (spending[b.category] ?? 0).compareTo(spending[a.category] ?? 0));
    final top = sorted.take(3).toList();
    final topTotal = top.fold<double>(
        0, (s, b) => s + (spending[b.category] ?? 0));

    final pctColor = over
        ? const Color(0xFFFF5C6C)
        : pct >= 0.75
            ? const Color(0xFFFFB870)
            : scheme.primary;

    return InkWell(
      onTap: () => context.push('/budgets'),
      child: Container(
      decoration: BoxDecoration(border: boxBorder),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _KLabel('MONTHLY BUDGET'),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.bricolageGrotesque(
                      color: scheme.onSurface,
                      fontSize: 52,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2,
                      height: 1.0,
                    ),
                    children: [
                      TextSpan(text: (pctClamped * 100).toStringAsFixed(0)),
                      TextSpan(
                        text: '%',
                        style: TextStyle(
                          color: pctColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.jetBrainsMono(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                      letterSpacing: 0.3,
                    ),
                    children: [
                      TextSpan(
                        text: currency.format(totalSpent),
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const TextSpan(text: '  /  '),
                      TextSpan(text: currency.format(totalBudgeted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // RIGHT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _KLabel('CATEGORIES'),
                const SizedBox(height: 10),
                _SegmentedBar(
                  segments: top.map((b) {
                    final spent = spending[b.category] ?? 0;
                    final w = topTotal == 0 ? 0.0 : spent / topTotal;
                    return _Seg(
                      weight: w,
                      color: catColors[b.category] ?? scheme.primary,
                    );
                  }).toList(),
                  emptyColor: scheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 10),
                ...top.map((b) {
                  final spent = spending[b.category] ?? 0;
                  final color = catColors[b.category] ?? scheme.primary;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(width: 8, height: 8, color: color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            b.category.toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.jetBrainsMono(
                              color: scheme.onSurfaceVariant,
                              fontSize: 10,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        Text(
                          currency.format(spent),
                          style: GoogleFonts.jetBrainsMono(
                            color: scheme.onSurface,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

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
        fontSize: 10,
        letterSpacing: 1.8,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _Seg {
  _Seg({required this.weight, required this.color});
  final double weight;
  final Color color;
}

class _SegmentedBar extends StatelessWidget {
  const _SegmentedBar({required this.segments, required this.emptyColor});
  final List<_Seg> segments;
  final Color emptyColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: Row(
        children: [
          for (int i = 0; i < segments.length; i++) ...[
            Expanded(
              flex: ((segments[i].weight * 1000).clamp(1, 1000)).toInt(),
              child: Container(color: segments[i].color),
            ),
            if (i < segments.length - 1) const SizedBox(width: 2),
          ],
        ],
      ),
    );
  }
}
