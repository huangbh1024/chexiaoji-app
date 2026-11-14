import 'package:chexiaoji_app/core/domain/enums.dart';
import 'package:chexiaoji_app/features/ledger/domain/ledger_models.dart';

LedgerRecord buildRecord({
  String id = 'rec-1',
  ExpenseCategory category = ExpenseCategory.charging,
  int amountCents = 5110,
  String title = '特来电充电站',
  String? note,
  int? odometerKm = 18426,
  String? plate = '粤B·D82K6',
}) {
  return LedgerRecord(
    id: id,
    vehicleId: 'byd-han-ev',
    vehicleShortName: '汉 EV',
    vehicleName: '比亚迪 汉 EV',
    powertrain: PowertrainType.ev,
    category: category,
    title: title,
    amountCents: amountCents,
    occurredAt: DateTime(2025, 5, 16, 13, 28),
    badgeText: '汉 EV',
    badgeKind: LedgerBadgeKind.vehicle,
    metrics: LedgerMetrics(
      odometerKm: odometerKm,
      plate: plate,
      paymentMethod: '微信',
    ),
    note: note,
  );
}
