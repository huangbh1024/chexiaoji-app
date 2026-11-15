import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/presentation/category_style.dart';
import '../../domain/vehicle_models.dart';
import 'vehicle_sheet_shell.dart';

Future<bool?> showArchivedVehiclesSheet(
  BuildContext context,
  List<ArchivedVehicle> vehicles, {
  required Future<String?> Function(String vehicleId) onRestore,
}) {
  return showVehicleSheet<bool>(
    context,
    (_) => _ArchivedVehiclesSheet(vehicles: vehicles, onRestore: onRestore),
  );
}

class _ArchivedVehiclesSheet extends StatefulWidget {
  const _ArchivedVehiclesSheet({
    required this.vehicles,
    required this.onRestore,
  });

  final List<ArchivedVehicle> vehicles;
  final Future<String?> Function(String vehicleId) onRestore;

  @override
  State<_ArchivedVehiclesSheet> createState() => _ArchivedVehiclesSheetState();
}

class _ArchivedVehiclesSheetState extends State<_ArchivedVehiclesSheet> {
  String? _restoringId;
  String? _error;

  Future<void> _restore(ArchivedVehicle vehicle) async {
    if (_restoringId != null) {
      return;
    }
    setState(() {
      _restoringId = vehicle.id;
      _error = null;
    });
    final error = await widget.onRestore(vehicle.id);
    if (!mounted) {
      return;
    }
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _restoringId = null;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.inventory_2_rounded, color: palette.secondaryText),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '已归档车辆',
                style: AppTypography.headlineSm.copyWith(
                  color: palette.onSurface,
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close_rounded, color: palette.outline),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '归档车辆不参与车队汇总，历史流水与统计完整保留。',
          style: AppTypography.bodySm.copyWith(color: palette.outline),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: AppTypography.bodySm.copyWith(color: palette.error),
          ),
        ],
        const SizedBox(height: 12),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: widget.vehicles.length,
            separatorBuilder: (_, _) => Divider(
              height: 16,
              color: palette.outlineVariant.withValues(alpha: 0.5),
            ),
            itemBuilder: (context, index) {
              final vehicle = widget.vehicles[index];
              final busy = _restoringId == vehicle.id;
              return Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: vehicle.vehicle.powertrain.color.withValues(
                        alpha: 0.14,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _vehicleIcon(vehicle.vehicle.powertrain),
                      size: 22,
                      color: vehicle.vehicle.powertrain.color,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.vehicle.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelLg.copyWith(
                            color: palette.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${vehicle.vehicle.plate} · ${dateFormat.format(vehicle.archivedAt)} 归档',
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
                  TextButton(
                    onPressed: busy ? null : () => _restore(vehicle),
                    child: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('恢复'),
                  ),
                ],
              );
            },
          ),
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
