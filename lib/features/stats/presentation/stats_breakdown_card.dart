import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/tab.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/domain/enums.dart';
import '../../../core/format/formatters.dart';
import '../../../core/presentation/category_style.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../ledger/domain/ledger_models.dart';
import '../../ledger/domain/providers.dart';
import '../domain/providers.dart';
import '../domain/stats_models.dart';
import '../domain/stats_period.dart';
import '../domain/stats_presenter.dart';

class StatsBreakdownCard extends ConsumerWidget {
  const StatsBreakdownCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final filter = ref.watch(statsFilterProvider);
    final scope = filter.toScope();
    final breakdown = ref.watch(statsBreakdownProvider(scope));
    final range = resolveStatsRange(filter.period, filter.anchor);

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '开销构成分析',
                style: AppTypography.headlineSm.copyWith(
                  color: palette.onSurface,
                ),
              ),
              const Spacer(),
              breakdown.maybeWhen(
                data: (data) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surfaceContainer,
                    borderRadius: BorderRadius.circular(
                      context.tokens.radiusPill,
                    ),
                  ),
                  child: Text(
                    breakdownBadge(range, data.count),
                    style: AppTypography.labelSm.copyWith(
                      color: palette.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          breakdown.when(
            loading: () => const _BreakdownSkeleton(),
            error: (error, stack) => SizedBox(
              height: 128,
              child: Center(
                child: TextButton.icon(
                  onPressed: () =>
                      ref.invalidate(statsBreakdownProvider(scope)),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('构成加载失败，点击重试'),
                ),
              ),
            ),
            data: (data) => data.isEmpty
                ? _EmptyBreakdown(count: data.count)
                : _BreakdownContent(
                    breakdown: data,
                    onTap: (slice) => _openLedger(ref, filter, range, slice),
                  ),
          ),
        ],
      ),
    );
  }

  void _openLedger(
    WidgetRef ref,
    StatsFilter filter,
    StatsRange range,
    StatsCategorySlice slice,
  ) {
    final ledgerFilter = ref.read(ledgerFilterProvider.notifier);
    ledgerFilter.selectVehicle(filter.vehicleId);
    ledgerFilter.selectMonth(monthStart(range.end));
    if (slice.category == ExpenseCategory.other) {
      ledgerFilter.selectCategory(null);
    } else {
      ledgerFilter.selectCategory(slice.category);
    }
    ref.read(appTabProvider.notifier).select(AppTab.ledger);
  }
}

class _BreakdownContent extends StatelessWidget {
  const _BreakdownContent({required this.breakdown, required this.onTap});

  final StatsBreakdown breakdown;
  final ValueChanged<StatsCategorySlice> onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
                  centerSpaceRadius: 50,
                  sectionsSpace: 2,
                  sections: [
                    for (final slice in breakdown.categories)
                      PieChartSectionData(
                        value: slice.amountCents.toDouble(),
                        color: slice.category.color,
                        radius: 14,
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
                    '合计支出',
                    style: AppTypography.labelSm.copyWith(
                      color: palette.outline,
                      fontWeight: FontWeight.w400,
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
              for (var index = 0; index < breakdown.categories.length; index++)
                Padding(
                  padding: EdgeInsets.only(top: index == 0 ? 0 : 6),
                  child: _LegendRow(
                    slice: breakdown.categories[index],
                    onTap: () => onTap(breakdown.categories[index]),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.slice, required this.onTap});

  final StatsCategorySlice slice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: slice.category.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                slice.category.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMd.copyWith(
                  color: palette.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              formatYuanCompact(slice.amountCents),
              style: AppTypography.headlineSm.copyWith(
                color: palette.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 30,
              child: Text(
                '${slice.percent}%',
                textAlign: TextAlign.right,
                style: AppTypography.labelSm.copyWith(
                  color: palette.outline,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBreakdown extends StatelessWidget {
  const _EmptyBreakdown({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        SizedBox(
          width: 128,
          height: 128,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: palette.surfaceContainer,
                    width: 28,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '合计支出',
                    style: AppTypography.labelSm.copyWith(
                      color: palette.outline,
                    ),
                  ),
                  Text(
                    '¥0.00',
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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '该周期暂无开销',
                style: AppTypography.bodyMd.copyWith(
                  color: palette.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '共 $count 笔记录',
                style: AppTypography.bodySm.copyWith(color: palette.outline),
              ),
            ],
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
    return Row(
      children: const [
        SkeletonBox(width: 128, height: 128, radius: 64),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              SkeletonBox(height: 16),
              SizedBox(height: 8),
              SkeletonBox(height: 16),
              SizedBox(height: 8),
              SkeletonBox(height: 16),
              SizedBox(height: 8),
              SkeletonBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}
