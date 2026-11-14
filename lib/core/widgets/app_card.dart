import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';

/// 卡片统一容器：白底、16 圆角、柔和阴影、1px 内描边。
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// 默认使用 [AppTokens.radiusCard]；账单页汇总卡传入 32。
  final double? radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? palette.surface,
        borderRadius: BorderRadius.circular(radius ?? tokens.radiusCard),
        border: Border.all(color: palette.cardBorder),
        boxShadow: tokens.cardShadow,
      ),
      child: child,
    );
  }
}
