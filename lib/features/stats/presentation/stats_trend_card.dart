import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/domain/enums.dart';
import '../../../core/format/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../domain/providers.dart';
import '../domain/stats_models.dart';
import '../domain/stats_period.dart';
import '../domain/stats_presenter.dart';
import 'stats_trend_chart.dart';

class StatsTrendCard extends ConsumerWidget {
  const StatsTrendCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final tokens = context.tokens;
    final filter = ref.watch(statsFilterProvider);
    final range = ref.watch(statsTrendRangeProvider);
    final query = StatsTrendQuery(
      vehicleId: filter.vehicleId,
      range: range,
      anchor: filter.anchor,
    );
    final trend = ref.watch(statsTrendProvider(query));

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '花费趋势与开销走势',
                style: AppTypography.headlineSm.copyWith(
                  color: palette.onSurface,
                ),
              ),
              const Spacer(),
              const _Legend(),
            ],
          ),
          const SizedBox(height: 6),
          trend.when(
            loading: () => const _TrendHeaderSkeleton(),
            error: (error, stack) => Text(
              '走势加载失败',
              style: AppTypography.bodyMd.copyWith(color: palette.outline),
            ),
            data: (data) => _TrendHeader(trend: data),
          ),
          const SizedBox(height: 12),
          _RangeSwitcher(
            selected: range,
            onSelect: (next) =>
                ref.read(statsTrendRangeProvider.notifier).select(next),
          ),
          const SizedBox(height: 14),
          trend.when(
            loading: () => const _TrendChartSkeleton(),
            error: (error, stack) => SizedBox(
              height: 176,
              child: Center(
                child: TextButton.icon(
                  onPressed: () => ref.invalidate(statsTrendProvider(query)),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('走势加载失败，点击重试'),
                ),
              ),
            ),
            data: (data) => Semantics(
              container: true,
              excludeSemantics: true,
              label: _trendSemantics(data),
              child: StatsTrendChart(trend: data),
            ),
          ),
          SizedBox(height: tokens.spaceXs),
        ],
      ),
    );
  }
}

String _trendSemantics(StatsTrend trend) {
  if (trend.isEmpty) {
    return '${trend.query.range.windowLabel}暂无开销记录';
  }
  final base =
      '${trend.query.range.windowLabel}花费 ${formatYuanCompact(trend.totalCents)}';
  final index = trend.peakIndex;
  if (index == null || index >= trend.buckets.length) {
    return base;
  }
  final peak = trend.buckets[index];
  return '$base，峰值 ${peak.label} ${formatYuanCompact(peak.totalCents)}';
}

class _TrendHeader extends StatelessWidget {
  const _TrendHeader({required this.trend});

  final StatsTrend trend;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final direction = trend.changeTrend;
    final color = switch (direction) {
      TrendDirection.up => palette.error,
      TrendDirection.down => palette.primaryText,
      TrendDirection.flat || TrendDirection.none => palette.outline,
    };
    final icon = switch (direction) {
      TrendDirection.up => Icons.arrow_drop_up_rounded,
      TrendDirection.down => Icons.arrow_drop_down_rounded,
      TrendDirection.flat || TrendDirection.none => Icons.remove_rounded,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          formatYuanCompact(trend.totalCents),
          style: AppTypography.headlineMd.copyWith(
            color: palette.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 14, color: color),
        Flexible(
          child: Text(
            trendChangeLabel(trend),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSm.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          trend.query.range.windowLabel,
          style: AppTypography.labelSm.copyWith(
            color: palette.outline,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _LegendRow(color: palette.primary, label: '能源(充/油)'),
        const SizedBox(height: 4),
        _LegendRow(color: palette.secondary, label: '其他开销'),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTypography.labelSm.copyWith(
            color: context.palette.outline,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _RangeSwitcher extends StatelessWidget {
  const _RangeSwitcher({required this.selected, required this.onSelect});

  final StatsTrendRange selected;
  final ValueChanged<StatsTrendRange> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.surfaceContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(tokens.radiusCard),
      ),
      child: Row(
        children: [
          for (final range in StatsTrendRange.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelect(range),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    color: selected == range
                        ? palette.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(tokens.radiusChip),
                    boxShadow: selected == range
                        ? [
                            BoxShadow(
                              color: palette.shadow.withValues(alpha: 0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      range.label,
                      style: AppTypography.labelMd.copyWith(
                        color: selected == range
                            ? palette.onSurface
                            : palette.outline,
                        fontWeight: selected == range
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrendHeaderSkeleton extends StatelessWidget {
  const _TrendHeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 4),
      child: SkeletonBox(width: 160, height: 18, radius: 6),
    );
  }
}

class _TrendChartSkeleton extends StatelessWidget {
  const _TrendChartSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 176,
      child: SkeletonBox(height: 176, radius: 12),
    );
  }
}
