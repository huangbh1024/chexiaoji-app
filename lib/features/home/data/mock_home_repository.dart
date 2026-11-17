import 'dart:math' as math;

import '../../../core/format/formatters.dart';
import '../../ledger/data/ledger_repository.dart';
import '../../ledger/data/mock_ledger_repository.dart';
import '../../ledger/domain/ledger_analytics.dart';
import '../../ledger/domain/ledger_models.dart';
import '../../ledger/domain/ledger_presenter.dart';
import '../../vehicles/data/vehicle_seed_data.dart';
import '../../vehicles/data/vehicle_store.dart';
import '../domain/home_models.dart';
import 'home_repository.dart';

/// 首页数据仓库。
///
/// Mock 阶段直接从账单流水聚合：首页 Hero、构成、能耗、保养与趋势都与
/// 账单页 / 统计页 / 月度报表读取同一批记录、使用同一套口径，不再维护
/// 一份写死的演示数据。车辆基础信息来自 [VehicleStore]。
class MockHomeRepository implements HomeRepository {
  MockHomeRepository({
    this.ledger,
    this.odometerResolver,
    this.store,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final LedgerRepository? ledger;

  /// 记账页新增记录后，用账单里的最新读数刷新车辆当前里程。
  final int? Function(String vehicleId)? odometerResolver;

  /// 车库状态的唯一来源；为空时回退到内置演示车辆（测试 / 旧构造）。
  final VehicleStore? store;

  final DateTime Function() _clock;

  late final VehicleStore _fallbackStore = seededVehicleStore(now: _clock());

  VehicleStore get _vehicles => store ?? _fallbackStore;

  @override
  String? get defaultVehicleId =>
      _vehicles.primaryVehicleId ??
      (_vehicles.active.isEmpty ? null : _vehicles.active.first.id);

  @override
  Future<List<Vehicle>> fetchVehicles() async {
    return [
      for (final record in _vehicles.active)
        _withOdometer(record.vehicle, odometerResolver?.call(record.id)),
    ];
  }

  Vehicle _withOdometer(Vehicle vehicle, int? latestKm) {
    if (latestKm == null || latestKm <= vehicle.odometerKm) {
      return vehicle;
    }
    return Vehicle(
      id: vehicle.id,
      name: vehicle.name,
      plate: vehicle.plate,
      powertrain: vehicle.powertrain,
      powertrainLabel: vehicle.powertrainLabel,
      odometerKm: latestKm,
      badge: vehicle.badge,
      batteryCapacityKwh: vehicle.batteryCapacityKwh,
      tankCapacityL: vehicle.tankCapacityL,
      defaultFuelGrade: vehicle.defaultFuelGrade,
    );
  }

  @override
  Future<HomeDashboard> fetchDashboard(String vehicleId) async {
    final record = _vehicles.byId(vehicleId);
    if (record == null) {
      throw StateError('Unknown vehicle: $vehicleId');
    }
    final vehicle = record.vehicle;
    final now = _clock();
    final month = DateTime(now.year, now.month);
    final records = await _recordsInMonth(vehicleId, month);
    final previousRecords = await _recordsInMonth(
      vehicleId,
      DateTime(now.year, now.month - 1),
    );

    final totalCents = totalCentsOf(records);
    final previousTotal = previousRecords.isEmpty
        ? null
        : totalCentsOf(previousRecords);
    final distanceKm = distanceOf(records).km;
    final energyCents = energyCentsOf(records);
    final change = compareTotals(totalCents, previousTotal);

    return HomeDashboard(
      vehicle: vehicle,
      summary: HomeSummary(
        costPerKm: distanceKm <= 0 ? 0 : totalCents / 100 / distanceKm,
        monthSpendCents: totalCents,
        monthMileageKm: distanceKm,
        energyCostPerKm: distanceKm <= 0 ? 0 : energyCents / 100 / distanceKm,
        momChangePercent: change.percent,
        momTrend: change.trend,
      ),
      consumption: _consumption(vehicle, records, now),
      maintenance: await _maintenance(vehicle, record, records, now),
    );
  }

  @override
  Future<Breakdown> fetchBreakdown(String vehicleId) async {
    final now = _clock();
    final records = await _recordsInMonth(
      vehicleId,
      DateTime(now.year, now.month),
    );
    final breakdown = buildCategoryBreakdown(records);
    return Breakdown(
      totalCents: breakdown.totalCents,
      count: breakdown.count,
      categories: [
        for (final item in breakdown.items)
          BreakdownCategory(
            category: item.category,
            amountCents: item.amountCents,
            percent: item.percent,
          ),
      ],
    );
  }

  @override
  Future<List<RecordItem>> fetchRecords(String vehicleId) async {
    final now = _clock();
    final records = await _recordsInMonth(
      vehicleId,
      DateTime(now.year, now.month),
    );
    final sorted = [...records]
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return sorted.take(5).map(_toRecordItem).toList(growable: false);
  }

  RecordItem _toRecordItem(LedgerRecord record) {
    final subtitle = record.subtitle;
    return RecordItem(
      id: record.id,
      category: record.category,
      title: '${record.category.label} · ${record.title}',
      subtitle: subtitle == null
          ? formatDayTitle(record.occurredAt)
          : '${formatDayTitle(record.occurredAt)} · $subtitle',
      amountCents: record.amountCents,
      subLabel: record.unitPricePillText,
    );
  }

  @override
  Future<TrendData> fetchTrend(String vehicleId, TrendRange range) async {
    final now = _clock();
    final window = _trendWindow(range, now);
    final previous = _previousTrendWindow(range, window);
    final records = await _recordsBetween(vehicleId, window.from, window.to);
    if (records.isEmpty) {
      return TrendData(
        range: range,
        points: const [],
        totalCents: 0,
        previousTotalCents: 0,
      );
    }
    final previousRecords = await _recordsBetween(
      vehicleId,
      previous.from,
      previous.to,
    );
    final points = _trendPoints(range, window, records);
    return TrendData(
      range: range,
      points: points,
      totalCents: points.fold(
        0,
        (sum, point) => sum + point.energyCents + point.otherCents,
      ),
      previousTotalCents: totalCentsOf(previousRecords),
    );
  }

  /// 同一进程内的 Mock 账本可以同步聚合，避免首页为「本月 + 上月」
  /// 付两次模拟网络延迟；接入真实接口后走 [LedgerRepository] 的异步方法。
  MockLedgerRepository? get _mockLedger {
    final repository = ledger;
    return repository is MockLedgerRepository ? repository : null;
  }

  Future<List<LedgerRecord>> _recordsInMonth(
    String vehicleId,
    DateTime month,
  ) async {
    final mock = _mockLedger;
    if (mock != null) {
      final start = DateTime(month.year, month.month);
      final end = DateTime(
        month.year,
        month.month + 1,
      ).subtract(const Duration(milliseconds: 1));
      return mock
          .recordsBetween(start, end)
          .where((record) => record.vehicleId == vehicleId)
          .toList(growable: false);
    }
    final repository = ledger;
    if (repository == null) {
      return const <LedgerRecord>[];
    }
    final page = await repository.fetchRecords(
      LedgerQuery(month: month, vehicleId: vehicleId),
      limit: 500,
    );
    return page.items;
  }

  Future<List<LedgerRecord>> _recordsBetween(
    String vehicleId,
    DateTime from,
    DateTime to,
  ) async {
    final mock = _mockLedger;
    if (mock != null) {
      return mock
          .recordsBetween(from, to)
          .where((record) => record.vehicleId == vehicleId)
          .toList(growable: false);
    }
    final repository = ledger;
    if (repository == null) {
      return const <LedgerRecord>[];
    }
    final months = <DateTime>[];
    var cursor = DateTime(from.year, from.month);
    final end = DateTime(to.year, to.month);
    while (!cursor.isAfter(end)) {
      months.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    final pages = await Future.wait([
      for (final month in months)
        repository.fetchRecords(
          LedgerQuery(month: month, vehicleId: vehicleId),
          limit: 500,
        ),
    ]);
    return [
      for (final page in pages)
        for (final record in page.items)
          if (isWithinRange(record.occurredAt, from, to)) record,
    ];
  }

  Consumption _consumption(
    Vehicle vehicle,
    List<LedgerRecord> records,
    DateTime now,
  ) {
    final distanceKm = distanceOf(records).km;
    final values = consumptionOf(records, distanceKm);
    final electric =
        vehicle.powertrain == PowertrainType.ev ||
        vehicle.powertrain == PowertrainType.phev;
    var primaryValue = electric ? values.kwhPer100km : values.litersPer100km;
    var primaryUnit = electric ? 'kWh/百公里' : 'L/百公里';
    var secondaryValue = vehicle.powertrain == PowertrainType.phev
        ? values.litersPer100km
        : null;
    // 插混本月可能只有加油没有充电：此时把油耗升为主指标，
    // 不显示 0.0 kWh/百公里 的伪读数。
    if (electric && primaryValue == null && secondaryValue != null) {
      primaryValue = secondaryValue;
      primaryUnit = 'L/百公里';
      secondaryValue = null;
    }
    final primaryUsesKwh = primaryUnit == 'kWh/百公里';
    final hasData = primaryValue != null;
    return Consumption(
      label: _consumptionLabel(vehicle.powertrain),
      typeLabel: _consumptionTypeLabel(vehicle),
      primary: EnergyValue(value: primaryValue ?? 0, unit: primaryUnit),
      secondary: secondaryValue == null
          ? null
          : EnergyValue(value: secondaryValue, unit: 'L/百公里'),
      primarySparkline: hasData
          ? _sparkline(records, now, primaryUsesKwh)
          : const [],
      secondarySparkline: secondaryValue == null
          ? const []
          : _sparkline(records, now, false),
      hasData: hasData,
    );
  }

  List<double> _sparkline(
    List<LedgerRecord> records,
    DateTime now,
    bool useKwh,
  ) {
    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year, now.month, now.day);
    final buckets = bucketRecordsByDay(records, from: start, to: end);
    if (buckets.length < 2) {
      return const <double>[];
    }
    final groupSize = (buckets.length / 8).ceil();
    final points = <double>[];
    for (var index = 0; index < buckets.length; index += groupSize) {
      final group = buckets.sublist(
        index,
        math.min(index + groupSize, buckets.length),
      );
      final groupRecords = [for (final bucket in group) ...bucket.records];
      final km = distanceOf(groupRecords).km;
      if (km <= 0) {
        continue;
      }
      final values = consumptionOf(groupRecords, km);
      final value = useKwh ? values.kwhPer100km : values.litersPer100km;
      if (value != null) {
        points.add(value);
      }
    }
    return points.length >= 2 ? points : const <double>[];
  }

  Future<Maintenance> _maintenance(
    Vehicle vehicle,
    VehicleRecord record,
    List<LedgerRecord> monthRecords,
    DateTime now,
  ) async {
    final next = record.nextMaintenanceKm;
    if (next == null || next <= 0) {
      return const Maintenance(
        enabled: false,
        remainingKm: 0,
        progressPercent: 0,
        status: MaintenanceStatus.normal,
        hasProgress: false,
      );
    }
    final latest = odometerResolver?.call(vehicle.id);
    final current = latest != null && latest > vehicle.odometerKm
        ? latest
        : vehicle.odometerKm;
    final last = await ledger?.latestMaintenanceOdometer(vehicle.id);
    final hasProgress = last != null && next > last;
    final progress = hasProgress
        ? (((current - last) / (next - last)) * 100).clamp(0, 100).round()
        : 0;
    final remaining = next - current;
    final dailyKm = _dailyAverageKm(monthRecords, now);
    final remainingDays = remaining > 0 && dailyKm > 0
        ? (remaining / dailyKm).round()
        : null;
    return Maintenance(
      enabled: true,
      remainingKm: remaining,
      remainingDays: remainingDays,
      progressPercent: progress,
      status: remaining < 0
          ? MaintenanceStatus.overdue
          : (remaining <= 1000
                ? MaintenanceStatus.warning
                : MaintenanceStatus.normal),
      hasProgress: hasProgress,
    );
  }

  double _dailyAverageKm(List<LedgerRecord> records, DateTime now) {
    final km = distanceOf(records).km;
    return km / math.max(1, now.day);
  }

  String _consumptionLabel(PowertrainType powertrain) {
    return switch (powertrain) {
      PowertrainType.ev => '平均能耗',
      PowertrainType.phev || PowertrainType.hev => '综合能耗',
      PowertrainType.ice => '综合油耗',
    };
  }

  String _consumptionTypeLabel(Vehicle vehicle) {
    return switch (vehicle.powertrain) {
      PowertrainType.ev => '纯电电耗',
      PowertrainType.phev => '双模混动',
      PowertrainType.hev => '油电混动',
      PowertrainType.ice =>
        vehicle.defaultFuelGrade == null
            ? '纯燃油'
            : '${vehicle.defaultFuelGrade}号汽油',
    };
  }

  ({DateTime from, DateTime to}) _trendWindow(TrendRange range, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    switch (range) {
      case TrendRange.d7:
      case TrendRange.d30:
        final days = range == TrendRange.d7 ? 7 : 30;
        return (
          from: today.subtract(Duration(days: days - 1)),
          to: DateTime(today.year, today.month, today.day, 23, 59, 59, 999),
        );
      case TrendRange.halfYear:
      case TrendRange.year:
        final months = range == TrendRange.halfYear ? 6 : 12;
        return (
          from: DateTime(today.year, today.month - (months - 1)),
          to: DateTime(today.year, today.month + 1, 0, 23, 59, 59, 999),
        );
    }
  }

  ({DateTime from, DateTime to}) _previousTrendWindow(
    TrendRange range,
    ({DateTime from, DateTime to}) window,
  ) {
    switch (range) {
      case TrendRange.d7:
      case TrendRange.d30:
        final days = range == TrendRange.d7 ? 7 : 30;
        return (
          from: window.from.subtract(Duration(days: days)),
          to: window.from.subtract(const Duration(milliseconds: 1)),
        );
      case TrendRange.halfYear:
      case TrendRange.year:
        final months = range == TrendRange.halfYear ? 6 : 12;
        return (
          from: DateTime(window.from.year, window.from.month - months),
          to: window.from.subtract(const Duration(milliseconds: 1)),
        );
    }
  }

  List<TrendPoint> _trendPoints(
    TrendRange range,
    ({DateTime from, DateTime to}) window,
    List<LedgerRecord> records,
  ) {
    final buckets = switch (range) {
      TrendRange.d7 || TrendRange.d30 => bucketRecordsByDay(
        records,
        from: window.from,
        to: window.to,
      ),
      TrendRange.halfYear || TrendRange.year => bucketRecordsByMonth(
        records,
        from: window.from,
        to: window.to,
      ),
    };
    return [
      for (final bucket in buckets)
        TrendPoint(
          date: bucket.start,
          energyCents: bucket.energyCents,
          otherCents: bucket.otherCents,
        ),
    ];
  }
}
