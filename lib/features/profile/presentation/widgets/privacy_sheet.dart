import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';

class PrivacySheet extends StatelessWidget {
  const PrivacySheet({super.key});

  static const _items = <String>[
    '当前版本的数据保存在本机，未上传云端；演示阶段为本地模拟数据。',
    '手机号仅在账号区以掩码形式展示；车牌在车辆卡中完整展示。',
    '导出的报表文件保存在本机临时目录，24 小时后自动清理。',
    '当前版本尚未启用端到端加密，因此不展示相关安全承诺。',
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.shield_rounded,
                    size: 22,
                    color: palette.primaryText,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '隐私与数据',
                  style: AppTypography.headlineSm.copyWith(
                    color: palette.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final item in _items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        size: 16,
                        color: palette.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: AppTypography.bodyMd.copyWith(
                          color: palette.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusPill),
                  ),
                ),
                child: const Text('知道了'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
