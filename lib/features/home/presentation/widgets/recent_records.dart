import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/format/formatters.dart';
import '../../domain/home_models.dart';
import '../../domain/providers.dart';
import '../home_style.dart';
import 'home_card.dart';

class RecentRecords extends ConsumerWidget {
  const RecentRecords({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final vehicleId = ref.watch(selectedVehicleIdProvider);
    final records = ref.watch(recordsProvider(vehicleId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '最近记录',
              style: AppTypography.headlineSm.copyWith(
                color: palette.onSurface,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => _toast(context, '账单列表待接入'),
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
                    '全部',
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
        records.when(
          loading: () => const _RecordsSkeleton(),
          error: (error, stack) => SectionError(
            onRetry: () => ref.invalidate(recordsProvider(vehicleId)),
            message: '最近记录加载失败',
          ),
          data: (items) => items.isEmpty
              ? EmptyState(
                  icon: Icons.receipt_long_rounded,
                  title: '本月还没有记录',
                  actionLabel: '记一笔',
                  onAction: () => _toast(context, '记账页待接入'),
                )
              : HomeCard(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      for (var index = 0; index < items.length; index++) ...[
                        if (index > 0)
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: palette.surfaceContainer,
                          ),
                        _RecordRow(item: items[index]),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
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

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.item});

  final RecordItem item;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = item.category.color;
    final subColor = switch (item.category) {
      ExpenseCategory.charging => palette.primaryText,
      ExpenseCategory.fuel => palette.secondaryText,
      _ => palette.outline,
    };

    return InkWell(
      onTap: () => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('账单详情待接入'),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            duration: const Duration(seconds: 2),
          ),
        ),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.category.icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyLg.copyWith(
                      color: palette.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
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
                  formatExpense(item.amountCents),
                  maxLines: 1,
                  style: AppTypography.headlineSm.copyWith(
                    color: palette.onSurface,
                  ),
                ),
                if (item.subLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.subLabel!,
                    style: AppTypography.labelSm.copyWith(
                      color: subColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordsSkeleton extends StatelessWidget {
  const _RecordsSkeleton();

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          for (var index = 0; index < 3; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            const Row(
              children: [
                SkeletonBox(width: 40, height: 40, radius: 14),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 150, height: 14),
                      SizedBox(height: 6),
                      SkeletonBox(width: 110, height: 10),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                SkeletonBox(width: 56, height: 16),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
