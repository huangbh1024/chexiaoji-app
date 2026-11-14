/// 统计接口契约（暂不实现）。
///
/// 接入后端时新增 `HttpStatsApi`，由 `StatsRepositoryImpl` 调用并做
/// DTO 映射；页面与 provider 不感知 JSON 字段。
abstract class StatsApi {
  Future<Map<String, dynamic>> getOverview({
    required String vehicleIds,
    required String period,
    required String anchor,
    required String timezone,
  });

  Future<Map<String, dynamic>> getBreakdown({
    required String vehicleIds,
    required String period,
    required String anchor,
    required String timezone,
  });

  Future<Map<String, dynamic>> getTrend({
    required String vehicleIds,
    required String range,
    required String anchor,
    required String timezone,
  });

  Future<Map<String, dynamic>> getRecent({
    required String vehicleIds,
    required String period,
    required String anchor,
    required int limit,
    required String timezone,
  });
}

/// 过期响应：UI 静默忽略。
class StaleStatsResponse implements Exception {
  const StaleStatsResponse();
}
