import 'package:chexiaoji_app/app/theme/app_theme.dart';
import 'package:chexiaoji_app/features/home/data/mock_home_repository.dart';
import 'package:chexiaoji_app/features/ledger/data/mock_ledger_repository.dart';
import 'package:chexiaoji_app/features/ledger/domain/providers.dart';
import 'package:chexiaoji_app/features/vehicles/data/mock_vehicle_repository.dart';
import 'package:chexiaoji_app/features/vehicles/data/vehicle_seed_data.dart';
import 'package:chexiaoji_app/features/vehicles/data/vehicle_store.dart';
import 'package:chexiaoji_app/features/vehicles/data/vehicle_store_provider.dart';
import 'package:chexiaoji_app/features/vehicles/domain/providers.dart';
import 'package:chexiaoji_app/features/vehicles/presentation/vehicle_editor_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

final _now = DateTime(2026, 11, 15);

Future<VehicleStore> _pumpEditor(
  WidgetTester tester, {
  VehicleStore? store,
  String? vehicleId,
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
        ledgerRepositoryProvider.overrideWithValue(ledger),
        vehicleRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('open-editor'),
                onPressed: () =>
                    openVehicleEditor(context, vehicleId: vehicleId),
                child: const Text('打开编辑器'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open-editor')));
  await tester.pumpAndSettle();
  return vehicleStore;
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.dragUntilVisible(
    finder,
    find.byType(ListView).first,
    const Offset(0, -220),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('新增态渲染四类动力与三张表单卡', (tester) async {
    await _pumpEditor(tester);

    expect(find.text('添加爱车档案'), findsOneWidget);
    expect(find.text('保存并添加到车库'), findsOneWidget);
    expect(find.text('纯电 EV'), findsOneWidget);
    expect(find.text('插混·增程'), findsOneWidget);
    expect(find.text('油电混动'), findsOneWidget);
    expect(find.text('燃油 ICE'), findsOneWidget);
    expect(find.text('车辆身份信息'), findsOneWidget);
    expect(find.text('动力与能耗基准'), findsOneWidget);
    await _scrollTo(tester, find.text('周期提醒与偏好'));
    expect(find.text('周期提醒与偏好'), findsOneWidget);
    expect(find.text('归档此车辆'), findsNothing);
  });

  testWidgets('空表单保存提示必填错误', (tester) async {
    await _pumpEditor(tester);

    await tester.tap(find.text('保存并添加到车库'));
    await tester.pumpAndSettle();

    expect(find.text('请填写品牌与车型'), findsOneWidget);
    expect(find.text('请填写车牌号码'), findsOneWidget);
    expect(find.text('请填写当前总里程'), findsOneWidget);
  });

  testWidgets('切换动力类型展示对应规格字段', (tester) async {
    await _pumpEditor(tester);

    await tester.tap(find.text('插混·增程'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('动力与能耗基准'));
    expect(find.text('纯电续航 (WLTC)'), findsOneWidget);
    expect(find.text('动力电池容量'), findsOneWidget);
    expect(find.text('油箱容积'), findsOneWidget);
    expect(find.text('百公里亏电油耗'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, 700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('燃油 ICE'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('动力与能耗基准'));
    expect(find.text('标称综合油耗'), findsOneWidget);
    expect(find.text('动力电池容量'), findsNothing);
  });

  testWidgets('省份弹层选择后回填', (tester) async {
    await _pumpEditor(tester);
    await _scrollTo(tester, find.byKey(const Key('editor-plate')));
    await tester.tap(find.byKey(const Key('editor-province')));
    await tester.pumpAndSettle();

    expect(find.text('选择所属省份简称'), findsOneWidget);
    await tester.tap(find.text('京').last);
    await tester.pumpAndSettle();

    expect(find.text('选择所属省份简称'), findsNothing);
    expect(find.text('已选择车牌简称「京」'), findsOneWidget);
  });

  testWidgets('新增车辆保存后写回车库', (tester) async {
    final store = await _pumpEditor(tester);

    await tester.enterText(find.byKey(const Key('editor-name')), '测试新车');
    await tester.enterText(find.byKey(const Key('editor-plate')), 'BDF8932');
    await tester.enterText(find.byKey(const Key('editor-odometer')), '1000');
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存并添加到车库'));
    await tester.pumpAndSettle();

    expect(find.text('打开编辑器'), findsOneWidget);
    expect(store.active.length, 5);
    expect(store.active.any((record) => record.vehicle.name == '测试新车'), isTrue);
    expect(find.text('「测试新车」已添加到车库'), findsOneWidget);
  });

  testWidgets('编辑态回显档案，脏表单返回需确认', (tester) async {
    final store = await _pumpEditor(tester, vehicleId: 'byd-han-ev');

    expect(find.text('编辑爱车档案'), findsOneWidget);
    final nameField = tester.widget<TextField>(
      find.byKey(const Key('editor-name')),
    );
    expect(nameField.controller?.text, '比亚迪 汉 EV');

    await tester.enterText(find.byKey(const Key('editor-name')), '比亚迪 汉 EV 改');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    expect(find.text('放弃未保存的修改？'), findsOneWidget);
    await tester.tap(find.text('放弃修改'));
    await tester.pumpAndSettle();

    expect(find.text('打开编辑器'), findsOneWidget);
    expect(store.byId('byd-han-ev')!.vehicle.name, '比亚迪 汉 EV');
  });

  testWidgets('编辑页归档复用确认弹层', (tester) async {
    final store = await _pumpEditor(tester, vehicleId: 'byd-han-ev');

    await tester.tap(find.text('归档此车辆'));
    await tester.pumpAndSettle();
    expect(find.text('归档「比亚迪 汉 EV」？'), findsOneWidget);

    await tester.tap(find.text('确认归档'));
    await tester.pumpAndSettle();

    expect(store.archived.any((record) => record.id == 'byd-han-ev'), isTrue);
    expect(find.text('打开编辑器'), findsOneWidget);
    expect(find.text('已将「比亚迪 汉 EV」归档'), findsOneWidget);
  });
}
