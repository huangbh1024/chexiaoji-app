import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/format/formatters.dart';
import '../../domain/home_models.dart';
import '../../domain/providers.dart';
import '../../../../core/widgets/section_error.dart';
import '../../../../core/widgets/skeleton_box.dart';

class HeroCard extends ConsumerWidget {
  const HeroCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleId = ref.watch(selectedVehicleIdProvider);
    final dashboard = ref.watch(homeDashboardProvider(vehicleId));

    return dashboard.when(
      loading: () => const _HeroSkeleton(),
      error: (error, stack) => SectionError(
        onRetry: () => ref.invalidate(homeDashboardProvider(vehicleId)),
        message: '本月数据加载失败',
      ),
      data: (data) => _HeroContent(dashboard: data),
    );
  }
}

class _HeroContent extends StatelessWidget {
  const _HeroContent({required this.dashboard});

  final HomeDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final summary = dashboard.summary;
    final percent = summary.momChangePercent;
    final isUp = summary.momTrend == TrendDirection.up;
    final isDown = summary.momTrend == TrendDirection.down;

    final badgeBackground = isUp
        ? AppColors.rise.withValues(alpha: 0.30)
        : Colors.white.withValues(alpha: 0.20);
    final badgeBorder = isUp
        ? AppColors.rise.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.20);
    final badgeIcon = isUp
        ? Icons.trending_up_rounded
        : isDown
        ? Icons.trending_down_rounded
        : Icons.remove_rounded;
    final badgeText = percent == null
        ? '较上月 —'
        : '较上月 ${formatSignedPercent(percent)}';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.heroStart, palette.heroMid, palette.heroEnd],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
        boxShadow: tokens.heroShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        child: Stack(
          children: [
            Positioned(
              right: -56,
              top: -56,
              child: Container(
                width: 176,
                height: 176,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.24),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -64,
              bottom: -64,
              child: Container(
                width: 192,
                height: 192,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF63FCC0).withValues(alpha: 0.20),
                      const Color(0xFF63FCC0).withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _HeroWavePainter()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.speed_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '综合每公里成本 · 本月',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelMd.copyWith(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBackground,
                          borderRadius: BorderRadius.circular(
                            tokens.radiusPill,
                          ),
                          border: Border.all(color: badgeBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(badgeIcon, size: 12, color: Colors.white),
                            const SizedBox(width: 2),
                            Text(
                              badgeText,
                              style: AppTypography.labelSm.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '¥',
                          style: AppTypography.headlineLg.copyWith(
                            color: Colors.white.withValues(alpha: 0.90),
                          ),
                        ),
                        TextSpan(
                          text: formatTwoDecimals(summary.costPerKm),
                          style: AppTypography.displayHero.copyWith(
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        TextSpan(
                          text: ' /km',
                          style: AppTypography.bodyMd.copyWith(
                            color: Colors.white.withValues(alpha: 0.80),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(tokens.radiusCard),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Row(
                      children: [
                        _Metric(
                          label: '本月花费',
                          value: formatYuanCompact(summary.monthSpendCents),
                        ),
                        _divider(),
                        _Metric(
                          label: '本月里程',
                          value: formatKmValue(summary.monthMileageKm),
                          unit: ' km',
                        ),
                        _divider(),
                        _Metric(
                          label: '能源成本',
                          value:
                              '¥${formatTwoDecimals(summary.energyCostPerKm)}',
                          unit: '/km',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white.withValues(alpha: 0.20),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.unit});

  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySm.copyWith(
              color: Colors.white.withValues(alpha: 0.80),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: AppTypography.headlineSm.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  if (unit != null)
                    TextSpan(
                      text: unit,
                      style: AppTypography.bodySm.copyWith(
                        color: Colors.white.withValues(alpha: 0.80),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    return Container(
      height: 196,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surfaceContainer,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 150, height: 12),
          const SizedBox(height: 16),
          const SkeletonBox(width: 120, height: 38, radius: 10),
          const Spacer(),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 24),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 48, height: 10),
                      SizedBox(height: 6),
                      SkeletonBox(width: 64, height: 16),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroWavePainter extends CustomPainter {
  const _HeroWavePainter();

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
