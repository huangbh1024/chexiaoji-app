import '../../home/data/home_repository.dart';
import '../../ledger/data/ledger_repository.dart';
import '../../ledger/data/mock_ledger_repository.dart';
import '../../ledger/domain/ledger_models.dart';
import '../domain/garage_aggregation.dart';
import '../domain/profile_models.dart';
import 'profile_repository.dart';

/// 我的页本地 Mock：复用首页与账本仓库，保证车库金额与账单口径一致。
class MockProfileRepository implements ProfileRepository {
  MockProfileRepository({
    required this.home,
    required this.ledger,
    this.delay = const Duration(milliseconds: 140),
  });

  final HomeRepository home;
  final LedgerRepository ledger;
  final Duration delay;

  static const _user = ProfileUser(
    id: 'local-user',
    nickname: '林漪',
    verifiedOwner: true,
    tagline: '车小记 · 驱动每公里透明',
    phoneMasked: '138 **** 9208',
  );

  @override
  Future<ProfileOverview> fetchOverview() async {
    await Future<void>.delayed(delay);
    final now = DateTime.now();
    final lifetime = await ledger.fetchLifetimeStats();
    return ProfileOverview(
      user: _user,
      stats: ProfileStats(
        accountDays: computeAccountDays(lifetime.firstRecordAt, now),
        recordCount: lifetime.recordCount,
        firstRecordAt: lifetime.firstRecordAt,
      ),
      dataUpdatedAt: now,
    );
  }

  @override
  Future<GarageData> fetchGarage({String? vehicleId, DateTime? month}) async {
    await Future<void>.delayed(delay);
    final now = DateTime.now();
    final targetMonth = month ?? DateTime(now.year, now.month);
    final vehicles = await home.fetchVehicles();
    final dashboards = await Future.wait(
      vehicles.map((vehicle) => home.fetchDashboard(vehicle.id)),
    );
    final maintenanceByVehicle = {
      for (final dashboard in dashboards)
        dashboard.vehicle.id: dashboard.maintenance,
    };
    final energyCostByVehicle = {
      for (final dashboard in dashboards)
        dashboard.vehicle.id: (dashboard.summary.energyCostPerKm * 100).round(),
    };

    final garageVehicles = [
      for (final vehicle in vehicles)
        GarageVehicle(
          id: vehicle.id,
          name: vehicle.name,
          shortName: shortNameFor(vehicle.name),
          plate: vehicle.plate,
          powertrain: vehicle.powertrain,
          powertrainLabel: vehicle.powertrainLabel,
          odometerKm: vehicle.odometerKm,
          energyCostPerKmCents: energyCostByVehicle[vehicle.id],
        ),
    ];

    final knownVehicle =
        vehicleId != null &&
        garageVehicles.any((vehicle) => vehicle.id == vehicleId);
    final effectiveVehicleId = knownVehicle ? vehicleId : null;
    final records = await _fetchMonthRecords(targetMonth, effectiveVehicleId);

    return GarageData(
      vehicles: garageVehicles,
      snapshot: buildGarageSnapshot(
        vehicleId: effectiveVehicleId,
        vehicles: garageVehicles,
        monthRecords: records,
        maintenanceByVehicle: maintenanceByVehicle,
        now: now,
      ),
      dataUpdatedAt: now,
    );
  }

  @override
  Future<ProfileServices> fetchServices() async {
    await Future<void>.delayed(delay);
    return const ProfileServices(
      report: ProfileServiceStatus(available: true),
      voucher: ProfileServiceStatus(available: false),
      sync: ProfileServiceStatus(available: false, state: SyncState.local),
      offline: ProfileServiceStatus(available: false),
    );
  }

  @override
  Future<ProfilePreferences> fetchPreferences() async {
    await Future<void>.delayed(delay);
    return const ProfilePreferences();
  }

  @override
  Future<ProfilePreferences> updatePreferences(ProfilePreferences preferences) {
    throw UnimplementedError('P1 才支持保存偏好');
  }

  @override
  Future<void> logout() {
    throw UnimplementedError('P1 才支持退出登录');
  }

  Future<List<LedgerRecord>> _fetchMonthRecords(
    DateTime month,
    String? vehicleId,
  ) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(
      month.year,
      month.month + 1,
    ).subtract(const Duration(milliseconds: 1));
    final mock = ledger is MockLedgerRepository
        ? ledger as MockLedgerRepository
        : null;
    if (mock != null) {
      return mock
          .recordsBetween(start, end)
          .where((record) => vehicleId == null || record.vehicleId == vehicleId)
          .toList(growable: false);
    }
    final items = <LedgerRecord>[];
    String? cursor;
    for (var page = 0; page < 20; page++) {
      final result = await ledger.fetchRecords(
        LedgerQuery(month: month, vehicleId: vehicleId),
        cursor: cursor,
        limit: 200,
      );
      items.addAll(result.items);
      if (!result.hasMore || result.nextCursor == null) {
        break;
      }
      cursor = result.nextCursor;
    }
    return items;
  }
}
