import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/report_models.dart';
import '../../domain/report_presenter.dart';

/// 底部固定操作栏：全屏全貌 + 动态导出 CTA。
class ReportBottomDock extends StatelessWidget {
  const ReportBottomDock({
    super.key,
    required this.format,
    required this.enabled,
    required this.onFullscreen,
    required this.onExport,
    this.busy = false,
    this.disabledReason,
  });

  final ReportFormat format;
  final bool enabled;
  final VoidCallback onFullscreen;
  final VoidCallback onExport;
  final bool busy;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final canTap = enabled && !busy;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
          decoration: BoxDecoration(
            color: palette.surface.withValues(alpha: 0.92),
            boxShadow: tokens.navShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _SecondaryButton(onTap: onFullscreen),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PrimaryButton(
                      label: reportCtaLabel(format),
                      icon: _formatIcon(format),
                      enabled: canTap,
                      busy: busy,
                      onTap: onExport,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                disabledReason ?? '支持 AirDrop隔空投送 · 微信文件传输 · 邮件发送与本地留存',
                textAlign: TextAlign.center,
                style: AppTypography.bodySm.copyWith(
                  color: disabledReason == null
                      ? palette.outline
                      : palette.secondaryText,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _formatIcon(ReportFormat format) => switch (format) {
    ReportFormat.pdf => Icons.download_rounded,
    ReportFormat.csv => Icons.table_view_rounded,
    ReportFormat.poster => Icons.image_rounded,
  };
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      button: true,
      label: '全屏全貌',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: palette.surfaceContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.preview_rounded, size: 18, color: palette.onSurface),
              const SizedBox(width: 6),
              Text(
                '全屏全貌',
                style: AppTypography.labelLg.copyWith(
                  color: palette.onSurface,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: enabled ? onTap : null,
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.primaryText,
          disabledBackgroundColor: palette.primary.withValues(alpha: 0.35),
          disabledForegroundColor: palette.onSurface.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: const StadiumBorder(),
          textStyle: AppTypography.headlineSm.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: palette.primaryText,
                ),
              )
            else
              Icon(icon, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                busy ? '正在生成…' : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
