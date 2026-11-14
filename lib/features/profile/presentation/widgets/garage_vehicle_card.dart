import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/presentation/category_style.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/profile_models.dart';
import '../../domain/profile_presenter.dart';

class GarageVehicleCard extends StatelessWidget {
  const GarageVehicleCard({
    super.key,
    required this.view,
    required this.snapshot,
    required this.onAdd,
  });

  final GarageCardView view;
  final GarageSnapshot snapshot;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final powertrain = snapshot.powertrain;
    final tint = powertrain?.color ?? palette.primary;
    final badgeTextColor =
        powertrain?.badgeTextColor(palette) ?? palette.primaryText;
    final icon = powertrain?.icon ?? Icons.garage_rounded;

    return AppCard(
      key: const Key('garage-card'),
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        child: Stack(
          children: [
            Positioned(
              right: -46,
              bottom: -58,
              child: IgnorePointer(
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        tint.withValues(alpha: 0.16),
                        tint.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tint.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(
                                      tokens.radiusPill,
                                    ),
                                  ),
                                  child: Text(
                                    view.badge,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.labelSm.copyWith(
                                      color: badgeTextColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: palette.surfaceContainer,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      view.plateText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.labelMd.copyWith(
                                        color: palette.onSurface,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Text(
                              view.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.headlineSm.copyWith(
                                color: palette.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              view.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySm.copyWith(
                                color: palette.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: palette.surfaceContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(icon, size: 28, color: tint),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(height: 1, color: palette.surfaceContainer),
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _MetricBox(
                            label: '当前总里程',
                            value: view.odometerText,
                            sub: '公里',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MetricBox(
                            label: '本月能耗支出',
                            value: view.energyAmountText,
                            sub: view.energySubText,
                            valueColor: palette.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MetricBox(
                            label: '下期保养预警',
                            value: view.maintenanceValue,
                            sub: view.maintenanceUnit,
                            valueColor: _maintenanceColor(
                              palette,
                              view.maintenanceStatus,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(height: 1, color: palette.surfaceContainer),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        _tipIcon(view.tipKind),
                        size: 16,
                        color: view.tipKind == GarageTipKind.empty
                            ? palette.outline
                            : palette.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          view.tipText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySm.copyWith(
                            color: palette.outline,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        button: true,
                        label: '添加新车',
                        child: Material(
                          color: palette.surfaceContainer,
                          borderRadius: BorderRadius.circular(
                            tokens.radiusPill,
                          ),
                          child: InkWell(
                            key: const Key('garage-add-vehicle'),
                            onTap: onAdd,
                            borderRadius: BorderRadius.circular(
                              tokens.radiusPill,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_rounded,
                                    size: 14,
                                    color: palette.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '添加新车',
                                    style: AppTypography.labelMd.copyWith(
                                      color: palette.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({
    required this.label,
    required this.value,
    required this.sub,
    this.valueColor,
  });

  final String label;
  final String value;
  final String sub;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surfaceContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSm.copyWith(color: palette.outline),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: AppTypography.headlineSm.copyWith(
                color: valueColor ?? palette.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.labelSm.copyWith(color: palette.outline),
          ),
        ],
      ),
    );
  }
}

Color _maintenanceColor(AppPalette palette, MaintenanceStatus status) {
  return switch (status) {
    MaintenanceStatus.overdue || MaintenanceStatus.warning => palette.error,
    MaintenanceStatus.normal => palette.secondary,
  };
}

IconData _tipIcon(GarageTipKind kind) {
  return switch (kind) {
    GarageTipKind.charging => Icons.bolt_rounded,
    GarageTipKind.fuel => Icons.local_gas_station_rounded,
    GarageTipKind.mixed => Icons.ev_station_rounded,
    GarageTipKind.energySummary => Icons.verified_rounded,
    GarageTipKind.empty => Icons.info_outline_rounded,
  };
}
