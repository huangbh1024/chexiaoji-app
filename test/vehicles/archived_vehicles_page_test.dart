import 'package:chexiaoji_app/app/theme/app_theme.dart';
import 'package:chexiaoji_app/features/home/data/mock_home_repository.dart';
import 'package:chexiaoji_app/features/ledger/data/mock_ledger_repository.dart';
import 'package:chexiaoji_app/features/vehicles/data/mock_vehicle_repository.dart';
import 'package:chexiaoji_app/features/vehicles/data/vehicle_seed_data.dart';
import 'package:chexiaoji_app/features/vehicles/data/vehicle_store.dart';
import 'package:chexiaoji_app/features/vehicles/data/vehicle_store_provider.dart';
import 'package:chexiaoji_app/features/vehicles/domain/providers.dart';
import 'package:chexiaoji_app/features/vehicles/presentation/archived_vehicles_page.dart';
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
        home: const ArchivedVehiclesPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return vehicleStore;
}

void main() {
  testWidgets('渲染封存列表、三指标与归档日期', (tester) async {
    final store = seededVehicleStore(now: _now);
    store.archive('toyota-camry-hev', at: _now);
    await _pumpPage(tester, store: store);

    expect(find.text('已归档车辆'), findsOneWidget);
    expect(find.text('封存座驾列表'), findsOneWidget);
    expect(find.text('丰田 凯美瑞 双擎'), findsOneWidget);
    expect(find.text('封存总里程'), findsOneWidget);
    expect(find.text('累计记账花费'), findsOneWidget);
    expect(find.text('历史综合油耗'), findsOneWidget);
    expect(find.text('今日封存'), findsOneWidget);
    expect(find.textContaining('归档于 2026年11月15日'), findsOneWidget);
    expect(find.textContaining('云端'), findsNothing);
  });

  testWidgets('空归档显示空态', (tester) async {
    await _pumpPage(tester);

    expect(find.text('车库档案箱空空如也'), findsOneWidget);
    expect(find.text('返回常用车库'), findsOneWidget);
    expect(find.text('封存座驾列表'), findsNothing);
  });

  testWidgets('彻底删除必须同时输入尾号并勾选知情', (tester) async {
    final store = seededVehicleStore(now: _now);
    store.archive('toyota-camry-hev', at: _now);
    await _pumpPage(tester, store: store);

    final purgeEntry = find.text('彻底删除');
    await tester.ensureVisible(purgeEntry);
    await tester.tap(purgeEntry);
    await tester.pumpAndSettle();

    expect(find.text('彻底删除车辆档案？'), findsOneWidget);
    expect(find.textContaining('7Q315'), findsAtLeastNWidgets(1));

    FilledButton dangerButton() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '彻底销毁座驾档案'),
    );

    expect(dangerButton().onPressed, isNull);

    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '7Q315');
    await tester.pumpAndSettle();
    expect(dangerButton().onPressed, isNull);

    final acknowledge = find.textContaining('我已了解该车辆档案将被永久删除');
    await tester.ensureVisible(acknowledge);
    await tester.tap(acknowledge);
    await tester.pumpAndSettle();
    expect(dangerButton().onPressed, isNotNull);

    final dangerAction = find.text('彻底销毁座驾档案');
    await tester.ensureVisible(dangerAction);
    await tester.tap(dangerAction);
    await tester.pumpAndSettle();

    expect(find.text('已彻底删除「丰田 凯美瑞 双擎」的车辆档案'), findsOneWidget);
    expect(store.archived, isEmpty);
    expect(find.text('车库档案箱空空如也'), findsOneWidget);
  });

  testWidgets('尾号错误时危险按钮保持禁用', (tester) async {
    final store = seededVehicleStore(now: _now);
    store.archive('toyota-camry-hev', at: _now);
    await _pumpPage(tester, store: store);

    final purgeEntry = find.text('彻底删除');
    await tester.ensureVisible(purgeEntry);
    await tester.tap(purgeEntry);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '00000');
    final acknowledge = find.textContaining('我已了解该车辆档案将被永久删除');
    await tester.ensureVisible(acknowledge);
    await tester.tap(acknowledge);
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '彻底销毁座驾档案'),
    );
    expect(button.onPressed, isNull);
    expect(store.archived, hasLength(1));
  });

  testWidgets('恢复弹层说明改为默认主驾并完成恢复', (tester) async {
    final store = seededVehicleStore(now: _now);
    for (final record in store.active.toList()) {
      store.archive(record.id, at: _now);
    }
    await _pumpPage(tester, store: store);

    final restore = find.text('恢复至车库').first;
    await tester.ensureVisible(restore);
    await tester.tap(restore);
    await tester.pumpAndSettle();
    expect(find.textContaining('恢复后该车将成为默认主驾'), findsOneWidget);

    await tester.tap(find.text('确认恢复'));
    await tester.pumpAndSettle();

    expect(store.archived.length, 3);
    expect(store.primaryVehicleId, isNotNull);
  });
}
