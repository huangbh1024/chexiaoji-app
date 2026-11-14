/// 我的页接口契约（暂不实现）。
///
/// 接入后端时新增 `HttpProfileApi`，由仓库实现调用并做 DTO 映射；
/// 页面与 provider 不感知 JSON 字段。
abstract class ProfileApi {
  Future<Map<String, dynamic>> getOverview({required String timezone});

  Future<Map<String, dynamic>> getGarage({
    required String vehicleId,
    required String month,
    required String timezone,
  });

  Future<Map<String, dynamic>> getServices();

  Future<Map<String, dynamic>> getPreferences();

  Future<Map<String, dynamic>> updatePreferences(Map<String, dynamic> body);

  Future<void> logout();
}

/// 过期响应：UI 静默忽略。
class StaleProfileResponse implements Exception {
  const StaleProfileResponse();
}
