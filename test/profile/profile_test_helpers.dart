import 'package:chexiaoji_app/features/home/domain/home_models.dart';
import 'package:chexiaoji_app/features/ledger/domain/ledger_models.dart';
import 'package:chexiaoji_app/features/profile/domain/profile_models.dart';

ProfileOverview profileOverview({
  int accountDays = 328,
  int recordCount = 142,
  String nickname = '林漪',
  String? phoneMasked = '138 **** 9208',
}) {
  return ProfileOverview(
    user: ProfileUser(
      id: 'local-user',
      nickname: nickname,
      verifiedOwner: true,
      tagline: '车小记 · 驱动每公里透明',
      phoneMasked: phoneMasked,
    ),
    stats: ProfileStats(
      accountDays: accountDays,
      recordCount: recordCount,
      firstRecordAt: DateTime(2025, 12, 21),
    ),
    dataUpdatedAt: DateTime(2026, 11, 14, 18),
  );
}

GarageVehicle garageVehicle({
  String id = 'byd-han-ev',
  String name = '比亚迪 汉 EV',
  String shortName = '汉 EV',
  String plate = '粤B·D82K6',
  PowertrainType powertrain = PowertrainType.ev,
  String powertrainLabel = '纯电',
  int odometerKm = 18426,
  int? energyCostPerKmCents = 18,
}) {
  return GarageVehicle(
    id: id,
    name: name,
    shortName: shortName,
    plate: plate,
    powertrain: powertrain,
    powertrainLabel: powertrainLabel,
    odometerKm: odometerKm,
    energyCostPerKmCents: energyCostPerKmCents,
  );
}

Maintenance maintenance({
  int remainingKm = 1574,
  int progressPercent = 78,
  MaintenanceStatus status = MaintenanceStatus.normal,
  int? remainingDays = 22,
}) {
  return Maintenance(
    enabled: true,
    remainingKm: remainingKm,
    progressPercent: progressPercent,
    status: status,
    remainingDays: remainingDays,
  );
}

LedgerRecord profileRecord({
  String id = 'rec-1',
  String vehicleId = 'byd-han-ev',
  PowertrainType powertrain = PowertrainType.ev,
  ExpenseCategory category = ExpenseCategory.charging,
  int amountCents = 1000,
  DateTime? occurredAt,
  double? kwh,
  double? liters,
}) {
  return LedgerRecord(
    id: id,
    vehicleId: vehicleId,
    vehicleShortName: '测试车',
    vehicleName: '测试车辆',
    powertrain: powertrain,
    category: category,
    title: '测试记录',
    amountCents: amountCents,
    occurredAt: occurredAt ?? DateTime(2026, 11, 10, 8, 30),
    metrics: LedgerMetrics(kwh: kwh, liters: liters),
  );
}
