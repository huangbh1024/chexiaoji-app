import '../../ledger/domain/ledger_models.dart';
import '../domain/report_models.dart';

/// 报表数据仓库。当前由 [MockReportRepository] 提供本地聚合，
/// 后端接口接入后替换为 Http 实现，UI 与 provider 不需要改动。
abstract class ReportRepository {
  Future<MonthlyReport> fetchReport(ReportScope scope);

  /// CSV 导出用：拉取该范围全月记录（自动翻页）。
  Future<List<LedgerRecord>> fetchAllRecords(ReportScope scope);
}
