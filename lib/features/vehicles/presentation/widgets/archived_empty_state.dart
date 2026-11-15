import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../archived_vehicles_style.dart';

/// 归档列表为空：说明当前没有封存车辆并提供返回入口。
class ArchivedEmptyState extends StatelessWidget {
  const ArchivedEmptyState({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(ArchivedVehiclesStyle.cardRadius),
        border: Border.all(
          color: palette.outlineVariant.withValues(alpha: 0.60),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: palette.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.garage_rounded, size: 32, color: palette.outline),
          ),
          const SizedBox(height: 14),
          Text(
            '车库档案箱空空如也',
            style: AppTypography.headlineSm.copyWith(color: palette.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            '当前没有封存车辆，所有在用座驾都在常用车库中提供能耗与开销看板。',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd.copyWith(
              color: palette.outline,
              height: 20 / 13,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onBack,
            style: FilledButton.styleFrom(
              backgroundColor: palette.surfaceContainer,
              foregroundColor: palette.primaryText,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            child: Text(
              '返回常用车库',
              style: AppTypography.labelLg.copyWith(
                color: palette.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
