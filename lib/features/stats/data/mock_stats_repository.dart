import '../../home/data/home_repository.dart';
import '../../home/domain/home_models.dart';
import '../../ledger/data/mock_ledger_repository.dart';
import '../../ledger/domain/ledger_models.dart';
import '../domain/stats_aggregation.dart';
import '../domain/stats_models.dart';
import '../domain/stats_period.dart';
import 'stats_repository.dart';

/// 可在测试中注入的失败模块。
enum StatsMockFailure { overview, breakdown, trend, recent }

/// 本地统计仓库：记录来自 [MockLedgerRepository]，车辆 / 保养来自
/// [HomeRepository]，保证与账单页同一批记录、同一套口径。
class MockStatsRepository implements StatsRepository {
  MockStatsRepository({
    required this.ledger,
    required this.home,
    this.delay = const Duration(milliseconds: 120),
    this.failures = const <StatsMockFailure>{},
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final MockLedgerRepository ledger;
  final HomeRepository home;
  final Duration delay;
  final Set<StatsMockFailure> failures;
  final DateTime Function() _clock;

  @override
  Future<StatsOverview> fetchOverview(StatsScope scope) async {
    await _enter(StatsMockFailure.overview);
    final now = _clock();
    final vehicles = await home.fetchVehicles();
    final firstRecordAt = scope.period == StatsPeriod.all
        ? ledger.firstRecordAt(vehicleId: scope.vehicleId)
        : null;
    final range = resolveStatsRange(
      scope.period,
      scope.anchor,
      now: now,
      firstRecordAt: firstRecordAt,
    );
    final records = _records(scope.vehicleId, range);
    final previousRange = previousStatsRange(scope.period, range, now: now);
    final previousRecords = previousRange == null
        ? const <LedgerRecord>[]
        : _records(scope.vehicleId, previousRange);
    final summary = buildStatsSummary(
      period: scope.period,
      records: records,
      previousRecords: previousRecords,
      now: now,
      firstRecordAt: firstRecordAt,
    );
    final vehicle = scope.vehicleId == null
        ? null
        : _vehicleById(vehicles, scope.vehicleId!);

    return StatsOverview(
      scope: scope,
      range: range,
      powertrain: vehicle?.powertrain,
      summary: summary,
      consumption: _consumption(
        scope: scope,
        range: range,
        vehicle: vehicle,
        records: records,
        summary: summary,
        now: now,
      ),
      maintenance: await _maintenance(scope.vehicleId, vehicles),
      dataUpdatedAt: now,
    );
  }

  @override
  Future<StatsBreakdown> fetchBreakdown(StatsScope scope) async {
    await _enter(StatsMockFailure.breakdown);
    final firstRecordAt = scope.period == StatsPeriod.all
        ? ledger.firstRecordAt(vehicleId: scope.vehicleId)
        : null;
    final range = resolveStatsRange(
      scope.period,
      scope.anchor,
      now: _clock(),
      firstRecordAt: firstRecordAt,
    );
    return buildStatsBreakdown(_records(scope.vehicleId, range));
  }

  @override
  Future<StatsTrend> fetchTrend(StatsTrendQuery query) async {
    await _enter(StatsMockFailure.trend);
    final now = _clock();
    final window = statsTrendWindow(query.range, now);
    final previousWindow = previousStatsTrendWindow(query.range, now);
    return buildStatsTrend(
      query: query,
      records: _recordsInWindow(query.vehicleId, window.from, window.to),
      previousRecords: _recordsInWindow(
        query.vehicleId,
        previousWindow.from,
        previousWindow.to,
      ),
      now: now,
    );
  }

  @override
  Future<List<StatsRecord>> fetchRecent(
    StatsScope scope, {
    int limit = 3,
  }) async {
    await _enter(StatsMockFailure.recent);
    final firstRecordAt = scope.period == StatsPeriod.all
        ? ledger.firstRecordAt(vehicleId: scope.vehicleId)
        : null;
    final range = resolveStatsRange(
      scope.period,
      scope.anchor,
      now: _clock(),
      firstRecordAt: firstRecordAt,
    );
    return recentStatsRecords(
      _records(scope.vehicleId, range),
      limit: limit,
      showVehicle: scope.vehicleId == null,
    );
  }

  Future<void> _enter(StatsMockFailure module) async {
    await Future<void>.delayed(delay);
    if (failures.contains(module)) {
      throw StateError('mock stats failure: ${module.name}');
    }
  }

  List<LedgerRecord> _records(String? vehicleId, StatsRange range) =>
      _recordsInWindow(vehicleId, range.start, range.end);

  List<LedgerRecord> _recordsInWindow(
    String? vehicleId,
    DateTime from,
    DateTime to,
  ) {
    return ledger
        .recordsBetween(from, to)
        .where((record) => vehicleId == null || record.vehicleId == vehicleId)
        .toList(growable: false);
  }

  StatsConsumption _consumption({
    required StatsScope scope,
    required StatsRange range,
    required Vehicle? vehicle,
    required List<LedgerRecord> records,
    required StatsSummary summary,
    required DateTime now,
  }) {
    if (vehicle == null) {
      final cost = summary.energyCostPerKmCents;
      return StatsConsumption(
        rating: StatsRating.fleet,
        primary: StatsEnergyValue(
          value: cost == null ? null : cost / 100,
          unit: 'CNY/km',
        ),
        sparkline: energyCostSparkline(records, range),
      );
    }

    final useKwh =
        vehicle.powertrain == PowertrainType.ev ||
        vehicle.powertrain == PowertrainType.phev;
    final values = consumptionOf(records, summary.distanceKm);
    final primaryValue = useKwh ? values.kwhPer100km : values.litersPer100km;
    final secondaryValue = vehicle.powertrain == PowertrainType.phev
        ? values.litersPer100km
        : null;
    final baseline = _baselineConsumption(
      scope,
      range,
      useKwh: useKwh,
      now: now,
    );

    return StatsConsumption(
      rating: ratingFor(primaryValue, baseline),
      primary: StatsEnergyValue(
        value: primaryValue,
        unit: useKwh ? 'kWh/100km' : 'L/100km',
      ),
      secondary: secondaryValue == null
          ? null
          : StatsEnergyValue(value: secondaryValue, unit: 'L/100km'),
      sparkline: consumptionSparkline(records, range, useKwh: useKwh),
    );
  }

  double? _baselineConsumption(
    StatsScope scope,
    StatsRange current, {
    required bool useKwh,
    required DateTime now,
  }) {
    if (scope.period == StatsPeriod.all) {
      return null;
    }
    var cursor = current;
    var sum = 0.0;
    var count = 0;
    for (var index = 0; index < 6; index++) {
      final previous = previousStatsRange(scope.period, cursor, now: now);
      if (previous == null) {
        break;
      }
      final records = _records(scope.vehicleId, previous);
      final distance = distanceOf(records).km;
      final values = consumptionOf(records, distance);
      final value = useKwh ? values.kwhPer100km : values.litersPer100km;
      if (value != null) {
        sum += value;
        count++;
      }
      cursor = previous;
    }
    return count == 0 ? null : sum / count;
  }

  Future<StatsMaintenance?> _maintenance(
    String? vehicleId,
    List<Vehicle> vehicles,
  ) async {
    if (vehicleId == null) {
      StatsMaintenance? urgent;
      for (final vehicle in vehicles) {
        final item = await _maintenanceFor(vehicle);
        if (!item.enabled) {
          continue;
        }
        if (urgent == null || item.remainingKm < urgent.remainingKm) {
          urgent = item;
        }
      }
      return urgent;
    }
    final vehicle = _vehicleById(vehicles, vehicleId);
    if (vehicle == null) {
      return null;
    }
    return _maintenanceFor(vehicle);
  }

  Future<StatsMaintenance> _maintenanceFor(Vehicle vehicle) async {
    final dashboard = await home.fetchDashboard(vehicle.id);
    final maintenance = dashboard.maintenance;
    return StatsMaintenance(
      enabled: maintenance.enabled,
      vehicleId: vehicle.id,
      vehicleName: vehicle.name,
      tag: _maintenanceTag(vehicle, maintenance),
      remainingKm: maintenance.remainingKm,
      progressPercent: maintenance.progressPercent,
      status: maintenance.status,
      remainingDays: maintenance.remainingDays,
    );
  }

  String _maintenanceTag(Vehicle vehicle, Maintenance maintenance) {
    if (!maintenance.enabled) {
      return '未设置';
    }
    if (vehicle.powertrain == PowertrainType.phev) {
      return '首保/小保';
    }
    return maintenance.remainingKm <= 1000 ? '大保养' : '小保养';
  }

  Vehicle? _vehicleById(List<Vehicle> vehicles, String id) {
    for (final vehicle in vehicles) {
      if (vehicle.id == id) {
        return vehicle;
      }
    }
    return null;
  }
}
