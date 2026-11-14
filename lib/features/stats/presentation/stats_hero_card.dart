import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/domain/enums.dart';
import '../../../core/format/formatters.dart';
import '../../../core/widgets/hero_wave_background.dart';
import '../../../core/widgets/section_error.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../domain/providers.dart';
import '../domain/stats_models.dart';
import '../domain/stats_presenter.dart';

class StatsHeroCard extends ConsumerWidget {
  const StatsHeroCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(statsFilterProvider);
    final scope = filter.toScope();
    final overview = ref.watch(statsOverviewProvider(scope));

    return overview.when(
      loading: () => const _HeroSkeleton(),
      error: (error, stack) => SectionError(
        onRetry: () => ref.invalidate(statsOverviewProvider(scope)),
        message: '汇总加载失败',
      ),
      data: (data) => _HeroContent(overview: data),
    );
  }
}

class _HeroContent extends StatelessWidget {
  const _HeroContent({required this.overview});

  final StatsOverview overview;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final summary = overview.summary;
    final range = overview.range;
    final isUp = summary.changeTrend == TrendDirection.up;

    final badgeIcon = switch (summary.changeTrend) {
      TrendDirection.up => Icons.trending_up_rounded,
      TrendDirection.down => Icons.trending_down_rounded,
      TrendDirection.flat || TrendDirection.none => Icons.remove_rounded,
    };
    final badgeText = changeLabel(
      range: range,
      trend: summary.changeTrend,
      percent: summary.changePercent,
      changeText: summary.changeText,
    );
    final costSemantic = summary.costPerKmCents == null
        ? '暂无每公里成本'
        : '${formatTwoDecimals(summary.costPerKmCents! / 100)} 元每公里';

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '综合每公里成本 $costSemantic，$badgeText',
      child: Container(
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
              const Positioned.fill(child: HeroWaveBackground()),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _Pill(
                              icon: Icons.speed_rounded,
                              text: heroPeriodLabel(
                                overview.scope.period,
                                range,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _Pill(
                          icon: badgeIcon,
                          text: badgeText,
                          background: isUp
                              ? AppColors.rise.withValues(alpha: 0.30)
                              : Colors.white.withValues(alpha: 0.25),
                          border: isUp
                              ? AppColors.rise.withValues(alpha: 0.35)
                              : Colors.white.withValues(alpha: 0.20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '¥',
                          style: AppTypography.headlineLg.copyWith(
                            color: Colors.white.withValues(alpha: 0.90),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              summary.costPerKmCents == null
                                  ? '—'
                                  : formatTwoDecimals(
                                      summary.costPerKmCents! / 100,
                                    ),
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
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '/km',
                          style: AppTypography.bodyMd.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.only(top: 14),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.20),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          _HeroMetric(
                            label: periodSubLabel(range),
                            value: formatYuanCompact(summary.totalCents),
                            align: TextAlign.left,
                          ),
                          _divider(),
                          _HeroMetric(
                            label: periodMileageLabel(range),
                            value: formatKmValue(summary.distanceKm),
                            unit: ' km',
                            align: TextAlign.center,
                          ),
                          _divider(),
                          _HeroMetric(
                            label: energyCostTitle(overview.powertrain),
                            value: costPerKmText(summary.energyCostPerKmCents),
                            unit: '/km',
                            align: TextAlign.right,
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
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: Colors.white.withValues(alpha: 0.20),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.text,
    this.background,
    this.border,
  });

  final IconData icon;
  final String text;
  final Color? background;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        border: Border.all(
          color: border ?? Colors.white.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelMd.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.align,
    this.unit,
  });

  final String label;
  final String value;
  final TextAlign align;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: switch (align) {
          TextAlign.center => CrossAxisAlignment.center,
          TextAlign.right => CrossAxisAlignment.end,
          _ => CrossAxisAlignment.start,
        },
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: align,
            style: AppTypography.bodySm.copyWith(
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: switch (align) {
              TextAlign.center => Alignment.center,
              TextAlign.right => Alignment.centerRight,
              _ => Alignment.centerLeft,
            },
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
