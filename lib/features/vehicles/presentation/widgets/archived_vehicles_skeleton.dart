import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../archived_vehicles_style.dart';

class ArchivedVehiclesSkeleton extends StatelessWidget {
  const ArchivedVehiclesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SkeletonBox(width: 96, height: 16),
        const SizedBox(height: 12),
        for (var index = 0; index < 2; index++) ...[
          Container(
            padding: const EdgeInsets.all(ArchivedVehiclesStyle.cardPadding),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(
                ArchivedVehiclesStyle.cardRadius,
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SkeletonBox(width: 48, height: 48, radius: 16),
                    SizedBox(width: 12),
                    Expanded(child: SkeletonBox(height: 16)),
                    SizedBox(width: 12),
                    SkeletonBox(width: 64, height: 20, radius: 10),
                  ],
                ),
                SizedBox(height: 16),
                SkeletonBox(height: 64, radius: 16),
                SizedBox(height: 14),
                SkeletonBox(width: 160, height: 12),
                SizedBox(height: 14),
                Row(
                  children: [
                    SkeletonBox(width: 72, height: 32, radius: 16),
                    Spacer(),
                    SkeletonBox(width: 96, height: 32, radius: 16),
                    SizedBox(width: 8),
                    SkeletonBox(width: 96, height: 32, radius: 16),
                  ],
                ),
              ],
            ),
          ),
          if (index < 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}
