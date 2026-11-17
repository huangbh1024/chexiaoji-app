import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_update_installer.dart';
import '../data/app_update_repository.dart';
import '../data/http_app_update_repository.dart';

/// 更新清单地址，通过构建参数注入：
///
/// ```bash
/// flutter build apk --dart-define=UPDATE_MANIFEST_URL=https://cdn.example.com/update.json
/// ```
///
/// 为空时隐藏「检查更新」入口，避免出现不可用按钮。
final appUpdateManifestUrlProvider = Provider<String>((ref) {
  return const String.fromEnvironment('UPDATE_MANIFEST_URL');
});

final appUpdateRepositoryProvider = Provider<AppUpdateRepository>((ref) {
  final url = ref.watch(appUpdateManifestUrlProvider).trim();
  if (url.isEmpty) {
    return const DisabledAppUpdateRepository();
  }
  return HttpAppUpdateRepository(manifestUrl: url);
});

final appUpdateInstallerProvider = Provider<AppUpdateInstaller>((ref) {
  return const MethodChannelAppUpdateInstaller();
});
