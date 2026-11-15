import 'package:chexiaoji_app/app/theme/app_theme.dart';
import 'package:chexiaoji_app/features/home/data/mock_home_repository.dart';
import 'package:chexiaoji_app/features/ledger/data/mock_ledger_repository.dart';
import 'package:chexiaoji_app/features/vehicles/data/mock_vehicle_repository.dart';
import 'package:chexiaoji_app/features/vehicles/data/vehicle_seed_data.dart';
import 'package:chexiaoji_app/features/vehicles/data/vehicle_store.dart';
import 'package:chexiaoji_app/features/vehicles/data/vehicle_store_provider.dart';
import 'package:chexiaoji_app/features/vehicles/domain/providers.dart';
import 'package:chexiaoji_app/features/vehicles/presentation/vehicle_management_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 15);

Future<VehicleStore> _pumpPage(
  WidgetTester tester, {
  VehicleStore? store,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final vehicleStore = store ?? seededVehicleStore(now: _now);
  final ledger = MockLedgerRepository(delay: Duration.zero);
  final home = MockHomeRepository(ledger: ledger, store: vehicleStore);
  final repository = MockVehicleRepository(
    store: vehicleStore,
    home: home,
    ledger: ledger,
    now: () => _now,
    delay: Duration.zero,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vehicleStoreProvider.overrideWithValue(vehicleStore),
        vehicleRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const VehicleManagementPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return vehicleStore;
}

Finder _card(String id) => find.byKey(ValueKey<String>(id));

void main() {
  testWidgets('渲染车库总览与四辆车辆，默认主驾置顶', (tester) async {
    await _pumpPage(tester);

    expect(find.text('车辆管理'), findsOneWidget);
    expect(find.text('车库资产总览'), findsOneWidget);
    expect(find.text('共 4 辆'), findsOneWidget);
    expect(find.text('比亚迪 汉 EV'), findsOneWidget);
    expect(find.text('丰田 凯美瑞 双擎'), findsOneWidget);
    expect(find.text('默认主座驾'), findsOneWidget);
    expect(find.text('1 项待处理'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('添加新座驾到车库'), 300);
    expect(find.text('添加新座驾到车库'), findsOneWidget);
  });

  testWidgets('设为主驾需要确认，确认后列表重排', (tester) async {
    final store = await _pumpPage(tester);
    final camry = _card('toyota-camry-hev');
    await tester.ensureVisible(camry);
    await tester.tap(find.descendant(of: camry, matching: find.text('设为主驾')));
    await tester.pumpAndSettle();

    expect(find.text('将 丰田 凯美瑞 双擎 设为默认主驾？'), findsOneWidget);

    await tester.tap(find.text('确认设为主驾'));
    await tester.pumpAndSettle();

    expect(find.text('已将 丰田 凯美瑞 双擎 设为默认主驾'), findsOneWidget);
    expect(store.primaryVehicleId, 'toyota-camry-hev');
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 1200));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: _card('toyota-camry-hev'),
        matching: find.text('默认主座驾'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('有流水车辆删除被拦截并引导归档', (tester) async {
    await _pumpPage(tester);
    final camry = _card('toyota-camry-hev');
    await tester.ensureVisible(camry);
    await tester.tap(
      find.descendant(
        of: camry,
        matching: find.byIcon(Icons.more_vert_rounded),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除车辆'));
    await tester.pumpAndSettle();

    expect(find.text('该车辆有历史流水'), findsOneWidget);
    expect(find.text('去归档'), findsOneWidget);
  });

  testWidgets('归档车辆后移出列表并出现已归档入口', (tester) async {
    final store = await _pumpPage(tester);
    final camry = _card('toyota-camry-hev');
    await tester.ensureVisible(camry);
    await tester.tap(
      find.descendant(
        of: camry,
        matching: find.byIcon(Icons.more_vert_rounded),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('车辆归档'));
    await tester.pumpAndSettle();

    expect(find.text('归档「丰田 凯美瑞 双擎」？'), findsOneWidget);
    await tester.tap(find.text('确认归档'));
    await tester.pumpAndSettle();

    expect(find.text('已将「丰田 凯美瑞 双擎」归档'), findsOneWidget);
    expect(store.active.length, 3);
    expect(store.archived.single.id, 'toyota-camry-hev');
    expect(
      find.byKey(const ValueKey<String>('toyota-camry-hev')),
      findsNothing,
    );

    await tester.scrollUntilVisible(find.text('已归档车辆'), 300);
    expect(find.text('已归档车辆'), findsOneWidget);
  });

  testWidgets('空车库显示空态与添加入口', (tester) async {
    final store = seededVehicleStore(now: _now);
    for (final record in store.active.toList()) {
      store.archive(record.id, at: _now);
    }
    await _pumpPage(tester, store: store);

    expect(find.text('车库还是空的'), findsOneWidget);
    expect(find.text('添加第一辆爱车'), findsOneWidget);
    expect(find.text('共 0 辆'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('已归档车辆'), 300);
    expect(find.text('已归档车辆'), findsOneWidget);
  });

  testWidgets('已归档车辆可以恢复', (tester) async {
    final store = seededVehicleStore(now: _now);
    store.archive('toyota-camry-hev', at: _now);
    await _pumpPage(tester, store: store);

    await tester.scrollUntilVisible(find.text('已归档车辆'), 300);
    await tester.tap(find.text('已归档车辆'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复'));
    await tester.pumpAndSettle();

    expect(find.text('已恢复到车库'), findsOneWidget);
    expect(store.active.length, 4);
    expect(store.archived, isEmpty);
  });
}
