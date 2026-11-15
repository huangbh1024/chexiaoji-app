import 'package:flutter/foundation.dart';

import '../../home/domain/home_models.dart';

/// 车库中的一辆在库车辆：基础信息 + 管理 / 展示所需的派生数据。
@immutable
class ManagedVehicle {
  const ManagedVehicle({
    required this.vehicle,
    required this.specLabel,
    required this.sortOrder,
    required this.isPrimary,
    required this.monthSpendCents,
    required this.recordCount,
    required this.consumption,
    required this.maintenance,
    this.nickname,
    this.batteryHealthPercent,
    this.insuranceExpiry,
    this.inspectionExpiry,
  });

  final Vehicle vehicle;
  final String specLabel;
  final int sortOrder;
  final bool isPrimary;

  /// 当月该车全部类别支出（分）。
  final int monthSpendCents;

  /// 该车全部历史未删除记录数，用于删除拦截。
  final int recordCount;

  final Consumption consumption;
  final Maintenance maintenance;

  /// 档案别名；不替换 [vehicle.name]。
  final String? nickname;

  final int? batteryHealthPercent;
  final DateTime? insuranceExpiry;
  final DateTime? inspectionExpiry;

  String get id => vehicle.id;
  PowertrainType get powertrain => vehicle.powertrain;
}

/// 已归档车辆：只保留恢复所需的最小信息，不构造伪指标。
@immutable
class ArchivedVehicle {
  const ArchivedVehicle({
    required this.vehicle,
    required this.specLabel,
    required this.sortOrder,
    required this.archivedAt,
  });

  final Vehicle vehicle;
  final String specLabel;
  final int sortOrder;
  final DateTime archivedAt;

  String get id => vehicle.id;
}

/// 归档页的单车快照：车辆档案 + 全历史汇总。
@immutable
class ArchivedVehicleSummary {
  const ArchivedVehicleSummary({
    required this.vehicle,
    required this.specLabel,
    required this.sortOrder,
    required this.archivedAt,
    required this.lifetimeSpendCents,
    required this.recordCount,
    required this.energyRecordCount,
    this.averageConsumption,
    this.latestRecordAt,
  });

  final Vehicle vehicle;
  final String specLabel;
  final int sortOrder;
  final DateTime archivedAt;

  /// 该车全部未删除流水合计（分），退款为负。
  final int lifetimeSpendCents;

  final int recordCount;

  /// 充电 + 加油笔数。
  final int energyRecordCount;

  /// 归档前最后一次有效能耗读数；无数据为 null。
  final EnergyValue? averageConsumption;

  /// 最近一条流水时间；无流水为 null。
  final DateTime? latestRecordAt;

  String get id => vehicle.id;
  PowertrainType get powertrain => vehicle.powertrain;
}

/// 归档页快照：按归档时间倒序。
@immutable
class ArchivedGarage {
  const ArchivedGarage({required this.vehicles, required this.fetchedAt});

  final List<ArchivedVehicleSummary> vehicles;
  final DateTime fetchedAt;
}

@immutable
class FleetSummary {
  const FleetSummary({
    required this.vehicleCount,
    required this.totalOdometerKm,
    required this.monthSpendCents,
    required this.powertrainCounts,
    required this.pendingIssueCount,
    required this.hasReminderData,
  });

  final int vehicleCount;
  final int totalOdometerKm;
  final int monthSpendCents;

  /// 只包含数量 > 0 的动力类型。
  final Map<PowertrainType, int> powertrainCounts;

  final int pendingIssueCount;
  final bool hasReminderData;
}

@immutable
class GarageOverview {
  const GarageOverview({
    required this.vehicles,
    required this.archivedVehicles,
    required this.primaryVehicleId,
    required this.summary,
    required this.fetchedAt,
  });

  final List<ManagedVehicle> vehicles;
  final List<ArchivedVehicle> archivedVehicles;
  final String? primaryVehicleId;
  final FleetSummary summary;
  final DateTime fetchedAt;
}

enum VehicleMetricTone { normal, accent, warning, danger, muted }

@immutable
class VehicleMetric {
  const VehicleMetric({
    required this.label,
    required this.value,
    required this.unit,
    this.tone = VehicleMetricTone.normal,
    this.missing = false,
  });

  final String label;
  final String value;
  final String unit;
  final VehicleMetricTone tone;
  final bool missing;
}

enum VehicleReminderKind { maintenance, insurance, inspection }

@immutable
class VehicleReminder {
  const VehicleReminder({
    required this.kind,
    required this.text,
    required this.tone,
  });

  final VehicleReminderKind kind;
  final String text;
  final VehicleMetricTone tone;
}
