import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/report_models.dart';

/// 报表临时文件的命名、写入与清理。
class ReportFileService {
  ReportFileService({this.directoryName = 'reports'});

  final String directoryName;

  /// 单个报表文件上限；超过时提示用户而不是写满磁盘。
  static const int maxFileBytes = 10 * 1024 * 1024;

  Future<Directory> _directory() async {
    final base = await getTemporaryDirectory();
    final directory = Directory('${base.path}/$directoryName');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<File> write(String fileName, List<int> bytes) async {
    if (bytes.length > maxFileBytes) {
      throw const FileSystemException('报表文件超过 10MB 上限');
    }
    final directory = await _directory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// 启动时清理 24 小时前的报表文件，避免占用存储。
  Future<void> cleanOlderThan(Duration age) async {
    final directory = await _directory();
    if (!await directory.exists()) {
      return;
    }
    final deadline = DateTime.now().subtract(age);
    await for (final entity in directory.list()) {
      if (entity is! File) {
        continue;
      }
      try {
        final stat = await entity.stat();
        if (stat.modified.isBefore(deadline)) {
          await entity.delete();
        }
      } on FileSystemException {
        // 单个文件清理失败不影响其他文件。
      }
    }
  }

  String pdfFileName(MonthlyReport report) =>
      '车小记_月度报表_${report.scope.monthKey}_${_vehicleName(report)}.pdf';

  String csvFileName(MonthlyReport report) =>
      '车小记_账单明细_${report.scope.monthKey}_${_vehicleName(report)}.csv';

  String imageFileName(MonthlyReport report) =>
      '车小记_月报_${report.scope.monthKey}_${_vehicleName(report)}.png';

  String _vehicleName(MonthlyReport report) {
    final name = report.vehicles.length == 1
        ? report.vehicles.single.name
        : '全部车辆';
    return name
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
  }
}
