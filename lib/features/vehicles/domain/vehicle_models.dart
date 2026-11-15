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
