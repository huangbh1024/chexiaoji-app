import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/format/formatters.dart';
import '../../domain/home_models.dart';
import '../../domain/providers.dart';
import 'home_card.dart';

class ConsumptionCard extends ConsumerWidget {
  const ConsumptionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleId = ref.watch(selectedVehicleIdProvider);
    final dashboard = ref.watch(homeDashboardProvider(vehicleId));

    return dashboard.when(
      loading: () => const _ConsumptionSkeleton(),
      error: (error, stack) => SectionError(
        onRetry: () => ref.invalidate(homeDashboardProvider(vehicleId)),
        message: '能耗数据加载失败',
      ),
      data: (data) => _ConsumptionContent(consumption: data.consumption),
    );
  }
}

class _ConsumptionContent extends StatelessWidget {
  const _ConsumptionContent({required this.consumption});

  final Consumption consumption;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final hasSecondary = consumption.secondary != null;

    return HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.speed_rounded,
                  size: 16,
                  color: palette.primary,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  consumption.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMd.copyWith(
                    color: palette.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: palette.surfaceContainer,
                  borderRadius: BorderRadius.circular(tokens.radiusPill),
                ),
                child: Text(
                  consumption.typeLabel,
                  maxLines: 1,
                  style: AppTypography.labelSm.copyWith(
                    color: palette.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatOneDecimal(consumption.primary.value),
                style: AppTypography.metric.copyWith(color: palette.onSurface),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  consumption.primary.unit,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySm.copyWith(
                    fontSize: 10,
                    color: palette.outline,
                  ),
                ),
              ),
            ],
          ),
          if (hasSecondary) ...[
            Container(
              margin: const EdgeInsets.only(top: 5),
              padding: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: palette.surfaceContainer, width: 1),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    formatOneDecimal(consumption.secondary!.value),
                    style: AppTypography.metricSub.copyWith(
                      color: palette.secondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      consumption.secondary!.unit,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySm.copyWith(
                        fontSize: 10,
                        color: palette.outline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            width: double.infinity,
            child: CustomPaint(
              painter: SparklinePainter(
                primary: consumption.primarySparkline,
                secondary: consumption.secondarySparkline,
                primaryColor: palette.primary,
                secondaryColor: palette.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsumptionSkeleton extends StatelessWidget {
  const _ConsumptionSkeleton();

  @override
  Widget build(BuildContext context) {
    return const HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 100, height: 12),
          SizedBox(height: 14),
          SkeletonBox(width: 72, height: 24, radius: 8),
          SizedBox(height: 12),
          SkeletonBox(height: 32, radius: 8),
        ],
      ),
    );
  }
}

class SparklinePainter extends CustomPainter {
  SparklinePainter({
    required this.primary,
    required this.secondary,
    required this.primaryColor,
    required this.secondaryColor,
  });

  final List<double> primary;
  final List<double> secondary;
  final Color primaryColor;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final all = [...primary, ...secondary];
    if (primary.length < 2 || all.isEmpty) {
      return;
    }
    var minValue = all.reduce(math.min);
    var maxValue = all.reduce(math.max);
    if ((maxValue - minValue).abs() < 0.001) {
      minValue -= 1;
      maxValue += 1;
    }
    const horizontalPadding = 2.0;
    const verticalPadding = 3.0;
    final width = size.width - horizontalPadding * 2;
    final height = size.height - verticalPadding * 2;

    List<Offset> pointsOf(List<double> values) {
      return [
        for (var index = 0; index < values.length; index++)
          Offset(
            horizontalPadding + width * index / (values.length - 1),
            verticalPadding +
                height *
                    (1 - (values[index] - minValue) / (maxValue - minValue)),
          ),
      ];
    }

    final primaryPoints = pointsOf(primary);
    final primaryPath = _smoothPath(primaryPoints);
    final areaPath = Path.from(primaryPath)
      ..lineTo(primaryPoints.last.dx, size.height)
      ..lineTo(primaryPoints.first.dx, size.height)
      ..close();

    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            primaryColor.withValues(alpha: 0.16),
            primaryColor.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      primaryPath,
      Paint()
        ..color = primaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    if (secondary.length >= 2) {
      final secondaryPath = _smoothPath(pointsOf(secondary));
      final paint = Paint()
        ..color = secondaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      for (final metric in secondaryPath.computeMetrics()) {
        var distance = 0.0;
        while (distance < metric.length) {
          final end = math.min(distance + 3, metric.length);
          canvas.drawPath(metric.extractPath(distance, end), paint);
          distance = end + 3;
        }
      }
    }
  }

  Path _smoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      final middle = Offset(
        (previous.dx + current.dx) / 2,
        (previous.dy + current.dy) / 2,
      );
      path.quadraticBezierTo(previous.dx, previous.dy, middle.dx, middle.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  @override
  bool shouldRepaint(covariant SparklinePainter oldDelegate) {
    return oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}
