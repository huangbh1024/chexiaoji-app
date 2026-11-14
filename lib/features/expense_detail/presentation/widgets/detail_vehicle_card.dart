import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/presentation/category_style.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/expense_detail_models.dart';
import '../../domain/expense_detail_presenter.dart';
import '../expense_detail_style.dart';

/// 关联爱车资产卡：车辆快照、绑定状态与记录里程。
class DetailVehicleCard extends StatelessWidget {
  const DetailVehicleCard({
    super.key,
    required this.detail,
    required this.onTap,
  });

  final ExpenseDetail detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bound = detail.vehicleBound;
    final plate = detail.plate;
    return AppCard(
      radius: ExpenseDetailStyle.cardRadius,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.directions_car_rounded,
                size: 18,
                color: palette.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '关联爱车资产',
                style: AppTypography.labelLg.copyWith(
                  color: palette.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _BindBadge(bound: bound),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: palette.surfaceContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(ExpenseDetailStyle.rowRadius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: palette.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        detail.record.powertrain.icon,
                        size: 24,
                        color: palette.primary,
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
                                detail.vehicleName,
                                style: AppTypography.headlineSm.copyWith(
                                  color: palette.onSurface,
                                ),
                              ),
                              if (plate != null && plate.isNotEmpty)
                                _PlateTag(plate: plate),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            detail.odometerText,
                            style: AppTypography.bodySm.copyWith(
                              color: palette.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (bound)
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: palette.outlineVariant,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BindBadge extends StatelessWidget {
  const _BindBadge({required this.bound});

  final bool bound;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: bound
            ? palette.primary.withValues(alpha: 0.2)
            : palette.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        bound ? '已绑定' : '已解绑',
        style: AppTypography.labelSm.copyWith(
          color: bound ? palette.primaryText : palette.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PlateTag extends StatelessWidget {
  const _PlateTag({required this.plate});

  final String plate;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: palette.surfaceContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        plate,
        style: AppTypography.labelSm.copyWith(
          color: palette.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
