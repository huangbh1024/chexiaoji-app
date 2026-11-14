import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';

/// 账单页顶部栏：图标 + 标题 + 导出 / 筛选。
class LedgerHeader extends StatelessWidget {
  const LedgerHeader({
    super.key,
    required this.hasActiveFilter,
    required this.onExport,
    required this.onFilter,
  });

  final bool hasActiveFilter;
  final VoidCallback onExport;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.surfaceContainer,
              border: Border.all(
                color: palette.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 20,
              color: palette.primaryText,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '账单明细',
            style: AppTypography.headlineMd.copyWith(
              color: palette.onSurface,
            ),
          ),
          const Spacer(),
          _HeaderAction(
            icon: Icons.ios_share_rounded,
            tooltip: '导出报表',
            onTap: onExport,
          ),
          const SizedBox(width: 8),
          _HeaderAction(
            icon: Icons.tune_rounded,
            tooltip: '筛选明细',
            onTap: onFilter,
            showDot: hasActiveFilter,
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
    final tokens = context.tokens;

    return Semantics(
      button: true,
      label: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: palette.surface,
            boxShadow: tokens.cardShadow,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 18, color: palette.onSurface),
              if (showDot)
                Positioned(
                  top: 7,
                  right: 7,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.primary,
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
