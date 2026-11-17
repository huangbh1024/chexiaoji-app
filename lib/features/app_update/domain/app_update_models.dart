import 'package:material_ui/material_ui.dart';

/// 更新相关错误：`message` 直接面向用户。
class AppUpdateException implements Exception {
  const AppUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 当前安装版本：versionName + versionCode。
@immutable
class InstalledAppVersion {
  const InstalledAppVersion({required this.name, required this.build});

  final String name;
  final int build;

  @override
  String toString() => '$name+$build';
}

/// 比较点分版本号；缺失段按 0 处理。
///
/// 例如 `1.2` 与 `1.2.0` 相等；`1.10.0` 大于 `1.9.9`。
int compareAppVersions(String a, String b) {
  final partsA = a.split('.');
  final partsB = b.split('.');
  final length = partsA.length > partsB.length ? partsA.length : partsB.length;
  for (var i = 0; i < length; i++) {
    final valueA = int.tryParse(i < partsA.length ? partsA[i] : '0') ?? 0;
    final valueB = int.tryParse(i < partsB.length ? partsB[i] : '0') ?? 0;
    if (valueA != valueB) {
      return valueA.compareTo(valueB);
    }
  }
  return 0;
}

final RegExp _versionPattern = RegExp(r'^\d+(\.\d+){0,3}$');
final RegExp _sha256Pattern = RegExp(r'^[a-fA-F0-9]{64}$');

/// 服务端下发的全量更新清单。
///
/// 字段定义见 `docs/technical/app-update.md`；客户端只信任 HTTPS 源，
/// 安装前还会在 Android 侧重新计算 SHA-256。
@immutable
class AppUpdateManifest {
  const AppUpdateManifest({
    required this.version,
    required this.buildNumber,
    required this.apkUrl,
    required this.sha256,
    this.sizeBytes,
    this.changelog,
    this.force = false,
    this.publishedAt,
    this.minSupportedVersion,
  });

  factory AppUpdateManifest.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    if (version is! String || !_versionPattern.hasMatch(version)) {
      throw const FormatException('version 字段缺失或格式错误');
    }

    final buildNumber = json['buildNumber'];
    if (buildNumber is! int || buildNumber < 0) {
      throw const FormatException('buildNumber 字段缺失或格式错误');
    }

    final apkUrl = json['apkUrl'];
    final parsedUrl = apkUrl is String ? Uri.tryParse(apkUrl) : null;
    if (apkUrl is! String ||
        parsedUrl == null ||
        !parsedUrl.hasScheme ||
        parsedUrl.host.isEmpty) {
      throw const FormatException('apkUrl 字段缺失或格式错误');
    }

    final sha256 = json['sha256'];
    if (sha256 is! String || !_sha256Pattern.hasMatch(sha256)) {
      throw const FormatException('sha256 字段缺失或格式错误');
    }

    final sizeBytes = json['sizeBytes'];
    if (sizeBytes != null && (sizeBytes is! int || sizeBytes <= 0)) {
      throw const FormatException('sizeBytes 字段格式错误');
    }

    final changelog = json['changelog'];
    if (changelog != null && changelog is! String) {
      throw const FormatException('changelog 字段格式错误');
    }

    final force = json['force'] ?? false;
    if (force is! bool) {
      throw const FormatException('force 字段格式错误');
    }

    final minSupportedVersion = json['minSupportedVersion'];
    if (minSupportedVersion != null &&
        (minSupportedVersion is! String ||
            !_versionPattern.hasMatch(minSupportedVersion))) {
      throw const FormatException('minSupportedVersion 字段格式错误');
    }

    final publishedAtRaw = json['publishedAt'];
    DateTime? publishedAt;
    if (publishedAtRaw is String && publishedAtRaw.isNotEmpty) {
      publishedAt = DateTime.tryParse(publishedAtRaw);
      if (publishedAt == null) {
        throw const FormatException('publishedAt 字段格式错误');
      }
    }

    return AppUpdateManifest(
      version: version,
      buildNumber: buildNumber,
      apkUrl: apkUrl,
      sha256: sha256.toLowerCase(),
      sizeBytes: sizeBytes as int?,
      changelog: changelog as String?,
      force: force,
      publishedAt: publishedAt,
      minSupportedVersion: minSupportedVersion as String?,
    );
  }

  final String version;
  final int buildNumber;
  final String apkUrl;
  final String sha256;
  final int? sizeBytes;
  final String? changelog;

  /// 为 true 时用户不能跳过本次更新。
  final bool force;

  final DateTime? publishedAt;

  /// 低于该版本时也必须更新；与 [force] 二选一或同时使用。
  final String? minSupportedVersion;

  bool isNewerThan(InstalledAppVersion current) {
    final compared = compareAppVersions(version, current.name);
    return compared > 0 || (compared == 0 && buildNumber > current.build);
  }

  bool isBlocking(InstalledAppVersion current) {
    if (force) {
      return true;
    }
    final minimum = minSupportedVersion;
    return minimum != null && compareAppVersions(current.name, minimum) < 0;
  }
}

enum AppUpdatePhase {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  installing,
  installStarted,
  failed,
}

/// 更新流程状态。UI 只读该对象，所有网络与安装操作由 controller 驱动。
@immutable
class AppUpdateState {
  const AppUpdateState._({
    required this.phase,
    this.current,
    this.manifest,
    this.progress,
    this.message,
    this.filePath,
    this.needsInstallPermission = false,
  });

  const AppUpdateState.idle({InstalledAppVersion? current})
    : this._(phase: AppUpdatePhase.idle, current: current);

  const AppUpdateState.checking({InstalledAppVersion? current})
    : this._(phase: AppUpdatePhase.checking, current: current);

  const AppUpdateState.upToDate({required InstalledAppVersion current})
    : this._(phase: AppUpdatePhase.upToDate, current: current);

  const AppUpdateState.available({
    required InstalledAppVersion current,
    required AppUpdateManifest manifest,
  }) : this._(
         phase: AppUpdatePhase.available,
         current: current,
         manifest: manifest,
       );

  const AppUpdateState.downloading({
    required InstalledAppVersion current,
    required AppUpdateManifest manifest,
    double? progress,
  }) : this._(
         phase: AppUpdatePhase.downloading,
         current: current,
         manifest: manifest,
         progress: progress,
       );

  const AppUpdateState.installing({
    required InstalledAppVersion current,
    required AppUpdateManifest manifest,
    required String filePath,
  }) : this._(
         phase: AppUpdatePhase.installing,
         current: current,
         manifest: manifest,
         filePath: filePath,
       );

  const AppUpdateState.installStarted({
    required InstalledAppVersion current,
    required AppUpdateManifest manifest,
  }) : this._(
         phase: AppUpdatePhase.installStarted,
         current: current,
         manifest: manifest,
       );

  const AppUpdateState.failed({
    InstalledAppVersion? current,
    AppUpdateManifest? manifest,
    required String message,
    String? filePath,
    bool needsInstallPermission = false,
  }) : this._(
         phase: AppUpdatePhase.failed,
         current: current,
         manifest: manifest,
         message: message,
         filePath: filePath,
         needsInstallPermission: needsInstallPermission,
       );

  final AppUpdatePhase phase;
  final InstalledAppVersion? current;
  final AppUpdateManifest? manifest;

  /// 0.0–1.0；null 表示总大小未知。
  final double? progress;

  final String? message;

  /// 已下载的安装包路径；用于权限失败后直接重试安装，避免重复下载。
  final String? filePath;

  final bool needsInstallPermission;

  bool get isBusy =>
      phase == AppUpdatePhase.checking ||
      phase == AppUpdatePhase.downloading ||
      phase == AppUpdatePhase.installing;
}
