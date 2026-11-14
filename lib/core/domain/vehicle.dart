import 'enums.dart';

/// 车辆基础信息，首页车辆卡、账单页筛选与记录徽标共用。
class Vehicle {
  const Vehicle({
    required this.id,
    required this.name,
    required this.plate,
    required this.powertrain,
    required this.powertrainLabel,
    required this.odometerKm,
    this.badge,
    this.batteryCapacityKwh,
    this.tankCapacityL,
    this.defaultFuelGrade,
  });

  final String id;
  final String name;
  final String plate;
  final PowertrainType powertrain;
  final String powertrainLabel;
  final int odometerKm;

  /// 车辆卡右上角动力 / 油品标签，选中时隐藏。
  final String? badge;

  /// 电池容量（kWh），仅新能源车有值；录入页用于推导 SOC 与「充满」。
  final double? batteryCapacityKwh;

  /// 油箱容量（L），用于「加满」估算。
  final double? tankCapacityL;

  /// 默认油品标号，如 95。
  final int? defaultFuelGrade;
}
