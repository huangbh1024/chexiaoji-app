import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/presentation/category_style.dart';
import '../../domain/vehicle_models.dart';
import '../../domain/vehicle_presenter.dart';
import '../archived_vehicles_style.dart';

/// 归档卡三指标托盘：封存里程 / 累计花费 / 历史能耗。
class ArchivedVehicleMetrics extends StatelessWidget {
  const ArchivedVehicleMetrics({super.key, required this.vehicle});

  final ArchivedVehicleSummary vehicle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accent = vehicle.powertrain.color;
    final metrics = ArchivedVehiclePresenter.metricsOf(vehicle);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceContainer.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(
          ArchivedVehiclesStyle.metricTrayRadius,
        ),
        border: Border.all(
          color: palette.surfaceContainer.withValues(alpha: 0.60),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < metrics.length; index++) ...[
            if (index > 0)
              Container(
                width: 1,
                height: 34,
                margin: const EdgeInsets.only(right: 8),
                color: palette.outlineVariant.withValues(alpha: 0.40),
              ),
            Expanded(
              child: _MetricColumn(metric: metrics[index], accent: accent),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({required this.metric, required this.accent});

  final VehicleMetric metric;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = switch (metric.tone) {
      VehicleMetricTone.normal => palette.onSurface,
      VehicleMetricTone.accent => accent,
      VehicleMetricTone.warning => palette.secondaryText,
      VehicleMetricTone.danger => palette.error,
      VehicleMetricTone.muted => palette.outline,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          metric.label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelSm.copyWith(color: palette.outline),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                metric.value,
                style: AppTypography.headlineSm.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (metric.unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(
                  metric.unit,
                  style: AppTypography.labelSm.copyWith(
                    color: color.withValues(alpha: 0.70),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
