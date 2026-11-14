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

  testWidgets('底部导航可以切换到占位页', (tester) async {
    await _pumpHome(tester);

    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    expect(find.text('页面待接入'), findsOneWidget);
  });
}
