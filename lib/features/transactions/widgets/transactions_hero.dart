import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/ledger_style.dart';
import 'package:budgetti/features/transactions/widgets/transaction_ledger_item.dart'
    show kLedgerInset;

class TransactionsHero extends ConsumerWidget {
  const TransactionsHero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final totals = ref.watch(filteredTotalsProvider);
    final filters = ref.watch(transactionFiltersProvider);
    final currency = ref.watch(currencyProvider);

    final periodLabel = _periodLabel(context, filters.dateRange);
    // Same two inks the rows use. Side-by-side totals are the one place colour
    // earns its keep, because here the directions are being compared.
    final netColor = totals.net >= 0
        ? incomeInk(scheme.brightness)
        : expenseInk(scheme.brightness);
    final netPrefix = totals.net > 0 ? '+' : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          kLedgerInset, 8, kLedgerInset, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${context.l10n.txActivity.toUpperCase()}  ·  $periodLabel',
            style: GoogleFonts.jetBrainsMono(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
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
                  label: context.l10n.commonIncome.toUpperCase(),
                  value: currency.format(totals.income),
                  color: incomeInk(scheme.brightness),
                ),
              ),
              _Divider(color: scheme.outlineVariant.withValues(alpha: 0.35)),
              Expanded(
                child: _Stat(
                  label: context.l10n.commonExpense.toUpperCase(),
                  value: currency.format(totals.expense),
                  color: expenseInk(scheme.brightness),
                ),
              ),
              _Divider(color: scheme.outlineVariant.withValues(alpha: 0.35)),
              Expanded(
                child: _Stat(
                  label: context.l10n.txMovements.toUpperCase(),
                  value: totals.count.toString(),
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _periodLabel(BuildContext context, DateTimeRange? range) {
    if (range == null) return context.l10n.txAllTime.toUpperCase();
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
    // No leading pad: the first stat has to start on the same left edge as the
    // headline above it. Breathing room comes from the dividers instead.
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
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
                letterSpacing: 0,
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
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.only(right: 12),
      color: color,
    );
  }
}
