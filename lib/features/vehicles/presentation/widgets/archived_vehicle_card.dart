import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/presentation/category_style.dart';
import '../../domain/vehicle_models.dart';
import '../../domain/vehicle_presenter.dart';
import '../archived_vehicles_style.dart';
import 'archived_vehicle_actions.dart';
import 'archived_vehicle_metrics.dart';

/// 归档车辆卡：车辆档案 + 封存时长 + 三指标 + 恢复 / 报表 / 删除。
class ArchivedVehicleCard extends StatelessWidget {
  const ArchivedVehicleCard({
    super.key,
    required this.vehicle,
    required this.busy,
    required this.onPurge,
    required this.onReport,
    required this.onRestore,
  });

  final ArchivedVehicleSummary vehicle;
  final bool busy;
  final VoidCallback onPurge;
  final VoidCallback onReport;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final accent = vehicle.powertrain.color;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(ArchivedVehiclesStyle.cardRadius),
        border: Border.all(
          color: palette.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: tokens.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -36,
            top: -36,
            child: IgnorePointer(
              child: Container(
                width: 144,
                height: 144,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(ArchivedVehiclesStyle.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: ArchivedVehiclesStyle.iconBox,
                      height: ArchivedVehiclesStyle.iconBox,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(
                          ArchivedVehiclesStyle.innerRadius,
                        ),
                      ),
                      child: Icon(
                        _vehicleIcon(vehicle.powertrain),
                        size: 26,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                vehicle.vehicle.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.headlineSm.copyWith(
                                  color: palette.onSurface,
                                ),
                              ),
                              _SpecBadge(label: vehicle.specLabel),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _PlateTag(plate: vehicle.vehicle.plate),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    vehicle.vehicle.powertrainLabel.isEmpty
                                        ? vehicle.powertrain.label
                                        : vehicle.vehicle.powertrainLabel,
                                    style: AppTypography.bodySm.copyWith(
                                      color: palette.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ArchiveBadge(
                      label: ArchivedVehiclePresenter.archiveDurationLabel(
                        vehicle.archivedAt,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ArchivedVehicleMetrics(vehicle: vehicle),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.event_note_rounded,
                      size: 15,
                      color: palette.outline,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        ArchivedVehiclePresenter.archiveDateLabel(
                          vehicle.archivedAt,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm.copyWith(
                          color: palette.outline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(
                  height: 1,
                  color: palette.surfaceContainer.withValues(alpha: 0.90),
                ),
                const SizedBox(height: 6),
                ArchivedVehicleActions(
                  vehicle: vehicle,
                  busy: busy,
                  onPurge: onPurge,
                  onReport: onReport,
                  onRestore: onRestore,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _vehicleIcon(PowertrainType type) => switch (type) {
    PowertrainType.ev => Icons.electric_car_rounded,
    PowertrainType.phev => Icons.ev_station_rounded,
    PowertrainType.hev => Icons.local_gas_station_rounded,
    PowertrainType.ice => Icons.directions_car_rounded,
  };
}

class _SpecBadge extends StatelessWidget {
  const _SpecBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = label.trim().isEmpty ? '配置待完善' : label.trim();
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: palette.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.labelSm.copyWith(color: palette.onSurfaceVariant),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: palette.surfaceContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: AppTypography.labelMd.copyWith(
          color: palette.onSurface,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _ArchiveBadge extends StatelessWidget {
  const _ArchiveBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: palette.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.archive_rounded, size: 13, color: palette.outline),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTypography.labelSm.copyWith(
              color: palette.outline,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
