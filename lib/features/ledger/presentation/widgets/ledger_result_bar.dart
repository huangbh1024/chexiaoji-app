import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/format/formatters.dart';
import '../../domain/ledger_models.dart';

/// 分类筛选生效时的结果提示条。
class LedgerResultBar extends StatelessWidget {
  const LedgerResultBar({super.key, required this.row, required this.onClear});

  final LedgerResultBarRow row;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 4, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.filter_alt_rounded,
            size: 14,
            color: palette.primaryText,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '已筛选：${row.category.filterLabel} · ${row.count} 笔 · '
              '${formatYuanDetail(row.totalCents)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelMd.copyWith(
                color: palette.primaryText,
              ),
            ),
          ),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              foregroundColor: palette.primaryText,
              textStyle: AppTypography.labelMd,
            ),
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }
}
