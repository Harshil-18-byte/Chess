import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/board_themes.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/liquid_glass.dart';

class PerformanceGraph extends StatelessWidget {
  final List<double> ratings; // List of ELO ratings over time
  final List<String> labels; // Dates or match IDs

  const PerformanceGraph({
    super.key,
    required this.ratings,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    if (ratings.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: BoardThemes.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BoardThemes.borderSubtle),
        ),
        child: Center(
          child: Text(
            '[NO DATA AVAILABLE]',
            style: TextStyle(color: BoardThemes.mutedSilver),
          ),
        ),
      );
    }

    final double minY = (ratings.reduce((a, b) => a < b ? a : b) - 50).clamp(0, double.infinity);
    final double maxY = ratings.reduce((a, b) => a > b ? a : b) + 50;

    final spots = ratings.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value);
    }).toList();

    return LiquidGlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'PERFORMANCE TREND',
            style: AppTypography.labelSmall.copyWith(color: BoardThemes.mutedSilver),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (ratings.length - 1).toDouble(),
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 50,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: BoardThemes.borderSubtle,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        // Only show first, last, and maybe middle if many
                        if (index == 0 || index == labels.length - 1 || labels.length <= 5) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              labels[index],
                              style: const TextStyle(color: BoardThemes.mutedSilver, fontSize: 10),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(color: BoardThemes.mutedSilver, fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: BoardThemes.accentCyan,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: BoardThemes.accentCyan.withAlpha(25),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => BoardThemes.surfaceCard,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          spot.y.toInt().toString(),
                          const TextStyle(color: BoardThemes.pureWhite, fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
