import 'package:chexiaoji_app/app/app.dart';
import 'package:chexiaoji_app/features/app_update/domain/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'app_update_test_helpers.dart';

Future<void> _pumpProfile(
  WidgetTester tester, {
  required FakeAppUpdateRepository repository,
  required FakeAppUpdateInstaller installer,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appUpdateManifestUrlProvider.overrideWithValue(
          'https://example.com/update.json',
        ),
        appUpdateRepositoryProvider.overrideWithValue(repository),
        appUpdateInstallerProvider.overrideWithValue(installer),
      ],
      child: const CheXiaoJiApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('我的'));
  await tester.pumpAndSettle();

  await tester.dragUntilVisible(
    find.byKey(const Key('settings-about')),
    find.byKey(const Key('profile-scroll')),
    const Offset(0, -260),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('settings-about')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('关于页检查更新并打开新版本浮层', (tester) async {
    final repository = FakeAppUpdateRepository()..manifest = updateManifest();
    final installer = FakeAppUpdateInstaller();
    await _pumpProfile(tester, repository: repository, installer: installer);

    expect(find.byKey(const Key('settings-check-update')), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-check-update')));
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.textContaining('v1.1.0'), findsWidgets);
    expect(find.text('更新内容'), findsOneWidget);
    expect(find.text('立即更新'), findsOneWidget);

    await tester.tap(find.byKey(const Key('update-install')));
    await tester.pumpAndSettle();

    expect(find.text('已打开系统安装界面'), findsOneWidget);
    expect(repository.downloadCount, 1);
    expect(installer.installCount, 1);
  });

  testWidgets('未配置更新源时不显示检查更新入口', (tester) async {
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
    await tester.dragUntilVisible(
      find.byKey(const Key('settings-about')),
      find.byKey(const Key('profile-scroll')),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-about')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-check-update')), findsNothing);
  });
}
