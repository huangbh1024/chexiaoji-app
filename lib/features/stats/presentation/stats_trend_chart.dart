import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../domain/stats_models.dart';
import '../domain/stats_presenter.dart';

const double _trendHeight = 176;
const double _leftReserved = 34;
const double _bottomReserved = 24;

/// 趋势图：双序列面积曲线 + 峰值 / 点选提示气泡。
///
/// 气泡默认停在峰值桶；点按或拖动时移动到最近的桶。
class StatsTrendChart extends StatefulWidget {
  const StatsTrendChart({super.key, required this.trend});

  final StatsTrend trend;

  @override
  State<StatsTrendChart> createState() => _StatsTrendChartState();
}

class _StatsTrendChartState extends State<StatsTrendChart> {
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.trend.peakIndex;
  }

  @override
  void didUpdateWidget(covariant StatsTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trend.query != widget.trend.query ||
        oldWidget.trend.peakIndex != widget.trend.peakIndex) {
      _selectedIndex = widget.trend.peakIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final trend = widget.trend;
    final style = AppTypography.labelSm.copyWith(
      color: palette.outline,
      fontSize: 9,
      fontWeight: FontWeight.w500,
    );
    final maxY = trend.axis.maxCents / 100;
    final interval = trend.axis.ticksCents.length > 1
        ? trend.axis.ticksCents[1] / 100
        : maxY;
    final labelIndices = _labelIndices(trend.buckets.length);
    final selected =
        _selectedIndex != null &&
            _selectedIndex! >= 0 &&
            _selectedIndex! < trend.buckets.length
        ? _selectedIndex
        : trend.peakIndex;
    final selectedColor = _seriesColor(trend, selected, palette);

    return SizedBox(
      height: _trendHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: math.max(1, trend.buckets.length - 1).toDouble(),
                      minY: 0,
                      maxY: maxY,
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: interval,
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
                            reservedSize: _leftReserved,
                            interval: interval,
                            getTitlesWidget: (value, meta) {
                              return SideTitleWidget(
                                meta: meta,
                                space: 4,
                                child: Text(
                                  formatYuanAxis(value),
                                  style: style,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: _bottomReserved,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.round();
                              if (!labelIndices.contains(index)) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  trend.buckets[index].label,
                                  style: style,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        enabled: !trend.isEmpty,
                        handleBuiltInTouches: false,
                        touchCallback: (event, response) {
                          if (!event.isInterestedForInteractions) {
                            return;
                          }
                          final spots = response?.lineBarSpots;
                          if (spots == null || spots.isEmpty) {
                            return;
                          }
                          final index = spots.first.x.round().clamp(
                            0,
                            trend.buckets.length - 1,
                          );
                          if (index != _selectedIndex) {
                            setState(() => _selectedIndex = index);
                          }
                        },
                      ),
                      lineBarsData: trend.isEmpty
                          ? const []
                          : [
                              _bar(
                                trend.buckets,
                                (bucket) => bucket.otherCents,
                                palette.secondary,
                                selectedIndex: selected,
                                selectedColor: selectedColor,
                              ),
                              _bar(
                                trend.buckets,
                                (bucket) => bucket.energyCents,
                                palette.primary,
                                selectedIndex: selected,
                                selectedColor: selectedColor,
                              ),
                            ],
                    ),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                  ),
                ),
              ),
              if (trend.isEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Text(
                        '该区间暂无开销记录',
                        style: AppTypography.bodyMd.copyWith(
                          color: palette.outline,
                        ),
                      ),
                    ),
                  ),
                )
              else if (selected != null)
                _TooltipOverlay(
                  bucket: trend.buckets[selected],
                  index: selected,
                  count: trend.buckets.length,
                  maxCents: trend.axis.maxCents,
                  width: constraints.maxWidth,
                ),
            ],
          );
        },
      ),
    );
  }

  LineChartBarData _bar(
    List<StatsBucket> buckets,
    int Function(StatsBucket) valueOf,
    Color color, {
    required int? selectedIndex,
    required Color selectedColor,
  }) {
    return LineChartBarData(
      spots: [
        for (var index = 0; index < buckets.length; index++)
          FlSpot(index.toDouble(), valueOf(buckets[index]) / 100),
      ],
      isCurved: true,
      curveSmoothness: 0.32,
      preventCurveOverShooting: true,
      barWidth: 2.5,
      isStrokeCapRound: true,
      color: color,
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.30), color.withValues(alpha: 0)],
        ),
      ),
      dotData: FlDotData(
        show: selectedIndex != null && selectedColor == color,
        checkToShowDot: (spot, bar) =>
            selectedIndex != null && spot.x.round() == selectedIndex,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 4,
          color: Colors.white,
          strokeWidth: 3,
          strokeColor: color,
        ),
      ),
    );
  }

  Color _seriesColor(StatsTrend trend, int? index, AppPalette palette) {
    if (index == null || index < 0 || index >= trend.buckets.length) {
      return palette.primary;
    }
    final bucket = trend.buckets[index];
    return bucket.otherCents > bucket.energyCents
        ? palette.secondary
        : palette.primary;
  }

  Set<int> _labelIndices(int length) {
    if (length <= 7) {
      return {for (var index = 0; index < length; index++) index};
    }
    return {
      for (var index = 0; index < 7; index++)
        (index * (length - 1) / 6).round(),
    };
  }
}

class _TooltipOverlay extends StatelessWidget {
  const _TooltipOverlay({
    required this.bucket,
    required this.index,
    required this.count,
    required this.maxCents,
    required this.width,
  });

  final StatsBucket bucket;
  final int index;
  final int count;
  final int maxCents;
  final double width;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final plotWidth = math.max(0.0, width - _leftReserved);
    final plotHeight = _trendHeight - _bottomReserved;
    final x = count <= 1
        ? _leftReserved
        : _leftReserved + plotWidth * index / (count - 1);
    final value = math.max(bucket.energyCents, bucket.otherCents) / 100;
    final y = maxCents <= 0
        ? plotHeight
        : plotHeight * (1 - value / (maxCents / 100));
    const bubbleWidth = 140.0;
    const bubbleHeight = 26.0;
    final left = (x - bubbleWidth / 2)
        .clamp(0.0, math.max(0.0, width - bubbleWidth))
        .toDouble();
    final top = (y - bubbleHeight - 10)
        .clamp(0.0, _trendHeight - 60)
        .toDouble();

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: SizedBox(
          width: bubbleWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: bubbleHeight,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: palette.onSurface.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: palette.shadow.withValues(alpha: 0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  trendBucketTooltip(bucket),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSm.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -3),
                child: Transform.rotate(
                  angle: math.pi / 4,
                  child: Container(
                    width: 6,
                    height: 6,
                    color: palette.onSurface.withValues(alpha: 0.94),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
