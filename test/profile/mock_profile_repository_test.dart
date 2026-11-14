import 'package:chexiaoji_app/features/home/data/mock_home_repository.dart';
import 'package:chexiaoji_app/features/ledger/data/mock_ledger_repository.dart';
import 'package:chexiaoji_app/features/ledger/domain/ledger_models.dart';
import 'package:chexiaoji_app/features/profile/data/mock_profile_repository.dart';
import 'package:chexiaoji_app/features/profile/domain/profile_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockLedgerRepository ledger;
  late MockHomeRepository home;
  late MockProfileRepository profile;

  setUp(() {
    ledger = MockLedgerRepository(delay: Duration.zero);
    home = MockHomeRepository(ledger: ledger);
    profile = MockProfileRepository(
      home: home,
      ledger: ledger,
      delay: Duration.zero,
    );
  });

  test('概览使用账本生命周期统计', () async {
    final overview = await profile.fetchOverview();
    final lifetime = await ledger.fetchLifetimeStats();

    expect(overview.user.nickname, '林漪');
    expect(overview.user.verifiedOwner, isTrue);
    expect(overview.user.phoneMasked, '138 **** 9208');
    expect(overview.stats.recordCount, lifetime.recordCount);
    expect(overview.stats.recordCount, greaterThan(0));
    expect(overview.stats.firstRecordAt, lifetime.firstRecordAt);
    expect(overview.stats.accountDays, greaterThan(0));
  });

  test('全部资产能耗金额与账单同月汇总一致', () async {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    final summary = await ledger.fetchSummary(LedgerScope(month: month));
    final garage = await profile.fetchGarage();

    final odometer = garage.vehicles.fold<int>(
      0,
      (sum, vehicle) => sum + vehicle.odometerKm,
    );

    expect(garage.vehicles, hasLength(4));
    expect(garage.snapshot.vehicleId, isNull);
    expect(garage.snapshot.monthEnergy.amountCents, summary.energyCents);
    expect(garage.snapshot.odometerKm, odometer);
    expect(garage.snapshot.monthEnergy.kwh, isNull);
    expect(garage.snapshot.monthEnergy.liters, isNull);
    expect(garage.snapshot.subtitle, contains('纯电'));
  });

  test('单车能耗金额与账单同车汇总一致', () async {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    const vehicleId = 'byd-han-ev';
    final summary = await ledger.fetchSummary(
      LedgerScope(month: month, vehicleId: vehicleId),
    );
    final garage = await profile.fetchGarage(vehicleId: vehicleId);

    expect(garage.snapshot.vehicleId, vehicleId);
    expect(garage.snapshot.badge, '纯电');
    expect(garage.snapshot.monthEnergy.amountCents, summary.energyCents);
    expect(garage.snapshot.monthEnergy.kwh, isNotNull);
    expect(garage.snapshot.monthEnergy.liters, isNull);
  });

  test('未知车辆回退全部资产，不抛异常', () async {
    final garage = await profile.fetchGarage(vehicleId: 'missing-vehicle');
    expect(garage.snapshot.vehicleId, isNull);
    expect(garage.snapshot.title, '我的全部车辆');
  });

  test('工具状态不提供伪造数量', () async {
    final services = await profile.fetchServices();
    expect(services.report.available, isTrue);
    expect(services.voucher.available, isFalse);
    expect(services.voucher.count, isNull);
    expect(services.sync.available, isFalse);
    expect(services.sync.state, SyncState.local);
    expect(services.offline.available, isFalse);
    expect(services.offline.pendingCount, isNull);
  });

  test('偏好默认公制与人民币', () async {
    final preferences = await profile.fetchPreferences();
    expect(preferences.unitSystem, UnitSystem.metric);
    expect(preferences.currency, CurrencyCode.cny);
    expect(preferences.notificationsEnabled, isFalse);
  });
}
