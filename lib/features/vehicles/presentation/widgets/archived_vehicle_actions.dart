import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/vehicle_models.dart';
import '../../domain/vehicle_presenter.dart';
import '../archived_vehicles_style.dart';

/// 归档卡操作行：彻底删除 / 查看历史报表 / 恢复至车库。
class ArchivedVehicleActions extends StatelessWidget {
  const ArchivedVehicleActions({
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
    final canReport = ArchivedVehiclePresenter.canOpenReports(vehicle);

    return Row(
      children: [
        TextButton.icon(
          onPressed: busy ? null : onPurge,
          style: TextButton.styleFrom(
            foregroundColor: palette.outline,
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: AppTypography.labelMd,
          ),
          icon: const Icon(Icons.delete_outline_rounded, size: 16),
          label: const Text('彻底删除'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              _PillButton(
                label: '查看历史报表',
                enabled: !busy && canReport,
                onTap: onReport,
              ),
              _PillButton(
                label: '恢复至车库',
                icon: Icons.unarchive_rounded,
                emphasized: true,
                enabled: !busy,
                onTap: onRestore,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.icon,
    this.emphasized = false,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final IconData? icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final background = emphasized ? palette.primary : palette.surfaceContainer;
    final foreground = emphasized ? Colors.white : palette.onSurface;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: ArchivedVehiclesStyle.actionHeight,
              minWidth: 44,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: foreground),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    maxLines: 1,
                    style: AppTypography.labelMd.copyWith(
                      color: foreground,
                      fontWeight: emphasized
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
