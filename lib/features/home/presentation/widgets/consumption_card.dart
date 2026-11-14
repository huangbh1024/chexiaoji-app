import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/format/formatters.dart';
import '../../domain/home_models.dart';
import '../../domain/providers.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/sparkline.dart';
import '../../../../core/widgets/section_error.dart';
import '../../../../core/widgets/skeleton_box.dart';

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

    return AppCard(
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
    return const AppCard(
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
