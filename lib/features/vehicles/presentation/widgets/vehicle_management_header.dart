import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/vehicle_models.dart';
import '../../domain/vehicle_presenter.dart';

class VehicleManagementHeader extends StatelessWidget {
  const VehicleManagementHeader({
    super.key,
    required this.summary,
    required this.canPop,
    required this.onAdd,
  });

  final FleetSummary? summary;
  final bool canPop;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final subtitle = summary == null
        ? '车库数据加载中'
        : '名下在库 ${summary!.vehicleCount} 辆座驾 · ${_healthText(summary!)}';

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: SizedBox(
        height: tokens.headerHeight,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.pagePadding),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: '返回',
                child: Material(
                  color: palette.surface,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: canPop
                        ? () => Navigator.of(context).maybePop()
                        : null,
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: canPop ? palette.onSurface : palette.disabled,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '车辆管理',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headlineMd.copyWith(
                        color: palette.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
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
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: '添加爱车',
                child: Material(
                  color: palette.primary,
                  borderRadius: BorderRadius.circular(tokens.radiusPill),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onAdd,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.add_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '添加爱车',
                            style: AppTypography.labelMd.copyWith(
                              color: Colors.white,
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
        ),
      ),
    );
  }

  String _healthText(FleetSummary value) {
    final label = VehiclePresenter.healthLabel(value);
    return label.isEmpty ? '资产数据待完善' : label;
  }
}
