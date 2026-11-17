import '../../../core/format/formatters.dart';
import '../../home/domain/home_models.dart';
import '../../ledger/domain/ledger_models.dart';
import 'profile_models.dart';

/// 记账天数：首笔记录日期到今天（含首日）；无记录或未来记录返回 0。
int computeAccountDays(DateTime? firstRecordAt, DateTime now) {
  if (firstRecordAt == null) {
    return 0;
  }
  final first = DateTime(
    firstRecordAt.year,
    firstRecordAt.month,
    firstRecordAt.day,
  );
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(first).inDays + 1;
  return days < 0 ? 0 : days;
}

const _brandPrefixes = <String>[
  '比亚迪',
  '丰田',
  '宝马',
  '奔驰',
  '奥迪',
  '大众',
  '本田',
  '吉利',
  '理想',
  '小鹏',
  '蔚来',
  '特斯拉',
  '长安',
  '奇瑞',
];

/// 车辆简称：去掉常见品牌前缀，保留车型；未知品牌保留全名。
String shortNameFor(String name) {
  for (final brand in _brandPrefixes) {
    final prefix = '$brand ';
    if (name.startsWith(prefix)) {
      return name.substring(prefix.length).trim();
    }
  }
  return name;
}

/// 聚合某个月的充电 + 加油记录。
///
/// 退款金额按负值计入总额；数量只累计正值。没有对应数量时返回 null。
MonthEnergy aggregateMonthEnergy(
  Iterable<LedgerRecord> records, {
  required DateTime month,
  required DateTime now,
}) {
  final start = DateTime(month.year, month.month);
  final end = DateTime(month.year, month.month + 1);
  var amountCents = 0;
  var count = 0;
  var kwh = 0.0;
  var liters = 0.0;
  var hasKwh = false;
  var hasLiters = false;

  for (final record in records) {
    if (record.category != ExpenseCategory.charging &&
        record.category != ExpenseCategory.fuel) {
      continue;
    }
    if (record.occurredAt.isBefore(start) ||
        !record.occurredAt.isBefore(end) ||
        record.occurredAt.isAfter(now)) {
      continue;
    }
    amountCents += record.amountCents;
    count++;
    final recordKwh = record.metrics.kwh;
    final recordLiters = record.metrics.liters;
    if (recordKwh != null && recordKwh > 0) {
      kwh += recordKwh;
      hasKwh = true;
    }
    if (recordLiters != null && recordLiters > 0) {
      liters += recordLiters;
      hasLiters = true;
    }
  }

  return MonthEnergy(
    amountCents: amountCents,
    count: count,
    kwh: hasKwh ? kwh : null,
    liters: hasLiters ? liters : null,
  );
}

/// 构建车库快照：`vehicleId == null` 为全部资产。
GarageSnapshot buildGarageSnapshot({
  required String? vehicleId,
  required List<GarageVehicle> vehicles,
  required List<LedgerRecord> monthRecords,
  required Map<String, Maintenance> maintenanceByVehicle,
  required DateTime now,
}) {
  final month = DateTime(now.year, now.month);

  if (vehicles.isEmpty) {
    return _emptySnapshot();
  }

  if (vehicleId != null) {
    final vehicle = vehicles.firstWhere(
      (item) => item.id == vehicleId,
      orElse: () => throw StateError('Unknown vehicle: $vehicleId'),
    );
    final records = monthRecords
        .where((record) => record.vehicleId == vehicleId)
        .toList(growable: false);
    final energy = aggregateMonthEnergy(records, month: month, now: now);
    final maintenance = _maintenanceFor(
      vehicle,
      maintenanceByVehicle[vehicleId],
    );
    return GarageSnapshot(
      vehicleId: vehicleId,
      badge: vehicle.powertrainLabel,
      plateText: vehicle.plate.isEmpty ? '未填写车牌' : vehicle.plate,
      title: vehicle.name,
      subtitle: _singleSubtitle(vehicle, energy),
      powertrain: vehicle.powertrain,
      odometerKm: vehicle.odometerKm,
      monthEnergy: energy,
      maintenance: maintenance,
      tip: buildGarageTip(
        records: records,
        energy: energy,
        isAllAssets: false,
        month: month,
        now: now,
      ),
    );
  }

  final energy = aggregateMonthEnergy(monthRecords, month: month, now: now);
  final types = vehicles.map((vehicle) => vehicle.powertrain).toSet();
  final allEv = types.every((type) => type == PowertrainType.ev);
  final allFuel = types.every(
    (type) => type == PowertrainType.hev || type == PowertrainType.ice,
  );
  final monthEnergy = MonthEnergy(
    amountCents: energy.amountCents,
    count: energy.count,
    kwh: allEv ? energy.kwh : null,
    liters: allFuel ? energy.liters : null,
  );

  return GarageSnapshot(
    badge: '全部资产',
    plateText: '${formatCount(vehicles.length)} 辆在役',
    title: '我的全部车辆',
    subtitle: powertrainComposition(vehicles),
    odometerKm: vehicles.fold(0, (sum, vehicle) => sum + vehicle.odometerKm),
    monthEnergy: monthEnergy,
    maintenance: pickMostUrgent(maintenanceByVehicle, vehicles),
    tip: buildGarageTip(
      records: monthRecords,
      energy: monthEnergy,
      isAllAssets: true,
      month: month,
      now: now,
    ),
  );
}

/// 全部资产保养：优先未超期车辆中剩余最少的一辆；全部超期则取超期最多的一辆。
GarageMaintenance pickMostUrgent(
  Map<String, Maintenance> maintenanceByVehicle,
  List<GarageVehicle> vehicles,
) {
  final candidates = <({GarageVehicle vehicle, Maintenance maintenance})>[
    for (final vehicle in vehicles)
      if (maintenanceByVehicle[vehicle.id] case final maintenance?
          when maintenance.enabled)
        (vehicle: vehicle, maintenance: maintenance),
  ];
  if (candidates.isEmpty) {
    return const GarageMaintenance(
      enabled: false,
      status: MaintenanceStatus.normal,
    );
  }
  final positive = candidates.where((item) => item.maintenance.remainingKm > 0);
  final pool = positive.isNotEmpty ? positive : candidates;
  final picked = pool.reduce(
    (a, b) => a.maintenance.remainingKm <= b.maintenance.remainingKm ? a : b,
  );
  return _maintenanceFor(picked.vehicle, picked.maintenance);
}

/// 动力构成文案，例如「纯电 1 · 混动 2 · 燃油 1」。
String powertrainComposition(List<GarageVehicle> vehicles) {
  if (vehicles.isEmpty) {
    return '暂无车辆';
  }
  final ev = vehicles
      .where((vehicle) => vehicle.powertrain == PowertrainType.ev)
      .length;
  final hybrid = vehicles
      .where(
        (vehicle) =>
            vehicle.powertrain == PowertrainType.hev ||
            vehicle.powertrain == PowertrainType.phev,
      )
      .length;
  final ice = vehicles
      .where((vehicle) => vehicle.powertrain == PowertrainType.ice)
      .length;
  return [
    if (ev > 0) '纯电 $ev',
    if (hybrid > 0) '混动 $hybrid',
    if (ice > 0) '燃油 $ice',
  ].join(' · ');
}

/// 车辆卡底部提示：只描述本月真实能耗，不出现未实现的能力。
GarageTip buildGarageTip({
  required Iterable<LedgerRecord> records,
  required MonthEnergy energy,
  required bool isAllAssets,
  required DateTime month,
  required DateTime now,
}) {
  if (isAllAssets) {
    if (energy.count == 0) {
      return const GarageTip(kind: GarageTipKind.empty, text: '本月暂无能耗记录');
    }
    return GarageTip(
      kind: GarageTipKind.energySummary,
      text:
          '本月共 ${formatCount(energy.count)} 笔能耗记录 · '
          '合计 ${formatYuanOneDecimal(energy.amountCents)}',
    );
  }

  final start = DateTime(month.year, month.month);
  final end = DateTime(month.year, month.month + 1);
  var chargeCount = 0;
  var fuelCount = 0;
  var chargeAmount = 0;
  var fuelAmount = 0;
  var chargeKwh = 0.0;
  var fuelLiters = 0.0;

  for (final record in records) {
    if (record.occurredAt.isBefore(start) ||
        !record.occurredAt.isBefore(end) ||
        record.occurredAt.isAfter(now)) {
      continue;
    }
    if (record.category == ExpenseCategory.charging) {
      chargeCount++;
      final quantity = record.metrics.kwh;
      if (record.amountCents > 0 && quantity != null && quantity > 0) {
        chargeAmount += record.amountCents;
        chargeKwh += quantity;
      }
    } else if (record.category == ExpenseCategory.fuel) {
      fuelCount++;
      final quantity = record.metrics.liters;
      if (record.amountCents > 0 && quantity != null && quantity > 0) {
        fuelAmount += record.amountCents;
        fuelLiters += quantity;
      }
    }
  }

  if (chargeCount == 0 && fuelCount == 0) {
    return const GarageTip(kind: GarageTipKind.empty, text: '本月暂无能耗记录');
  }

  final chargePrice = chargeKwh > 0
      ? formatUnitPrice((chargeAmount / chargeKwh).round(), 'kWh')
      : null;
  final fuelPrice = fuelLiters > 0
      ? formatUnitPrice((fuelAmount / fuelLiters).round(), 'L')
      : null;

  if (chargeCount > 0 && fuelCount > 0) {
    final parts = <String>[
      '本月充电 $chargeCount 次',
      '加油 $fuelCount 次',
      if (chargePrice != null) '电 $chargePrice',
      if (fuelPrice != null) '油 $fuelPrice',
    ];
    return GarageTip(kind: GarageTipKind.mixed, text: parts.join(' · '));
  }

  if (chargeCount > 0) {
    final suffix = chargePrice == null ? '' : ' · 平均 $chargePrice';
    return GarageTip(
      kind: GarageTipKind.charging,
      text: '本月充电 $chargeCount 次$suffix',
    );
  }

  final suffix = fuelPrice == null ? '' : ' · 平均 $fuelPrice';
  return GarageTip(kind: GarageTipKind.fuel, text: '本月加油 $fuelCount 次$suffix');
}

GarageSnapshot _emptySnapshot() {
  return const GarageSnapshot(
    badge: '全部资产',
    plateText: '0 辆在役',
    title: '我的全部车辆',
    subtitle: '暂无车辆',
    odometerKm: 0,
    monthEnergy: MonthEnergy(amountCents: 0, count: 0),
    maintenance: GarageMaintenance(
      enabled: false,
      status: MaintenanceStatus.normal,
    ),
    tip: GarageTip(kind: GarageTipKind.empty, text: '本月暂无能耗记录'),
  );
}

String _singleSubtitle(GarageVehicle vehicle, MonthEnergy energy) {
  final cost = vehicle.energyCostPerKmCents;
  if (cost != null && cost > 0) {
    return '本月能耗 ${formatYuanDetail(cost)}/km';
  }
  return '本月已记 ${formatCount(energy.count)} 笔';
}

GarageMaintenance _maintenanceFor(
  GarageVehicle vehicle,
  Maintenance? maintenance,
) {
  if (maintenance == null || !maintenance.enabled) {
    return const GarageMaintenance(
      enabled: false,
      status: MaintenanceStatus.normal,
    );
  }
  final remainingKm = maintenance.remainingKm;
  final status = remainingKm <= 0
      ? MaintenanceStatus.overdue
      : maintenance.isWarning
      ? MaintenanceStatus.warning
      : MaintenanceStatus.normal;
  return GarageMaintenance(
    enabled: true,
    status: status,
    vehicleId: vehicle.id,
    vehicleName: vehicle.shortName,
    remainingKm: remainingKm,
    remainingDays: maintenance.remainingDays,
  );
}
