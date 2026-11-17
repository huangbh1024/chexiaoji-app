# 全量 APK 更新（Android）

> 状态：已实现 Android 端全量更新；iOS 不支持。
>
> 本文只讨论「整包下载 + 系统安装器」的更新方式，不包含 Dart 代码热更新
> （code push）。热更新评估见团队内部调研记录；当前阶段不接入。

## 1. 目标与边界

| 项 | 结论 |
| --- | --- |
| 支持平台 | Android |
| 更新方式 | 下载完整 APK，交给系统安装器覆盖安装 |
| 触发方式 | 「我的 → 关于与帮助 → 检查更新」手动触发 |
| 强制更新 | 清单可下发 `force` 或 `minSupportedVersion`，用户不能跳过 |
| 不做 | 热更新、增量/差分下载、静默安装、应用商店 SDK、iOS 更新 |
| 前提 | 新旧 APK 必须使用**同一签名**，且 `versionCode` 递增 |

## 2. 用户流程

1. 用户打开「我的 → 关于与帮助」，点击「检查更新」。
2. 客户端 `GET` 更新清单；清单地址由构建参数注入。
3. 比较 `versionName` 与 `versionCode`：
   - 服务端版本更高 → 展示版本、大小、更新内容和「立即更新」；
   - 相同或更低 → 展示「当前已是最新版本」。
4. 用户点击「立即更新」：
   - 下载到应用缓存目录 `cache/app_update/`；
   - 显示下载进度；
   - 下载完成后由 Android 原生侧计算 SHA-256 并比对清单；
   - 校验通过后通过 `FileProvider` 打开系统安装器。
5. 用户在系统界面确认安装；覆盖安装成功后重新打开 App 即为新版本。

> 安装必须由用户在系统界面确认，App 不会静默安装。

## 3. 更新清单

### 3.1 地址

通过构建参数注入：

```bash
flutter build apk --release --target-platform android-arm64 \
  --dart-define=UPDATE_MANIFEST_URL=https://cdn.example.com/chexiaoji/update.json
```

CI 读取仓库变量 `UPDATE_MANIFEST_URL` 自动注入；未配置时 App 隐藏
「检查更新」入口。

### 3.2 字段

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `version` | string | 是 | `versionName`，点分数字，如 `1.1.0` |
| `buildNumber` | int | 是 | `versionCode`，必须大于已安装版本 |
| `apkUrl` | string | 是 | APK 的 HTTPS 地址 |
| `sha256` | string | 是 | APK 的 SHA-256，64 位十六进制 |
| `sizeBytes` | int | 否 | 用于下载进度与完整性校验 |
| `changelog` | string | 否 | 纯文本更新说明；客户端按纯文本展示 |
| `force` | bool | 否 | 为 `true` 时不能跳过更新 |
| `minSupportedVersion` | string | 否 | 当前版本低于该值时强制更新 |
| `publishedAt` | string | 否 | ISO-8601 时间，用于展示 |

### 3.3 示例

```json
{
  "version": "1.1.0",
  "buildNumber": 2,
  "apkUrl": "https://cdn.example.com/chexiaoji/chexiaoji-1.1.0-2.apk",
  "sha256": "2f1c9c0f0e1d4d6a8b1e2f3a4b5c6d7e8f9012345678abcdef9012345678ab",
  "sizeBytes": 18350080,
  "changelog": "• 修复部分设备记账页闪退\n• 优化账单加载速度",
  "force": false,
  "minSupportedVersion": "1.0.0",
  "publishedAt": "2026-11-17T12:00:00+08:00"
}
```

### 3.4 版本比较

- `version` 按点分段、逐段转整数比较；缺失段按 0 处理。
- 版本号相同时再比较 `buildNumber`。
- `minSupportedVersion` 只比较 `version`，不比较 `buildNumber`。

## 4. 客户端实现

| 文件 | 职责 |
| --- | --- |
| `lib/features/app_update/domain/app_update_models.dart` | 清单解析、版本比较、状态模型 |
| `lib/features/app_update/domain/app_update_controller.dart` | 检查 → 下载 → 安装 → 失败重试状态机 |
| `lib/features/app_update/domain/app_update_dependencies.dart` | 清单地址、仓库、安装器 Provider |
| `lib/features/app_update/data/http_app_update_repository.dart` | HTTPS 拉清单、下载 APK、长度校验、清理临时文件 |
| `lib/features/app_update/data/app_update_installer.dart` | MethodChannel 封装版本读取与安装 |
| `lib/features/app_update/presentation/app_update_sheet.dart` | 更新浮层（进度、错误、强制更新） |
| `lib/features/profile/presentation/widgets/about_sheet.dart` | 「检查更新」入口 |
| `android/.../MainActivity.kt` | 读取版本、SHA-256 校验、FileProvider 打开安装器 |

### 4.1 状态机

```text
idle → checking → upToDate
                ↘ available → downloading → installing → installStarted
                                      ↘ failed → retryInstall（复用已下载文件）
```

- 失败时若已有安装包，`retryInstall()` 直接重试安装，不重复下载。
- SHA-256 不匹配会丢弃文件路径，重试时重新下载。
- 用户关闭浮层后 controller 重置；下载/安装中不允许关闭。

### 4.2 Android 细节

- `REQUEST_INSTALL_PACKAGES` 权限：仅用于打开系统安装器。
- Android 8+ 需用户在「安装未知应用」中授权；未授权时返回
  `permission_required`，UI 提供「去设置」。
- `FileProvider` authority：`${applicationId}.fileprovider`；
  路径只暴露 `cache/app_update/`。
- APK 必须位于应用缓存目录内，原生侧会校验路径前缀，防止安装任意文件。
- SHA-256 在原生线程计算，避免阻塞 UI。
- 系统安装器会再次校验 APK 签名；签名不一致会安装失败。

## 5. 发布流程

1. **提升版本号**：修改 `pubspec.yaml` 的 `version`，例如 `1.1.0+2`。
   `versionCode` 必须递增，否则 Android 会拒绝覆盖安装。
2. **配置正式签名**：仓库 Secrets 配置
   `ANDROID_KEYSTORE_BASE64`、`ANDROID_KEYSTORE_PASSWORD`、
   `ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD`。
   未配置时 CI 回退 debug 签名，只能用于内测，**不能用于全量更新**。
3. **构建 APK**：合并到 `main` 后 CI 产出
   `build/app/outputs/flutter-apk/app-release.apk`。
4. **上传 APK**：上传到长期可用的 HTTPS 地址（OSS/CDN/对象存储）。
   Actions Artifact 仅保留 7 天，不能作为更新源。
5. **生成清单**：

   ```bash
   sha256sum app-release.apk
   stat -c '%s' app-release.apk
   ```

   将结果填入 `update.json`，按需设置 `force` / `minSupportedVersion`。
6. **上传清单**：覆盖 `UPDATE_MANIFEST_URL` 指向的文件。
   客户端请求会带随机参数并禁用缓存，发布后下一次检查即可生效。
7. **验证**：在安装上一个版本的设备上检查更新，确认下载、校验、
   系统安装、覆盖安装全部通过。
8. **回滚**：Android 默认禁止降级安装。需要回滚时，发布一个
   `versionCode` 更高、代码为旧版本的包，并更新清单，而不是改回旧包。

## 6. 安全与合规

- 清单与 APK 必须使用 HTTPS；release 构建拒绝 `http://`（debug 允许本地调试）。
- 安装前校验 SHA-256；Android 安装器还会校验 APK 签名。
- 清单被篡改最多导致下载失败；攻击者无法安装未使用同一签名的 APK。
- `changelog` 按纯文本展示，不解析 HTML/链接。
- 国内应用商店对「下载可执行代码」有各自规则；自分发 APK 时需自行承担
  安全、回滚与用户告知责任。上架前需确认目标渠道政策。

## 7. 已知限制与后续

- 仅 Android；iOS 需走 App Store 或 TestFlight。
- 只支持全量下载，没有差分补丁；包体较大时下载耗时和流量较高。
- 当前为手动检查，尚未做启动时自动检查/强制更新拦截；
  `force` 只在用户打开更新浮层后生效。
- 未接入应用商店的 in-app update API；如后续上架 Google Play，
  建议改用 Play In-App Updates 并复核政策。
- 未生成更新清单的 CI 步骤；当前由发布者手动生成并上传。
