import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';

/// 顶部「更多」菜单。
class DetailMoreSheet extends StatelessWidget {
  const DetailMoreSheet({
    super.key,
    required this.onCopy,
    required this.onDelete,
  });

  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '更多操作',
                  style: AppTypography.labelLg.copyWith(
                    color: palette.outline,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.copy_rounded,
                color: palette.onSurfaceVariant,
              ),
              title: Text(
                '复制账单信息',
                style: AppTypography.bodyLg.copyWith(color: palette.onSurface),
              ),
              onTap: () {
                Navigator.of(context).pop();
                onCopy();
              },
            ),
            ListTile(
              enabled: false,
              leading: Icon(Icons.image_rounded, color: palette.disabled),
              title: Text(
                '分享为图片',
                style: AppTypography.bodyLg.copyWith(color: palette.disabled),
              ),
              subtitle: Text(
                '暂不支持',
                style: AppTypography.bodySm.copyWith(color: palette.disabled),
              ),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: palette.error),
              title: Text(
                '删除此笔账单',
                style: AppTypography.bodyLg.copyWith(color: palette.error),
              ),
              onTap: () {
                Navigator.of(context).pop();
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}
