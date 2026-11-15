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

  /// 账号生命周期统计：全部车辆、全部历史、未删除记录。
  Future<LedgerLifetimeStats> fetchLifetimeStats();

  /// 账号生命周期内、未删除的记录数；传入 [vehicleId] 时只统计该车。
  Future<int> countRecords({String? vehicleId});
}
