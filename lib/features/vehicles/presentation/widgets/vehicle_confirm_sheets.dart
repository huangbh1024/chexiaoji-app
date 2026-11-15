import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/presentation/category_style.dart';
import '../../domain/vehicle_models.dart';
import '../../domain/vehicle_presenter.dart';
import 'vehicle_sheet_shell.dart';

Future<bool?> showSetPrimarySheet(
  BuildContext context,
  ManagedVehicle vehicle, {
  required Future<String?> Function() onConfirm,
}) {
  return showVehicleSheet<bool>(
    context,
    (_) => _SetPrimarySheet(vehicle: vehicle, onConfirm: onConfirm),
  );
}

Future<bool?> showArchiveVehicleSheet(
  BuildContext context,
  ManagedVehicle vehicle, {
  required String body,
  required String confirmLabel,
  required Future<String?> Function() onConfirm,
}) {
  return showVehicleSheet<bool>(
    context,
    (_) => _ArchiveVehicleSheet(
      vehicle: vehicle,
      body: body,
      confirmLabel: confirmLabel,
      onConfirm: onConfirm,
    ),
  );
}

enum DeleteSheetResult { deleted, archive }

Future<DeleteSheetResult?> showDeleteVehicleSheet(
  BuildContext context,
  ManagedVehicle vehicle, {
  required DeleteBlockReason? blockReason,
  required int recordCount,
  required Future<String?> Function() onConfirm,
}) {
  return showVehicleSheet<DeleteSheetResult>(
    context,
    (_) => _DeleteVehicleSheet(
      vehicle: vehicle,
      blockReason: blockReason,
      recordCount: recordCount,
      onConfirm: onConfirm,
    ),
  );
}

class _SetPrimarySheet extends StatefulWidget {
  const _SetPrimarySheet({required this.vehicle, required this.onConfirm});

  final ManagedVehicle vehicle;
  final Future<String?> Function() onConfirm;

  @override
  State<_SetPrimarySheet> createState() => _SetPrimarySheetState();
}

class _SetPrimarySheetState extends State<_SetPrimarySheet> {
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
    final accent = widget.vehicle.powertrain.color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _IconBlock(
          icon: Icons.directions_car_rounded,
          color: accent,
          background: accent.withValues(alpha: 0.14),
        ),
        const SizedBox(height: 12),
        Text(
          '将 ${widget.vehicle.vehicle.name} 设为默认主驾？',
          textAlign: TextAlign.center,
          style: AppTypography.headlineSm.copyWith(color: palette.onSurface),
        ),
        const SizedBox(height: 8),
        Text(
          '设为默认后，首页看板、快捷记账及能耗统计将优先展示该车辆数据。',
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
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SheetActionButton(
                label: '确认设为主驾',
                icon: Icons.check_rounded,
                busy: _submitting,
                backgroundColor: palette.primary,
                foregroundColor: Colors.white,
                onPressed: _confirm,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ArchiveVehicleSheet extends StatefulWidget {
  const _ArchiveVehicleSheet({
    required this.vehicle,
    required this.body,
    required this.confirmLabel,
    required this.onConfirm,
  });

  final ManagedVehicle vehicle;
  final String body;
  final String confirmLabel;
  final Future<String?> Function() onConfirm;

  @override
  State<_ArchiveVehicleSheet> createState() => _ArchiveVehicleSheetState();
}

class _ArchiveVehicleSheetState extends State<_ArchiveVehicleSheet> {
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _IconBlock(
          icon: Icons.inventory_2_rounded,
          color: palette.secondaryText,
          background: palette.secondary.withValues(alpha: 0.16),
        ),
        const SizedBox(height: 12),
        Text(
          '归档「${widget.vehicle.vehicle.name}」？',
          textAlign: TextAlign.center,
          style: AppTypography.headlineSm.copyWith(color: palette.onSurface),
        ),
        const SizedBox(height: 8),
        Text(
          widget.body,
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
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SheetActionButton(
                label: widget.confirmLabel,
                icon: Icons.archive_rounded,
                busy: _submitting,
                backgroundColor: palette.secondary,
                foregroundColor: Colors.white,
                onPressed: _confirm,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DeleteVehicleSheet extends StatefulWidget {
  const _DeleteVehicleSheet({
    required this.vehicle,
    required this.blockReason,
    required this.recordCount,
    required this.onConfirm,
  });

  final ManagedVehicle vehicle;
  final DeleteBlockReason? blockReason;
  final int recordCount;
  final Future<String?> Function() onConfirm;

  @override
  State<_DeleteVehicleSheet> createState() => _DeleteVehicleSheetState();
}

class _DeleteVehicleSheetState extends State<_DeleteVehicleSheet> {
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
      Navigator.of(context).pop(DeleteSheetResult.deleted);
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
    final blocked = widget.blockReason;

    if (blocked == DeleteBlockReason.isPrimary) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _IconBlock(
            icon: Icons.warning_rounded,
            color: palette.error,
            background: palette.errorSoft,
          ),
          const SizedBox(height: 12),
          Text(
            '默认主座驾不可直接删除',
            textAlign: TextAlign.center,
            style: AppTypography.headlineSm.copyWith(color: palette.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            '「${widget.vehicle.vehicle.name}」当前为默认主座驾。请先将车库中其他座驾设为主驾后再删除。',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd.copyWith(
              color: palette.outline,
              height: 20 / 13,
            ),
          ),
          const SizedBox(height: 20),
          SheetActionButton(
            label: '我知道了，去切换主驾',
            foregroundColor: Colors.white,
            backgroundColor: palette.primary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }

    if (blocked == DeleteBlockReason.hasRecords) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _IconBlock(
            icon: Icons.inventory_2_rounded,
            color: palette.secondaryText,
            background: palette.secondary.withValues(alpha: 0.16),
          ),
          const SizedBox(height: 12),
          Text(
            '该车辆有历史流水',
            textAlign: TextAlign.center,
            style: AppTypography.headlineSm.copyWith(color: palette.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            '「${widget.vehicle.vehicle.name}」名下还有 ${widget.recordCount} 笔记账流水。为避免账目缺口，请先归档：归档会保留全部流水且可恢复。',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd.copyWith(
              color: palette.outline,
              height: 20 / 13,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SheetActionButton(
                  label: '取消',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SheetActionButton(
                  label: '去归档',
                  icon: Icons.archive_rounded,
                  backgroundColor: palette.secondary,
                  foregroundColor: Colors.white,
                  onPressed: () =>
                      Navigator.of(context).pop(DeleteSheetResult.archive),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _IconBlock(
          icon: Icons.warning_rounded,
          color: palette.error,
          background: palette.errorSoft,
        ),
        const SizedBox(height: 12),
        Text(
          '永久删除爱车？',
          textAlign: TextAlign.center,
          style: AppTypography.headlineSm.copyWith(color: palette.onSurface),
        ),
        const SizedBox(height: 8),
        Text(
          '确定要永久删除「${widget.vehicle.vehicle.name}」吗？删除后车辆档案与配置将无法恢复。',
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
                label: '我再想想',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SheetActionButton(
                label: '确认删除',
                icon: Icons.delete_forever_rounded,
                busy: _submitting,
                backgroundColor: palette.error,
                foregroundColor: Colors.white,
                onPressed: _confirm,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _IconBlock extends StatelessWidget {
  const _IconBlock({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(icon, size: 30, color: color),
      ),
    );
  }
}
