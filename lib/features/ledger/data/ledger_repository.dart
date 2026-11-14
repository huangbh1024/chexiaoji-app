import '../domain/ledger_models.dart';

/// 账单数据仓库。当前由 [MockLedgerRepository] 提供本地数据，
/// 接入接口时替换实现，UI 与 provider 不需要改动。
abstract class LedgerRepository {
  Future<LedgerMonthSummary> fetchSummary(LedgerScope scope);

  Future<LedgerRecordsPage> fetchRecords(
    LedgerQuery query, {
    String? cursor,
    int limit = 30,
  });
}
