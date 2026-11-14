import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/blurred_header_delegate.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_error.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../domain/ledger_models.dart';
import '../domain/providers.dart';
import 'widgets/ledger_category_chips.dart';
import 'widgets/ledger_day_header.dart';
import 'widgets/ledger_footer.dart';
import 'widgets/ledger_header.dart';
import 'widgets/ledger_record_card.dart';
import 'widgets/ledger_result_bar.dart';
import 'widgets/ledger_summary_card.dart';
import 'widgets/ledger_vehicle_chips.dart';

/// 账单 Tab：月度汇总 + 筛选 + 按天分组流水。
class LedgerPage extends ConsumerStatefulWidget {
  const LedgerPage({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  ConsumerState<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends ConsumerState<LedgerPage> {
  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant LedgerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || !widget.scrollController.hasClients) {
      return;
    }
    if (widget.scrollController.position.extentAfter < 240) {
      ref.read(ledgerRecordsProvider.notifier).loadMore();
    }
  }

  Future<void> _refresh() async {
    final filter = ref.read(ledgerFilterProvider);
    final scope = LedgerScope(
      month: filter.month,
      vehicleId: filter.vehicleId,
    );
    ref.invalidate(ledgerSummaryProvider(scope));
    await ref.read(ledgerRecordsProvider.notifier).refresh();
  }

  void _toast(String message) {
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

  void _showSortSheet() {
    final filter = ref.read(ledgerFilterProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final palette = sheetContext.palette;
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(
                      '排序方式',
                      style: AppTypography.headlineSm.copyWith(
                        color: palette.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '金额区间与支付方式待接入',
                      style: AppTypography.labelMd.copyWith(
                        color: palette.outline,
                      ),
                    ),
                  ],
                ),
              ),
              for (final sort in LedgerSort.values)
                ListTile(
                  title: Text(
                    _sortLabel(sort),
                    style: AppTypography.bodyLg.copyWith(
                      color: palette.onSurface,
                    ),
                  ),
                  trailing: filter.sort == sort
                      ? Icon(
                          Icons.check_circle_rounded,
                          size: 20,
                          color: palette.primary,
                        )
                      : null,
                  onTap: () {
                    ref.read(ledgerFilterProvider.notifier).selectSort(sort);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  String _sortLabel(LedgerSort sort) => switch (sort) {
    LedgerSort.timeDesc => '时间倒序',
    LedgerSort.amountDesc => '金额从高到低',
    LedgerSort.category => '按分类',
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final filter = ref.watch(ledgerFilterProvider);
    final list = ref.watch(ledgerRecordsProvider);
    final hasActiveFilter =
        filter.vehicleId != null ||
        filter.category != null ||
        filter.sort != LedgerSort.timeDesc;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 448),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: palette.primary,
            onRefresh: _refresh,
            child: CustomScrollView(
              controller: widget.scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: BlurredHeaderDelegate(
                    height: tokens.headerHeight,
                    child: LedgerHeader(
                      hasActiveFilter: hasActiveFilter,
                      onExport: () => _toast('导出功能开发中'),
                      onFilter: _showSortSheet,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const LedgerSummaryCard(),
                      const SizedBox(height: 12),
                      const LedgerVehicleChips(),
                      const SizedBox(height: 8),
                      const LedgerCategoryChips(),
                      const SizedBox(height: 12),
                    ]),
                  ),
                ),
                ..._buildListSlivers(list, filter),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: tokens.contentBottomPadding + bottomInset,
                    ),
                    child: LedgerFooter(
                      state: list,
                      onRetry: () => ref
                          .read(ledgerRecordsProvider.notifier)
                          .retryLoadMore(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildListSlivers(LedgerListState list, LedgerQuery filter) {
    if (list.isLoading) {
      return const [
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(child: _RecordsSkeleton()),
        ),
      ];
    }

    if (list.errorMessage != null) {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: SectionError(
              message: list.errorMessage!,
              onRetry: () =>
                  ref.read(ledgerRecordsProvider.notifier).retry(),
            ),
          ),
        ),
      ];
    }

    if (list.items.isEmpty) {
      final hasCategory = filter.category != null;
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: EmptyState(
              icon: hasCategory
                  ? Icons.filter_alt_off_rounded
                  : Icons.receipt_long_rounded,
              title: hasCategory ? '没有符合条件的记录' : '本月还没有记录',
              actionLabel: hasCategory ? '清除筛选' : '记一笔',
              onAction: hasCategory
                  ? () => ref
                        .read(ledgerFilterProvider.notifier)
                        .selectCategory(null)
                  : () => _toast('记账页待接入'),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.builder(
          itemCount: list.rows.length,
          itemBuilder: (context, index) => _buildRow(list.rows[index]),
        ),
      ),
    ];
  }

  Widget _buildRow(LedgerRow row) {
    return switch (row) {
      LedgerResultBarRow result => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: LedgerResultBar(
          row: result,
          onClear: () =>
              ref.read(ledgerFilterProvider.notifier).selectCategory(null),
        ),
      ),
      LedgerDayHeaderRow header => LedgerDayHeader(row: header),
      LedgerRecordRow recordRow => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: LedgerRecordCard(
          record: recordRow.record,
          onTap: () => _toast('账单详情待接入'),
        ),
      ),
    };
  }
}

class _RecordsSkeleton extends StatelessWidget {
  const _RecordsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Row(
          children: [
            SkeletonBox(width: 110, height: 16, radius: 6),
            Spacer(),
            SkeletonBox(width: 90, height: 12, radius: 6),
          ],
        ),
        const SizedBox(height: 10),
        for (var index = 0; index < 3; index++) ...[
          const _RecordSkeleton(),
          const SizedBox(height: 6),
        ],
        const SizedBox(height: 12),
        const Row(
          children: [
            SkeletonBox(width: 90, height: 16, radius: 6),
            Spacer(),
            SkeletonBox(width: 80, height: 12, radius: 6),
          ],
        ),
        const SizedBox(height: 10),
        for (var index = 0; index < 2; index++) ...[
          const _RecordSkeleton(),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _RecordSkeleton extends StatelessWidget {
  const _RecordSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(context.tokens.radiusCard),
      ),
      child: Row(
        children: [
          const SkeletonBox(width: 44, height: 44, radius: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: 150, height: 15, radius: 6),
                const SizedBox(height: 6),
                const SkeletonBox(width: 110, height: 11, radius: 6),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const SkeletonBox(width: 64, height: 16, radius: 6),
        ],
      ),
    );
  }
}
