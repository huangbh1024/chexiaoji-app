import 'dart:io';

import '../domain/app_update_models.dart';

/// 全量更新数据源：拉取清单、下载 APK。
///
/// 当前实现为 `HttpAppUpdateRepository`；测试注入假实现。
abstract class AppUpdateRepository {
  Future<AppUpdateManifest?> fetchManifest();

  /// 下载到应用缓存目录，返回完整文件；失败时清理临时文件。
  Future<File> downloadApk({
    required AppUpdateManifest manifest,
    void Function(int received, int? total)? onProgress,
  });
}

/// 未配置 `UPDATE_MANIFEST_URL` 时的空实现。
class DisabledAppUpdateRepository implements AppUpdateRepository {
  const DisabledAppUpdateRepository();

  @override
  Future<AppUpdateManifest?> fetchManifest() async => null;

  @override
  Future<File> downloadApk({
    required AppUpdateManifest manifest,
    void Function(int received, int? total)? onProgress,
  }) async {
    throw const AppUpdateException('当前版本未配置更新源');
  }
}
