import 'dart:math';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
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

    return chartsDataAsync.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryGreen),
        ),
      ),
      error: (err, _) => SizedBox(
        height: 200,
        child: Center(child: Text("Error: $err")),
      ),
      data: (data) {
        if (data.isEmpty) {
          return const SizedBox(
            height: 200,
            child: Center(
              child: Text(
                "No data available",
                style: TextStyle(color: AppTheme.textGrey),
              ),
            ),
          );
        }

        final maxAmount = data.map((e) => e.amount).reduce(max);
        final spots = data
            .asMap()
            .entries
            .map((e) => FlSpot(e.key.toDouble(), e.value.amount))
            .toList();

        return SizedBox(
          height: 200,
          child: Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 4),
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxAmount * 1.2,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppTheme.surfaceGrey,
                    getTooltipItems: (touchedSpots) =>
                        touchedSpots.map((spot) {
                          final point = data[spot.x.toInt()];
                          final date = point.label;
                          String dateLabel;
                          switch (granularity) {
                            case ChartGranularity.daily:
                              dateLabel = DateFormat('MMM d').format(date);
                              break;
                            case ChartGranularity.weekly:
                              dateLabel =
                                  "Week of ${DateFormat('MMM d').format(date)}";
                              break;
                            case ChartGranularity.monthly:
                              dateLabel = DateFormat('MMM yyyy').format(date);
                              break;
                          }
                          return LineTooltipItem(
                            '$dateLabel\n${currencyFormatter.format(spot.y)}',
                            const TextStyle(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          );
                        }).toList(),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppTheme.surfaceGreyLight.withValues(alpha: 0.15),
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
                        if (index < 0 || index >= data.length) {
                          return const SizedBox.shrink();
                        }

                        // Show fewer labels when many data points
                        if (data.length > 10 &&
                            index % (data.length ~/ 5) != 0 &&
                            index != data.length - 1) {
                          return const SizedBox.shrink();
                        }

                        final date = data[index].label;
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
                            style: const TextStyle(
                              color: AppTheme.textGrey,
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
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppTheme.primaryGreen,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryGreen.withValues(alpha: 0.25),
                          AppTheme.primaryGreen.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
