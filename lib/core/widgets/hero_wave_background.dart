import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Hero 卡的有机波浪与光斑装饰。
///
/// 首页与统计页共用；置于渐变容器内、内容层之下。
class HeroWaveBackground extends StatelessWidget {
  const HeroWaveBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -56,
            top: -56,
            child: _Glow(size: 176, color: Colors.white, opacity: 0.24),
          ),
          Positioned(
            left: -64,
            bottom: -64,
            child: _Glow(size: 192, color: Color(0xFF63FCC0), opacity: 0.20),
          ),
          CustomPaint(painter: HeroWavePainter()),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color, required this.opacity});

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class HeroWavePainter extends CustomPainter {
  const HeroWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 340, size.height / 180);

    final fill = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final fillPath = Path()
      ..moveTo(-20, 70)
      ..cubicTo(60, 30, 140, 130, 240, 60)
      ..cubicTo(300, 20, 330, 80, 380, 50)
      ..lineTo(380, 200)
      ..lineTo(-20, 200)
      ..close();
    canvas.drawPath(fillPath, fill);

    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final linePath = Path()
      ..moveTo(-10, 110)
      ..cubicTo(70, 80, 160, 140, 260, 90)
      ..cubicTo(310, 65, 340, 110, 380, 95);
    for (final metric in linePath.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + 4, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), stroke);
        distance = end + 4;
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
