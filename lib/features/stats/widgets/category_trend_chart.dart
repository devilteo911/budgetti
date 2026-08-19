import 'dart:math' as math;
import 'package:budgetti/core/l10n.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class CategoryTrendChart extends StatelessWidget {
  final List<String> months;
  final Map<String, double> monthlyData;
  final Color accent;
  final NumberFormat currencyFormatter;

  const CategoryTrendChart({
    super.key,
    required this.months,
    required this.monthlyData,
    required this.accent,
    required this.currencyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final currentKey = DateFormat('yyyy-MM').format(DateTime(now.year, now.month));

    if (months.isEmpty || monthlyData.values.every((v) => v == 0)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Text(
          context.l10n.statsNoTrendData.toUpperCase(),
          style: GoogleFonts.jetBrainsMono(
            color: scheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      );
    }

    final maxVal = monthlyData.values.isEmpty
        ? 0.0
        : monthlyData.values.reduce(math.max);
    final roundedMax = _roundedMax(maxVal);

    final groups = List.generate(months.length, (i) {
      final key = months[i];
      final v = monthlyData[key] ?? 0;
      final isCurrent = key == currentKey;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: v,
            color: accent.withValues(alpha: isCurrent ? 1.0 : 0.55),
            width: 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
          ),
        ],
      );
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            maxY: roundedMax,
            alignment: BarChartAlignment.spaceBetween,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => scheme.surfaceContainerHigh,
                tooltipPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                getTooltipItem: (group, _, rod, __) {
                  final key = months[group.x];
                  final date = DateTime.parse('$key-01');
                  return BarTooltipItem(
                    '${DateFormat('MMM yyyy').format(date)}\n',
                    GoogleFonts.jetBrainsMono(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                    children: [
                      TextSpan(
                        text: currencyFormatter.format(rod.toY),
                        style: GoogleFonts.jetBrainsMono(
                          color: scheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= months.length) return const SizedBox();
                    if (months.length > 6 && i % 2 != 0) {
                      return const SizedBox();
                    }
                    final date = DateTime.parse('${months[i]}-01');
                    return SideTitleWidget(
                      meta: meta,
                      space: 10,
                      child: Text(
                        DateFormat('MMM').format(date).toUpperCase(),
                        style: GoogleFonts.jetBrainsMono(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: groups,
          ),
        ),
      ),
    );
  }

  static double _roundedMax(double maxVal) {
    if (maxVal <= 0) return 100;
    final log10 = (math.log(maxVal) / math.ln10).floorToDouble();
    final powerOf10 = math.pow(10, log10).toDouble();
    if (maxVal <= powerOf10) return powerOf10;
    if (maxVal <= powerOf10 * 2) return powerOf10 * 2;
    if (maxVal <= powerOf10 * 5) return powerOf10 * 5;
    return powerOf10 * 10;
  }
}
