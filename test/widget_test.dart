import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:chexiaoji_app/app/app.dart';

Future<void> _pumpHome(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(const ProviderScope(child: CheXiaoJiApp()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('首页静态骨架展示默认车辆数据', (tester) async {
    await _pumpHome(tester);

    expect(find.text('车小记'), findsOneWidget);
    expect(find.text('我的车辆'), findsOneWidget);
    expect(find.text('比亚迪 汉 EV'), findsOneWidget);
    expect(find.textContaining('0.60', findRichText: true), findsOneWidget);
    expect(find.text('14.8'), findsOneWidget);
    expect(find.text('1,574'), findsOneWidget);
    expect(find.text('花费趋势'), findsOneWidget);
  });

  testWidgets('切换到插电混动车辆后展示双能耗', (tester) async {
    await _pumpHome(tester);

    final target = find.text('宋PLUS DM-i');
    await tester.dragUntilVisible(
      target,
      find.byKey(const Key('vehicle-list')),
      const Offset(-120, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();

    expect(find.textContaining('0.45', findRichText: true), findsOneWidget);
    expect(find.text('12.5'), findsOneWidget);
    expect(find.text('2.8'), findsOneWidget);
    expect(find.text('综合能耗'), findsOneWidget);
  });

  testWidgets('燃油车保养进入警示态', (tester) async {
    await _pumpHome(tester);

    final target = find.text('宝马 3系 325Li');
    await tester.dragUntilVisible(
      target,
      find.byKey(const Key('vehicle-list')),
      const Offset(-120, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();

    expect(find.text('8.6'), findsOneWidget);
    expect(find.text('综合油耗'), findsOneWidget);
    expect(find.textContaining('即将保养', findRichText: true), findsOneWidget);
  });

  testWidgets('深色按钮切换主题图标', (tester) async {
    await _pumpHome(tester);

    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.dark_mode_rounded));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
  });

  testWidgets('底部导航可以切换到统计页', (tester) async {
    await _pumpHome(tester);

    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    expect(find.text('数据统计'), findsOneWidget);
    expect(find.textContaining('综合每公里成本'), findsOneWidget);
    expect(find.text('花费趋势与开销走势'), findsOneWidget);
  });

  testWidgets('充电记录副指标显示充电单价', (tester) async {
    await _pumpHome(tester);

    await tester.dragUntilVisible(
      find.text('最近记录'),
      find.byType(CustomScrollView),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -260));
    await tester.pumpAndSettle();

    expect(find.textContaining('/kWh'), findsWidgets);
    expect(find.text('¥0.17/km'), findsNothing);
  });

  testWidgets('首页最近记录点击进入详情', (tester) async {
    await _pumpHome(tester);

    await tester.dragUntilVisible(
      find.text('最近记录'),
      find.byType(CustomScrollView),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -260));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('recent-record-first')));
    await tester.pumpAndSettle();

    expect(find.text('开销详情'), findsOneWidget);
    expect(find.text('结算明细'), findsOneWidget);
  });

  testWidgets('底部账单/统计与中央 FAB 保持设计间距', (tester) async {
    await _pumpHome(tester);

    final ledger = tester.getCenter(find.text('账单'));
    final stats = tester.getCenter(find.text('统计'));
    final fab = tester.getCenter(find.byKey(const Key('quick-add-fab')));

    expect(fab.dx - ledger.dx, closeTo(81, 3));
    expect(stats.dx - fab.dx, closeTo(81, 3));
  });

  testWidgets('账单页展示月度汇总、筛选与流水', (tester) async {
    await _pumpHome(tester);

    await tester.tap(find.text('账单'));
    await tester.pumpAndSettle();

    expect(find.text('账单明细'), findsOneWidget);
    expect(find.text('能源电油'), findsOneWidget);
    expect(find.text('维保服务'), findsOneWidget);
    expect(find.text('日均开支'), findsOneWidget);
    expect(find.textContaining('全部车辆'), findsOneWidget);
    expect(find.text('全部类型'), findsOneWidget);
    expect(find.textContaining('共 '), findsWidgets);
  });

  testWidgets('账单页分类筛选展示结果提示条并可清除', (tester) async {
    await _pumpHome(tester);

    await tester.tap(find.text('账单'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('保养'));
    await tester.pumpAndSettle();

    expect(find.textContaining('已筛选：保养'), findsOneWidget);

    await tester.tap(find.text('清除'));
    await tester.pumpAndSettle();

    expect(find.textContaining('已筛选：保养'), findsNothing);
  });

  testWidgets('账单页可打开月份选择器', (tester) async {
    await _pumpHome(tester);

    await tester.tap(find.text('账单'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.expand_more_rounded));
    await tester.pumpAndSettle();

    expect(find.text('选择月份'), findsOneWidget);
    expect(find.text('确定'), findsOneWidget);
  });
}
