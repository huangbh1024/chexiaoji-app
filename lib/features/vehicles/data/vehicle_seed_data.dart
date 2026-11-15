import '../../../core/domain/enums.dart';
import '../../../core/domain/vehicle.dart';
import 'vehicle_store.dart';

/// Mock 车库种子：与首页 / 账单 / 统计使用的 4 辆车保持一致。
///
/// 管理字段（配置名、SOH、保险 / 年检到期）是演示数据，接口接入后由服务端返回；
/// 保险 / 年检用「相对今天的天数」生成，避免演示值随时间过期。
VehicleStore seededVehicleStore({DateTime? now}) {
  final today = now ?? DateTime.now();
  DateTime inDays(int days) => today.add(Duration(days: days));

  final records = <VehicleRecord>[
    VehicleRecord(
      vehicle: const Vehicle(
        id: 'byd-han-ev',
        name: '比亚迪 汉 EV',
        plate: '粤B·D82K6',
        powertrain: PowertrainType.ev,
        powertrainLabel: '纯电',
        odometerKm: 18426,
        batteryCapacityKwh: 85.4,
      ),
      specLabel: '2023款 创世旗舰型 · 纯电',
      sortOrder: 0,
      batteryHealthPercent: 98,
      insuranceExpiry: inDays(200),
      inspectionExpiry: inDays(300),
    ),
    VehicleRecord(
      vehicle: const Vehicle(
        id: 'toyota-camry-hev',
        name: '丰田 凯美瑞 双擎',
        plate: '粤B·7Q315',
        powertrain: PowertrainType.hev,
        powertrainLabel: '油电混动',
        odometerKm: 46210,
        badge: '油电双模',
        tankCapacityL: 50,
        defaultFuelGrade: 95,
      ),
      specLabel: '2.5L 豪华版 · 92号汽油',
      sortOrder: 1,
      insuranceExpiry: inDays(48),
      inspectionExpiry: inDays(150),
    ),
    VehicleRecord(
      vehicle: const Vehicle(
        id: 'byd-song-plus-dmi',
        name: '宋PLUS DM-i',
        plate: '粤B·9X521',
        powertrain: PowertrainType.phev,
        powertrainLabel: '插电混动',
        odometerKm: 31520,
        badge: '绿牌插混',
        batteryCapacityKwh: 18.3,
        tankCapacityL: 60,
        defaultFuelGrade: 92,
      ),
      specLabel: '110km 旗舰PLUS · 油电双驱',
      sortOrder: 2,
      batteryHealthPercent: 94,
      insuranceExpiry: inDays(180),
      inspectionExpiry: inDays(240),
    ),
    VehicleRecord(
      vehicle: const Vehicle(
        id: 'bmw-325li',
        name: '宝马 3系 325Li',
        plate: '粤B·88K32',
        powertrain: PowertrainType.ice,
        powertrainLabel: '纯燃油',
        odometerKm: 58940,
        badge: '95号汽油',
        tankCapacityL: 59,
        defaultFuelGrade: 95,
      ),
      specLabel: '325Li M运动套装 · 95号汽油',
      sortOrder: 3,
      insuranceExpiry: inDays(120),
      inspectionExpiry: inDays(90),
    ),
  ];

  return VehicleStore(records: records, primaryVehicleId: 'byd-han-ev');
}
