import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';

/// 月度报表页顶部栏：返回 + 标题 + 打印 / 分享。
class ReportHeader extends StatelessWidget {
  const ReportHeader({
    super.key,
    required this.onBack,
    required this.onPrint,
    required this.onShare,
    this.busy = false,
  });

  final VoidCallback onBack;
  final VoidCallback onPrint;
  final VoidCallback onShare;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _CircleButton(
            icon: Icons.arrow_back_rounded,
            tooltip: '返回账单',
            onTap: onBack,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '月度报表与导出',
                  style: AppTypography.headlineSm.copyWith(
                    color: palette.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '核对用车成本并生成凭证文档',
                  style: AppTypography.bodySm.copyWith(color: palette.outline),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _CircleButton(
            icon: Icons.print_rounded,
            tooltip: '打印预览',
            onTap: busy ? null : onPrint,
            busy: busy,
          ),
          const SizedBox(width: 8),
          _CircleButton(
            icon: Icons.share_rounded,
            tooltip: '快速分享',
            onTap: busy ? null : onShare,
            busy: busy,
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool busy;

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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: palette.surface,
            boxShadow: tokens.cardShadow,
          ),
          child: Center(
            child: busy
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.primary,
                    ),
                  )
                : Icon(icon, size: 20, color: palette.onSurface),
          ),
        ),
      ),
    );
  }
}
