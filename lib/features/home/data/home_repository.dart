import '../domain/home_models.dart';

/// 首页数据仓库。静态阶段由 [MockHomeRepository] 提供本地数据，
/// 后续接入接口时替换实现即可，UI 与 provider 不需要改动。
abstract class HomeRepository {
  String get defaultVehicleId;

  Future<List<Vehicle>> fetchVehicles();

  Future<HomeDashboard> fetchDashboard(String vehicleId);

  Future<Breakdown> fetchBreakdown(String vehicleId);

  Future<List<RecordItem>> fetchRecords(String vehicleId);

  Future<TrendData> fetchTrend(String vehicleId, TrendRange range);
}
