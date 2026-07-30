import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/models/category.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgetti/core/theme/ledger_style.dart';

class CategoryHero extends ConsumerWidget {
  final Category category;
  final List<Transaction> transactionsForPeriod;
  final StatsPeriod period;
  final NumberFormat currencyFormatter;

  const CategoryHero({
    super.key,
    required this.category,
    required this.transactionsForPeriod,
    required this.period,
    required this.currencyFormatter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final catColor = ref.watch(
            categoryColorCacheProvider(scheme.brightness))[category.name] ??
        unknownCategoryInk(scheme);
    final now = DateTime.now();
    final isMonthly = period.month != null;

    final total = transactionsForPeriod.fold<double>(
      0,
      (s, t) => s + t.amount.abs(),
    );
    final count = transactionsForPeriod.length;
    final largest = transactionsForPeriod.isEmpty
        ? 0.0
        : transactionsForPeriod
            .map((t) => t.amount.abs())
            .reduce((a, b) => a > b ? a : b);

    final double avg;
    final String avgLabel;
    if (isMonthly) {
      final days = (period.year == now.year && period.month == now.month)
          ? now.day
          : DateTime(period.year, period.month! + 1, 0).day;
      avg = days > 0 ? total / days : 0;
      avgLabel = 'DAILY AVG';
    } else {
      final monthsElapsed = period.year == now.year ? now.month : 12;
      avg = monthsElapsed > 0 ? total / monthsElapsed : 0;
      avgLabel = 'MONTHLY AVG';
    }

    final periodLabel = isMonthly
        ? DateFormat('MMMM yyyy')
            .format(DateTime(period.year, period.month!))
            .toUpperCase()
        : '${period.year}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: catColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${category.name.toUpperCase()}  ·  $periodLabel',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(
                    color: scheme.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              currencyFormatter.format(total),
              style: GoogleFonts.jetBrainsMono(
                color: scheme.onSurface,
                fontSize: 52,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.8,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 22),
          _StatRow(
            items: [
              _Stat(
                label: avgLabel,
                value: currencyFormatter.format(avg),
                color: scheme.onSurface,
              ),
              _Stat(
                label: 'LARGEST',
                value: currencyFormatter.format(largest),
                color: scheme.onSurface,
              ),
              _Stat(
                label: 'TXN COUNT',
                value: count.toString(),
                color: catColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final List<_Stat> items;
  const _StatRow({required this.items});

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
    return Row(children: children);
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

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
                color: color,
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
