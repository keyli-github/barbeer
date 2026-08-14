import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Gráfica de barras de ventas — últimos 7 días
class DSWeeklySalesChart extends StatelessWidget {
  final List<double> data; // 7 valores, index 0 = hace 6 días, 6 = hoy
  final Color barColor;
  final String title;

  const DSWeeklySalesChart({
    super.key,
    required this.data,
    this.barColor = AppColors.primary,
    this.title = 'Ventas últimos 7 días',
  });

  static const _days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  /// Etiquetas de día basadas en hoy
  List<String> _dayLabels() {
    final now = DateTime.now();
    final labels = <String>[];
    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      labels.add(_days[d.weekday - 1]);
    }
    return labels;
  }

  @override
  Widget build(BuildContext context) {
    final maxVal = data.fold(0.0, (m, v) => v > m ? v : m);
    final labels = _dayLabels();
    final todayIdx = 6;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border, width: 0.75),
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                maxY: maxVal == 0 ? 100 : maxVal * 1.25,
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxVal == 0 ? 50 : maxVal / 3,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: context.colors.borderLight, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: i == todayIdx
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: i == todayIdx
                                  ? barColor
                                  : context.colors.textTertiary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(7, (i) {
                  final isToday = i == todayIdx;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: data[i],
                        color: isToday
                            ? barColor
                            : barColor.withValues(alpha: 0.3),
                        width: 22,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxVal == 0 ? 100 : maxVal * 1.25,
                          color: context.colors.surfaceAlt,
                        ),
                      ),
                    ],
                  );
                }),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        Theme.of(context).colorScheme.inverseSurface,
                    getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                      'S/ ${rod.toY.toStringAsFixed(0)}',
                      TextStyle(
                        color: Theme.of(context).colorScheme.onInverseSurface,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }
}
