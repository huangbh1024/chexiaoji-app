# CI 构建（GitHub Actions）

工作流：`.github/workflows/flutter-android.yml`

## 触发

- push / pull_request：修改 `lib/`、`test/`、`android/`、`ios/`、`pubspec.*` 或工作流本身
- workflow_dispatch：Actions 页面手动运行

## 流程

1. Java 21 + Flutter 3.50.0 stable
2. 安装 Android SDK `platforms;android-36`、`build-tools;36.0.0`
3. `flutter pub get` → `flutter analyze` → `flutter test`（有测试时）
4. `flutter build apk --release --target-platform android-arm64`
5. 上传 APK Artifact，保留 7 天

下载：Actions → 某次运行 → 页面底部 **Artifacts**。

## 费用

- 公开仓库：标准 `ubuntu-latest` runner 免费，Android 打包无额外费用。
- 私有仓库：Free 计划每月 $12 计算额度；Linux 2-core 约 $0.006/分钟；Artifact 500 MB、缓存 10 GB。macOS runner 约 $0.062/分钟。
- 建议在 Settings → Billing 设置 spending limit，避免意外账单。

## 正式签名

仓库 **Settings → Secrets and variables → Actions**：

| Secret | 内容 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore 密码 |
| `ANDROID_KEY_ALIAS` | 例如 `upload` |
| `ANDROID_KEY_PASSWORD` | key 密码 |

然后在 `android/app/build.gradle.kts` 配置 `signingConfigs.release`，读取
`android/key.properties`。未配置 secrets 时工作流继续使用 debug 签名，仅适合内测。

## iOS

Ubuntu runner 不能打 iOS。需要另加 `macos-latest` 工作流：

```yaml
runs-on: macos-latest
steps:
  - uses: actions/checkout@v4
  - uses: subosito/flutter-action@v2
    with:
      flutter-version: '3.50.0'
      channel: stable
  - run: flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

## 本地 Docker 构建（可选）

如果需要在本地/离线出包，参考 `deploy/flutter-builder/README.md`。
只用 CI 时不需要本地镜像，可以删除镜像和缓存卷释放磁盘：

```bash
docker rmi cxj-flutter-builder:3.50.0
docker volume rm cxj-flutter-pub-cache cxj-flutter-gradle-cache cxj-flutter-android-sdk
```
