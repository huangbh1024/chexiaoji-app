import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/report_models.dart';

/// 导出配置：能耗分析、发票附件、车牌脱敏。
class ReportOptionToggles extends StatelessWidget {
  const ReportOptionToggles({
    super.key,
    required this.options,
    required this.onChanged,
    required this.onUnavailable,
  });

  final ReportOptions options;
  final ValueChanged<ReportOptions> onChanged;
  final VoidCallback onUnavailable;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        border: Border.all(color: palette.cardBorder),
        boxShadow: tokens.cardShadow,
      ),
      child: Column(
        children: [
          _ToggleRow(
            title: '包含能耗与每公里成本分析',
            description: '附带每百公里能耗图表与环比变化',
            value: options.includeEnergy,
            onTap: () => onChanged(
              options.copyWith(includeEnergy: !options.includeEnergy),
            ),
          ),
          _Divider(color: palette.surfaceContainer),
          _ToggleRow(
            title: '附带消费电子凭证与发票小票',
            description: '自动提取报销专用二维码与发票缩略图',
            value: options.includeInvoices,
            enabled: false,
            trailingLabel: '暂不支持',
            onTap: onUnavailable,
          ),
          _Divider(color: palette.surfaceContainer),
          _ToggleRow(
            title: '隐藏车牌及个人敏感隐私',
            description: options.maskPlate
                ? '车牌已脱敏 · 粤B·D****'
                : '车牌中段脱敏处理 (粤B·D****)',
            value: options.maskPlate,
            onTap: () =>
                onChanged(options.copyWith(maskPlate: !options.maskPlate)),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.description,
    required this.value,
    required this.onTap,
    this.enabled = true,
    this.trailingLabel,
  });

  final String title;
  final String description;
  final bool value;
  final VoidCallback onTap;
  final bool enabled;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      checked: value,
      enabled: enabled,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Opacity(
          opacity: enabled ? 1 : 0.55,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: AppTypography.labelLg.copyWith(
                                color: palette.onSurface,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (trailingLabel != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: palette.surfaceContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                trailingLabel!,
                                style: AppTypography.labelSm.copyWith(
                                  color: palette.outline,
                                  fontSize: 8,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: AppTypography.bodySm.copyWith(
                          color: palette.outline,
                          fontSize: 9,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _CheckBox(value: value),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: value ? palette.primary : palette.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: value
              ? palette.primary
              : palette.outlineVariant.withValues(alpha: 0.8),
          width: 1.5,
        ),
      ),
      child: value
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: color);
  }
}
