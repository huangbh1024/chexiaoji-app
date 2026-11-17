import '../../home/data/home_repository.dart';
import '../../home/domain/home_models.dart';
import '../../ledger/data/ledger_repository.dart';
import '../domain/vehicle_editor_models.dart';
import '../domain/vehicle_editor_presenter.dart';
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
    String Function()? idGenerator,
    this.delay = const Duration(milliseconds: 140),
  }) : _now = now ?? DateTime.now,
       _idGenerator = idGenerator ?? _defaultId;

  final VehicleStore store;
  final HomeRepository home;
  final LedgerRepository ledger;
  final DateTime Function() _now;
  final String Function() _idGenerator;
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
          nickname: records[index].nickname,
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

  @override
  Future<ArchivedGarage> fetchArchivedGarage() async {
    await Future<void>.delayed(delay);
    final records = store.archived;
    final vehicles = await Future.wait([
      for (final record in records) _archivedSummary(record),
    ]);
    return ArchivedGarage(
      vehicles: List<ArchivedVehicleSummary>.unmodifiable(vehicles),
      fetchedAt: _now(),
    );
  }

  Future<ArchivedVehicleSummary> _archivedSummary(VehicleRecord record) async {
    final stats = await ledger.fetchVehicleStats(record.id);
    // 历史平均能耗由账本全周期汇总推导；没有读数时保持 null，
    // 归档卡显示「未录入」而不是 0.0。
    final electric =
        record.vehicle.powertrain == PowertrainType.ev ||
        record.vehicle.powertrain == PowertrainType.phev;
    final value = stats.distanceKm <= 0
        ? null
        : electric
        ? (stats.energyKwh > 0
              ? stats.energyKwh / stats.distanceKm * 100
              : null)
        : (stats.fuelLiters > 0
              ? stats.fuelLiters / stats.distanceKm * 100
              : null);
    final averageConsumption = value == null
        ? null
        : EnergyValue(value: value, unit: electric ? 'kWh/百公里' : 'L/百公里');
    return ArchivedVehicleSummary(
      vehicle: record.vehicle,
      specLabel: record.specLabel,
      sortOrder: record.sortOrder,
      archivedAt: record.archivedAt ?? _now(),
      lifetimeSpendCents: stats.totalSpendCents,
      recordCount: stats.recordCount,
      energyRecordCount: stats.energyRecordCount,
      averageConsumption: averageConsumption,
      latestRecordAt: stats.latestRecordAt,
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

  @override
  Future<void> purgeArchivedVehicle(
    String vehicleId, {
    required String plateTail,
  }) async {
    await Future<void>.delayed(delay);
    final record = store.byId(vehicleId);
    if (record == null) {
      throw const VehicleOperationException(VehicleErrorCode.notFound);
    }
    if (!record.isArchived) {
      throw const VehicleOperationException(VehicleErrorCode.notArchived);
    }
    if (ArchivedVehiclePresenter.plateTailOf(record.vehicle.plate) !=
        plateTail.trim().toUpperCase()) {
      throw const VehicleOperationException(VehicleErrorCode.plateTailMismatch);
    }
    try {
      store.purge(vehicleId);
    } on VehicleStoreException catch (error) {
      throw _mapStoreError(error);
    }
  }

  @override
  Future<VehicleEditorSnapshot> fetchVehicleEditor(String vehicleId) async {
    await Future<void>.delayed(delay);
    final record = store.byId(vehicleId);
    if (record == null) {
      throw const VehicleOperationException(VehicleErrorCode.notFound);
    }
    if (record.isArchived) {
      throw const VehicleOperationException(VehicleErrorCode.notArchived);
    }
    final latest = await ledger.latestOdometerForVehicle(vehicleId);
    final isPrimary = store.primaryVehicleId == vehicleId;
    final successor = isPrimary ? store.successorOf(vehicleId) : null;
    return VehicleEditorSnapshot(
      vehicleId: vehicleId,
      draft: VehicleEditorPresenter.draftOf(
        record,
        latestOdometerKm: latest,
        isPrimary: isPrimary,
      ),
      isPrimary: isPrimary,
      activeVehicleCount: store.active.length,
      maxActiveVehicles: VehicleStore.maxActiveVehicles,
      latestOdometerKm: latest,
      version: 1,
      successorName: successor == null
          ? null
          : store.byId(successor)?.vehicle.name,
      isOnlyActiveVehicle: store.active.length == 1,
    );
  }

  @override
  Future<VehicleEditorResult> createVehicle(VehicleEditorDraft draft) async {
    await Future<void>.delayed(delay);
    if (store.active.length >= VehicleStore.maxActiveVehicles) {
      throw const VehicleOperationException(VehicleErrorCode.limitReached);
    }
    final conflict = store.byPlate(draft.plate);
    if (conflict != null) {
      throw VehicleOperationException(
        VehicleErrorCode.duplicatePlate,
        conflict.vehicle.name,
      );
    }
    final id = _idGenerator();
    final vehicle = VehicleEditorPresenter.buildVehicle(
      draft: draft,
      id: id,
      badge: _badgeOf(draft),
    );
    final record = VehicleEditorPresenter.buildRecord(
      vehicle: vehicle,
      draft: draft,
      sortOrder: store.nextSortOrder,
    );
    final created = store.add(
      record,
      makePrimary: draft.makePrimary || store.active.isEmpty,
    );
    return VehicleEditorResult(vehicleId: created.id, created: true);
  }

  @override
  Future<VehicleEditorResult> updateVehicle(
    String vehicleId,
    VehicleEditorDraft draft, {
    int? version,
  }) async {
    await Future<void>.delayed(delay);
    final existing = store.byId(vehicleId);
    if (existing == null) {
      throw const VehicleOperationException(VehicleErrorCode.notFound);
    }
    if (existing.isArchived) {
      throw const VehicleOperationException(VehicleErrorCode.notArchived);
    }
    final conflict = store.byPlate(draft.plate);
    if (conflict != null && conflict.id != vehicleId) {
      throw VehicleOperationException(
        VehicleErrorCode.duplicatePlate,
        conflict.vehicle.name,
      );
    }
    final vehicle = VehicleEditorPresenter.buildVehicle(
      draft: draft,
      id: vehicleId,
      badge: _badgeOf(draft, fallback: existing.vehicle.badge),
    );
    final record = VehicleEditorPresenter.buildRecord(
      vehicle: vehicle,
      draft: draft,
      sortOrder: existing.sortOrder,
      existing: existing,
    );
    store.update(vehicleId, record, makePrimary: draft.makePrimary);
    return VehicleEditorResult(vehicleId: vehicleId, created: false);
  }

  String? _badgeOf(VehicleEditorDraft draft, {String? fallback}) {
    if (draft.defaultFuelGrade != null) {
      return '${draft.defaultFuelGrade}号汽油';
    }
    if (fallback == null || fallback.contains('号汽油')) {
      return null;
    }
    return fallback;
  }

  static String _defaultId() =>
      'veh-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  VehicleOperationException _mapStoreError(VehicleStoreException error) {
    return switch (error.error) {
      VehicleStoreError.notFound || VehicleStoreError.archived =>
        const VehicleOperationException(VehicleErrorCode.notFound),
      VehicleStoreError.notArchived => const VehicleOperationException(
        VehicleErrorCode.notArchived,
      ),
      VehicleStoreError.isPrimary => const VehicleOperationException(
        VehicleErrorCode.isPrimary,
      ),
      VehicleStoreError.duplicatePlate => const VehicleOperationException(
        VehicleErrorCode.duplicatePlate,
      ),
      VehicleStoreError.limitReached => const VehicleOperationException(
        VehicleErrorCode.limitReached,
      ),
    };
  }
}
