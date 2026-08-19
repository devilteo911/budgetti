import 'dart:math';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/ledger_style.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class SpendingLineChart extends ConsumerWidget {
  const SpendingLineChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartsDataAsync = ref.watch(chartsDataProvider);
    final granularity = ref.watch(chartGranularityProvider);
    final currencyFormatter = ref.watch(currencyProvider);
    final scope = ref.watch(statsScopeProvider);
    final scheme = Theme.of(context).colorScheme;
    final brightness = scheme.brightness;

    // Reds for expenses, greens for income, both overlaid for "all".
    // Each line sweeps soft → strong along the chart; the fill fades down.
    final expenseAccent = expenseInk(brightness);
    final incomeAccent = incomeInk(brightness);

    return chartsDataAsync.when(
      loading: () => SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: scheme.primary),
        ),
      ),
      error: (err, _) => SizedBox(
        height: 200,
        child: Center(child: Text("Error: $err")),
      ),
      data: (series) {
        if (series.isEmpty) {
          return SizedBox(
            height: 200,
            child: Center(
              child: Text(
                "No data available",
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          );
        }

        // Shared x axis: the union of both series' buckets, so a day with
        // only income still lines up with the expense line's zeros.
        final showBoth = scope == StatsScope.all;
        final labels = <DateTime>{
          if (showBoth || scope == StatsScope.expenses)
            ...series.expenses.map((p) => p.label),
          if (showBoth || scope == StatsScope.income)
            ...series.income.map((p) => p.label),
        }.toList()
          ..sort();
        if (labels.isEmpty) {
          return SizedBox(
            height: 200,
            child: Center(
              child: Text(
                "No data available",
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          );
        }

        final expenseValues = {
          for (final p in series.expenses) p.label: p.amount,
        };
        final incomeValues = {for (final p in series.income) p.label: p.amount};

        List<FlSpot> spotsOf(Map<DateTime, double> values) => [
              for (var i = 0; i < labels.length; i++)
                FlSpot(i.toDouble(), values[labels[i]] ?? 0),
            ];

        final maxAmount = max(
          expenseValues.values.fold(0.0, max),
          incomeValues.values.fold(0.0, max),
        );

        LineChartBarData barOf(
          List<FlSpot> spots,
          Color accent,
        ) =>
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: accent,
              gradient: LinearGradient(
                colors: [accent.withValues(alpha: 0.35), accent],
              ),
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  radius: 3,
                  color: accent,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    accent.withValues(alpha: 0.20),
                    accent.withValues(alpha: 0.02),
                  ],
                ),
              ),
            );

        final bars = [
          if (showBoth || scope == StatsScope.expenses)
            barOf(spotsOf(expenseValues), expenseAccent),
          if (showBoth || scope == StatsScope.income)
            barOf(spotsOf(incomeValues), incomeAccent),
        ];

        String dateLabelOf(DateTime date) => switch (granularity) {
              ChartGranularity.daily => DateFormat('MMM d').format(date),
              ChartGranularity.weekly =>
                "Week of ${DateFormat('MMM d').format(date)}",
              ChartGranularity.monthly => DateFormat('MMM yyyy').format(date),
            };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showBoth)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 6),
                child: Row(
                  children: [
                    _ChartLegendDot(color: expenseAccent, label: 'Expenses'),
                    const SizedBox(width: 14),
                    _ChartLegendDot(color: incomeAccent, label: 'Income'),
                  ],
                ),
              ),
            SizedBox(
              height: 200,
              child: Padding(
                padding: const EdgeInsets.only(right: 12, top: 8, bottom: 4),
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: maxAmount * 1.2,
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => scheme.surfaceContainer,
                        getTooltipItems: (touchedSpots) => touchedSpots.map(
                          (spot) {
                            final date = labels[spot.x.toInt()];
                            final accent = bars[spot.barIndex].color!;
                            final value =
                                currencyFormatter.format(spot.y);
                            // Date prefix only on the first bar's row, so
                            // the tooltip doesn't repeat it per line.
                            final prefix =
                                spot.barIndex == 0 ? '${dateLabelOf(date)}\n' : '';
                            return LineTooltipItem(
                              '$prefix$value',
                              TextStyle(
                                color: accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            );
                          },
                        ).toList(),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: scheme.surfaceContainerHigh
                            .withValues(alpha: 0.15),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= labels.length) {
                              return const SizedBox.shrink();
                            }

                            // Show fewer labels when many data points
                            if (labels.length > 10 &&
                                index % (labels.length ~/ 5) != 0 &&
                                index != labels.length - 1) {
                              return const SizedBox.shrink();
                            }

                            final date = labels[index];
                            String text;
                            switch (granularity) {
                              case ChartGranularity.daily:
                                text = DateFormat('dd').format(date);
                                break;
                              case ChartGranularity.weekly:
                                text = 'W${(date.day / 7).ceil()}';
                                break;
                              case ChartGranularity.monthly:
                                text = DateFormat('MMM').format(date);
                                break;
                            }
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                text,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: bars,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChartLegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
