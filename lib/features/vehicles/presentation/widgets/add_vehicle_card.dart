import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../vehicle_management_style.dart';

class AddVehicleCard extends StatelessWidget {
  const AddVehicleCard({super.key, required this.onTap, this.enabled = true});

  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final borderColor = (enabled ? palette.primary : palette.outlineVariant)
        .withValues(alpha: enabled ? 0.42 : 0.60);

    return CustomPaint(
      painter: _DashedBorderPainter(
        color: borderColor,
        radius: VehicleManagementStyle.cardRadius,
        strokeWidth: 2,
      ),
      child: Material(
        color: palette.surfaceContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(VehicleManagementStyle.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: enabled
                        ? palette.primary.withValues(alpha: 0.12)
                        : palette.surfaceContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    size: 26,
                    color: enabled ? palette.primary : palette.outline,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  enabled ? '添加新座驾到车库' : '车库车辆已达上限',
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineSm.copyWith(
                    color: palette.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  enabled ? '支持快速扫描行驶证或手动配置动力规格' : '先归档不再使用的车辆后再添加',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySm.copyWith(color: palette.outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            strokeWidth / 2,
            strokeWidth / 2,
            size.width - strokeWidth,
            size.height - strokeWidth,
          ),
          Radius.circular(radius),
        ),
      );
    const dash = 7.0;
    const gap = 5.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
