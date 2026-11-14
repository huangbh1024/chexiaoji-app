import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/report_models.dart';
import '../../domain/report_presenter.dart';
import 'report_paper_preview.dart';

/// 全屏报表预览：深色背景 + 可捏合缩放的 A4 纸张。
class ReportFullscreenPreview extends StatelessWidget {
  const ReportFullscreenPreview({
    super.key,
    required this.report,
    required this.options,
  });

  final MonthlyReport report;
  final ReportOptions options;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xF20B1C30),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 64, 16, 24),
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 3,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: ReportPaperSurface(
                        report: report,
                        options: options,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      report.fullscreenTitle,
                      style: AppTypography.headlineSm.copyWith(
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Semantics(
                    button: true,
                    label: '关闭全屏预览',
                    child: InkResponse(
                      onTap: () => Navigator.of(context).pop(),
                      radius: 22,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
