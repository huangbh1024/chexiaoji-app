import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../../domain/report_aggregation.dart';
import '../../domain/report_models.dart';
import '../../domain/report_presenter.dart';
import '../report_style.dart';

/// 屏幕内的 A4 报表预览：固定比例、白纸、支持双指缩放与双击。
class ReportPaperPreview extends StatefulWidget {
  const ReportPaperPreview({
    super.key,
    required this.report,
    required this.options,
  });

  final MonthlyReport report;
  final ReportOptions options;

  @override
  State<ReportPaperPreview> createState() => _ReportPaperPreviewState();
}

class _ReportPaperPreviewState extends State<ReportPaperPreview> {
  final TransformationController _controller = TransformationController();
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncZoom);
  }

  @override
  void didUpdateWidget(covariant ReportPaperPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.report.scope != widget.report.scope ||
        oldWidget.options != widget.options) {
      _controller.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_syncZoom)
      ..dispose();
    super.dispose();
  }

  void _syncZoom() {
    final zoomed = _controller.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) {
      setState(() => _zoomed = zoomed);
    }
  }

  void _toggleZoom(Size size) {
    if (_zoomed) {
      _controller.value = Matrix4.identity();
      return;
    }
    final matrix = Matrix4.identity();
    matrix.setEntry(0, 0, 2);
    matrix.setEntry(1, 1, 2);
    matrix.setEntry(0, 3, -size.width / 2);
    matrix.setEntry(1, 3, -size.height / 2);
    _controller.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = width * reportPaperHeight / reportPaperWidth;
        final size = Size(width, height);

        return SizedBox(
          width: width,
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(reportPaperRadius),
            child: GestureDetector(
              onDoubleTap: () => _toggleZoom(size),
              child: InteractiveViewer(
                transformationController: _controller,
                minScale: 1,
                maxScale: 2.5,
                panEnabled: _zoomed,
                scaleEnabled: true,
                child: SizedBox(
                  width: width,
                  height: height,
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: ReportPaperSurface(
                      report: widget.report,
                      options: widget.options,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 固定尺寸（358×506）的纸张，供预览与全屏共用。
class ReportPaperSurface extends StatelessWidget {
  const ReportPaperSurface({
    super.key,
    required this.report,
    required this.options,
  });

  final MonthlyReport report;
  final ReportOptions options;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return SizedBox(
      width: reportPaperWidth,
      height: reportPaperHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppPalette.light.surface,
          borderRadius: BorderRadius.circular(reportPaperRadius),
          boxShadow: reportPaperShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(reportPaperRadius),
          child: Theme(
            data: reportPaperTheme(),
            child: MediaQuery(
              data: media.copyWith(textScaler: TextScaler.noScaling),
              child: ReportPaperCanvas(report: report, options: options),
            ),
          ),
        ),
      ),
    );
  }
}

/// 纸张内容。必须在 358×506 设计画布内完整布局。
class ReportPaperCanvas extends StatelessWidget {
  const ReportPaperCanvas({
    super.key,
    required this.report,
    required this.options,
  });

  final MonthlyReport report;
  final ReportOptions options;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ColoredBox(
      color: palette.surface,
      child: Padding(
        padding: const EdgeInsets.all(reportPaperPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PaperHeader(report: report),
            const SizedBox(height: 7),
            _VehicleStrip(report: report, options: options),
            const SizedBox(height: 7),
            _KpiRow(report: report, includeEnergy: options.includeEnergy),
            if (options.includeEnergy) ...[
              const SizedBox(height: 7),
              _TrendCard(report: report),
            ],
            const SizedBox(height: 7),
            _CategorySection(report: report),
            const Spacer(),
            _PaperFooter(report: report),
          ],
        ),
      ),
    );
  }
}

class _PaperHeader extends StatelessWidget {
  const _PaperHeader({required this.report});

  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.charging,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '车小记',
                        style: AppTypography.headlineSm.copyWith(
                          color: palette.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '· AUTO LEDGER',
                        style: AppTypography.labelSm.copyWith(
                          color: palette.outline,
                          fontSize: 7.5,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '用车开销与能耗综合月度分析报告',
                    style: AppTypography.bodySm.copyWith(
                      color: palette.outline,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '生成单号',
                  style: AppTypography.labelSm.copyWith(
                    color: palette.outline,
                    fontSize: 7.5,
                  ),
                ),
                Text(
                  report.reportNo,
                  style: AppTypography.labelMd.copyWith(
                    color: palette.onSurface,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  report.dateLine,
                  style: AppTypography.bodySm.copyWith(
                    color: palette.outline,
                    fontSize: 7.5,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 5),
        Container(height: 1, color: palette.surfaceContainer),
      ],
    );
  }
}

class _VehicleStrip extends StatelessWidget {
  const _VehicleStrip({required this.report, required this.options});

  final MonthlyReport report;
  final ReportOptions options;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final vehicles = report.vehicles;
    final single = vehicles.length == 1 ? vehicles.single : null;
    final icon = vehicles.length > 1
        ? Icons.garage_rounded
        : vehicles.isEmpty
        ? Icons.directions_car_rounded
        : reportPowertrainIcon(vehicles.single.powertrain);
    final plate = single == null
        ? null
        : options.maskPlate
        ? maskPlate(single.plate)
        : single.plate;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: palette.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: palette.surfaceContainer.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: palette.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: palette.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        report.vehicleTitle,
                        style: AppTypography.headlineSm.copyWith(
                          color: palette.onSurface,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (plate != null) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD3E4FE),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          plate,
                          style: AppTypography.labelSm.copyWith(
                            color: palette.onSurfaceVariant,
                            fontSize: 7.5,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  report.vehicleSubtitle,
                  style: AppTypography.bodySm.copyWith(
                    color: palette.outline,
                    fontSize: 8.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '累计总里程',
                style: AppTypography.labelSm.copyWith(
                  color: palette.outline,
                  fontSize: 7.5,
                ),
              ),
              Text(
                vehicles.isEmpty ? '—' : formatKm(report.totalOdometerKm),
                style: AppTypography.labelMd.copyWith(
                  color: palette.onSurface,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.report, required this.includeEnergy});

  final MonthlyReport report;
  final bool includeEnergy;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _KpiCard(
        label: '本月总开销',
        value: formatYuanCompact(report.totalCents),
        note: _TrendNote(report: report),
      ),
      if (includeEnergy)
        _KpiCard(
          label: '综合每公里',
          value: report.costPerKmText,
          valueColor: context.palette.primaryText,
          note: _TextNote(report.energyNote),
        ),
      _KpiCard(
        label: '本月行驶',
        value: report.distanceText,
        mono: true,
        note: _TextNote('公里 · ${report.days}天'),
      ),
    ];

    return SizedBox(
      height: 62,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < cards.length; index++) ...[
            if (index > 0) const SizedBox(width: 5),
            Expanded(child: cards[index]),
          ],
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.note,
    this.valueColor,
    this.mono = false,
  });

  final String label;
  final String value;
  final Widget note;
  final Color? valueColor;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: palette.surfaceContainer.withValues(alpha: 0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelSm.copyWith(
              color: palette.outline,
              fontSize: 8,
              height: 1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: AppTypography.headlineSm.copyWith(
              color: valueColor ?? palette.onSurface,
              fontSize: 15,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              fontFeatures: mono ? const [FontFeature.tabularFigures()] : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          note,
        ],
      ),
    );
  }
}

class _TrendNote extends StatelessWidget {
  const _TrendNote({required this.report});

  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final trend = report.momTrend;
    final color = switch (trend) {
      TrendDirection.up => palette.error,
      TrendDirection.down => palette.primaryText,
      TrendDirection.flat || TrendDirection.none => palette.outline,
    };
    final icon = switch (trend) {
      TrendDirection.up => Icons.trending_up_rounded,
      TrendDirection.down => Icons.trending_down_rounded,
      TrendDirection.flat => Icons.trending_flat_rounded,
      TrendDirection.none => Icons.remove_rounded,
    };
    final text = report.momPercent == null
        ? '较上月 —'
        : formatSignedPercent(report.momPercent!);

    return Row(
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 1),
        Flexible(
          child: Text(
            text,
            style: AppTypography.labelSm.copyWith(color: color, fontSize: 8),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _TextNote extends StatelessWidget {
  const _TextNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.bodySm.copyWith(
        color: context.palette.outline,
        fontSize: 7.5,
        height: 1.1,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.report});

  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final points = report.daily;
    final hasData = points.any((point) => point.totalCents > 0);

    return Container(
      height: 100,
      padding: const EdgeInsets.fromLTRB(7, 6, 7, 5),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: palette.surfaceContainer.withValues(alpha: 0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '每日开销走势',
                style: AppTypography.labelSm.copyWith(
                  color: palette.onSurface,
                  fontSize: 8.5,
                ),
              ),
              const Spacer(),
              _LegendDot(color: palette.primary, label: '充电动能'),
              const SizedBox(width: 7),
              _LegendDot(color: palette.secondary, label: '其他开销'),
            ],
          ),
          const SizedBox(height: 2),
          Expanded(
            child: hasData
                ? _ReportLineChart(points: points)
                : Center(
                    child: Text(
                      '本月暂无开支数据',
                      style: AppTypography.bodySm.copyWith(
                        color: palette.outline,
                        fontSize: 8,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: AppTypography.labelSm.copyWith(
            color: context.palette.outline,
            fontSize: 7.5,
          ),
        ),
      ],
    );
  }
}

class _ReportLineChart extends StatelessWidget {
  const _ReportLineChart({required this.points});

  final List<ReportDailyPoint> points;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final maxCents = points.fold(
      0,
      (max, point) =>
          math.max(max, math.max(point.chargingCents, point.otherCents)),
    );
    final maxY = maxCents <= 0 ? 100.0 : maxCents / 100 * 1.2;
    final peakIndex = _peakIndex(points);
    final tickIndices = <int>{
      0,
      points.length ~/ 4,
      peakIndex,
      points.length * 3 ~/ 4,
      points.length - 1,
    };

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: math.max(1, points.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        clipData: const FlClipData(
          top: false,
          bottom: false,
          left: false,
          right: false,
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 2,
          getDrawingHorizontalLine: (value) => FlLine(
            color: palette.surfaceContainer,
            strokeWidth: 1,
            dashArray: const [3, 3],
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 17,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (!tickIndices.contains(index) ||
                    index < 0 ||
                    index >= points.length) {
                  return const SizedBox.shrink();
                }
                final point = points[index];
                final isPeak = index == peakIndex;
                final category = point.dominantCategory;
                final text = isPeak && category != null
                    ? '${point.date.month}/${point.date.day}\n(${category.label})'
                    : '${point.date.month}/${point.date.day}';
                return Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: AppTypography.labelSm.copyWith(
                      color: isPeak ? palette.secondaryText : palette.outline,
                      fontSize: 6.5,
                      height: 1.1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          _line(
            spots: [
              for (var index = 0; index < points.length; index++)
                FlSpot(index.toDouble(), points[index].chargingCents / 100),
            ],
            color: palette.primary,
            showDots: false,
          ),
          _line(
            spots: [
              for (var index = 0; index < points.length; index++)
                FlSpot(index.toDouble(), points[index].otherCents / 100),
            ],
            color: palette.secondary,
            showDots: true,
            peakIndex: peakIndex,
          ),
        ],
      ),
    );
  }

  LineChartBarData _line({
    required List<FlSpot> spots,
    required Color color,
    required bool showDots,
    int? peakIndex,
  }) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.3,
      preventCurveOverShooting: true,
      barWidth: 1.6,
      isStrokeCapRound: true,
      color: color,
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.26), color.withValues(alpha: 0)],
        ),
      ),
      dotData: FlDotData(
        show: showDots,
        checkToShowDot: (spot, bar) =>
            peakIndex != null && spot.x.round() == peakIndex,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 2.6,
          color: color,
          strokeWidth: 1.2,
          strokeColor: Colors.white,
        ),
      ),
    );
  }

  int _peakIndex(List<ReportDailyPoint> points) {
    var bestIndex = 0;
    var best = -1;
    for (var index = 0; index < points.length; index++) {
      final total = points[index].totalCents;
      if (total > best) {
        best = total;
        bestIndex = index;
      }
    }
    return bestIndex;
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.report});

  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final groups = report.categories
        .where((group) => group.count > 0 || group.amountCents != 0)
        .toList(growable: false);
    final barGroups = groups
        .where((group) => group.amountCents > 0)
        .toList(growable: false);
    final rows = <Widget>[];
    for (var index = 0; index < groups.length; index += 2) {
      rows.add(
        Row(
          children: [
            Expanded(child: _LegendItem(group: groups[index])),
            const SizedBox(width: 8),
            Expanded(
              child: index + 1 < groups.length
                  ? _LegendItem(group: groups[index + 1])
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '分类支出核算明细',
              style: AppTypography.labelSm.copyWith(
                color: palette.onSurface,
                fontSize: 8.5,
              ),
            ),
            const Spacer(),
            Text(
              '共 ${report.recordCount} 笔收支',
              style: AppTypography.labelSm.copyWith(
                color: palette.outline,
                fontSize: 7.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 8,
            child: barGroups.isEmpty
                ? ColoredBox(color: palette.surfaceContainer)
                : Row(
                    children: [
                      for (final group in barGroups)
                        Expanded(
                          flex: group.amountCents.clamp(1, 1 << 30).toInt(),
                          child: ColoredBox(
                            color: reportCategoryColor(group.key),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 5),
        if (groups.isEmpty)
          Text(
            '本月暂无可核算支出',
            style: AppTypography.bodySm.copyWith(
              color: palette.outline,
              fontSize: 8,
            ),
          )
        else
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) const SizedBox(height: 1),
            rows[index],
          ],
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.group});

  final ReportCategoryGroup group;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final percent = group.percent;
    final amount =
        '${formatYuanCompact(group.amountCents)}'
        '${percent == null ? '' : ' ($percent%)'}';

    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: reportCategoryColor(group.key),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            group.label,
            style: AppTypography.bodySm.copyWith(
              color: palette.onSurface,
              fontSize: 7.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          amount,
          style: AppTypography.labelSm.copyWith(
            color: palette.outline,
            fontSize: 7.5,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          maxLines: 1,
        ),
      ],
    );
  }
}

class _PaperFooter extends StatelessWidget {
  const _PaperFooter({required this.report});

  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final verified = report.verified;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DashedLine(color: palette.outlineVariant.withValues(alpha: 0.5)),
        const SizedBox(height: 5),
        Row(
          children: [
            Icon(
              verified ? Icons.verified_rounded : Icons.info_outline_rounded,
              size: 11,
              color: verified ? palette.primary : palette.outline,
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                report.verificationText,
                style: AppTypography.labelSm.copyWith(
                  color: verified ? palette.primary : palette.outline,
                  fontSize: 7.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: palette.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '车小记 · 月度报表',
                style: AppTypography.labelSm.copyWith(
                  color: palette.primaryText,
                  fontSize: 7,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: CustomPaint(painter: _DashedLinePainter(color: color)),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 3.0;
    const gap = 3.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(math.min(x + dash, size.width), 0),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 预览骨架，保持与纸张相同的比例。
class ReportPaperSkeleton extends StatelessWidget {
  const ReportPaperSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = width * reportPaperHeight / reportPaperWidth;
        return SizedBox(
          width: width,
          height: height,
          child: Theme(
            data: reportPaperTheme(),
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.noScaling),
              child: Container(
                padding: const EdgeInsets.all(reportPaperPadding),
                decoration: BoxDecoration(
                  color: AppPalette.light.surface,
                  borderRadius: BorderRadius.circular(reportPaperRadius),
                  boxShadow: reportPaperShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        SkeletonBox(width: 110, height: 14, radius: 5),
                        Spacer(),
                        SkeletonBox(width: 70, height: 12, radius: 5),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const SkeletonBox(height: 52, radius: 12),
                    const SizedBox(height: 10),
                    const Row(
                      children: [
                        Expanded(child: SkeletonBox(height: 62, radius: 12)),
                        SizedBox(width: 5),
                        Expanded(child: SkeletonBox(height: 62, radius: 12)),
                        SizedBox(width: 5),
                        Expanded(child: SkeletonBox(height: 62, radius: 12)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const SkeletonBox(height: 100, radius: 12),
                    const SizedBox(height: 10),
                    const SkeletonBox(height: 70, radius: 8),
                    const Spacer(),
                    const SkeletonBox(height: 16, radius: 5),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
