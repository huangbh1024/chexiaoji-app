import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../vehicle_management_style.dart';

class VehicleManagementSkeleton extends StatelessWidget {
  const VehicleManagementSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 150,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: palette.primary.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(
              VehicleManagementStyle.cardRadius,
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 120, height: 14),
              Spacer(),
              Row(
                children: [
                  Expanded(child: SkeletonBox(height: 52, radius: 16)),
                  SizedBox(width: 12),
                  Expanded(child: SkeletonBox(height: 52, radius: 16)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SkeletonBox(width: 96, height: 16),
        const SizedBox(height: 12),
        for (var index = 0; index < 3; index++) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(
                VehicleManagementStyle.cardRadius,
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SkeletonBox(width: 44, height: 44, radius: 16),
                    SizedBox(width: 12),
                    Expanded(child: SkeletonBox(height: 16)),
                  ],
                ),
                SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: SkeletonBox(height: 34)),
                    SizedBox(width: 12),
                    Expanded(child: SkeletonBox(height: 34)),
                    SizedBox(width: 12),
                    Expanded(child: SkeletonBox(height: 34)),
                  ],
                ),
                SizedBox(height: 16),
                SkeletonBox(height: 36, radius: 18),
              ],
            ),
          ),
          if (index < 2) const SizedBox(height: 12),
        ],
      ],
    );
  }
}
