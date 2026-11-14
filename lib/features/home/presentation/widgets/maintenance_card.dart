import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/format/formatters.dart';
import '../../domain/home_models.dart';
import '../../domain/providers.dart';
import 'home_card.dart';

class MaintenanceCard extends ConsumerWidget {
  const MaintenanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleId = ref.watch(selectedVehicleIdProvider);
    final dashboard = ref.watch(homeDashboardProvider(vehicleId));

    return dashboard.when(
      loading: () => const _MaintenanceSkeleton(),
      error: (error, stack) => SectionError(
        onRetry: () => ref.invalidate(homeDashboardProvider(vehicleId)),
        message: '保养数据加载失败',
      ),
      data: (data) => _MaintenanceContent(maintenance: data.maintenance),
    );
  }
}

class _MaintenanceContent extends StatelessWidget {
  const _MaintenanceContent({required this.maintenance});

  final Maintenance maintenance;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final warning = maintenance.isWarning || maintenance.isOverdue;
    final accent = warning ? palette.error : palette.secondary;
    final accentSoft = warning
        ? palette.errorSoft
        : palette.secondary.withValues(alpha: 0.14);

    return HomeCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: accentSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.build_rounded, size: 16, color: accent),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '下次保养',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMd.copyWith(
                    color: palette.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!maintenance.enabled)
            _SetupMaintenance(onTap: () => _toast(context))
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatKmValue(maintenance.remainingKm.abs()),
                        maxLines: 1,
                        style: AppTypography.headlineLg.copyWith(
                          color: palette.onSurface,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      _MaintenanceDescription(
                        maintenance: maintenance,
                        errorColor: palette.error,
                        mutedColor: palette.outline,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: (maintenance.progressPercent / 100).clamp(0, 1),
                    ),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return CustomPaint(
                        painter: _RingPainter(
                          progress: value,
                          color: accent,
                          trackColor: palette.surfaceContainer,
                          strokeWidth: 3.5,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _toast(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('保养提醒设置待接入'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          duration: const Duration(seconds: 2),
        ),
      );
  }
}

class _MaintenanceDescription extends StatelessWidget {
  const _MaintenanceDescription({
    required this.maintenance,
    required this.errorColor,
    required this.mutedColor,
  });

  final Maintenance maintenance;
  final Color errorColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final baseStyle = AppTypography.bodySm.copyWith(color: mutedColor);
    if (maintenance.isOverdue) {
      return Text(
        '已超期 ${formatKmValue(maintenance.remainingKm.abs())} km',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: baseStyle.copyWith(color: errorColor),
      );
    }

    final days = maintenance.remainingDays;
    final suffix = maintenance.isWarning ? '（即将保养）' : '';
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'km 后${days == null ? '' : ' · 约 $days 天'}'),
          if (suffix.isNotEmpty)
            TextSpan(
              text: suffix,
              style: baseStyle.copyWith(
                color: errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: baseStyle,
    );
  }
}

class _SetupMaintenance extends StatelessWidget {
  const _SetupMaintenance({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(
          Icons.add_alert_rounded,
          size: 16,
          color: palette.primaryText,
        ),
        label: Text(
          '设置保养提醒',
          style: AppTypography.labelMd.copyWith(color: palette.primaryText),
        ),
      ),
    );
  }
}

class _MaintenanceSkeleton extends StatelessWidget {
  const _MaintenanceSkeleton();

  @override
  Widget build(BuildContext context) {
    return const HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 88, height: 12),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 64, height: 24, radius: 8),
                    SizedBox(height: 8),
                    SkeletonBox(width: 80, height: 10),
                  ],
                ),
              ),
              SkeletonBox(width: 44, height: 44, radius: 22),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
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
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
