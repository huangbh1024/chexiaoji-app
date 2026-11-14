import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/domain/providers.dart';
import '../../ledger/domain/providers.dart';
import '../data/mock_report_repository.dart';
import '../data/report_repository.dart';
import 'report_models.dart';

/// 报表仓库。后端接口接入后只需替换这里的实现（M5）。
final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return MockReportRepository(
    ledger: ref.watch(ledgerRepositoryProvider),
    home: ref.watch(homeRepositoryProvider),
  );
});

/// 月度报表：按 `month + vehicleId` 聚合，范围变化自动重新请求。
final monthlyReportProvider = FutureProvider.autoDispose
    .family<MonthlyReport, ReportScope>((ref, scope) {
      return ref.watch(reportRepositoryProvider).fetchReport(scope);
    });
