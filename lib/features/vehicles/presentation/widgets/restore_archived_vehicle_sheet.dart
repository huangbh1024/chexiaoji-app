import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/vehicle_models.dart';
import 'vehicle_sheet_shell.dart';

Future<bool?> showRestoreArchivedVehicleSheet(
  BuildContext context,
  ArchivedVehicleSummary vehicle, {
  required bool garageEmpty,
  required Future<String?> Function() onConfirm,
}) {
  return showVehicleSheet<bool>(
    context,
    (_) => _RestoreArchivedVehicleSheet(
      vehicle: vehicle,
      garageEmpty: garageEmpty,
      onConfirm: onConfirm,
    ),
    isDismissible: false,
    enableDrag: false,
  );
}

class _RestoreArchivedVehicleSheet extends StatefulWidget {
  const _RestoreArchivedVehicleSheet({
    required this.vehicle,
    required this.garageEmpty,
    required this.onConfirm,
  });

  final ArchivedVehicleSummary vehicle;
  final bool garageEmpty;
  final Future<String?> Function() onConfirm;

  @override
  State<_RestoreArchivedVehicleSheet> createState() =>
      _RestoreArchivedVehicleSheetState();
}

class _RestoreArchivedVehicleSheetState
    extends State<_RestoreArchivedVehicleSheet> {
  bool _submitting = false;
  String? _error;

  Future<void> _confirm() async {
    if (_submitting) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await widget.onConfirm();
    if (!mounted) {
      return;
    }
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return PopScope(
      canPop: !_submitting,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.unarchive_rounded,
                size: 30,
                color: palette.primaryText,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '将「${widget.vehicle.vehicle.name}」恢复至车库？',
            textAlign: TextAlign.center,
            style: AppTypography.headlineSm.copyWith(color: palette.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            '恢复后，该车辆将重新出现在车辆管理、首页仪表盘及快捷记账列表中，'
            '可随时在车库中切换为主力座驾。'
            '${widget.garageEmpty ? '当前车库没有在用车辆，恢复后该车将成为默认主驾。' : ''}',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd.copyWith(
              color: palette.outline,
              height: 20 / 13,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(color: palette.error),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SheetActionButton(
                  label: '取消',
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SheetActionButton(
                  label: '确认恢复',
                  icon: Icons.unarchive_rounded,
                  busy: _submitting,
                  backgroundColor: palette.primary,
                  foregroundColor: Colors.white,
                  onPressed: _confirm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
