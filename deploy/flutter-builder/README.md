# Flutter Android 构建环境（Docker）

固定版本的 Flutter + Android SDK 构建镜像，用于在 Linux 服务器上产出 APK，不污染宿主机。
**可选**：如果构建全部走 GitHub Actions，不需要本地镜像；本文档用于本地/离线兜底。

## 版本

| 组件 | 版本 |
| --- | --- |
| Flutter | 3.50.0 stable（Dart 3.14.0） |
| JDK | 21 |
| Android SDK Platform | android-36 |
| Android Build-Tools | 36.0.0 |
| Android cmdline-tools | 16111833 |

## 使用

```bash
# 1. 构建镜像（首次约 15–30 分钟，镜像约 12 GB）
./deploy/flutter-builder/build.sh image

# 2. 检查工具链
./deploy/flutter-builder/build.sh doctor

# 3. 构建 APK（Flutter 工程在仓库根目录）
./deploy/flutter-builder/build.sh apk --release --target-platform android-arm64

# 调试包
./deploy/flutter-builder/build.sh apk --debug
```

产物在 `build/app/outputs/flutter-apk/`。

如果 Flutter 工程不在仓库根目录：

```bash
APP_DIR=apps/other ./deploy/flutter-builder/build.sh apk --release
```

构建时会自动把工程 `android/gradle/wrapper/gradle-wrapper.properties` 里的
`services.gradle.org` 临时替换为腾讯 Gradle 镜像（`-all` 自动换成更小的 `-bin`），
构建结束（含失败）后恢复原文件。可用 `GRADLE_DIST_MIRROR=off` 关闭，或指定其他镜像：

```bash
GRADLE_DIST_MIRROR=https://mirrors.aliyun.com/gradle ./deploy/flutter-builder/build.sh apk --release
```

## 缓存

三个具名卷会保留在宿主机，第二次构建无需重新下载：

- `cxj-flutter-pub-cache` → `/home/dev/.pub-cache`
- `cxj-flutter-gradle-cache` → `/home/dev/.gradle`
- `cxj-flutter-android-sdk` → `/opt/android-sdk`（保存 Gradle/Flutter 自动安装的 NDK 等组件；首次构建会安装一次，之后复用）

升级镜像后如需刷新 SDK 组件：

```bash
docker volume rm cxj-flutter-android-sdk
```

Gradle 默认限制为 `-Xmx1536m`、2 个 worker，适合 4 GB 内存机器；可在
`~/.gradle/gradle.properties`（卷内）或工程 `android/gradle.properties` 中调整。

## 签名

release 包默认使用 Flutter 模板的 debug 签名，仅适合内测。正式发布时：

1. 生成 keystore；
2. 把 `key.properties` 与 `.jks` 放在宿主机（不要打进镜像）；
3. 在 `android/app/build.gradle(.kts)` 配置 `signingConfigs.release`；
4. 构建时挂载密钥目录：

```bash
DOCKER_RUN_ARGS="-v $HOME/keys:/keys:ro" ./deploy/flutter-builder/build.sh apk --release
```

## 卸载

```bash
docker rmi cxj-flutter-builder:3.50.0
docker volume rm cxj-flutter-pub-cache cxj-flutter-gradle-cache cxj-flutter-android-sdk
# 可选，清理共享构建缓存（会影响其他项目，先确认）
docker builder prune
```

## 限制

- 仅构建 Android APK；iOS 需要 macOS + Xcode。
- 不包含 Android 模拟器，不适合容器内日常 `flutter run` 热重载。
- Docker 共享宿主机内存；内存不足时优先加 swap，并降低 Gradle 并发。
- 仅用 CI 构建时，可以删除本地镜像和三个缓存卷，释放约 16 GB。
