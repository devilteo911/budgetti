import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:budgetti/core/providers/providers.dart';

class TransactionsHero extends ConsumerWidget {
  const TransactionsHero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final totals = ref.watch(filteredTotalsProvider);
    final filters = ref.watch(transactionFiltersProvider);
    final currency = ref.watch(currencyProvider);

    final periodLabel = _periodLabel(filters.dateRange);
    final netColor = totals.net >= 0 ? scheme.primary : scheme.error;
    final netPrefix = totals.net > 0 ? '+' : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACTIVITY  ·  $periodLabel',
            style: GoogleFonts.jetBrainsMono(
              color: scheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$netPrefix${currency.format(totals.net)}',
              style: GoogleFonts.jetBrainsMono(
                color: netColor,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.4,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _Stat(
                  label: 'INCOME',
                  value: currency.format(totals.income),
                  color: scheme.primary,
                ),
              ),
              _Divider(color: scheme.outlineVariant.withValues(alpha: 0.35)),
              Expanded(
                child: _Stat(
                  label: 'EXPENSE',
                  value: currency.format(totals.expense),
                  color: scheme.error,
                ),
              ),
              _Divider(color: scheme.outlineVariant.withValues(alpha: 0.35)),
              Expanded(
                child: _Stat(
                  label: 'COUNT',
                  value: totals.count.toString().padLeft(2, '0'),
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _periodLabel(DateTimeRange? range) {
    if (range == null) return 'ALL TIME';
    final start = range.start;
    final end = range.end;
    final spansYear = start.year == DateTime(start.year).year &&
        start.month == 1 &&
        start.day == 1 &&
        end.month == 12 &&
        end.day == 31 &&
        start.year == end.year;
    if (spansYear) return '${start.year}';

    final sameMonth = start.year == end.year && start.month == end.month;
    if (sameMonth) {
      final firstOfMonth = DateTime(start.year, start.month, 1);
      final lastOfMonth = DateTime(start.year, start.month + 1, 0);
      if (start.day == firstOfMonth.day && end.day == lastOfMonth.day) {
        return DateFormat('MMMM yyyy').format(start).toUpperCase();
      }
    }

    final sameDay = start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    if (sameDay) {
      return DateFormat('dd MMM yyyy').format(start).toUpperCase();
    }

    return '${DateFormat('dd MMM').format(start).toUpperCase()} → ${DateFormat('dd MMM').format(end).toUpperCase()}';
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Stat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final Color color;
  const _Divider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 30, color: color);
  }
}
