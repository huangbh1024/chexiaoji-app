import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// 圆环进度：底环 + 圆头进度弧，从 12 点方向顺时针。
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    this.size = 44,
    required this.progress,
    required this.color,
    required this.trackColor,
    this.strokeWidth = 3.5,
    this.child,
  });

  final double size;

  /// 0–1，超出会钳制。
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: ProgressRingPainter(
              progress: progress,
              color: color,
              trackColor: trackColor,
              strokeWidth: strokeWidth,
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}

class ProgressRingPainter extends CustomPainter {
  ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2 - 1;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (progress <= 0) {
      return;
    }
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
