import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';

/// 资产安全与报表联动说明。
class ArchiveSecurityCard extends StatelessWidget {
  const ArchiveSecurityCard({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceContainer.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: palette.surfaceContainer.withValues(alpha: 0.90),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_rounded,
            size: 20,
            color: palette.primaryText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '资产安全与报表联动说明',
                  style: AppTypography.labelMd.copyWith(
                    color: palette.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '车辆归档后，已导出的年度账单与凭证仍包含其历史明细；'
                  '恢复后即刻回到首页与记账列表。彻底删除会移除车辆档案，'
                  '历史流水仍计入账目总额但不再归属该车。',
                  style: AppTypography.bodySm.copyWith(
                    color: palette.outline,
                    height: 18 / 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
