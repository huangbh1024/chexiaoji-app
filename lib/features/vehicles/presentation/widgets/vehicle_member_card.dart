import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/presentation/category_style.dart';
import '../../domain/vehicle_models.dart';
import '../../domain/vehicle_presenter.dart';
import '../vehicle_management_style.dart';

class VehicleMemberCard extends StatelessWidget {
  const VehicleMemberCard({
    super.key,
    required this.vehicle,
    required this.isBusy,
    required this.onRecord,
    required this.onStats,
    required this.onSetPrimary,
    required this.onEdit,
    required this.onMore,
  });

  final ManagedVehicle vehicle;
  final bool isBusy;
  final VoidCallback onRecord;
  final VoidCallback onStats;
  final VoidCallback onSetPrimary;
  final VoidCallback onEdit;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final primary = vehicle.isPrimary;
    final accent = vehicle.powertrain.color;
    final reminder = VehiclePresenter.reminderOf(vehicle);
    final metrics = VehiclePresenter.metricsOf(vehicle);

    return Container(
      padding: const EdgeInsets.all(VehicleManagementStyle.cardPadding),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(VehicleManagementStyle.cardRadius),
        border: Border.all(
          color: primary
              ? palette.primary.withValues(alpha: 0.30)
              : palette.outlineVariant.withValues(alpha: 0.60),
          width: primary ? 1.5 : 1,
        ),
        boxShadow: primary ? tokens.selectedShadow : tokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: VehicleManagementStyle.iconBox,
                height: VehicleManagementStyle.iconBox,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(
                    VehicleManagementStyle.innerRadius,
                  ),
                ),
                child: Icon(
                  _vehicleIcon(vehicle.powertrain),
                  size: 24,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
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
                        const SizedBox(width: 6),
                        _StatusBadge(vehicle: vehicle),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _PlateTag(plate: vehicle.vehicle.plate),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            VehiclePresenter.specLine(vehicle),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySm.copyWith(
                              color: palette.outline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Semantics(
                button: true,
                label: '管理${vehicle.vehicle.name}',
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: isBusy ? null : onMore,
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(
                        Icons.more_vert_rounded,
                        size: 20,
                        color: isBusy ? palette.disabled : palette.outline,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: palette.outlineVariant.withValues(alpha: 0.55),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < metrics.length; index++) ...[
                  if (index > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _MetricColumn(
                      metric: metrics[index],
                      accent: accent,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Divider(
            height: 1,
            color: palette.outlineVariant.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (reminder != null) ...[
                Icon(
                  _reminderIcon(reminder.kind),
                  size: 16,
                  color: _toneColor(reminder.tone, palette, accent),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    reminder.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySm.copyWith(
                      color: _toneColor(reminder.tone, palette, accent),
                    ),
                  ),
                ),
              ] else
                const Spacer(),
              const SizedBox(width: 8),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '本月产生支出：',
                      style: AppTypography.bodySm.copyWith(
                        color: palette.onSurfaceVariant,
                      ),
                    ),
                    TextSpan(
                      text: formatYuanDetail(vehicle.monthSpendCents),
                      style: AppTypography.bodySm.copyWith(
                        color: palette.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.add_circle_rounded,
                  label: '记一笔',
                  emphasized: primary,
                  enabled: !isBusy,
                  onTap: onRecord,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: primary
                    ? _ActionButton(
                        icon: Icons.insights_rounded,
                        label: '能耗统计',
                        enabled: !isBusy,
                        onTap: onStats,
                      )
                    : _ActionButton(
                        icon: Icons.check_circle_rounded,
                        label: '设为主驾',
                        enabled: !isBusy,
                        onTap: onSetPrimary,
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.tune_rounded,
                  label: '编辑档案',
                  enabled: !isBusy,
                  onTap: onEdit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _vehicleIcon(PowertrainType type) => switch (type) {
    PowertrainType.ev => Icons.electric_car_rounded,
    PowertrainType.phev => Icons.ev_station_rounded,
    PowertrainType.hev => Icons.local_gas_station_rounded,
    PowertrainType.ice => Icons.local_gas_station_rounded,
  };

  IconData _reminderIcon(VehicleReminderKind kind) => switch (kind) {
    VehicleReminderKind.maintenance => Icons.build_circle_rounded,
    VehicleReminderKind.insurance => Icons.verified_user_rounded,
    VehicleReminderKind.inspection => Icons.schedule_rounded,
  };
}

Color _toneColor(VehicleMetricTone tone, AppPalette palette, Color accent) {
  return switch (tone) {
    VehicleMetricTone.normal => palette.onSurface,
    VehicleMetricTone.accent => accent,
    VehicleMetricTone.warning => palette.secondaryText,
    VehicleMetricTone.danger => palette.error,
    VehicleMetricTone.muted => palette.outline,
  };
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({required this.metric, required this.accent});

  final VehicleMetric metric;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = _toneColor(metric.tone, palette, accent);
    final isSoh = metric.label.contains('SOH');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          metric.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodySm.copyWith(color: palette.outline),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                metric.value,
                style: AppTypography.labelLg.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (isSoh && metric.tone == VehicleMetricTone.normal) ...[
                const SizedBox(width: 3),
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    color: palette.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              const SizedBox(width: 2),
              Text(
                metric.unit,
                style: AppTypography.labelSm.copyWith(
                  color: metric.missing
                      ? palette.outline
                      : color.withValues(alpha: 0.70),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.vehicle});

  final ManagedVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final primary = vehicle.isPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: primary
            ? palette.primary
            : vehicle.powertrain.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(tokens.radiusPill),
      ),
      child: Text(
        primary ? '默认主座驾' : vehicle.vehicle.powertrainLabel,
        style: AppTypography.labelSm.copyWith(
          color: primary
              ? Colors.white
              : vehicle.powertrain.badgeTextColor(palette),
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
    final text = plate.trim().isEmpty ? '未填写车牌' : plate.trim().toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: palette.surfaceContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: AppTypography.labelMd.copyWith(
          color: palette.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final foreground = emphasized ? palette.primaryText : palette.onSurface;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: emphasized
            ? palette.primary.withValues(alpha: 0.12)
            : palette.surfaceContainer.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: SizedBox(
            height: VehicleManagementStyle.actionHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelMd.copyWith(color: foreground),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
