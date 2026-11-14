import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

/// 首字头像：渐变底 + 昵称首字 + 可选在线状态点。
///
/// 首页顶栏、我的页顶栏与个人资料卡共用；不依赖图片资源。
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.initial,
    this.size = 40,
    this.showStatusDot = true,
    this.ringColor,
  });

  final String initial;
  final double size;
  final bool showStatusDot;

  /// 头像描边色；为空时使用卡片底色，与首页顶栏保持一致。
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dotSize = size >= 40 ? 12.0 : 10.0;
    final borderWidth = size >= 48 ? 3.0 : 2.0;
    final ring = ringColor;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFD9C0), Color(0xFFF7B7A3)],
              ),
              border: Border.all(
                color: ring ?? palette.surface,
                width: borderWidth,
              ),
              boxShadow: ring == null
                  ? [
                      BoxShadow(
                        color: palette.shadow.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: ring.withValues(alpha: 0.35),
                        blurRadius: size * 0.16,
                        spreadRadius: 1,
                      ),
                    ],
            ),
            child: Text(
              initial,
              maxLines: 1,
              style: AppTypography.headlineSm.copyWith(
                fontSize: size * 0.4,
                color: const Color(0xFF8A4B3C),
              ),
            ),
          ),
          if (showStatusDot)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: dotSize,
                height: dotSize,
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
