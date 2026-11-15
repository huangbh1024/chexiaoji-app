import '../../../core/domain/enums.dart';
import '../../../core/format/formatters.dart';
import '../domain/vehicle_models.dart';

enum DeleteBlockReason { isPrimary, hasRecords }

abstract final class VehiclePresenter {
  /// 车辆卡三指标：当前里程 + 能耗 + 健康 / 归属。
  static List<VehicleMetric> metricsOf(ManagedVehicle vehicle) {
    final consumption = vehicle.consumption;
    final isElectric =
        vehicle.powertrain == PowertrainType.ev ||
        vehicle.powertrain == PowertrainType.phev;

    return [
      VehicleMetric(
        label: '当前里程',
        value: formatKmValue(vehicle.vehicle.odometerKm),
        unit: 'km',
      ),
      VehicleMetric(
        label: isElectric ? '动力电耗' : '综合油耗',
        value: formatOneDecimal(consumption.primary.value),
        unit: consumption.primary.unit,
        tone: VehicleMetricTone.accent,
      ),
      _thirdMetric(vehicle),
    ];
  }

  static VehicleMetric _thirdMetric(ManagedVehicle vehicle) {
    switch (vehicle.powertrain) {
      case PowertrainType.ev:
        final soh = vehicle.batteryHealthPercent;
        if (soh == null) {
          return _missing('电池健康 (SOH)');
        }
        return VehicleMetric(
          label: '电池健康 (SOH)',
          value: '$soh',
          unit: '%',
          tone: soh < 80 ? VehicleMetricTone.danger : VehicleMetricTone.normal,
        );
      case PowertrainType.phev:
        final secondary = vehicle.consumption.secondary;
        if (secondary == null) {
          return _missing('亏电油耗');
        }
        return VehicleMetric(
          label: '亏电油耗',
          value: formatOneDecimal(secondary.value),
          unit: secondary.unit,
          tone: VehicleMetricTone.accent,
        );
      case PowertrainType.hev:
      case PowertrainType.ice:
        final expiry = vehicle.insuranceExpiry;
        if (expiry == null) {
          return _missing('车险剩余');
        }
        final days = _daysUntil(expiry)!;
        if (days < 0) {
          return VehicleMetric(
            label: '车险剩余',
            value: '已过期',
            unit: '${days.abs()} 天',
            tone: VehicleMetricTone.danger,
          );
        }
        return VehicleMetric(
          label: '车险剩余',
          value: '$days',
          unit: '天到期',
          tone: days <= 30
              ? VehicleMetricTone.danger
              : VehicleMetricTone.normal,
        );
    }
  }

  static VehicleMetric _missing(String label) => VehicleMetric(
    label: label,
    value: '—',
    unit: '未录入',
    tone: VehicleMetricTone.muted,
    missing: true,
  );

  /// 只展示最紧迫的一条提醒；没有提醒数据时返回 null。
  static VehicleReminder? reminderOf(ManagedVehicle vehicle, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final maintenance = vehicle.maintenance;

    if (maintenance.enabled && maintenance.isOverdue) {
      return VehicleReminder(
        kind: VehicleReminderKind.maintenance,
        text: '保养已超期 ${maintenance.remainingKm.abs()} km',
        tone: VehicleMetricTone.danger,
      );
    }

    final insurance = _daysUntil(vehicle.insuranceExpiry, now: reference);
    final inspection = _daysUntil(vehicle.inspectionExpiry, now: reference);
    final dueSoon = <({VehicleReminderKind kind, int days})>[
      if (insurance != null && insurance <= 30)
        (kind: VehicleReminderKind.insurance, days: insurance),
      if (inspection != null && inspection <= 30)
        (kind: VehicleReminderKind.inspection, days: inspection),
    ]..sort((a, b) => a.days.compareTo(b.days));

    if (dueSoon.isNotEmpty) {
      final first = dueSoon.first;
      final label = first.kind == VehicleReminderKind.insurance
          ? '交强险+商业险'
          : '年检';
      final text = first.days < 0
          ? '$label已过期 ${first.days.abs()} 天'
          : '$label ${first.days} 天后到期';
      return VehicleReminder(
        kind: first.kind,
        text: text,
        tone: VehicleMetricTone.danger,
      );
    }

    if (maintenance.enabled) {
      return VehicleReminder(
        kind: VehicleReminderKind.maintenance,
        text: '下次小保养：约 ${maintenance.remainingKm} km 后',
        tone: maintenance.isWarning
            ? VehicleMetricTone.warning
            : VehicleMetricTone.normal,
      );
    }

    return null;
  }

  static String healthLabel(FleetSummary summary) {
    if (!summary.hasReminderData) {
      return '';
    }
    return summary.pendingIssueCount == 0
        ? '全部在库良好'
        : '${summary.pendingIssueCount} 项待处理';
  }

  static String powertrainComposition(Map<PowertrainType, int> counts) {
    const order = [
      PowertrainType.ev,
      PowertrainType.phev,
      PowertrainType.hev,
      PowertrainType.ice,
    ];
    const labels = {
      PowertrainType.ev: '纯电',
      PowertrainType.phev: '插混',
      PowertrainType.hev: '油混',
      PowertrainType.ice: '燃油',
    };
    return [
      for (final type in order)
        if ((counts[type] ?? 0) > 0) '${labels[type]} ${counts[type]} 辆',
    ].join('  |  ');
  }

  static String specLine(ManagedVehicle vehicle) {
    final spec = vehicle.specLabel.trim();
    return spec.isEmpty ? '车辆档案待完善' : spec;
  }

  static DeleteBlockReason? deleteBlockReason(
    ManagedVehicle vehicle,
    GarageOverview garage,
  ) {
    if (vehicle.isPrimary && garage.vehicles.length > 1) {
      return DeleteBlockReason.isPrimary;
    }
    if (vehicle.recordCount > 0) {
      return DeleteBlockReason.hasRecords;
    }
    return null;
  }

  /// 保险 / 年检 / 保养是否需要在总览提示。
  static bool hasPendingIssue(ManagedVehicle vehicle, {DateTime? now}) {
    if (vehicle.maintenance.enabled &&
        vehicle.maintenance.status != MaintenanceStatus.normal) {
      return true;
    }
    final insurance = _daysUntil(vehicle.insuranceExpiry, now: now);
    final inspection = _daysUntil(vehicle.inspectionExpiry, now: now);
    return (insurance != null && insurance <= 30) ||
        (inspection != null && inspection <= 30);
  }

  static bool hasReminderData(ManagedVehicle vehicle) {
    return vehicle.maintenance.enabled ||
        vehicle.insuranceExpiry != null ||
        vehicle.inspectionExpiry != null;
  }

  static int? _daysUntil(DateTime? date, {DateTime? now}) {
    if (date == null) {
      return null;
    }
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.difference(today).inDays;
  }
}
