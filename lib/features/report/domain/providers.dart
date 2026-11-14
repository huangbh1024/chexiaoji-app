import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/domain/providers.dart';
import '../../ledger/domain/providers.dart';
import '../data/mock_report_repository.dart';
import '../data/report_repository.dart';
import '../export/report_exporter.dart';
import '../export/report_file_service.dart';
import 'report_models.dart';

/// 报表仓库。后端接口接入后只需替换这里的实现（M5）。
final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return MockReportRepository(
    ledger: ref.watch(ledgerRepositoryProvider),
    home: ref.watch(homeRepositoryProvider),
  );
});

/// 报表临时文件服务：启动清理与导出落盘共用。
final reportFileServiceProvider = Provider<ReportFileService>((ref) {
  return ReportFileService();
});

/// 导出器：生成 PDF / CSV / 长图并调起分享 / 打印。
final reportExporterProvider = Provider<ReportExporter>((ref) {
  return DefaultReportExporter(
    repository: ref.watch(reportRepositoryProvider),
    files: ref.watch(reportFileServiceProvider),
  );
});

/// 月度报表：按 `month + vehicleId` 聚合，范围变化自动重新请求。
final monthlyReportProvider = FutureProvider.autoDispose
    .family<MonthlyReport, ReportScope>((ref, scope) {
      return ref.watch(reportRepositoryProvider).fetchReport(scope);
    });
