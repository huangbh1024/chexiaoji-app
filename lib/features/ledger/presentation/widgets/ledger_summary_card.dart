import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/money_display.dart';
import '../../../../core/widgets/section_error.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../../domain/ledger_models.dart';
import '../../domain/providers.dart';
import 'ledger_daily_bars.dart';
import 'ledger_month_picker_sheet.dart';

/// 月度汇总卡：月份、环比、总额、三列子指标与日开销柱状图。
///
/// 只跟随「月份 + 车辆」筛选，不随分类筛选变化。
class LedgerSummaryCard extends ConsumerWidget {
  const LedgerSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(ledgerFilterProvider);
    final scope = LedgerScope(
      month: filter.month,
      vehicleId: filter.vehicleId,
    );
    final summary = ref.watch(ledgerSummaryProvider(scope));

    return summary.when(
      loading: () => const _SummarySkeleton(),
      error: (error, stack) => SectionError(
        message: '汇总加载失败',
        onRetry: () => ref.invalidate(ledgerSummaryProvider(scope)),
      ),
      data: (data) => _SummaryContent(
        summary: data,
        onPickMonth: () async {
          final picked = await showLedgerMonthPicker(context, filter.month);
          if (picked != null) {
            ref.read(ledgerFilterProvider.notifier).selectMonth(picked);
          }
        },
      ),
    );
  }
}

class _SummaryContent extends StatelessWidget {
  const _SummaryContent({required this.summary, required this.onPickMonth});

  final LedgerMonthSummary summary;
  final VoidCallback onPickMonth;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final radius = BorderRadius.circular(tokens.radiusSummary);

    return AppCard(
      radius: tokens.radiusSummary,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(
              right: -56,
              top: -56,
              child: _Glow(
                size: 176,
                color: palette.primary.withValues(alpha: 0.14),
              ),
            ),
            Positioned(
              left: -48,
              bottom: -56,
              child: _Glow(
                size: 144,
                color: palette.tertiary.withValues(alpha: 0.12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _MonthPill(
                        month: summary.month,
                        onTap: onPickMonth,
                      ),
                      const Spacer(),
                      _MomPill(
                        percent: summary.momPercent,
                        trend: summary.momTrend,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: MoneyDisplay(cents: summary.totalCents),
                      ),
                      Text(
                        '共 ${summary.count} 笔支出',
                        style: AppTypography.labelMd.copyWith(
                          color: palette.outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: palette.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _Metric(
                            label: '能源电油',
                            value: formatYuanDetail(summary.energyCents),
                            color: palette.primary,
                          ),
                        ),
                        const _VerticalDivider(),
                        Expanded(
                          child: _Metric(
                            label: '维保服务',
                            value: formatYuanDetail(summary.serviceCents),
                            color: palette.secondary,
                          ),
                        ),
                        const _VerticalDivider(),
                        Expanded(
                          child: _Metric(
                            label: '日均开支',
                            value: formatYuanDetail(summary.dailyAverageCents),
                            color: palette.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        '当月日开销波动',
                        style: AppTypography.labelSm.copyWith(
                          color: palette.outline,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        summary.peakDate == null
                            ? '本月还没有记录'
                            : _peakLabel(summary.peakDate!, summary.peakCents),
                        style: AppTypography.labelSm.copyWith(
                          color: summary.peakDate == null
                              ? palette.outline
                              : palette.primaryText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LedgerDailyBars(
                    points: summary.daily,
                    peakDate: summary.peakDate,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _peakLabel(DateTime date, int peakCents) =>
      '峰值 ${date.month}/${date.day} (${formatYuanCompact(peakCents)})';
}

class _MonthPill extends StatelessWidget {
  const _MonthPill({required this.month, required this.onTap});

  final DateTime month;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: palette.surfaceContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatMonthLabel(month),
              style: AppTypography.headlineSm.copyWith(
                color: palette.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more_rounded,
              size: 16,
              color: palette.outline,
            ),
          ],
        ),
      ),
    );
  }
}

class _MomPill extends StatelessWidget {
  const _MomPill({required this.percent, required this.trend});

  final double? percent;
  final TrendDirection trend;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isUp = trend == TrendDirection.up;
    final isDown = trend == TrendDirection.down;
    final background = isUp
        ? AppColors.rise.withValues(alpha: 0.16)
        : isDown
        ? palette.primary.withValues(alpha: 0.14)
        : palette.surfaceContainer;
    final foreground = isUp
        ? AppColors.rise
        : isDown
        ? palette.primaryText
        : palette.outline;
    final icon = isUp
        ? Icons.trending_up_rounded
        : isDown
        ? Icons.trending_down_rounded
        : Icons.remove_rounded;
    final text = percent == null
        ? '较上月 —'
        : '较上月 ${formatSignedPercent(percent!)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTypography.labelMd.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSm.copyWith(color: palette.outline),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.headlineSm.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.only(left: 8, right: 8),
      color: palette.outlineVariant.withValues(alpha: 0.5),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AppCard(
      radius: tokens.radiusSummary,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              SkeletonBox(width: 110, height: 28, radius: 14),
              Spacer(),
              SkeletonBox(width: 96, height: 22, radius: 11),
            ],
          ),
          const SizedBox(height: 16),
          const SkeletonBox(width: 180, height: 38, radius: 10),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: SkeletonBox(height: 32, radius: 8)),
              const SizedBox(width: 16),
              const Expanded(child: SkeletonBox(height: 32, radius: 8)),
              const SizedBox(width: 16),
              const Expanded(child: SkeletonBox(height: 32, radius: 8)),
            ],
          ),
          const SizedBox(height: 16),
          const SkeletonBox(height: 36, radius: 8),
        ],
      ),
    );
  }
}
