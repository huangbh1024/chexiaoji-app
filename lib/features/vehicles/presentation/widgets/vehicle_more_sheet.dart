import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/presentation/category_style.dart';
import '../../domain/vehicle_models.dart';
import '../../domain/vehicle_presenter.dart';
import 'vehicle_sheet_shell.dart';

enum VehicleMoreAction { setPrimary, edit, archive, delete }

Future<VehicleMoreAction?> showVehicleMoreSheet(
  BuildContext context,
  ManagedVehicle vehicle,
) {
  return showVehicleSheet<VehicleMoreAction>(
    context,
    (sheetContext) => _VehicleMoreSheet(vehicle: vehicle),
  );
}

class _VehicleMoreSheet extends StatelessWidget {
  const _VehicleMoreSheet({required this.vehicle});

  final ManagedVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accent = vehicle.powertrain.color;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _vehicleIcon(vehicle.powertrain),
                size: 22,
                color: accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          vehicle.vehicle.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.headlineSm.copyWith(
                            color: palette.onSurface,
                          ),
                        ),
                      ),
                      if (vehicle.isPrimary) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: palette.primary,
                            borderRadius: BorderRadius.circular(
                              context.tokens.radiusPill,
                            ),
                          ),
                          child: Text(
                            '主驾',
                            style: AppTypography.labelSm.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${vehicle.vehicle.plate} · ${VehiclePresenter.specLine(vehicle)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySm.copyWith(
                      color: palette.outline,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close_rounded, color: palette.outline),
            ),
          ],
        ),
        Divider(
          height: 20,
          color: palette.outlineVariant.withValues(alpha: 0.55),
        ),
        _SheetAction(
          icon: Icons.verified_rounded,
          iconColor: palette.primaryText,
          iconBackground: palette.primary.withValues(alpha: 0.14),
          title: '设为默认主驾',
          subtitle: vehicle.isPrimary ? '当前已是默认主驾' : '主屏看板与记账优先使用此座驾',
          trailing: vehicle.isPrimary
              ? _CurrentPrimaryChip()
              : Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: palette.outline,
                ),
          enabled: !vehicle.isPrimary,
          onTap: () => Navigator.of(context).pop(VehicleMoreAction.setPrimary),
        ),
        _SheetAction(
          icon: Icons.tune_rounded,
          iconColor: palette.onSurface,
          iconBackground: palette.surfaceContainer,
          title: '编辑车辆档案',
          subtitle: '修改牌号、维保周期与能耗基准',
          onTap: () => Navigator.of(context).pop(VehicleMoreAction.edit),
        ),
        _SheetAction(
          icon: Icons.inventory_2_rounded,
          iconColor: palette.secondaryText,
          iconBackground: palette.secondary.withValues(alpha: 0.16),
          title: '车辆归档',
          subtitle: '移出常用车库，完整保留历史流水与数据',
          titleColor: palette.secondaryText,
          onTap: () => Navigator.of(context).pop(VehicleMoreAction.archive),
        ),
        Divider(
          height: 12,
          color: palette.outlineVariant.withValues(alpha: 0.55),
        ),
        _SheetAction(
          icon: Icons.delete_forever_rounded,
          iconColor: palette.error,
          iconBackground: palette.errorSoft,
          title: '删除车辆',
          subtitle: '彻底移除该车辆与绑定配置，不可撤销',
          titleColor: palette.error,
          onTap: () => Navigator.of(context).pop(VehicleMoreAction.delete),
        ),
      ],
    );
  }

  IconData _vehicleIcon(PowertrainType type) => switch (type) {
    PowertrainType.ev => Icons.electric_car_rounded,
    PowertrainType.phev => Icons.ev_station_rounded,
    PowertrainType.hev => Icons.local_gas_station_rounded,
    PowertrainType.ice => Icons.local_gas_station_rounded,
  };
}

class _CurrentPrimaryChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(context.tokens.radiusPill),
      ),
      child: Text(
        '当前主驾',
        style: AppTypography.labelSm.copyWith(color: palette.primaryText),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.enabled = true,
    this.titleColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool enabled;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.labelLg.copyWith(
                          color: titleColor ?? palette.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm.copyWith(
                          color: palette.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                trailing ??
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: palette.outline,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
