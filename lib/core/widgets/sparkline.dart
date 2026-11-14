import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// 迷你走势：平滑曲线 + 渐变填充，可选第二条虚线。
///
/// 首页能耗卡与统计页能耗卡共用；数据少于 2 个点时不绘制。
class SparklinePainter extends CustomPainter {
  SparklinePainter({
    required this.primary,
    this.secondary = const <double>[],
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
