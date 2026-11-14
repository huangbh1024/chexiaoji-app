import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../expense_detail_style.dart';

/// 底部固定操作栏。
class DetailBottomBar extends StatelessWidget {
  const DetailBottomBar({
    super.key,
    required this.enabled,
    required this.onReAdd,
    required this.onEdit,
  });

  final bool enabled;
  final VoidCallback onReAdd;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.92),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: palette.glassBorder.withValues(alpha: 0.6),
          ),
        ),
        boxShadow: tokens.navShadow,
      ),
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: _ActionButton(
                label: '再记一笔',
                icon: Icons.add_circle_outline_rounded,
                onTap: enabled ? onReAdd : null,
                secondary: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _ActionButton(
                label: '编辑此笔账单',
                icon: Icons.edit_note_rounded,
                onTap: enabled ? onEdit : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.secondary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final foreground = secondary ? palette.onSurface : Colors.white;
    final decoration = BoxDecoration(
      color: secondary ? palette.surfaceContainer : null,
      gradient: secondary
          ? null
          : LinearGradient(
              colors: [palette.primaryText, palette.primary],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
      borderRadius: BorderRadius.circular(999),
      boxShadow: secondary
          ? null
          : [
              BoxShadow(
                color: palette.primary.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
    );
    return Semantics(
      button: true,
      label: label,
      enabled: onTap != null,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: decoration,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: ExpenseDetailStyle.actionHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: foreground),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLg.copyWith(
                        color: foreground,
                        fontSize: 14,
                        height: 22 / 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
