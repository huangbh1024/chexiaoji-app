import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/presentation/category_style.dart';
import '../../../../core/format/formatters.dart';
import '../../domain/ledger_models.dart';

/// 流水日期组头：色条 + 日期 + 当日笔数与合计。
class LedgerDayHeader extends StatelessWidget {
  const LedgerDayHeader({super.key, required this.row});

  final LedgerDayHeaderRow row;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accent = row.isToday
        ? palette.primary
        : row.dominantCategory?.color ?? palette.outlineVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 14,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            formatDayTitle(row.day),
            style: AppTypography.headlineSm.copyWith(
              color: palette.onSurface,
            ),
          ),
          const Spacer(),
          Text(
            '${row.count} 笔 · 共 ${formatYuanDetail(row.totalCents)}',
            style: AppTypography.labelMd.copyWith(color: palette.outline),
          ),
        ],
      ),
    );
  }
}
