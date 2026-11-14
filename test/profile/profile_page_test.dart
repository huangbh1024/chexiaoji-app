import 'package:chexiaoji_app/app/app.dart';
import 'package:chexiaoji_app/features/profile/domain/profile_models.dart';
import 'package:chexiaoji_app/features/profile/domain/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pumpProfile(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(const ProviderScope(child: CheXiaoJiApp()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('我的'));
  await tester.pumpAndSettle();
}

Future<void> _pumpFailingProfile(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileOverviewProvider.overrideWith(
          (ref) => Future<ProfileOverview>.error(Exception('fail')),
        ),
      ],
      child: const CheXiaoJiApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('我的'));
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.dragUntilVisible(
    target,
    find.byKey(const Key('profile-scroll')),
    const Offset(0, -260),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('我的页展示资料、车库、工具与设置', (tester) async {
    await _pumpProfile(tester);

    expect(find.text('记账天数'), findsOneWidget);
    expect(find.text('累计记录'), findsOneWidget);
    expect(find.text('关联车辆'), findsOneWidget);
    expect(find.text('车库资产与车辆'), findsOneWidget);
    expect(find.text('全部资产'), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const Key('garage-card')),
        matching: find.text('我的全部车辆'),
      ),
      findsOneWidget,
    );

    await _scrollTo(tester, find.text('车主核心工具箱'));

    expect(find.text('账单导出与报表'), findsOneWidget);
    expect(find.text('智能 OCR 票夹'), findsOneWidget);
    expect(find.text('云端数据同步'), findsOneWidget);
    expect(find.text('离线记账与缓存'), findsOneWidget);
    expect(find.text('即将上线'), findsWidgets);
    expect(find.text('本地数据'), findsOneWidget);
  });

  testWidgets('车库切换车辆后卡片联动，回到全部资产恢复汇总', (tester) async {
    await _pumpProfile(tester);

    await tester.tap(find.byKey(const Key('garage-pill-byd-han-ev')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('garage-card')),
        matching: find.text('比亚迪 汉 EV'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('garage-card')),
        matching: find.text('纯电'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('garage-pill-all')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('garage-card')),
        matching: find.text('我的全部车辆'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('报表工具打开月度报表页', (tester) async {
    await _pumpProfile(tester);
    await _scrollTo(tester, find.byKey(const Key('tool-report')));

    await tester.tap(find.byKey(const Key('tool-report')));
    await tester.pumpAndSettle();

    expect(find.text('月度报表与导出'), findsOneWidget);
  });

  testWidgets('未上线工具给出明确提示，不显示伪造数量', (tester) async {
    await _pumpProfile(tester);
    await _scrollTo(tester, find.byKey(const Key('tool-voucher')));

    await tester.tap(find.byKey(const Key('tool-voucher')));
    await tester.pump();

    expect(find.text('票夹功能即将上线'), findsOneWidget);
    expect(find.textContaining('已存'), findsNothing);
  });

  testWidgets('关于与隐私弹层内容与实现一致', (tester) async {
    await _pumpProfile(tester);
    await _scrollTo(tester, find.byKey(const Key('settings-about')));

    await tester.tap(find.byKey(const Key('settings-about')));
    await tester.pumpAndSettle();

    expect(find.text('常见问题'), findsOneWidget);
    expect(find.text('意见反馈'), findsOneWidget);
    expect(find.text('v1.0.0'), findsWidgets);

    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-privacy')));
    await tester.pumpAndSettle();

    expect(find.text('隐私与数据'), findsWidgets);
    expect(find.textContaining('端到端加密'), findsOneWidget);

    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
  });

  testWidgets('账号区显示掩码手机号，不展示退出与加密承诺', (tester) async {
    await _pumpProfile(tester);
    await _scrollTo(tester, find.byKey(const Key('profile-account-footer')));

    expect(find.textContaining('138 **** 9208'), findsOneWidget);
    expect(find.text('退出当前账号'), findsNothing);
    expect(find.textContaining('AES-256'), findsNothing);
    expect(find.textContaining('安全保护'), findsNothing);
  });

  testWidgets('资料加载失败时展示模块级错误，车库仍可用', (tester) async {
    await _pumpFailingProfile(tester);

    expect(find.text('资料加载失败'), findsOneWidget);
    expect(find.byKey(const Key('garage-card')), findsOneWidget);
    expect(find.text('车库资产与车辆'), findsOneWidget);
  });
}
