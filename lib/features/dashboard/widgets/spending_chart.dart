import 'package:budgetti/models/transaction.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class SpendingChart extends StatelessWidget {
  final List<Transaction> transactions;
  
  const SpendingChart({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    // 1. Prepare data: Last 7 days, Net Activity (Income + Expense)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final spots = <FlSpot>[];
    
    double minY = 0;
    double maxY = 0;

    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      
      // Calculate Net for this day
      final dailyNet = transactions
          .where((t) {
            final tDate = DateTime(t.date.year, t.date.month, t.date.day);
            return tDate == date;
          })
          .fold(0.0, (sum, t) => sum + t.amount); // Income is +, Expense is -

      spots.add(FlSpot(6.0 - i, dailyNet));
      
      if (dailyNet < minY) minY = dailyNet;
      if (dailyNet > maxY) maxY = dailyNet;
    }

    // Add padding to axis
    if (minY == 0 && maxY == 0) {
      maxY = 100; // Default range if empty
      minY = -100; 
    } else {
      final range = maxY - minY;
      maxY += range * 0.1; // 10% padding
      minY -= range * 0.1;
      if (range == 0) { maxY += 50; minY -= 50; }
    }

    // prevent flat line at 0 look weird
    if (maxY < 10) maxY = 10;
    if (minY > -10) minY = -10;

    // Calculate zero line position for gradient
    // Gradient goes from bottom (minY) to top (maxY)
    // 0 is at (0 - minY) / (maxY - minY)
    final totalRange = maxY - minY;
    final zeroPos = (0 - minY) / totalRange;
    final clampedZeroPos = zeroPos.clamp(0.0, 1.0);

    return AspectRatio(
      aspectRatio: 1.70,
      child: Padding(
        padding: const EdgeInsets.only(right: 18.0, top: 24, bottom: 12),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: totalRange / 4, 
              getDrawingHorizontalLine: (value) {
                // Highlight zero line
                if (value.abs() < (totalRange / 100)) {
                   return FlLine(color: Colors.white.withValues(alpha: 0.5), strokeWidth: 1);
                }
                return FlLine(
                  color: AppTheme.surfaceGreyLight,
                  strokeWidth: 1,
                );
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 1,
                  getTitlesWidget: (value, meta) => bottomTitleWidgets(value, meta, today),
                ),
              ),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: 6,
            minY: minY,
            maxY: maxY,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                // Red to Green gradient based on zero line
                gradient: LinearGradient(
                  colors: const [Colors.red, Colors.red, AppTheme.primaryGreen, AppTheme.primaryGreen],
                  stops: [0, clampedZeroPos, clampedZeroPos, 1],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                barWidth: 4,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.withValues(alpha: 0.2), 
                      Colors.red.withValues(alpha: 0.0), // Fade out
                      AppTheme.primaryGreen.withValues(alpha: 0.0), // Fade in
                      AppTheme.primaryGreen.withValues(alpha: 0.2)
                    ],
                    stops: [0, clampedZeroPos * 0.9, clampedZeroPos * 1.1, 1],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget bottomTitleWidgets(double value, TitleMeta meta, DateTime today) {
    const style = TextStyle(
      color: AppTheme.textGrey,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );
    
    int daysAgo = 6 - value.toInt();
    final date = today.subtract(Duration(days: daysAgo));
    String text = "";

    if (value.toInt() % 2 == 0) { 
      text = DateFormat('E').format(date).toUpperCase();
    }

    return SideTitleWidget(
      meta: meta,
      child: Text(text, style: style),
    );
  }
}
