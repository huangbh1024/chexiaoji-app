import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' as foundation;
import 'package:path_provider/path_provider.dart';

import '../domain/app_update_models.dart';
import 'app_update_repository.dart';

typedef AppUpdateDirectoryProvider = Future<Directory> Function();

/// 通过 HTTPS 拉取更新清单并下载 APK。
///
/// - 清单请求带随机参数并禁用缓存，避免 CDN 返回旧版本；
/// - APK 先写 `.part`，长度校验通过后再改名；
/// - SHA-256 由 Android 原生侧在安装前校验，见 `MainActivity.kt`。
class HttpAppUpdateRepository implements AppUpdateRepository {
  HttpAppUpdateRepository({
    required this.manifestUrl,
    this.timeout = const Duration(seconds: 15),
    this.downloadTimeout = const Duration(seconds: 30),
    AppUpdateDirectoryProvider? directoryProvider,
    this.httpClient,
  }) : _directoryProvider = directoryProvider ?? getTemporaryDirectory;

  final String manifestUrl;
  final Duration timeout;
  final Duration downloadTimeout;
  final AppUpdateDirectoryProvider _directoryProvider;
  final HttpClient? httpClient;

  Uri _validatedUri(String raw, {required String label}) {
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw AppUpdateException('$label地址无效');
    }
    if (uri.scheme != 'https' &&
        !(foundation.kDebugMode && uri.scheme == 'http')) {
      throw AppUpdateException('$label必须使用 HTTPS');
    }
    return uri;
  }

  @override
  Future<AppUpdateManifest?> fetchManifest() async {
    final uri = _validatedUri(manifestUrl, label: '更新清单');
    final requestUri = uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        '_t': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
    final client = httpClient ?? (HttpClient()..connectionTimeout = timeout);
    try {
      final request = await client.getUrl(requestUri).timeout(timeout);
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw AppUpdateException('检查更新失败（HTTP ${response.statusCode}）');
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const AppUpdateException('更新信息格式错误');
      }
      return AppUpdateManifest.fromJson(decoded);
    } on AppUpdateException {
      rethrow;
    } on TimeoutException {
      throw const AppUpdateException('检查更新超时，请稍后重试');
    } on SocketException {
      throw const AppUpdateException('网络连接失败，请检查网络后重试');
    } on FormatException {
      throw const AppUpdateException('更新信息格式错误');
    } on HttpException {
      throw const AppUpdateException('检查更新失败，请稍后重试');
    } finally {
      if (httpClient == null) {
        client.close(force: true);
      }
    }
  }

  @override
  Future<File> downloadApk({
    required AppUpdateManifest manifest,
    void Function(int received, int? total)? onProgress,
  }) async {
    final uri = _validatedUri(manifest.apkUrl, label: '安装包');
    final baseDir = await _directoryProvider();
    final directory = Directory(
      '${baseDir.path}${Platform.pathSeparator}app_update',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final target = File(
      '${directory.path}${Platform.pathSeparator}'
      'chexiaoji-${manifest.version}-${manifest.buildNumber}.apk',
    );
    final partial = File('${target.path}.part');
    if (await partial.exists()) {
      await partial.delete();
    }
    if (await target.exists()) {
      await target.delete();
    }

    final client = httpClient ?? (HttpClient()..connectionTimeout = timeout);
    var completed = false;
    IOSink? sink;
    try {
      final request = await client.getUrl(uri).timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw AppUpdateException('下载安装包失败（HTTP ${response.statusCode}）');
      }

      final total = response.contentLength > 0
          ? response.contentLength
          : manifest.sizeBytes;
      var received = 0;
      final output = partial.openWrite();
      sink = output;
      await for (final chunk in response.timeout(downloadTimeout)) {
        output.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await output.flush();
      await output.close();
      sink = null;

      if (total != null && total > 0 && received != total) {
        throw const AppUpdateException('安装包下载不完整，请重试');
      }
      if (manifest.sizeBytes != null && received != manifest.sizeBytes) {
        throw const AppUpdateException('安装包大小校验失败，请重试');
      }

      await partial.rename(target.path);
      completed = true;
      return target;
    } on AppUpdateException {
      rethrow;
    } on TimeoutException {
      throw const AppUpdateException('下载安装包超时，请检查网络后重试');
    } on SocketException {
      throw const AppUpdateException('网络连接失败，请检查网络后重试');
    } on HttpException {
      throw const AppUpdateException('下载安装包失败，请稍后重试');
    } finally {
      try {
        await sink?.close();
      } catch (_) {
        // 关闭失败时保留原始异常。
      }
      if (!completed && await partial.exists()) {
        try {
          await partial.delete();
        } catch (_) {
          // 清理失败不影响错误提示；下次下载会覆盖。
        }
      }
      if (httpClient == null) {
        client.close(force: true);
      }
    }
  }
}
