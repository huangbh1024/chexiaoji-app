import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/domain/vehicle.dart';
import '../../../../core/presentation/category_style.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../../../home/domain/providers.dart';
import '../../domain/providers.dart';

/// 车辆筛选：全部车辆 + 每辆车一行横向 chips。
class LedgerVehicleChips extends ConsumerWidget {
  const LedgerVehicleChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final filter = ref.watch(ledgerFilterProvider);

    return SizedBox(
      height: 32,
      child: vehiclesAsync.when(
        loading: () => const Row(
          children: [
            SkeletonBox(width: 96, height: 32, radius: 16),
            SizedBox(width: 8),
            SkeletonBox(width: 104, height: 32, radius: 16),
            SizedBox(width: 8),
            SkeletonBox(width: 88, height: 32, radius: 16),
          ],
        ),
        error: (error, stack) => _AllVehiclesChip(
          count: 0,
          selected: filter.vehicleId == null,
          onTap: () => ref.read(ledgerFilterProvider.notifier).selectVehicle(null),
        ),
        data: (vehicles) => _VehicleChipList(
          vehicles: vehicles,
          selectedId: filter.vehicleId,
        ),
      ),
    );
  }
}

class _VehicleChipList extends ConsumerWidget {
  const _VehicleChipList({required this.vehicles, required this.selectedId});

  final List<Vehicle> vehicles;
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final items = <Widget>[
      _AllVehiclesChip(
        count: vehicles.length,
        selected: selectedId == null,
        onTap: () => ref.read(ledgerFilterProvider.notifier).selectVehicle(null),
      ),
      for (final vehicle in vehicles)
        _PillChip(
          selected: selectedId == vehicle.id,
          onTap: () =>
              ref.read(ledgerFilterProvider.notifier).selectVehicle(vehicle.id),
          label: vehicle.name,
          leading: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: vehicle.powertrain.color,
            ),
          ),
          selectedColor: palette.onSurface,
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

class _AllVehiclesChip extends StatelessWidget {
  const _AllVehiclesChip({
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return _PillChip(
      selected: selected,
      onTap: onTap,
      label: '全部车辆 ($count)',
      leading: Icon(
        Icons.directions_car_rounded,
        size: 14,
        color: selected ? palette.surface : palette.onSurfaceVariant,
      ),
      selectedColor: palette.onSurface,
    );
  }
}

class _PillChip extends StatelessWidget {
  const _PillChip({
    required this.selected,
    required this.onTap,
    required this.label,
    required this.selectedColor,
    this.leading,
  });

  final bool selected;
  final VoidCallback onTap;
  final String label;
  final Color selectedColor;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final background = selected ? selectedColor : palette.surface;
    final foreground = selected ? palette.surface : palette.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? selectedColor
                : palette.outlineVariant.withValues(alpha: 0.6),
          ),
          boxShadow: selected ? null : tokens.cardShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 6)],
            Text(
              label,
              style: AppTypography.labelMd.copyWith(
                color: foreground,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
