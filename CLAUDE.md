# 车小记 Flutter 客户端（chexiaoji_app）

## 分支与合并规范（必须遵守）

- **禁止直接向 `main` 提交或 push**。所有改动——新功能、修复、重构、文档、CI——都必须从 `main` 新开分支。
- 分支命名：
  - `feat/<topic>` 新功能
  - `fix/<topic>` 修复
  - `refactor/<topic>` 重构
  - `docs/<topic>` 文档
  - `ci/<topic>` CI / 构建
  - `chore/<topic>` 其他工程改动
- 标准流程：
  1. `git switch main && git pull`
  2. `git switch -c <type>/<topic>`
  3. 开发、提交、`git push -u origin <branch>`
  4. `gh pr create --base main --head <branch>`
  5. 等 PR 的 `verify` 检查通过
  6. 合并 PR，删除分支
- 即使用户要求“直接提交到 main”，也应先创建分支并走 PR；只有用户明确要求临时绕过规范时才可例外，并在回复中说明。
- 不要修改 `main` 的分支保护规则，不要 force push `main`。
- 提交信息使用 Conventional Commits：`feat:` / `fix:` / `refactor:` / `docs:` / `ci:` / `chore:`。

详细说明见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## CI 与打包规范

工作流：`.github/workflows/flutter-android.yml`

- **PR → `main`**：只运行 `flutter pub get`、`flutter analyze`、`flutter test`，**不构建 APK**。
- **PR 合并进 `main` 后**：运行检查 + `flutter build apk --release --target-platform android-arm64`，并上传 Artifact（保留 7 天）。
- **只改文档的合并**：`push main` 忽略 `**.md`、`docs/**`、`LICENSE`、`.gitignore`、`.idea/**`、`.vscode/**` 等路径，纯文档改动不触发构建；`pull_request` 不过滤，保证 `verify` 始终上报（分支保护必需检查）。
- **workflow_dispatch**：手动触发时与 main 相同，会打包。
- 功能分支直接 push 不触发 CI；必须开 PR。
- 不要随意修改触发条件；如需调整，同步更新 `CONTRIBUTING.md` 和 `docs/CI.md`。
- 工具链固定：Flutter 3.50.0 stable、Java 21、Android SDK 36 / build-tools 36.0.0、runner `ubuntu-24.04`。

## 密钥与签名

- 禁止提交 `android/key.properties`、`*.jks`、`*.keystore`。
- 正式签名使用 GitHub Actions Secrets：
  `ANDROID_KEYSTORE_BASE64`、`ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD`。
- 未配置时 release 包使用 debug 签名，仅适合内测。

## 本地构建

- 构建优先走 CI；本地 Docker 构建是可选的兜底方案，见 `deploy/flutter-builder/README.md`。
- 本地镜像默认不保留（占用约 12 GB），需要时再按文档重建。
- 不要在本地生成的文件（`build/`、`.dart_tool/`、`.gradle/`）提交到仓库。

## 当前阶段

工程目前只有 Flutter 脚手架，尚未开始业务代码。开始编码前先确认接口契约与页面范围。
