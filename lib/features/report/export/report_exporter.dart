import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../data/report_repository.dart';
import '../domain/report_models.dart';
import 'report_csv_builder.dart';
import 'report_file_service.dart';
import 'report_pdf_builder.dart';

/// 导出动作：普通导出 / 打印 / 分享。
enum ReportExportAction { export, print, share }

class ReportExportException implements Exception {
  const ReportExportException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'ReportExportException: $message';
}

abstract class ReportExporter {
  Future<File> buildPdf(MonthlyReport report, ReportOptions options);

  Future<File> buildCsv(MonthlyReport report, ReportOptions options);

  Future<void> share(File file, {String? subject});

  Future<void> print(File file, {String? name});
}

/// 默认实现：PDF / CSV 在客户端生成，分享与打印交给系统。
class DefaultReportExporter implements ReportExporter {
  DefaultReportExporter({required this.repository, ReportFileService? files})
    : _files = files ?? ReportFileService();

  final ReportRepository repository;
  final ReportFileService _files;

  @override
  Future<File> buildPdf(MonthlyReport report, ReportOptions options) async {
    try {
      final bytes = await buildReportPdfBytes(report: report, options: options);
      return await _files.write(_files.pdfFileName(report), bytes);
    } catch (error) {
      throw ReportExportException('PDF 生成失败', error);
    }
  }

  @override
  Future<File> buildCsv(MonthlyReport report, ReportOptions options) async {
    try {
      final records = await repository.fetchAllRecords(report.scope);
      final csv = buildReportCsv(
        report: report,
        records: records,
        options: options,
      );
      return await _files.write(
        _files.csvFileName(report),
        Uint8List.fromList(utf8.encode(csv)),
      );
    } catch (error) {
      throw ReportExportException('CSV 生成失败', error);
    }
  }

  @override
  Future<void> share(File file, {String? subject}) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              file.path,
              mimeType: file.path.endsWith('.pdf')
                  ? 'application/pdf'
                  : file.path.endsWith('.csv')
                  ? 'text/csv'
                  : 'image/png',
            ),
          ],
          subject: subject,
          text: subject == null ? null : '$subject\n由车小记生成',
        ),
      );
    } catch (error) {
      throw ReportExportException('打开分享面板失败', error);
    }
  }

  @override
  Future<void> print(File file, {String? name}) async {
    try {
      final bytes = await file.readAsBytes();
      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: name ?? file.uri.pathSegments.last,
      );
    } on ReportExportException {
      rethrow;
    } catch (error) {
      throw ReportExportException('打印失败', error);
    }
  }
}
