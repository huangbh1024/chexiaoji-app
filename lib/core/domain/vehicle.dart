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
  });

  final String id;
  final String name;
  final String plate;
  final PowertrainType powertrain;
  final String powertrainLabel;
  final int odometerKm;

  /// 车辆卡右上角动力 / 油品标签，选中时隐藏。
  final String? badge;
}
