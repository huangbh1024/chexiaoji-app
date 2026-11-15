import 'package:chexiaoji_app/app/app.dart';
import 'package:chexiaoji_app/features/home/data/mock_home_repository.dart';
import 'package:chexiaoji_app/features/home/domain/home_models.dart';
import 'package:chexiaoji_app/features/ledger/data/mock_ledger_repository.dart';
import 'package:chexiaoji_app/features/vehicles/data/vehicle_seed_data.dart';
import 'package:chexiaoji_app/features/vehicles/data/vehicle_store.dart';
import 'package:chexiaoji_app/features/vehicles/data/vehicle_store_provider.dart';
import 'package:chexiaoji_app/features/vehicles/domain/vehicle_models.dart';
import 'package:chexiaoji_app/features/vehicles/domain/vehicle_presenter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

VehicleRecord _newRecord({int? nextMaintenanceKm}) {
  return VehicleRecord(
    vehicle: const Vehicle(
      id: 'new-ev',
      name: '测试新车',
      plate: '粤B·DF8932',
      powertrain: PowertrainType.ev,
      powertrainLabel: '纯电',
      odometerKm: 1000,
      batteryCapacityKwh: 60,
    ),
    specLabel: '',
    sortOrder: 4,
    nextMaintenanceKm: nextMaintenanceKm,
  );
}

void main() {
  _homeWidgetTests();
  late VehicleStore store;
  late MockHomeRepository home;

  setUp(() {
    store = seededVehicleStore(now: DateTime(2026, 11, 15));
    store.add(_newRecord());
    home = MockHomeRepository(
      ledger: MockLedgerRepository(delay: Duration.zero),
      store: store,
    );
  });

  test('新车辆 dashboard 返回空看板而不是抛错', () async {
    final dashboard = await home.fetchDashboard('new-ev');
    expect(dashboard.summary.monthSpendCents, 0);
    expect(dashboard.summary.monthMileageKm, 0);
    expect(dashboard.consumption.hasData, isFalse);
    expect(dashboard.maintenance.enabled, isFalse);
    expect(dashboard.maintenance.hasProgress, isFalse);

    final breakdown = await home.fetchBreakdown('new-ev');
    expect(breakdown.totalCents, 0);
    expect(breakdown.categories, isEmpty);

    final records = await home.fetchRecords('new-ev');
    expect(records, isEmpty);

    final trend = await home.fetchTrend('new-ev', TrendRange.d30);
    expect(trend.points, isEmpty);
    expect(trend.totalCents, 0);
  });

  test('新车辆三指标显示未录入，不显示 0 能耗', () async {
    final record = store.byId('new-ev')!;
    final dashboard = await home.fetchDashboard('new-ev');
    final managed = ManagedVehicle(
      vehicle: record.vehicle,
      specLabel: record.specLabel,
      sortOrder: record.sortOrder,
      isPrimary: false,
      monthSpendCents: 0,
      recordCount: 0,
      consumption: dashboard.consumption,
      maintenance: dashboard.maintenance,
    );
    final metrics = VehiclePresenter.metricsOf(managed);
    expect(metrics[1].missing, isTrue);
    expect(metrics[1].value, '—');
    expect(metrics[1].unit, '未录入');
  });

  test('下次保养里程覆盖提醒；无保养流水不显示进度环', () async {
    store.update('new-ev', _newRecord(nextMaintenanceKm: 1500));
    final dashboard = await home.fetchDashboard('new-ev');
    expect(dashboard.maintenance.enabled, isTrue);
    expect(dashboard.maintenance.remainingKm, 500);
    expect(dashboard.maintenance.status, MaintenanceStatus.warning);
    expect(dashboard.maintenance.hasProgress, isFalse);
  });
}

void _homeWidgetTests() {
  testWidgets('新车辆首页显示暂无能耗与保养提醒，不崩溃', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = seededVehicleStore(now: DateTime(2026, 11, 15));
    store.add(_newRecord());
    store.setPrimary('new-ev');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [vehicleStoreProvider.overrideWithValue(store)],
        child: const CheXiaoJiApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('暂无能耗记录'), findsOneWidget);
    expect(find.text('设置保养提醒'), findsOneWidget);
  });
}
