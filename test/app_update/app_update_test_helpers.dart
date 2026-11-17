import 'dart:io';

import 'package:chexiaoji_app/features/app_update/data/app_update_installer.dart';
import 'package:chexiaoji_app/features/app_update/data/app_update_repository.dart';
import 'package:chexiaoji_app/features/app_update/domain/app_update_models.dart';

AppUpdateManifest updateManifest({
  String version = '1.1.0',
  int buildNumber = 2,
  String apkUrl = 'https://example.com/chexiaoji.apk',
  String sha256 =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  int? sizeBytes = 12 * 1024 * 1024,
  String? changelog = '修复若干问题\n优化记账体验',
  bool force = false,
  String? minSupportedVersion,
  DateTime? publishedAt,
}) {
  return AppUpdateManifest(
    version: version,
    buildNumber: buildNumber,
    apkUrl: apkUrl,
    sha256: sha256,
    sizeBytes: sizeBytes,
    changelog: changelog,
    force: force,
    minSupportedVersion: minSupportedVersion,
    publishedAt: publishedAt,
  );
}

class FakeAppUpdateRepository implements AppUpdateRepository {
  FakeAppUpdateRepository({this.manifest, this.fetchError, this.downloadError});

  AppUpdateManifest? manifest;
  Object? fetchError;
  Object? downloadError;
  int fetchCount = 0;
  int downloadCount = 0;
  final File file = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}'
    'chexiaoji-fake-update.apk',
  );

  @override
  Future<AppUpdateManifest?> fetchManifest() async {
    fetchCount++;
    if (fetchError != null) {
      throw fetchError!;
    }
    return manifest;
  }

  @override
  Future<File> downloadApk({
    required AppUpdateManifest manifest,
    void Function(int received, int? total)? onProgress,
  }) async {
    downloadCount++;
    onProgress?.call(50, 100);
    onProgress?.call(100, 100);
    if (downloadError != null) {
      throw downloadError!;
    }
    return file;
  }
}

class FakeAppUpdateInstaller implements AppUpdateInstaller {
  FakeAppUpdateInstaller({
    this.version = const InstalledAppVersion(name: '1.0.0', build: 1),
    this.installStatus = AppInstallStatus.started,
    this.versionError,
  });

  InstalledAppVersion version;
  AppInstallStatus installStatus;
  Object? versionError;
  int installCount = 0;
  int settingsOpenCount = 0;
  String? lastPath;
  String? lastSha256;

  @override
  bool get isSupported => true;

  @override
  Future<InstalledAppVersion> getInstalledVersion() async {
    if (versionError != null) {
      throw versionError!;
    }
    return version;
  }

  @override
  Future<AppInstallResult> installApk({
    required String filePath,
    required String sha256,
  }) async {
    installCount++;
    lastPath = filePath;
    lastSha256 = sha256;
    return AppInstallResult(
      installStatus,
      message: installStatus == AppInstallStatus.permissionRequired
          ? '请允许车小记安装未知来源应用'
          : null,
    );
  }

  @override
  Future<void> openInstallPermissionSettings() async {
    settingsOpenCount++;
  }
}
