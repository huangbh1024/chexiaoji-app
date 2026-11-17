import 'package:chexiaoji_app/features/home/domain/home_models.dart';
import 'package:chexiaoji_app/features/vehicles/domain/vehicle_models.dart';
import 'package:chexiaoji_app/features/vehicles/domain/vehicle_presenter.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 15);

Vehicle _vehicle({
  PowertrainType powertrain = PowertrainType.ev,
  int odometerKm = 18426,
}) {
  return Vehicle(
    id: 'v1',
    name: '比亚迪 汉 EV',
    plate: '粤B·D82K6',
    powertrain: powertrain,
    powertrainLabel: '纯电',
    odometerKm: odometerKm,
  );
}

Consumption _consumption({
  double primary = 14.8,
  String primaryUnit = 'kWh/百公里',
  double? secondary,
  String secondaryUnit = 'L/百公里',
}) {
  return Consumption(
    label: '平均能耗',
    typeLabel: '纯电电耗',
    primary: EnergyValue(value: primary, unit: primaryUnit),
    secondary: secondary == null
        ? null
        : EnergyValue(value: secondary, unit: secondaryUnit),
    primarySparkline: const [14.8],
  );
}

Maintenance _maintenance({
  bool enabled = true,
  int remainingKm = 1574,
  int progressPercent = 78,
  MaintenanceStatus status = MaintenanceStatus.normal,
}) {
  return Maintenance(
    enabled: enabled,
    remainingKm: remainingKm,
    progressPercent: progressPercent,
    status: status,
  );
}

ManagedVehicle _managed({
  PowertrainType powertrain = PowertrainType.ev,
  int odometerKm = 18426,
  Consumption? consumption,
  Maintenance? maintenance,
  bool isPrimary = true,
  int recordCount = 0,
  int? batteryHealthPercent,
  DateTime? insuranceExpiry,
  DateTime? inspectionExpiry,
}) {
  return ManagedVehicle(
    vehicle: _vehicle(powertrain: powertrain, odometerKm: odometerKm),
    specLabel: '2023款 创世旗舰型 · 纯电',
    sortOrder: 0,
    isPrimary: isPrimary,
    monthSpendCents: 51200,
    recordCount: recordCount,
    consumption: consumption ?? _consumption(),
    maintenance: maintenance ?? _maintenance(),
    batteryHealthPercent: batteryHealthPercent,
    insuranceExpiry: insuranceExpiry,
    inspectionExpiry: inspectionExpiry,
  );
}

void main() {
  group('三指标', () {
    test('纯电：里程 + 电耗 + SOH', () {
      final metrics = VehiclePresenter.metricsOf(
        _managed(batteryHealthPercent: 98),
      );
      expect(metrics.map((item) => item.label), ['当前里程', '动力电耗', '电池健康 (SOH)']);
      expect(metrics[0].value, '18,426');
      expect(metrics[1].value, '14.8');
      expect(metrics[2].value, '98');
      expect(metrics[2].tone, VehicleMetricTone.normal);
    });

    test('纯电 SOH 低于 80 用危险色；缺失显示未录入', () {
      expect(
        VehiclePresenter.metricsOf(_managed(batteryHealthPercent: 72))[2].tone,
        VehicleMetricTone.danger,
      );
      final missing = VehiclePresenter.metricsOf(_managed())[2];
      expect(missing.value, '—');
      expect(missing.unit, '未录入');
      expect(missing.missing, isTrue);
    });

    test('插混：第三指标为亏电油耗', () {
      final metrics = VehiclePresenter.metricsOf(
        _managed(
          powertrain: PowertrainType.phev,
          consumption: _consumption(primary: 12.5, secondary: 4.4),
        ),
      );
      expect(metrics[1].label, '动力电耗');
      expect(metrics[2].label, '亏电油耗');
      expect(metrics[2].value, '4.4');
    });

    test('燃油：第三指标为车险剩余', () {
      final metrics = VehiclePresenter.metricsOf(
        _managed(
          powertrain: PowertrainType.ice,
          consumption: _consumption(primary: 6.8, primaryUnit: 'L/百公里'),
          insuranceExpiry: DateTime.now().add(const Duration(days: 48)),
        ),
      );
      expect(metrics[1].label, '综合油耗');
      expect(metrics[2].label, '车险剩余');
      expect(metrics[2].value, '48');
      expect(metrics[2].unit, '天到期');
    });

    test('车险 30 天内用危险色', () {
      final metric = VehiclePresenter.metricsOf(
        _managed(
          powertrain: PowertrainType.ice,
          insuranceExpiry: DateTime.now().add(const Duration(days: 12)),
        ),
      )[2];
      expect(metric.tone, VehicleMetricTone.danger);
    });
  });

  group('提醒优先级', () {
    test('保养超期优先于保险 / 年检', () {
      final reminder = VehiclePresenter.reminderOf(
        _managed(
          maintenance: _maintenance(
            remainingKm: -120,
            status: MaintenanceStatus.overdue,
          ),
          insuranceExpiry: _now.add(const Duration(days: 5)),
        ),
        now: _now,
      );
      expect(reminder?.kind, VehicleReminderKind.maintenance);
      expect(reminder?.text, contains('超期'));
    });

    test('保险 30 天内优先于保养正常', () {
      final reminder = VehiclePresenter.reminderOf(
        _managed(insuranceExpiry: _now.add(const Duration(days: 5))),
        now: _now,
      );
      expect(reminder?.kind, VehicleReminderKind.insurance);
      expect(reminder?.text, '交强险+商业险 5 天后到期');
    });

    test('保养预警与正常都展示下次保养', () {
      final warning = VehiclePresenter.reminderOf(
        _managed(
          maintenance: _maintenance(
            progressPercent: 90,
            status: MaintenanceStatus.warning,
          ),
        ),
        now: _now,
      );
      expect(warning?.tone, VehicleMetricTone.warning);
      expect(warning?.text, '下次小保养：约 1574 km 后');
    });

    test('无提醒数据返回 null', () {
      expect(
        VehiclePresenter.reminderOf(
          _managed(maintenance: _maintenance(enabled: false)),
          now: _now,
        ),
        isNull,
      );
    });
  });

  group('汇总与删除判断', () {
    test('健康文案', () {
      const empty = FleetSummary(
        vehicleCount: 0,
        totalOdometerKm: 0,
        monthSpendCents: 0,
        powertrainCounts: {},
        pendingIssueCount: 0,
        hasReminderData: false,
      );
      expect(VehiclePresenter.healthLabel(empty), '');

      const good = FleetSummary(
        vehicleCount: 1,
        totalOdometerKm: 100,
        monthSpendCents: 0,
        powertrainCounts: {},
        pendingIssueCount: 0,
        hasReminderData: true,
      );
      expect(VehiclePresenter.healthLabel(good), '全部在库良好');

      const pending = FleetSummary(
        vehicleCount: 2,
        totalOdometerKm: 100,
        monthSpendCents: 0,
        powertrainCounts: {},
        pendingIssueCount: 2,
        hasReminderData: true,
      );
      expect(VehiclePresenter.healthLabel(pending), '2 项待处理');
    });

    test('动力构成按固定顺序且跳过 0 辆', () {
      expect(
        VehiclePresenter.powertrainComposition({
          PowertrainType.ice: 1,
          PowertrainType.ev: 1,
          PowertrainType.phev: 0,
        }),
        '纯电 1 辆  |  燃油 1 辆',
      );
    });

    test('删除判断先主驾后有流水', () {
      final vehicle = _managed(isPrimary: true, recordCount: 3);
      final garage = GarageOverview(
        vehicles: [vehicle, _managed(isPrimary: false, recordCount: 0)],
        archivedVehicles: const [],
        primaryVehicleId: 'v1',
        summary: const FleetSummary(
          vehicleCount: 2,
          totalOdometerKm: 0,
          monthSpendCents: 0,
          powertrainCounts: {},
          pendingIssueCount: 0,
          hasReminderData: true,
        ),
        fetchedAt: _now,
      );
      expect(
        VehiclePresenter.deleteBlockReason(vehicle, garage),
        DeleteBlockReason.isPrimary,
      );
      expect(
        VehiclePresenter.deleteBlockReason(
          _managed(isPrimary: false, recordCount: 3),
          garage,
        ),
        DeleteBlockReason.hasRecords,
      );
      expect(
        VehiclePresenter.deleteBlockReason(
          _managed(isPrimary: false, recordCount: 0),
          garage,
        ),
        isNull,
      );
    });
  });
}
