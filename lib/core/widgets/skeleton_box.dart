import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';

/// 骨架占位块。
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.palette.surfaceContainer,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
