import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import 'app_card.dart';

/// 空状态：图标 + 说明 + 可选行动按钮。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      child: Column(
        children: [
          Icon(icon, size: 28, color: palette.outline),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd.copyWith(
              color: palette.onSurfaceVariant,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
