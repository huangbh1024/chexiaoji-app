import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/providers.dart';

class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final tokens = context.tokens;
    final themeMode = ref.watch(themeModeProvider);
    final unread = ref.watch(unreadCountProvider);

    return SizedBox(
      height: tokens.headerHeight,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.pagePadding,
          vertical: tokens.spaceSm,
        ),
        child: Row(
          children: [
            _Avatar(palette: palette),
            SizedBox(width: tokens.spaceSm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_greeting(DateTime.now())}，林漪',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySm.copyWith(
                      color: palette.outline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '车小记',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.headlineMd.copyWith(
                      color: palette.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: palette.surface.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(tokens.radiusPill),
                border: Border.all(
                  color: palette.glassBorder.withValues(alpha: 0.6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.shadow.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HeaderAction(
                    icon: themeMode == ThemeMode.dark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    tooltip: '切换深色模式',
                    onTap: () => ref.read(themeModeProvider.notifier).toggle(),
                  ),
                  _HeaderAction(
                    icon: Icons.palette_rounded,
                    tooltip: '主题色',
                    onTap: () => _toast(context, '主题色切换待接入'),
                  ),
                  _HeaderAction(
                    icon: Icons.notifications_none_rounded,
                    tooltip: '消息',
                    showDot: unread > 0,
                    onTap: () => _toast(context, '消息中心待接入'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  String _greeting(DateTime now) {
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
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
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

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 18, color: palette.onSurfaceVariant),
              if (showDot)
                Positioned(
                  top: 7,
                  right: 7,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: palette.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
