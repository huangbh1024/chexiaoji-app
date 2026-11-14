import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/tab.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/domain/enums.dart';
import '../../../core/format/formatters.dart';
import '../../../core/presentation/category_style.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../expense_detail/presentation/expense_detail_page.dart';
import '../../ledger/domain/ledger_models.dart';
import '../../ledger/domain/providers.dart';
import '../domain/providers.dart';
import '../domain/stats_models.dart';
import '../domain/stats_period.dart';

class StatsRecentRecords extends ConsumerWidget {
  const StatsRecentRecords({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final filter = ref.watch(statsFilterProvider);
    final scope = filter.toScope();
    final recent = ref.watch(statsRecentProvider(scope));
    final range = resolveStatsRange(filter.period, filter.anchor);

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '最近开销记录',
                style: AppTypography.headlineSm.copyWith(
                  color: palette.onSurface,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _openLedger(ref, filter, range),
                style: TextButton.styleFrom(
                  foregroundColor: palette.outline,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '查看全部',
                      style: AppTypography.labelMd.copyWith(
                        color: palette.outline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: palette.outline,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          recent.when(
            loading: () => const _RecentSkeleton(),
            error: (error, stack) => SizedBox(
              height: 72,
              child: Center(
                child: TextButton.icon(
                  onPressed: () => ref.invalidate(statsRecentProvider(scope)),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('记录加载失败，点击重试'),
                ),
              ),
            ),
            data: (records) => records.isEmpty
                ? _EmptyRecent(onTap: () => _toast(context, '记账页待接入'))
                : Column(
                    children: [
                      for (var index = 0; index < records.length; index++)
                        Padding(
                          padding: EdgeInsets.only(top: index == 0 ? 0 : 4),
                          child: _RecentRow(
                            record: records[index],
                            first: index == 0,
                            onTap: () => _openDetail(
                              context,
                              ref,
                              scope,
                              records[index],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    WidgetRef ref,
    StatsScope scope,
    StatsRecord record,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ExpenseDetailPage(recordId: record.id),
      ),
    );
    final range = ref.read(statsTrendRangeProvider);
    ref.invalidate(statsOverviewProvider(scope));
    ref.invalidate(statsBreakdownProvider(scope));
    ref.invalidate(statsRecentProvider(scope));
    ref.invalidate(
      statsTrendProvider(
        StatsTrendQuery(
          vehicleId: scope.vehicleId,
          range: range,
          anchor: scope.anchor,
        ),
      ),
    );
  }

  void _openLedger(WidgetRef ref, StatsFilter filter, StatsRange range) {
    final ledgerFilter = ref.read(ledgerFilterProvider.notifier);
    ledgerFilter.selectVehicle(filter.vehicleId);
    ledgerFilter.selectCategory(null);
    ledgerFilter.selectMonth(monthStart(range.end));
    ref.read(appTabProvider.notifier).select(AppTab.ledger);
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          duration: const Duration(seconds: 2),
        ),
      );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.record,
    required this.first,
    required this.onTap,
  });

  final StatsRecord record;
  final bool first;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final category = record.category;
    final tagIsEnergy =
        category == ExpenseCategory.charging ||
        category == ExpenseCategory.fuel;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: first ? const Key('stats-recent-first') : null,
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: category.softColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(category.icon, size: 20, color: category.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMd.copyWith(
                        color: palette.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      record.subtitle ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySm.copyWith(
                        color: palette.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatSignedYuan(record.amountCents),
                    style: AppTypography.headlineSm.copyWith(
                      color: palette.onSurface,
                    ),
                  ),
                  if (record.tag != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      record.tag!,
                      style: AppTypography.labelSm.copyWith(
                        color: tagIsEnergy
                            ? palette.primaryText
                            : palette.outline,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(Icons.receipt_long_rounded, size: 28, color: palette.outline),
          const SizedBox(height: 8),
          Text(
            '该周期暂无开销记录',
            style: AppTypography.bodyMd.copyWith(
              color: palette.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onTap,
            child: Text(
              '去记一笔',
              style: AppTypography.labelMd.copyWith(color: palette.primaryText),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSkeleton extends StatelessWidget {
  const _RecentSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _SkeletonRow(),
        SizedBox(height: 8),
        _SkeletonRow(),
        SizedBox(height: 8),
        _SkeletonRow(),
      ],
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SkeletonBox(width: 40, height: 40, radius: 14),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(height: 12),
              SizedBox(height: 6),
              SkeletonBox(width: 120, height: 10),
            ],
          ),
        ),
        SizedBox(width: 12),
        SkeletonBox(width: 56, height: 14),
      ],
    );
  }
}
