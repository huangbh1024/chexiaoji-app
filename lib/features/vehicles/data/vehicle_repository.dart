import '../domain/vehicle_models.dart';

/// 车库数据仓库。Mock 阶段由 [MockVehicleRepository] 提供内存实现，
/// 接入接口时替换为 HTTP 实现，页面与 provider 不需要改动。
abstract class VehicleRepository {
  String? get primaryVehicleId;

  Future<GarageOverview> fetchGarage();

  Future<void> setPrimary(String vehicleId);

  Future<void> archive(String vehicleId);

  Future<void> restore(String vehicleId);

  Future<void> delete(String vehicleId);
}

enum VehicleErrorCode {
  isPrimary,
  hasRecords,
  notFound,
  conflict,
  limitReached,
  unknown,
}

class VehicleOperationException implements Exception {
  const VehicleOperationException(this.code, [this.message]);

  final VehicleErrorCode code;
  final String? message;

  @override
  String toString() => 'VehicleOperationException($code, $message)';
}
