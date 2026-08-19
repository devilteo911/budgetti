import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/models/transaction.dart';

/// Brutalist-style recent transactions panel for the dashboard.
/// Dense rows with a colored category stripe and monospace amount/time.
class RecentTransactionsPanel extends ConsumerWidget {
  const RecentTransactionsPanel({super.key, required this.transactions});

  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final currency = ref.watch(currencyProvider);
    final catColors = ref.watch(categoryColorCacheProvider(Theme.of(context).colorScheme.brightness));

    final border = BorderSide(color: scheme.outline.withValues(alpha: 0.12));
    final rowBorder = BorderSide(color: scheme.outline.withValues(alpha: 0.06));

    final items = transactions.take(5).toList();

    return Container(
      decoration: BoxDecoration(border: Border(bottom: border, left: border, right: border)),
      child: Column(
        children: [
          // Header row
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: border),
              color: scheme.surface.withValues(alpha: 0.4),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.jetBrainsMono(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        TextSpan(
                            text:
                                '${context.l10n.dashRecentLabel.toUpperCase()} · '),
                        TextSpan(
                          text: context.l10n
                              .dashLastCount(items.length)
                              .toUpperCase(),
                          style: TextStyle(color: scheme.onSurface),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go('/transactions'),
                  child: Text(
                      '${context.l10n.dashAllLabel.toUpperCase()} →',
                      style: GoogleFonts.jetBrainsMono(
                        color: scheme.primary,
                        fontSize: 11,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w500,
                      )),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                context.l10n.dashNoTransactions,
                style: GoogleFonts.jetBrainsMono(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                  letterSpacing: 1.0,
                ),
              ),
            )
          else
            for (int i = 0; i < items.length; i++)
              _Row(
                t: items[i],
                last: i == items.length - 1,
                border: rowBorder,
                stripeColor: catColors[items[i].category] ?? scheme.primary,
                currency: currency,
              ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.t,
    required this.last,
    required this.border,
    required this.stripeColor,
    required this.currency,
  });

  final Transaction t;
  final bool last;
  final BorderSide border;
  final Color stripeColor;
  final dynamic currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIncome = t.type == 'income';
    final amtColor = isIncome ? scheme.primary : scheme.onSurface;
    final sign = isIncome ? '+' : '−';

    return Container(
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(width: 3, height: 26, color: stripeColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.description.isEmpty ? t.category : t.description,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.bricolageGrotesque(
                    color: scheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  t.category.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$sign${currency.format(t.amount.abs())}',
                style: GoogleFonts.jetBrainsMono(
                  color: amtColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _relDate(context, t.date),
                style: GoogleFonts.jetBrainsMono(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _relDate(BuildContext context, DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) {
      final h = d.hour.toString().padLeft(2, '0');
      final m = d.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    if (diff == 1) return context.l10n.dashYesterdayShort;
    if (diff < 7) return context.l10n.dashDaysAgoShort(diff);
    return '${DateFormat.MMM().format(d).toUpperCase()} ${d.day}';
  }
}
