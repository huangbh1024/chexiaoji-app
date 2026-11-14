import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/report_models.dart';

/// 导出格式选择：PDF / Excel-CSV / 长图海报。
class ReportFormatCards extends StatelessWidget {
  const ReportFormatCards({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onUnavailable,
  });

  final ReportFormat value;
  final ValueChanged<ReportFormat> onChanged;
  final VoidCallback onUnavailable;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '导出选项与格式',
              style: AppTypography.headlineSm.copyWith(
                color: palette.onSurface,
              ),
            ),
            const Spacer(),
            Text(
              '选择输出类型',
              style: AppTypography.labelSm.copyWith(color: palette.outline),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _FormatCard(
                icon: Icons.picture_as_pdf_rounded,
                iconColor: palette.primary,
                iconBackground: palette.primary.withValues(alpha: 0.14),
                title: 'PDF 官方报表',
                description: '适合财务报销及打印',
                footer: '推荐使用',
                footerColor: palette.primary,
                selected: value == ReportFormat.pdf,
                onTap: () => onChanged(ReportFormat.pdf),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _FormatCard(
                icon: Icons.table_chart_rounded,
                iconColor: palette.tertiary,
                iconBackground: palette.surfaceContainer,
                title: 'Excel / CSV',
                description: '明细流水及计算公式',
                footer: '原始数据',
                selected: value == ReportFormat.csv,
                onTap: () => onChanged(ReportFormat.csv),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _FormatCard(
                icon: Icons.photo_library_rounded,
                iconColor: palette.secondary,
                iconBackground: palette.surfaceContainer,
                title: '长图海报',
                description: '社交网络与车友圈',
                footer: '即将支持',
                enabled: false,
                selected: false,
                onTap: onUnavailable,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FormatCard extends StatelessWidget {
  const _FormatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.description,
    required this.footer,
    required this.selected,
    required this.onTap,
    this.footerColor,
    this.enabled = true,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String description;
  final String footer;
  final bool selected;
  final VoidCallback onTap;
  final Color? footerColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: enabled ? 1 : 0.55,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 116,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? palette.primary : Colors.transparent,
                  width: 2,
                ),
                boxShadow: tokens.cardShadow,
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: iconBackground,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(icon, size: 16, color: iconColor),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: AppTypography.labelMd.copyWith(
                          color: palette.onSurface,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: AppTypography.bodySm.copyWith(
                          color: palette.outline,
                          fontSize: 9,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Text(
                        footer,
                        style: AppTypography.labelSm.copyWith(
                          color: footerColor ?? palette.outline,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                  if (selected)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: palette.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: palette.surface,
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: Colors.white,
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
