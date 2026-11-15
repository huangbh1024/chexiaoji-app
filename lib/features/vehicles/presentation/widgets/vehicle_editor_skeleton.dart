import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/skeleton_box.dart';

class VehicleEditorSkeleton extends StatelessWidget {
  const VehicleEditorSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const SkeletonBox(height: 78, radius: 20),
        const SizedBox(height: 20),
        for (var i = 0; i < 3; i++) ...[
          AppCard(
            radius: 28,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: 120, height: 18),
                const SizedBox(height: 16),
                const SkeletonBox(height: 48, radius: 16),
                const SizedBox(height: 12),
                const SkeletonBox(height: 48, radius: 16),
                const SizedBox(height: 12),
                const SkeletonBox(height: 48, radius: 16),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}
