import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/format/formatters.dart';
import '../../domain/home_models.dart';
import '../../domain/providers.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/skeleton_box.dart';

class TrendCard extends ConsumerWidget {
  const TrendCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final vehicleId = ref.watch(selectedVehicleIdProvider);
    final range = ref.watch(trendRangeProvider);
    final trend = ref.watch(
      trendProvider((vehicleId: vehicleId, range: range)),
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(trend: trend.value),
          const SizedBox(height: 8),
          _RangeSwitcher(
            selected: range,
            onSelect: (value) =>
                ref.read(trendRangeProvider.notifier).select(value),
          ),
          const SizedBox(height: 14),
          trend.when(
            loading: () => const _TrendSkeleton(),
            error: (error, stack) => SizedBox(
              height: 150,
              child: Center(
                child: TextButton.icon(
                  onPressed: () => ref.invalidate(
                    trendProvider((vehicleId: vehicleId, range: range)),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('趋势加载失败，点击重试'),
                ),
              ),
            ),
            data: (data) => data.points.length < 2
                ? SizedBox(
                    height: 150,
                    child: Center(
                      child: Text(
                        '暂无数据',
                        style: AppTypography.bodyMd.copyWith(
                          color: palette.outline,
                        ),
                      ),
                    ),
                  )
                : _TrendChart(data: data, range: range),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.trend});

  final TrendData? trend;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final data = trend;
    final direction = data?.direction ?? TrendDirection.none;
    final color = switch (direction) {
      TrendDirection.up => palette.error,
      TrendDirection.down => palette.primaryText,
      TrendDirection.flat || TrendDirection.none => palette.outline,
    };
    final icon = switch (direction) {
      TrendDirection.up => Icons.arrow_drop_up_rounded,
      TrendDirection.down => Icons.arrow_drop_down_rounded,
      TrendDirection.flat || TrendDirection.none => Icons.remove_rounded,
    };
    final text = switch (direction) {
      TrendDirection.up => '比上期多 ${formatYuanCompact(data!.diffCents.abs())}',
      TrendDirection.down => '比上期少 ${formatYuanCompact(data!.diffCents.abs())}',
      TrendDirection.flat => '与上期持平',
      TrendDirection.none => '暂无对比',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '花费趋势',
                    style: AppTypography.bodySm.copyWith(
                      color: palette.outline,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data == null ? '¥—' : formatYuanCompact(data.totalCents),
                    style: AppTypography.headlineLg.copyWith(
                      color: palette.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(icon, size: 14, color: color),
                      Text(
                        text,
                        style: AppTypography.labelSm.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  _LegendDot(color: palette.primary, label: '能源'),
                  const SizedBox(width: 10),
                  _LegendDot(color: palette.secondary, label: '其他开销'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.labelSm.copyWith(
            color: palette.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RangeSwitcher extends StatelessWidget {
  const _RangeSwitcher({required this.selected, required this.onSelect});

  final TrendRange selected;
  final ValueChanged<TrendRange> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final range in TrendRange.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelect(range),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    color: range == selected
                        ? palette.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: range == selected
                        ? [
                            BoxShadow(
                              color: palette.shadow.withValues(alpha: 0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    range.label,
                    textAlign: TextAlign.center,
                    style: AppTypography.labelMd.copyWith(
                      color: range == selected
                          ? palette.onSurface
                          : palette.outline,
                      fontWeight: range == selected
                          ? FontWeight.w700
                          : FontWeight.w500,
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

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.data, required this.range});

  final TrendData data;
  final TrendRange range;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final maxYuan = data.points.fold<double>(0, (maxValue, point) {
      final energy = point.energyCents / 100;
      final other = point.otherCents / 100;
      return math.max(maxValue, math.max(energy, other));
    });
    final yMax = math.max(600.0, (maxYuan / 200).ceil() * 200.0);
    final yInterval = yMax / 3;
    final step = _xInterval(data.points.length);
    final labelStyle = AppTypography.labelSm.copyWith(
      color: palette.outline,
      fontSize: 9,
      fontWeight: FontWeight.w500,
    );

    return SizedBox(
      height: 176,
      child: RepaintBoundary(
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (data.points.length - 1).toDouble(),
            minY: 0,
            maxY: yMax,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: yInterval,
              getDrawingHorizontalLine: (value) => FlLine(
                color: palette.outlineVariant.withValues(alpha: 0.6),
                strokeWidth: 1,
                dashArray: const [4, 4],
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: yInterval,
                  getTitlesWidget: (value, meta) {
                    return SideTitleWidget(
                      meta: meta,
                      space: 4,
                      child: Text('¥${value.toInt()}', style: labelStyle),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: step.toDouble(),
                  getTitlesWidget: (value, meta) {
                    final index = value.round();
                    if (index < 0 || index >= data.points.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _xLabel(data.points[index].date, range),
                        style: labelStyle,
                      ),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (spot) =>
                    palette.onSurface.withValues(alpha: 0.94),
                getTooltipItems: (spots) => [
                  for (final spot in spots)
                    LineTooltipItem(
                      '¥${spot.y.toStringAsFixed(0)}',
                      TextStyle(
                        color: spot.bar.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            lineBarsData: [
              _bar(
                points: [
                  for (var index = 0; index < data.points.length; index++)
                    FlSpot(
                      index.toDouble(),
                      data.points[index].otherCents / 100,
                    ),
                ],
                color: palette.secondary,
              ),
              _bar(
                points: [
                  for (var index = 0; index < data.points.length; index++)
                    FlSpot(
                      index.toDouble(),
                      data.points[index].energyCents / 100,
                    ),
                ],
                color: palette.primary,
              ),
            ],
          ),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }

  LineChartBarData _bar({required List<FlSpot> points, required Color color}) {
    return LineChartBarData(
      spots: points,
      isCurved: true,
      curveSmoothness: 0.32,
      preventCurveOverShooting: true,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      color: color,
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.30), color.withValues(alpha: 0)],
        ),
      ),
    );
  }

  int _xInterval(int length) {
    if (length <= 7) {
      return 1;
    }
    if (length <= 12) {
      return length <= 7 ? 1 : 2;
    }
    return 5;
  }

  String _xLabel(DateTime date, TrendRange range) {
    if (range == TrendRange.halfYear || range == TrendRange.year) {
      return '${date.month}月';
    }
    return '${date.month}/${date.day}';
  }
}

class _TrendSkeleton extends StatelessWidget {
  const _TrendSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 176,
      child: Column(
        children: [
          Expanded(child: SkeletonBox(height: double.infinity, radius: 12)),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(width: 24, height: 8),
              SkeletonBox(width: 24, height: 8),
              SkeletonBox(width: 24, height: 8),
              SkeletonBox(width: 24, height: 8),
            ],
          ),
        ],
      ),
    );
  }
}
