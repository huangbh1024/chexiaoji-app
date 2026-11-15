import '../../home/data/home_repository.dart';
import '../../home/domain/home_models.dart';
import '../../ledger/data/ledger_repository.dart';
import '../domain/vehicle_models.dart';
import '../domain/vehicle_presenter.dart';
import 'vehicle_repository.dart';
import 'vehicle_store.dart';

/// 本地车库：由 [VehicleStore] 持有状态，首页 dashboard 与账单流水数用于补全展示字段。
class MockVehicleRepository implements VehicleRepository {
  MockVehicleRepository({
    required this.store,
    required this.home,
    required this.ledger,
    DateTime Function()? now,
    this.delay = const Duration(milliseconds: 140),
  }) : _now = now ?? DateTime.now;

  final VehicleStore store;
  final HomeRepository home;
  final LedgerRepository ledger;
  final DateTime Function() _now;
  final Duration delay;

  @override
  String? get primaryVehicleId => store.primaryVehicleId;

  @override
  Future<GarageOverview> fetchGarage() async {
    await Future<void>.delayed(delay);
    final records = store.active;
    if (records.isEmpty) {
      final now = _now();
      return GarageOverview(
        vehicles: const [],
        archivedVehicles: _archivedView(),
        primaryVehicleId: store.primaryVehicleId,
        summary: const FleetSummary(
          vehicleCount: 0,
          totalOdometerKm: 0,
          monthSpendCents: 0,
          powertrainCounts: {},
          pendingIssueCount: 0,
          hasReminderData: false,
        ),
        fetchedAt: now,
      );
    }

    final vehicles = await home.fetchVehicles();
    final vehiclesById = <String, Vehicle>{
      for (final vehicle in vehicles) vehicle.id: vehicle,
    };
    final dashboards = await Future.wait(
      records.map((record) => home.fetchDashboard(record.id)),
    );
    final recordCounts = await Future.wait(
      records.map((record) => ledger.countRecords(vehicleId: record.id)),
    );

    final managed = <ManagedVehicle>[
      for (var index = 0; index < records.length; index++)
        ManagedVehicle(
          vehicle: vehiclesById[records[index].id] ?? records[index].vehicle,
          specLabel: records[index].specLabel,
          sortOrder: records[index].sortOrder,
          isPrimary: records[index].id == store.primaryVehicleId,
          monthSpendCents: dashboards[index].summary.monthSpendCents,
          recordCount: recordCounts[index],
          consumption: dashboards[index].consumption,
          maintenance: dashboards[index].maintenance,
          batteryHealthPercent: records[index].batteryHealthPercent,
          insuranceExpiry: records[index].insuranceExpiry,
          inspectionExpiry: records[index].inspectionExpiry,
        ),
    ];

    return GarageOverview(
      vehicles: List<ManagedVehicle>.unmodifiable(managed),
      archivedVehicles: _archivedView(),
      primaryVehicleId: store.primaryVehicleId,
      summary: _summaryOf(managed),
      fetchedAt: _now(),
    );
  }

  List<ArchivedVehicle> _archivedView() {
    return [
      for (final record in store.archived)
        ArchivedVehicle(
          vehicle: record.vehicle,
          specLabel: record.specLabel,
          sortOrder: record.sortOrder,
          archivedAt: record.archivedAt ?? _now(),
        ),
    ];
  }

  FleetSummary _summaryOf(List<ManagedVehicle> vehicles) {
    final now = _now();
    final counts = <PowertrainType, int>{};
    var totalOdometer = 0;
    var monthSpend = 0;
    var pending = 0;
    var hasReminderData = false;

    for (final vehicle in vehicles) {
      totalOdometer += vehicle.vehicle.odometerKm;
      monthSpend += vehicle.monthSpendCents;
      counts.update(
        vehicle.powertrain,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      if (VehiclePresenter.hasPendingIssue(vehicle, now: now)) {
        pending++;
      }
      hasReminderData =
          hasReminderData || VehiclePresenter.hasReminderData(vehicle);
    }

    return FleetSummary(
      vehicleCount: vehicles.length,
      totalOdometerKm: totalOdometer,
      monthSpendCents: monthSpend,
      powertrainCounts: Map<PowertrainType, int>.unmodifiable(counts),
      pendingIssueCount: pending,
      hasReminderData: hasReminderData,
    );
  }

  @override
  Future<void> setPrimary(String vehicleId) async {
    await Future<void>.delayed(delay);
    final record = store.byId(vehicleId);
    if (record == null || record.isArchived) {
      throw const VehicleOperationException(VehicleErrorCode.notFound);
    }
    try {
      store.setPrimary(vehicleId);
    } on VehicleStoreException catch (error) {
      throw _mapStoreError(error);
    }
  }

  @override
  Future<void> archive(String vehicleId) async {
    await Future<void>.delayed(delay);
    if (store.byId(vehicleId) == null) {
      throw const VehicleOperationException(VehicleErrorCode.notFound);
    }
    try {
      store.archive(vehicleId);
    } on VehicleStoreException catch (error) {
      throw _mapStoreError(error);
    }
  }

  @override
  Future<void> restore(String vehicleId) async {
    await Future<void>.delayed(delay);
    final record = store.byId(vehicleId);
    if (record == null || !record.isArchived) {
      throw const VehicleOperationException(VehicleErrorCode.notFound);
    }
    try {
      store.restore(vehicleId);
    } on VehicleStoreException catch (error) {
      throw _mapStoreError(error);
    }
  }

  @override
  Future<void> delete(String vehicleId) async {
    await Future<void>.delayed(delay);
    final record = store.byId(vehicleId);
    if (record == null) {
      throw const VehicleOperationException(VehicleErrorCode.notFound);
    }
    if (store.primaryVehicleId == vehicleId && store.active.length > 1) {
      throw const VehicleOperationException(VehicleErrorCode.isPrimary);
    }
    final count = await ledger.countRecords(vehicleId: vehicleId);
    if (count > 0) {
      throw const VehicleOperationException(VehicleErrorCode.hasRecords);
    }
    try {
      store.delete(vehicleId);
    } on VehicleStoreException catch (error) {
      throw _mapStoreError(error);
    }
  }

  VehicleOperationException _mapStoreError(VehicleStoreException error) {
    return switch (error.error) {
      VehicleStoreError.notFound ||
      VehicleStoreError.archived ||
      VehicleStoreError.notArchived => const VehicleOperationException(
        VehicleErrorCode.notFound,
      ),
      VehicleStoreError.isPrimary => const VehicleOperationException(
        VehicleErrorCode.isPrimary,
      ),
    };
  }
}
