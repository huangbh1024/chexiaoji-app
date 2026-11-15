import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../archived_vehicles_style.dart';

/// 档案封存机制说明：归档不删除历史，只是从日常视图移出。
class ArchiveNoticeCard extends StatelessWidget {
  const ArchiveNoticeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.surface,
            palette.surfaceContainer.withValues(alpha: 0.72),
            palette.surfaceContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(ArchivedVehiclesStyle.noticeRadius),
        border: Border.all(color: palette.cardBorder.withValues(alpha: 0.80)),
        boxShadow: tokens.cardShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -28,
            child: IgnorePointer(
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Positioned(
            left: -24,
            bottom: -24,
            child: IgnorePointer(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: palette.tertiary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: palette.outlineVariant.withValues(alpha: 0.30),
                  ),
                ),
                child: Icon(
                  Icons.inventory_2_rounded,
                  size: 24,
                  color: palette.primaryText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '档案封存机制',
                          style: AppTypography.headlineSm.copyWith(
                            color: palette.onSurface,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: palette.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '历史完整保留',
                            style: AppTypography.labelSm.copyWith(
                              color: palette.primaryText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '已归档的车辆不会出现在首页仪表盘与快捷记账列表中，'
                      '但其所有历史记账凭证、能耗曲线及报表均完整保留，'
                      '可随时恢复回车库。',
                      style: AppTypography.bodyMd.copyWith(
                        color: palette.onSurfaceVariant,
                        height: 20 / 13,
                      ),
                    ),
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
