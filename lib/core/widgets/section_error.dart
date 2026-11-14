import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import 'app_card.dart';

/// 模块级错误提示：一行说明 + 重试。
class SectionError extends StatelessWidget {
  const SectionError({super.key, required this.onRetry, this.message = '加载失败'});

  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 20, color: palette.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyMd.copyWith(
                color: palette.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
