import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/format/formatters.dart';
import '../../domain/home_models.dart';
import '../../domain/providers.dart';
import '../home_style.dart';
import 'home_card.dart';

class BreakdownCard extends ConsumerWidget {
  const BreakdownCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleId = ref.watch(selectedVehicleIdProvider);
    final breakdown = ref.watch(breakdownProvider(vehicleId));

    return breakdown.when(
      loading: () => const _BreakdownSkeleton(),
      error: (error, stack) => SectionError(
        onRetry: () => ref.invalidate(breakdownProvider(vehicleId)),
        message: '开销构成加载失败',
      ),
      data: (data) => _BreakdownContent(breakdown: data),
    );
  }
}

class _BreakdownContent extends StatelessWidget {
  const _BreakdownContent({required this.breakdown});

  final Breakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final categories = breakdown.categories
        .where((item) => item.amountCents > 0)
        .toList(growable: false);

    return HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '开销构成',
                style: AppTypography.headlineSm.copyWith(
                  color: palette.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.surfaceContainer,
                  borderRadius: BorderRadius.circular(tokens.radiusPill),
                ),
                child: Text(
                  '本月 · ${breakdown.count} 笔',
                  style: AppTypography.labelSm.copyWith(
                    color: palette.outline,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (categories.isEmpty)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  '本月暂无开销',
                  style: AppTypography.bodyMd.copyWith(color: palette.outline),
                ),
              ),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 128,
                  height: 128,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          startDegreeOffset: -90,
                          centerSpaceRadius: 34,
                          sectionsSpace: 2,
                          sections: [
                            for (final item in categories)
                              PieChartSectionData(
                                value: item.amountCents.toDouble(),
                                color: item.category.color,
                                radius: 10,
                                showTitle: false,
                              ),
                          ],
                        ),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '合计',
                            style: AppTypography.bodySm.copyWith(
                              color: palette.outline,
                            ),
                          ),
                          Text(
                            formatYuanCompact(breakdown.totalCents),
                            style: AppTypography.headlineSm.copyWith(
                              color: palette.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < categories.length;
                        index++
                      ) ...[
                        if (index > 0) const SizedBox(height: 4),
                        _CategoryRow(item: categories[index]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.item});

  final BreakdownCategory item;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: item.category.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            item.category.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelMd.copyWith(
              color: palette.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          formatYuanCompact(item.amountCents),
          style: AppTypography.labelMd.copyWith(
            color: palette.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 26,
          child: Text(
            formatPercentInt(item.percent),
            textAlign: TextAlign.right,
            style: AppTypography.labelSm.copyWith(
              color: palette.outline,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _BreakdownSkeleton extends StatelessWidget {
  const _BreakdownSkeleton();

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              SkeletonBox(width: 80, height: 16),
              Spacer(),
              SkeletonBox(width: 64, height: 16),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const SkeletonBox(width: 128, height: 128, radius: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    for (var i = 0; i < 4; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      const Row(
                        children: [
                          SkeletonBox(width: 8, height: 8, radius: 4),
                          SizedBox(width: 6),
                          SkeletonBox(width: 40, height: 10),
                          Spacer(),
                          SkeletonBox(width: 44, height: 10),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
