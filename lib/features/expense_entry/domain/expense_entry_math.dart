import '../../../core/domain/enums.dart';
import 'expense_entry_detail.dart';

/// 金额 → 充电量（kWh）。单价单位为分 / kWh。
double? kwhFromAmount(int amountCents, int unitPriceCentsPerKwh) {
  if (amountCents <= 0 || unitPriceCentsPerKwh <= 0) {
    return null;
  }
  return amountCents / unitPriceCentsPerKwh;
}

/// 金额 → 加油升数（L）。单价单位为分 / L。
double? litersFromAmount(int amountCents, int unitPriceCentsPerLiter) {
  if (amountCents <= 0 || unitPriceCentsPerLiter <= 0) {
    return null;
  }
  return amountCents / unitPriceCentsPerLiter;
}

/// 结束 SOC：开始 SOC + 充入电量 / 电池容量。
int? socEndFromKwh({
  required int socStart,
  required double? kwh,
  required double? batteryCapacityKwh,
}) {
  if (kwh == null || batteryCapacityKwh == null || batteryCapacityKwh <= 0) {
    return null;
  }
  return (socStart + kwh / batteryCapacityKwh * 100).round().clamp(0, 100);
}

/// 金额 → 停车时长（分钟）。
int? parkingMinutes(int amountCents, int rateCentsPerHour) {
  if (amountCents <= 0 || rateCentsPerHour <= 0) {
    return null;
  }
  return (amountCents / rateCentsPerHour * 60).round();
}

/// 每公里成本（元）。
double? costPerKm(int amountCents, int? distanceKm) {
  if (amountCents <= 0 || distanceKm == null || distanceKm <= 0) {
    return null;
  }
  return amountCents / 100 / distanceKm;
}

/// 区间里程；任一为空返回 null。
int? mileageDelta(int? currentKm, int? lastKm) {
  if (currentKm == null || lastKm == null) {
    return null;
  }
  return currentKm - lastKm;
}

/// 「充满」估算金额（分）。
int? fullChargeCents({
  required double? batteryCapacityKwh,
  required int socStart,
  required int unitPriceCentsPerKwh,
}) {
  if (batteryCapacityKwh == null ||
      batteryCapacityKwh <= 0 ||
      unitPriceCentsPerKwh <= 0 ||
      socStart >= 100) {
    return null;
  }
  final kwh = batteryCapacityKwh * (100 - socStart) / 100;
  return (kwh * unitPriceCentsPerKwh).round();
}

/// 「加满」估算金额（分），按空箱估算。
int? fullTankCents({
  required double? tankCapacityL,
  required int unitPriceCentsPerLiter,
}) {
  if (tankCapacityL == null ||
      tankCapacityL <= 0 ||
      unitPriceCentsPerLiter <= 0) {
    return null;
  }
  return (tankCapacityL * unitPriceCentsPerLiter).round();
}

/// 里程跨度超过该值时，保存前需要二次确认。
const odometerConfirmThresholdKm = 5000;

bool needsOdometerConfirmation(int? deltaKm) =>
    deltaKm != null && deltaKm > odometerConfirmThresholdKm;

/// 依据金额与参数重算派生字段（电量 / 升数 / 时长）。
EntryCategoryDetail recomputeDetail(
  EntryCategoryDetail detail,
  int amountCents, {
  double? batteryCapacityKwh,
}) {
  return switch (detail) {
    ChargingDetail d => d.copyWith(
      kwh: kwhFromAmount(amountCents, d.unitPriceCentsPerKwh),
      socEnd: socEndFromKwh(
        socStart: d.socStart,
        kwh: kwhFromAmount(amountCents, d.unitPriceCentsPerKwh),
        batteryCapacityKwh: batteryCapacityKwh,
      ),
      clearDerived: amountCents <= 0,
    ),
    FuelDetail d => d.copyWith(
      liters: litersFromAmount(amountCents, d.unitPriceCentsPerLiter),
      clearDerived: amountCents <= 0,
    ),
    ParkingDetail d => d.copyWith(
      durationMinutes: parkingMinutes(amountCents, d.rateCentsPerHour),
      clearDerived: amountCents <= 0,
    ),
    _ => detail,
  };
}

/// 该分类是否需要里程读数（默认展开）。
bool categoryUsesOdometer(ExpenseCategory category) => switch (category) {
  ExpenseCategory.charging ||
  ExpenseCategory.fuel ||
  ExpenseCategory.maintenance ||
  ExpenseCategory.carWash => true,
  ExpenseCategory.parking ||
  ExpenseCategory.toll ||
  ExpenseCategory.other => false,
};
