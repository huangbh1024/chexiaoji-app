import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_typography.dart';

/// 一级 Tab 顶部栏：头像 + 问候 + 标题 + 自定义右侧区域。
///
/// 首页传操作按钮组，统计页传车辆切换胶囊 + 通知按钮。
class AppTabHeader extends StatelessWidget {
  const AppTabHeader({
    super.key,
    required this.title,
    this.trailing,
    this.showGreeting = true,
    this.leading,
  });

  final String title;
  final Widget? trailing;
  final bool showGreeting;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: SizedBox(
        height: tokens.headerHeight,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.pagePadding,
            vertical: tokens.spaceSm,
          ),
          child: Row(
            children: [
              leading ?? const _Avatar(),
              SizedBox(width: tokens.spaceSm),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showGreeting)
                        Text(
                          '${greetingFor(DateTime.now())}，林漪',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySm.copyWith(
                            color: palette.outline,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headlineMd.copyWith(
                          color: palette.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: tokens.spaceSm),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String greetingFor(DateTime now) {
  final hour = now.hour;
  if (hour >= 5 && hour < 11) {
    return '早上好';
  }
  if (hour >= 11 && hour < 13) {
    return '中午好';
  }
  if (hour >= 13 && hour < 18) {
    return '下午好';
  }
  if (hour >= 18 && hour < 23) {
    return '晚上好';
  }
  return '夜深了';
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFD9C0), Color(0xFFF7B7A3)],
              ),
              border: Border.all(color: palette.surface, width: 2),
              boxShadow: [
                BoxShadow(
                  color: palette.shadow.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '林',
              style: AppTypography.headlineSm.copyWith(
                color: const Color(0xFF8A4B3C),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: palette.primary,
                shape: BoxShape.circle,
                border: Border.all(color: palette.surface, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
