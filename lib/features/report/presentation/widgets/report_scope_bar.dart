import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/domain/vehicle.dart';
import '../../../../core/presentation/category_style.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../../../home/domain/providers.dart';
import '../../../ledger/presentation/widgets/ledger_month_picker_sheet.dart';
import '../../domain/report_models.dart';
import '../../domain/report_presenter.dart';

/// 报表范围条：月份 + 出账状态 + 车辆 chips。
class ReportScopeBar extends ConsumerWidget {
  const ReportScopeBar({
    super.key,
    required this.scope,
    required this.onMonthChanged,
    required this.onVehicleChanged,
  });

  final ReportScope scope;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<String?> onVehicleChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReportMonthPill(scope: scope, onChanged: onMonthChanged),
        const SizedBox(height: 8),
        ReportVehicleChips(
          selectedId: scope.vehicleId,
          onChanged: onVehicleChanged,
        ),
      ],
    );
  }
}

class ReportMonthPill extends StatelessWidget {
  const ReportMonthPill({
    super.key,
    required this.scope,
    required this.onChanged,
  });

  final ReportScope scope;
  final ValueChanged<DateTime> onChanged;

  Future<void> _pickMonth(BuildContext context) async {
    final selected = await showLedgerMonthPicker(context, scope.month);
    if (selected != null) {
      onChanged(DateTime(selected.year, selected.month));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final status = reportStatusFor(scope.month);

    return Container(
      height: 44,
      padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: tokens.cardShadow,
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_month_rounded, size: 18, color: palette.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    reportMonthTitle(scope.month),
                    style: AppTypography.labelMd.copyWith(
                      color: palette.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                _StatusBadge(status: status),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Semantics(
            button: true,
            label: '切换月份，当前 ${reportMonthTitle(scope.month)}',
            child: InkWell(
              onTap: () => _pickMonth(context),
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 44,
                child: Center(
                  widthFactor: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surfaceContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '切换月份',
                          style: AppTypography.labelMd.copyWith(
                            color: palette.outline,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.expand_more_rounded,
                          size: 14,
                          color: palette.outline,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final recording = status == ReportStatus.recording;
    final background = recording
        ? palette.secondary.withValues(alpha: 0.18)
        : const Color(0xFFDCE9FF);
    final foreground = recording
        ? palette.secondaryText
        : const Color(0xFF006591);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        recording ? '记录中' : '已出账',
        style: AppTypography.labelSm.copyWith(color: foreground, fontSize: 9),
      ),
    );
  }
}

class ReportVehicleChips extends ConsumerWidget {
  const ReportVehicleChips({
    super.key,
    required this.selectedId,
    required this.onChanged,
  });

  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehiclesProvider);

    return SizedBox(
      height: 44,
      child: vehiclesAsync.when(
        loading: () => const Row(
          children: [
            SkeletonBox(width: 100, height: 32, radius: 16),
            SizedBox(width: 8),
            SkeletonBox(width: 112, height: 32, radius: 16),
            SizedBox(width: 8),
            SkeletonBox(width: 96, height: 32, radius: 16),
          ],
        ),
        error: (error, stack) => _VehicleChipList(
          vehicles: const [],
          selectedId: selectedId,
          onChanged: onChanged,
        ),
        data: (vehicles) => _VehicleChipList(
          vehicles: vehicles,
          selectedId: selectedId,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _VehicleChipList extends StatelessWidget {
  const _VehicleChipList({
    required this.vehicles,
    required this.selectedId,
    required this.onChanged,
  });

  final List<Vehicle> vehicles;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _VehiclePill(
        label: '全部车辆 (${vehicles.length})',
        selected: selectedId == null,
        leading: Icon(
          Icons.directions_car_rounded,
          size: 14,
          color: selectedId == null
              ? context.palette.primaryText
              : context.palette.onSurfaceVariant,
        ),
        onTap: () => onChanged(null),
      ),
      for (final vehicle in vehicles)
        _VehiclePill(
          label: selectedId == vehicle.id
              ? '${vehicle.name} (当前)'
              : vehicle.name,
          selected: selectedId == vehicle.id,
          leading: _VehicleDot(
            color: vehicle.powertrain.color,
            selected: selectedId == vehicle.id,
          ),
          onTap: () => onChanged(vehicle.id),
        ),
    ];

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(width: 8),
      itemBuilder: (context, index) => items[index],
    );
  }
}

class _VehicleDot extends StatelessWidget {
  const _VehicleDot({required this.color, required this.selected});

  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? context.palette.primaryText : color,
      ),
    );
  }
}

class _VehiclePill extends StatelessWidget {
  const _VehiclePill({
    required this.label,
    required this.selected,
    required this.leading,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Widget leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 44,
            child: Center(
              widthFactor: 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: selected ? palette.primary : palette.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected
                        ? palette.primary
                        : palette.outlineVariant.withValues(alpha: 0.5),
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: palette.primary.withValues(alpha: 0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : tokens.cardShadow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    leading,
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: AppTypography.labelMd.copyWith(
                        color: selected ? palette.primaryText : palette.outline,
                        fontWeight: selected
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
      ),
    );
  }
}
