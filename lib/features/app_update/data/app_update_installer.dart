import 'dart:io' as io;

import 'package:flutter/services.dart';

import '../../../core/domain/app_info.dart';
import '../domain/app_update_models.dart';

enum AppInstallStatus {
  started,
  permissionRequired,
  unsupported,
  hashMismatch,
  failed,
}

class AppInstallResult {
  const AppInstallResult(this.status, {this.message});

  final AppInstallStatus status;
  final String? message;
}

/// 版本读取与安装器桥接。
abstract class AppUpdateInstaller {
  bool get isSupported;

  Future<InstalledAppVersion> getInstalledVersion();

  Future<AppInstallResult> installApk({
    required String filePath,
    required String sha256,
  });

  Future<void> openInstallPermissionSettings();
}

/// Android 原生实现：`MainActivity.kt` 中同名 MethodChannel。
///
/// 原生侧负责：
/// - 读取 versionName / versionCode；
/// - 校验文件位于缓存目录内；
/// - 计算 SHA-256 并比对；
/// - 通过 FileProvider + ACTION_VIEW 打开系统安装器。
class MethodChannelAppUpdateInstaller implements AppUpdateInstaller {
  const MethodChannelAppUpdateInstaller();

  static const MethodChannel _channel = MethodChannel('chexiaoji/app_update');

  @override
  bool get isSupported => io.Platform.isAndroid;

  @override
  Future<InstalledAppVersion> getInstalledVersion() async {
    if (!isSupported) {
      return const InstalledAppVersion(name: AppInfo.version, build: 0);
    }
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getInstalledVersion',
      );
      final name = result?['versionName'];
      final build = result?['versionCode'];
      return InstalledAppVersion(
        name: name is String && name.isNotEmpty ? name : AppInfo.version,
        build: build is num ? build.toInt() : 0,
      );
    } on MissingPluginException {
      return const InstalledAppVersion(name: AppInfo.version, build: 0);
    } on PlatformException {
      throw const AppUpdateException('读取当前版本失败，请稍后重试');
    }
  }

  @override
  Future<AppInstallResult> installApk({
    required String filePath,
    required String sha256,
  }) async {
    if (!isSupported) {
      return const AppInstallResult(
        AppInstallStatus.unsupported,
        message: '当前平台暂不支持应用内更新',
      );
    }
    try {
      final status = await _channel.invokeMethod<String>('installApk', {
        'path': filePath,
        'sha256': sha256,
      });
      return switch (status) {
        'started' => const AppInstallResult(AppInstallStatus.started),
        'permission_required' => const AppInstallResult(
          AppInstallStatus.permissionRequired,
          message: '请允许车小记安装未知来源应用',
        ),
        _ => const AppInstallResult(
          AppInstallStatus.failed,
          message: '安装失败，请重试',
        ),
      };
    } on PlatformException catch (error) {
      if (error.code == 'hash_mismatch' ||
          error.code == 'hash_failed' ||
          error.code == 'missing_file' ||
          error.code == 'invalid_path') {
        return AppInstallResult(
          AppInstallStatus.hashMismatch,
          message: error.message ?? '安装包不可用，请重新下载',
        );
      }
      return AppInstallResult(
        AppInstallStatus.failed,
        message: error.message ?? '安装失败，请重试',
      );
    } on MissingPluginException {
      return const AppInstallResult(
        AppInstallStatus.unsupported,
        message: '当前平台暂不支持应用内更新',
      );
    }
  }

  @override
  Future<void> openInstallPermissionSettings() async {
    if (!isSupported) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('openInstallPermissionSettings');
    } on PlatformException {
      // 用户可在系统设置中手动开启；这里不阻断流程。
    } on MissingPluginException {
      // 非 Android 平台。
    }
  }
}
