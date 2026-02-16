import 'dart:math';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class SpendingBarChart extends ConsumerWidget {
  const SpendingBarChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartsDataAsync = ref.watch(chartsDataProvider);
    final granularity = ref.watch(chartGranularityProvider);
    final currencyFormatter = ref.watch(currencyProvider);

    return chartsDataAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryGreen),
      ),
      error: (err, _) => Center(child: Text("Error: $err")),
      data: (data) {
        if (data.isEmpty) {
          return const Center(
            child: Text(
              "No transaction data for trends",
              style: TextStyle(color: AppTheme.textGrey),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      const Text(
                        "Spending Trends",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const Spacer(),
                      _buildGranularityPicker(ref, granularity),
                      IconButton(
                        icon: const Icon(Icons.fullscreen, color: AppTheme.primaryGreen),
                        onPressed: () => _showFullScreen(context, data, granularity, currencyFormatter),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
                    child: _BarChartContent(
                      data: data,
                      granularity: granularity,
                      currencyFormatter: currencyFormatter,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildGranularityPicker(WidgetRef ref, ChartGranularity current) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ChartGranularity>(
          value: current,
          dropdownColor: AppTheme.surfaceGrey,
          iconEnabledColor: AppTheme.primaryGreen,
          items: ChartGranularity.values.map((g) {
            return DropdownMenuItem(
              value: g,
              child: Text(
                g.name.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              ref.read(chartGranularityProvider.notifier).set(val);
            }
          },
        ),
      ),
    );
  }

  void _showFullScreen(
      BuildContext context, List<ChartDataPoint> data, ChartGranularity granularity, dynamic formatter) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenChart(
          data: data,
          granularity: granularity,
          currencyFormatter: formatter,
        ),
      ),
    );
  }
}

class _BarChartContent extends StatelessWidget {
  final List<ChartDataPoint> data;
  final ChartGranularity granularity;
  final dynamic currencyFormatter;

  const _BarChartContent({
    required this.data,
    required this.granularity,
    required this.currencyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxAmount = data.map((e) => e.amount).reduce(max);
    final barGroups = data.asMap().entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value.amount,
            color: AppTheme.primaryGreen,
            width: granularity == ChartGranularity.daily ? 8 : 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxAmount,
              color: AppTheme.primaryGreen.withOpacity(0.1),
            ),
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxAmount * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppTheme.surfaceGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final date = data[groupIndex].label;
              String label;
              switch (granularity) {
                case ChartGranularity.daily:
                  label = DateFormat('MMM d').format(date);
                  break;
                case ChartGranularity.weekly:
                  label = "Week of ${DateFormat('MMM d').format(date)}";
                  break;
                case ChartGranularity.monthly:
                  label = DateFormat('MMM yyyy').format(date);
                  break;
              }
              return BarTooltipItem(
                '$label\n',
                const TextStyle(color: AppTheme.textGrey, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(
                    text: currencyFormatter.format(rod.toY),
                    style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 16),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) return const SizedBox.shrink();
                
                // Show fewer labels if too many points
                if (data.length > 10 && index % (data.length ~/ 5) != 0 && index != data.length - 1) {
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
                  child: Text(text, style: const TextStyle(color: AppTheme.textGrey, fontSize: 10)),
                );
              },
              reservedSize: 28,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : value.toInt().toString(),
                    style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppTheme.surfaceGreyLight.withOpacity(0.1),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );
  }
}

class _FullScreenChart extends StatefulWidget {
  final List<ChartDataPoint> data;
  final ChartGranularity granularity;
  final dynamic currencyFormatter;

  const _FullScreenChart({
    required this.data,
    required this.granularity,
    required this.currencyFormatter,
  });

  @override
  State<_FullScreenChart> createState() => _FullScreenChartState();
}

class _FullScreenChartState extends State<_FullScreenChart> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: const Text("Spending Trends Fullscreen"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: _BarChartContent(
          data: widget.data,
          granularity: widget.granularity,
          currencyFormatter: widget.currencyFormatter,
        ),
      ),
    );
  }
}
