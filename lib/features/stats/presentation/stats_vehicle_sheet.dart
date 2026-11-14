import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/presentation/category_style.dart';
import '../../home/domain/providers.dart';
import '../domain/providers.dart';

class StatsVehicleSheet extends ConsumerWidget {
  const StatsVehicleSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final tokens = context.tokens;
    final vehicles = ref.watch(vehiclesProvider);
    final selectedId = ref.watch(
      statsFilterProvider.select((filter) => filter.vehicleId),
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.outlineVariant,
                  borderRadius: BorderRadius.circular(tokens.radiusPill),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.directions_car_rounded,
                    color: palette.primaryText,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '选择爱车',
                    style: AppTypography.headlineSm.copyWith(
                      color: palette.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: palette.outline),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Flexible(
                child: vehicles.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (error, stack) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      '车辆加载失败',
                      style: AppTypography.bodyMd.copyWith(
                        color: palette.outline,
                      ),
                    ),
                  ),
                  data: (items) => ListView(
                    shrinkWrap: true,
                    children: [
                      _VehicleOption(
                        title: '全部车辆（汇总）',
                        subtitle: '共 ${items.length} 辆车合并核算',
                        icon: Icons.garage_rounded,
                        iconColor: palette.tertiary,
                        iconBackground: palette.tertiary.withValues(
                          alpha: 0.14,
                        ),
                        selected: selectedId == null,
                        onTap: () {
                          ref
                              .read(statsFilterProvider.notifier)
                              .selectVehicle(null);
                          Navigator.of(context).pop();
                        },
                      ),
                      for (final vehicle in items)
                        _VehicleOption(
                          title: vehicle.name,
                          subtitle: vehicle.plate,
                          icon: vehicle.powertrain.icon,
                          iconColor: vehicle.powertrain.color,
                          iconBackground: vehicle.powertrain.color.withValues(
                            alpha: 0.14,
                          ),
                          chipLabel: vehicle.powertrainLabel,
                          chipColor: vehicle.powertrain.badgeTextColor(palette),
                          selected: selectedId == vehicle.id,
                          onTap: () {
                            ref
                                .read(statsFilterProvider.notifier)
                                .selectVehicle(vehicle.id);
                            Navigator.of(context).pop();
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleOption extends StatelessWidget {
  const _VehicleOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.selected,
    required this.onTap,
    this.chipLabel,
    this.chipColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final bool selected;
  final VoidCallback onTap;
  final String? chipLabel;
  final Color? chipColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final chipText = chipColor ?? palette.outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected
            ? palette.primary.withValues(alpha: 0.08)
            : palette.surfaceContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radiusCard),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.radiusCard),
              border: Border.all(
                color: selected
                    ? palette.primary.withValues(alpha: 0.25)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
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
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.headlineSm.copyWith(
                                fontSize: 15,
                                color: palette.onSurface,
                              ),
                            ),
                          ),
                          if (chipLabel != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: chipText.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                chipLabel!,
                                style: AppTypography.labelSm.copyWith(
                                  color: chipText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm.copyWith(
                          color: palette.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: palette.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
