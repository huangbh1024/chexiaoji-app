import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/ledger_models.dart';

/// 列表底部状态：加载中 / 分页失败 / 没有更多。
class LedgerFooter extends StatelessWidget {
  const LedgerFooter({super.key, required this.state, required this.onRetry});

  final LedgerListState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (state.isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: palette.primary,
            ),
          ),
        ),
      );
    }

    if (state.isNextPageFailed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: TextButton(
            onPressed: onRetry,
            child: const Text('加载失败，点击重试'),
          ),
        ),
      );
    }

    if (!state.hasMore && state.items.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            '— 没有更多了 —',
            style: AppTypography.labelMd.copyWith(color: palette.outline),
          ),
        ),
      );
    }

    return const SizedBox(height: 8);
  }
}
