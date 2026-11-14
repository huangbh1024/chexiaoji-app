import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';

/// 详情页顶部栏。由页面放进 [BlurredHeaderDelegate] 里吸顶。
class DetailHeader extends StatelessWidget {
  const DetailHeader({
    super.key,
    required this.topInset,
    required this.enabled,
    required this.onBack,
    required this.onShare,
    required this.onMore,
  });

  final double topInset;
  final bool enabled;
  final VoidCallback onBack;
  final VoidCallback? onShare;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 88),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '开销详情',
                  style: AppTypography.headlineSm.copyWith(
                    color: palette.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '全品类通用账单',
                  style: AppTypography.labelSm.copyWith(
                    color: palette.outline,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _RoundIconButton(
                icon: Icons.arrow_back_rounded,
                label: '返回',
                onTap: onBack,
              ),
              const Spacer(),
              _RoundIconButton(
                icon: Icons.ios_share_rounded,
                label: '分享凭证',
                onTap: enabled ? onShare : null,
                shadow: tokens.cardShadow,
              ),
              const SizedBox(width: 8),
              _RoundIconButton(
                icon: Icons.more_horiz_rounded,
                label: '更多操作',
                onTap: enabled ? onMore : null,
                shadow: tokens.cardShadow,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.shadow = const <BoxShadow>[],
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final List<BoxShadow> shadow;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onTap != null;
    return Semantics(
      button: true,
      label: label,
      enabled: enabled,
      child: Tooltip(
        message: label,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: palette.surface,
            shape: BoxShape.circle,
            boxShadow: shadow,
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Opacity(
                opacity: enabled ? 1 : 0.4,
                child: Icon(icon, size: 20, color: palette.onSurface),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
