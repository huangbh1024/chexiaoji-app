import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_update_installer.dart';
import '../data/app_update_repository.dart';
import 'app_update_dependencies.dart';
import 'app_update_models.dart';

final appUpdateControllerProvider =
    NotifierProvider<AppUpdateController, AppUpdateState>(
      AppUpdateController.new,
    );

/// 全量更新状态机：检查 → 下载 → 校验/安装 → 结果。
///
/// 失败时保留已下载的 [AppUpdateState.filePath]，授权未知来源后可跳过
/// 重复下载直接重试安装。
class AppUpdateController extends Notifier<AppUpdateState> {
  @override
  AppUpdateState build() => const AppUpdateState.idle();

  AppUpdateRepository get _repository => ref.read(appUpdateRepositoryProvider);

  AppUpdateInstaller get _installer => ref.read(appUpdateInstallerProvider);

  Future<void> checkForUpdate() async {
    if (state.phase == AppUpdatePhase.checking ||
        state.phase == AppUpdatePhase.downloading ||
        state.phase == AppUpdatePhase.installing) {
      return;
    }

    final cachedVersion = state.current;
    state = AppUpdateState.checking(current: cachedVersion);
    try {
      final installed = cachedVersion ?? await _installer.getInstalledVersion();
      final manifest = await _repository.fetchManifest();
      if (manifest == null) {
        state = AppUpdateState.failed(
          current: installed,
          message: '当前版本未配置更新源',
        );
        return;
      }
      state = manifest.isNewerThan(installed)
          ? AppUpdateState.available(current: installed, manifest: manifest)
          : AppUpdateState.upToDate(current: installed);
    } on AppUpdateException catch (error) {
      state = AppUpdateState.failed(
        current: state.current,
        message: error.message,
      );
    } catch (_) {
      state = AppUpdateState.failed(
        current: state.current,
        message: '检查更新失败，请稍后重试',
      );
    }
  }

  Future<void> downloadAndInstall() async {
    final manifest = state.manifest;
    final current = state.current;
    if (manifest == null || current == null) {
      return;
    }
    if (state.phase == AppUpdatePhase.downloading ||
        state.phase == AppUpdatePhase.installing) {
      return;
    }

    state = AppUpdateState.downloading(
      current: current,
      manifest: manifest,
      progress: 0,
    );
    try {
      final file = await _repository.downloadApk(
        manifest: manifest,
        onProgress: (received, total) {
          if (state.phase != AppUpdatePhase.downloading) {
            return;
          }
          final progress = total != null && total > 0
              ? (received / total).clamp(0.0, 1.0).toDouble()
              : null;
          state = AppUpdateState.downloading(
            current: current,
            manifest: manifest,
            progress: progress,
          );
        },
      );
      await _installFile(file.path, current: current, manifest: manifest);
    } on AppUpdateException catch (error) {
      state = AppUpdateState.failed(
        current: current,
        manifest: manifest,
        message: error.message,
      );
    } catch (_) {
      state = AppUpdateState.failed(
        current: current,
        manifest: manifest,
        message: '下载或安装失败，请重试',
      );
    }
  }

  /// 授权未知来源后重试：已下载则直接安装，否则重新下载。
  Future<void> retryInstall() async {
    final filePath = state.filePath;
    if (filePath == null) {
      await downloadAndInstall();
      return;
    }
    await _installFile(
      filePath,
      current: state.current,
      manifest: state.manifest,
    );
  }

  Future<void> openInstallPermissionSettings() =>
      _installer.openInstallPermissionSettings();

  Future<void> _installFile(
    String filePath, {
    InstalledAppVersion? current,
    AppUpdateManifest? manifest,
  }) async {
    final effectiveCurrent = current ?? state.current;
    final effectiveManifest = manifest ?? state.manifest;
    if (effectiveCurrent == null || effectiveManifest == null) {
      return;
    }

    state = AppUpdateState.installing(
      current: effectiveCurrent,
      manifest: effectiveManifest,
      filePath: filePath,
    );

    AppInstallResult result;
    try {
      result = await _installer.installApk(
        filePath: filePath,
        sha256: effectiveManifest.sha256,
      );
    } on AppUpdateException catch (error) {
      state = AppUpdateState.failed(
        current: effectiveCurrent,
        manifest: effectiveManifest,
        message: error.message,
        filePath: filePath,
      );
      return;
    } catch (_) {
      state = AppUpdateState.failed(
        current: effectiveCurrent,
        manifest: effectiveManifest,
        message: '安装失败，请重试',
        filePath: filePath,
      );
      return;
    }

    state = switch (result.status) {
      AppInstallStatus.started => AppUpdateState.installStarted(
        current: effectiveCurrent,
        manifest: effectiveManifest,
      ),
      AppInstallStatus.permissionRequired => AppUpdateState.failed(
        current: effectiveCurrent,
        manifest: effectiveManifest,
        message: result.message ?? '请允许车小记安装未知来源应用',
        filePath: filePath,
        needsInstallPermission: true,
      ),
      AppInstallStatus.hashMismatch => AppUpdateState.failed(
        current: effectiveCurrent,
        manifest: effectiveManifest,
        message: result.message ?? '安装包校验失败，请重新下载',
      ),
      AppInstallStatus.unsupported => AppUpdateState.failed(
        current: effectiveCurrent,
        manifest: effectiveManifest,
        message: result.message ?? '当前平台暂不支持应用内更新',
      ),
      AppInstallStatus.failed => AppUpdateState.failed(
        current: effectiveCurrent,
        manifest: effectiveManifest,
        message: result.message ?? '安装失败，请重试',
        filePath: filePath,
      ),
    };
  }

  void reset() {
    state = AppUpdateState.idle(current: state.current);
  }
}
