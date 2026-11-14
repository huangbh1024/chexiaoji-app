import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/domain/vehicle.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/presentation/category_style.dart';
import '../../../../core/presentation/toast.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../../domain/expense_entry_models.dart';
import '../../domain/providers.dart';
import '../expense_entry_style.dart';
import 'entry_vehicle_sheet.dart';

class EntryVehicleCard extends ConsumerWidget {
  const EntryVehicleCard({super.key, required this.args});

  final ExpenseEntryArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final state = ref.watch(expenseEntryControllerProvider(args));
    final vehicle = state.vehicle;

    if (vehicle == null) {
      if (state.hasNoVehicles) {
        return const SizedBox.shrink();
      }
      return const AppCard(
        radius: ExpenseEntryStyle.cardRadius,
        padding: EdgeInsets.fromLTRB(12, 12, 16, 12),
        child: Row(
          children: [
            SkeletonBox(width: 44, height: 44, radius: 22),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 132, height: 16),
                  SizedBox(height: 8),
                  SkeletonBox(width: 180, height: 12),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      radius: ExpenseEntryStyle.cardRadius,
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            top: -12,
            bottom: -12,
            width: 144,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      palette.primary.withValues(alpha: 0.15),
                      palette.primary.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: palette.primary.withValues(alpha: 0.24),
                  ),
                ),
                child: Icon(
                  vehicle.powertrain.icon,
                  size: 22,
                  color: palette.primaryText,
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
                            vehicle.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyLg.copyWith(
                              fontSize: 14,
                              height: 20 / 14,
                              fontWeight: FontWeight.w700,
                              color: palette.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _PowertrainBadge(vehicle: vehicle),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${vehicle.plate} · 当前 ${formatKm(vehicle.odometerKm)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySm.copyWith(
                        fontSize: 12,
                        color: palette.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SwitchButton(
                onTap: () async {
                  final selected = await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => EntryVehicleSheet(
                      vehicles: state.vehicles,
                      selectedId: vehicle.id,
                    ),
                  );
                  if (selected == null || !context.mounted) {
                    return;
                  }
                  await ref
                      .read(expenseEntryControllerProvider(args).notifier)
                      .selectVehicle(selected);
                  if (!context.mounted) {
                    return;
                  }
                  final next = ref
                      .read(expenseEntryControllerProvider(args))
                      .vehicle;
                  if (next != null) {
                    showAppToast(context, '已切换至 ${next.name}');
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PowertrainBadge extends StatelessWidget {
  const _PowertrainBadge({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = vehicle.powertrain.badgeTextColor(palette);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: vehicle.powertrain.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        vehicle.powertrainLabel,
        style: AppTypography.labelSm.copyWith(color: color),
      ),
    );
  }
}

class _SwitchButton extends StatelessWidget {
  const _SwitchButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: '切换记账车辆',
      child: SizedBox(
        width: 60,
        height: 44,
        child: Center(
          child: Material(
            color: palette.surfaceContainer,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '切换',
                      style: AppTypography.labelSm.copyWith(
                        color: palette.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.expand_more_rounded,
                      size: 14,
                      color: palette.onSurfaceVariant,
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
