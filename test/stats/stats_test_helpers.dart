import 'package:chexiaoji_app/core/domain/enums.dart';
import 'package:chexiaoji_app/features/ledger/domain/ledger_models.dart';

LedgerRecord statsRecord({
  String id = 'rec-1',
  String vehicleId = 'byd-han-ev',
  String vehicleName = '比亚迪 汉 EV',
  String vehicleShortName = '汉 EV',
  PowertrainType powertrain = PowertrainType.ev,
  ExpenseCategory category = ExpenseCategory.charging,
  int amountCents = 5000,
  DateTime? occurredAt,
  double? kwh,
  double? liters,
  int? odometerKm,
  int? distanceKm,
  String? description,
}) {
  return LedgerRecord(
    id: id,
    vehicleId: vehicleId,
    vehicleShortName: vehicleShortName,
    vehicleName: vehicleName,
    powertrain: powertrain,
    category: category,
    title: '测试记录',
    amountCents: amountCents,
    occurredAt: occurredAt ?? DateTime(2026, 11, 10, 8, 30),
    description: description,
    metrics: LedgerMetrics(
      kwh: kwh,
      liters: liters,
      odometerKm: odometerKm,
      distanceKm: distanceKm,
    ),
  );
}
