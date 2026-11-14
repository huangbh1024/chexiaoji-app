import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/domain/app_info.dart';

class AboutSheet extends StatelessWidget {
  const AboutSheet({super.key});

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
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [palette.heroStart, palette.heroEnd],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: tokens.heroShadow,
                ),
                child: const Icon(
                  Icons.directions_car_filled_rounded,
                  size: 28,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppInfo.name,
              textAlign: TextAlign.center,
              style: AppTypography.headlineMd.copyWith(
                color: palette.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'v${AppInfo.version}',
              textAlign: TextAlign.center,
              style: AppTypography.labelMd.copyWith(color: palette.outline),
            ),
            const SizedBox(height: 8),
            Text(
              AppInfo.tagline,
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(color: palette.outline),
            ),
            const SizedBox(height: 20),
            Container(height: 1, color: palette.surfaceContainer),
            const _AboutRow(title: '常见问题', trailing: '即将上线'),
            Container(height: 1, color: palette.surfaceContainer),
            const _AboutRow(title: '更新日志', trailing: 'v${AppInfo.version}'),
            Container(height: 1, color: palette.surfaceContainer),
            const _AboutRow(title: '意见反馈', trailing: '即将上线'),
            const SizedBox(height: 20),
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
                child: const Text('关闭'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTypography.bodyLg.copyWith(
                color: palette.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            trailing,
            style: AppTypography.labelMd.copyWith(color: palette.outline),
          ),
        ],
      ),
    );
  }
}
