import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:material_ui/material_ui.dart';

import '../domain/report_models.dart';
import '../export/report_exporter.dart';
import 'report_style.dart';
import 'widgets/report_paper_preview.dart';

/// 把 A4 纸张离屏渲染成宽 1080px 的 PNG，供长图分享使用。
///
/// 渲染使用与屏幕预览完全相同的 [ReportPaperSurface]，因此隐私开关、
/// 能耗开关与页脚文案都会自动保持一致。
abstract final class ReportPosterRenderer {
  /// 长图目标宽度（像素）。
  static const double targetWidth = 1080;

  static Future<Uint8List> capture(
    BuildContext context, {
    required MonthlyReport report,
    required ReportOptions options,
  }) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final boundaryKey = GlobalKey();
    final entry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        // 放在可视区域外，只参与绘制，不干扰当前页面。
        left: -reportPaperWidth - 32,
        top: 0,
        child: IgnorePointer(
          child: RepaintBoundary(
            key: boundaryKey,
            child: ReportPaperSurface(
              report: report,
              options: options,
              flat: true,
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = boundaryKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) {
        throw const ReportExportException('长图渲染失败');
      }

      final image = await boundary.toImage(
        pixelRatio: targetWidth / reportPaperWidth,
      );
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) {
          throw const ReportExportException('长图编码失败');
        }
        return data.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      if (entry.mounted) {
        entry.remove();
      }
    }
  }
}
