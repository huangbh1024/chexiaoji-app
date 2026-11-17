import 'package:chexiaoji_app/features/app_update/domain/app_update_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compareAppVersions', () {
    test('按数值比较而非字典序', () {
      expect(compareAppVersions('1.10.0', '1.9.9'), greaterThan(0));
      expect(compareAppVersions('1.9.9', '1.10.0'), lessThan(0));
    });

    test('缺失段按 0 处理', () {
      expect(compareAppVersions('1.2', '1.2.0'), 0);
      expect(compareAppVersions('1.2.1', '1.2'), greaterThan(0));
    });
  });

  group('AppUpdateManifest.fromJson', () {
    Map<String, dynamic> validJson() => {
      'version': '1.1.0',
      'buildNumber': 2,
      'apkUrl': 'https://cdn.example.com/chexiaoji-1.1.0-2.apk',
      'sha256':
          'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      'sizeBytes': 12345678,
      'changelog': '修复若干问题',
      'force': false,
      'publishedAt': '2026-11-17T12:00:00+08:00',
      'minSupportedVersion': '1.0.0',
    };

    test('解析完整清单并归一化 sha256', () {
      final manifest = AppUpdateManifest.fromJson(validJson());
      expect(manifest.version, '1.1.0');
      expect(manifest.buildNumber, 2);
      expect(manifest.sha256, hasLength(64));
      expect(manifest.sha256, isNot(contains('A')));
      expect(manifest.sizeBytes, 12345678);
      expect(manifest.changelog, '修复若干问题');
      expect(manifest.force, isFalse);
      expect(manifest.minSupportedVersion, '1.0.0');
      expect(manifest.publishedAt, isNotNull);
    });

    test('缺少必填字段时报错', () {
      final json = validJson()..remove('sha256');
      expect(
        () => AppUpdateManifest.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('拒绝非法版本与非法 URL', () {
      expect(
        () =>
            AppUpdateManifest.fromJson(validJson()..['version'] = '1.1.0-beta'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AppUpdateManifest.fromJson(validJson()..['apkUrl'] = 'not-a-url'),
        throwsA(isA<FormatException>()),
      );
    });

    test('force 必须是布尔值', () {
      expect(
        () => AppUpdateManifest.fromJson(validJson()..['force'] = 'yes'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('版本判定', () {
    test('versionName 更高或 versionCode 更大时提示更新', () {
      const manifest = AppUpdateManifest(
        version: '1.1.0',
        buildNumber: 2,
        apkUrl: 'https://example.com/app.apk',
        sha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      expect(
        manifest.isNewerThan(
          const InstalledAppVersion(name: '1.0.0', build: 1),
        ),
        isTrue,
      );
      expect(
        manifest.isNewerThan(
          const InstalledAppVersion(name: '1.0.0', build: 2),
        ),
        isTrue,
      );
      expect(
        manifest.isNewerThan(
          const InstalledAppVersion(name: '1.1.0', build: 2),
        ),
        isFalse,
      );
      expect(
        manifest.isNewerThan(
          const InstalledAppVersion(name: '1.2.0', build: 1),
        ),
        isFalse,
      );
    });

    test('force 或低于最低支持版本时不可跳过', () {
      const current = InstalledAppVersion(name: '1.0.0', build: 1);
      const forced = AppUpdateManifest(
        version: '1.1.0',
        buildNumber: 2,
        apkUrl: 'https://example.com/app.apk',
        sha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        force: true,
      );
      const minimum = AppUpdateManifest(
        version: '1.1.0',
        buildNumber: 2,
        apkUrl: 'https://example.com/app.apk',
        sha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        minSupportedVersion: '1.0.1',
      );
      expect(forced.isBlocking(current), isTrue);
      expect(minimum.isBlocking(current), isTrue);
      expect(
        minimum.isBlocking(const InstalledAppVersion(name: '1.0.1', build: 1)),
        isFalse,
      );
    });
  });
}
