# CI 构建（GitHub Actions）

工作流：`.github/workflows/flutter-android.yml`

## 触发

| 事件 | 行为 |
| --- | --- |
| PR → `main` | 只跑检查：`pub get` / `analyze` / `test`，**不打包**（不做路径过滤，保证 `verify` 始终上报） |
| push → `main`（PR 合并后） | 跑检查 + 构建 release arm64 APK + 上传 Artifact |
| push → `main`，但只改了文档等非代码文件 | **不触发**工作流，不产生 APK |
| workflow_dispatch | 手动触发，行为同 push main |

`push` 事件忽略以下路径（`.github/workflows/flutter-android.yml`）：

```yaml
paths-ignore:
  - '**.md'
  - 'docs/**'
  - 'LICENSE'
  - '.gitignore'
  - '.gitattributes'
  - '.editorconfig'
  - '.idea/**'
  - '.vscode/**'
```

一次推送里只要有一个非忽略文件（如 `lib/**`、`pubspec.yaml`、`android/**`），
就会正常构建。需要给纯文档改动出包时，用 Actions 页面的 `Run workflow` 手动触发。

> 为什么 PR 不做同样的过滤：`main` 分支保护把 `verify` 设为必需检查。若文档类 PR
> 被 `paths-ignore` 跳过，`verify` 不会上报，PR 会一直卡在 “Expected” 无法合并。

功能分支直接 push 不会触发 CI；先开 PR 到 `main`，合并后才会出 APK。
分支与合并规范见 [CONTRIBUTING.md](../CONTRIBUTING.md)。

## 流程

1. Java 21 + Flutter 3.50.0 stable
2. 安装 Android SDK `platforms;android-36`、`build-tools;36.0.0`
3. `flutter pub get` → `flutter analyze` → `flutter test`（有测试时）
4. 仅 main / 手动触发：`flutter build apk --release --target-platform android-arm64`
5. 仅 main / 手动触发：上传 APK Artifact，保留 7 天

下载：Actions → 某次运行 → 页面底部 **Artifacts**。

## 费用

- 公开仓库：标准 `ubuntu-24.04` runner 免费，Android 打包无额外费用。
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
  - uses: actions/checkout@v7
  - uses: actions/setup-java@v6
    with:
      distribution: temurin
      java-version: '21'
  - uses: subosito/flutter-action@v2
    with:
      flutter-version: '3.50.0'
      channel: stable
  - run: flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

## 本地 Docker 构建（可选）

如果需要在本地/离线出包，参考 `deploy/flutter-builder/README.md`。
当前本地镜像已删除；仅用 CI 时不需要它。
