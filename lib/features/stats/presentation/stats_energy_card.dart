import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/domain/enums.dart';
import '../../../core/presentation/category_style.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_error.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../../core/widgets/sparkline.dart';
import '../domain/providers.dart';
import '../domain/stats_models.dart';
import '../domain/stats_presenter.dart';

class StatsEnergyCard extends ConsumerWidget {
  const StatsEnergyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(statsFilterProvider);
    final scope = filter.toScope();
    final overview = ref.watch(statsOverviewProvider(scope));

    return overview.when(
      loading: () => const _EnergySkeleton(),
      error: (error, stack) => SectionError(
        onRetry: () => ref.invalidate(statsOverviewProvider(scope)),
        message: '能耗加载失败',
      ),
      data: (data) => _EnergyContent(
        consumption: data.consumption,
        powertrain: data.powertrain,
      ),
    );
  }
}

class _EnergyContent extends StatelessWidget {
  const _EnergyContent({required this.consumption, required this.powertrain});

  final StatsConsumption consumption;
  final PowertrainType? powertrain;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final primary = consumption.primary;
    final secondary = consumption.secondary;
    final icon = powertrain?.icon ?? Icons.auto_graph_rounded;
    final valueText = primary.value == null
        ? '—'
        : formatEnergyValue(primary.value!, primary.unit);
    final unitText = consumptionUnit(primary.unit);
    final valueSemantic = primary.value == null
        ? '暂无数据'
        : '${formatEnergyValue(primary.value!, primary.unit)} $unitText';
    final semantic =
        '${consumptionTitle(powertrain)} $valueSemantic，'
        '评级${ratingLabel(consumption.rating)}';

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: semantic,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: palette.primaryText),
                ),
                const Spacer(),
                _RatingChip(rating: consumption.rating),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              consumptionTitle(powertrain),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySm.copyWith(color: palette.outline),
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    valueText,
                    maxLines: 1,
                    style: AppTypography.headlineLg.copyWith(
                      color: palette.onSurface,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    unitText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSm.copyWith(
                      color: palette.outline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (secondary != null && secondary.value != null) ...[
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: palette.surfaceContainer),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      formatEnergyValue(secondary.value!, secondary.unit),
                      style: AppTypography.metricSub.copyWith(
                        color: palette.secondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      consumptionUnit(secondary.unit),
                      style: AppTypography.labelSm.copyWith(
                        color: palette.outline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Spacer(),
            const SizedBox(height: 12),
            SizedBox(
              height: 32,
              width: double.infinity,
              child: CustomPaint(
                painter: SparklinePainter(
                  primary: consumption.sparkline,
                  primaryColor: palette.primary,
                  secondaryColor: palette.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.rating});

  final StatsRating rating;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final (background, foreground) = switch (rating) {
      StatsRating.high => (palette.errorSoft, palette.error),
      StatsRating.fleet => (
        palette.tertiary.withValues(alpha: 0.12),
        palette.tertiary,
      ),
      StatsRating.none => (palette.surfaceContainer, palette.outline),
      _ => (palette.surfaceContainer, palette.outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(tokens.radiusPill),
      ),
      child: Text(
        ratingLabel(rating),
        style: AppTypography.labelSm.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EnergySkeleton extends StatelessWidget {
  const _EnergySkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 32, height: 32, radius: 16),
          SizedBox(height: 12),
          SkeletonBox(width: 88, height: 10),
          SizedBox(height: 6),
          SkeletonBox(width: 70, height: 24, radius: 8),
          SizedBox(height: 16),
          SkeletonBox(height: 32, radius: 8),
        ],
      ),
    );
  }
}
