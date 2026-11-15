import '../domain/vehicle_editor_models.dart';
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

  /// 编辑态档案快照；不存在 / 已归档抛对应错误。
  Future<VehicleEditorSnapshot> fetchVehicleEditor(String vehicleId);

  /// 新增车辆；返回新 id 与是否成为主驾。
  Future<VehicleEditorResult> createVehicle(VehicleEditorDraft draft);

  /// 更新档案；[version] 用于生产环境的乐观并发校验。
  Future<VehicleEditorResult> updateVehicle(
    String vehicleId,
    VehicleEditorDraft draft, {
    int? version,
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
  duplicatePlate,
  invalidField,
  unknown,
}

class VehicleOperationException implements Exception {
  const VehicleOperationException(this.code, [this.message]);

  final VehicleErrorCode code;
  final String? message;

  @override
  String toString() => 'VehicleOperationException($code, $message)';
}
