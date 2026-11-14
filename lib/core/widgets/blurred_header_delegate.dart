import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';

/// 毛玻璃吸顶栏：页面底色 86% + 16px 模糊。
class BlurredHeaderDelegate extends SliverPersistentHeaderDelegate {
  const BlurredHeaderDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final palette = context.palette;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: ColoredBox(
          color: palette.background.withValues(alpha: 0.86),
          child: child,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant BlurredHeaderDelegate oldDelegate) => true;
}
