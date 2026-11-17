import 'package:chexiaoji_app/features/app_update/data/app_update_installer.dart';
import 'package:chexiaoji_app/features/app_update/domain/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_update_test_helpers.dart';

void main() {
  late FakeAppUpdateRepository repository;
  late FakeAppUpdateInstaller installer;
  late ProviderContainer container;

  setUp(() {
    repository = FakeAppUpdateRepository();
    installer = FakeAppUpdateInstaller();
    container = ProviderContainer(
      overrides: [
        appUpdateRepositoryProvider.overrideWithValue(repository),
        appUpdateInstallerProvider.overrideWithValue(installer),
      ],
    );
  });

  tearDown(() => container.dispose());

  AppUpdateController controller() =>
      container.read(appUpdateControllerProvider.notifier);

  AppUpdateState state() => container.read(appUpdateControllerProvider);

  test('发现新版本', () async {
    repository.manifest = updateManifest();

    await controller().checkForUpdate();

    expect(state().phase, AppUpdatePhase.available);
    expect(state().current?.name, '1.0.0');
    expect(state().manifest?.version, '1.1.0');
    expect(repository.fetchCount, 1);
  });

  test('同版本只比较 versionCode', () async {
    repository.manifest = updateManifest(version: '1.0.0', buildNumber: 1);

    await controller().checkForUpdate();

    expect(state().phase, AppUpdatePhase.upToDate);
  });

  test('检查失败时展示可读错误', () async {
    repository.fetchError = const AppUpdateException('网络连接失败，请检查网络后重试');

    await controller().checkForUpdate();

    expect(state().phase, AppUpdatePhase.failed);
    expect(state().message, '网络连接失败，请检查网络后重试');
    expect(state().manifest, isNull);
  });

  test('下载后交给安装器并校验 sha256', () async {
    repository.manifest = updateManifest();
    await controller().checkForUpdate();

    await controller().downloadAndInstall();

    expect(state().phase, AppUpdatePhase.installStarted);
    expect(repository.downloadCount, 1);
    expect(installer.installCount, 1);
    expect(installer.lastSha256, repository.manifest?.sha256);
    expect(installer.lastPath, repository.file.path);
  });

  test('缺少未知来源权限时保留安装包，授权后不重复下载', () async {
    repository.manifest = updateManifest();
    installer.installStatus = AppInstallStatus.permissionRequired;
    await controller().checkForUpdate();

    await controller().downloadAndInstall();

    expect(state().phase, AppUpdatePhase.failed);
    expect(state().needsInstallPermission, isTrue);
    expect(state().filePath, repository.file.path);
    expect(repository.downloadCount, 1);

    installer.installStatus = AppInstallStatus.started;
    await controller().retryInstall();

    expect(state().phase, AppUpdatePhase.installStarted);
    expect(installer.installCount, 2);
    expect(repository.downloadCount, 1);
  });

  test('校验失败后重试会重新下载', () async {
    repository.manifest = updateManifest();
    installer.installStatus = AppInstallStatus.hashMismatch;
    await controller().checkForUpdate();
    await controller().downloadAndInstall();

    expect(state().phase, AppUpdatePhase.failed);
    expect(state().filePath, isNull);

    installer.installStatus = AppInstallStatus.started;
    await controller().retryInstall();

    expect(state().phase, AppUpdatePhase.installStarted);
    expect(repository.downloadCount, 2);
  });

  test('下载失败不进入安装阶段', () async {
    repository.manifest = updateManifest();
    repository.downloadError = const AppUpdateException('安装包下载不完整，请重试');
    await controller().checkForUpdate();

    await controller().downloadAndInstall();

    expect(state().phase, AppUpdatePhase.failed);
    expect(state().message, '安装包下载不完整，请重试');
    expect(installer.installCount, 0);
  });
}
