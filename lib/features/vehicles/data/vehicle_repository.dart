import '../domain/vehicle_models.dart';

/// 车库数据仓库。Mock 阶段由 [MockVehicleRepository] 提供内存实现，
/// 接入接口时替换为 HTTP 实现，页面与 provider 不需要改动。
abstract class VehicleRepository {
  String? get primaryVehicleId;

  Future<GarageOverview> fetchGarage();

  /// 归档页快照：每车全历史汇总。
  Future<ArchivedGarage> fetchArchivedGarage();

  Future<void> setPrimary(String vehicleId);

  Future<void> archive(String vehicleId);

  Future<void> restore(String vehicleId);

  Future<void> delete(String vehicleId);

  /// 彻底删除归档车辆档案；[plateTail] 由客户端与服务端双重校验。
  Future<void> purgeArchivedVehicle(
    String vehicleId, {
    required String plateTail,
  });
}

enum VehicleErrorCode {
  isPrimary,
  hasRecords,
  notFound,
  notArchived,
  plateTailMismatch,
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
