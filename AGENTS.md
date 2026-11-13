# Agent 规范

本仓库面向所有 AI / 自动化代理的完整规范见 [CLAUDE.md](CLAUDE.md)，必须遵守。

核心规则：

1. **不要直接提交或 push `main`**。所有改动从 `main` 新开分支，走 PR。
2. 分支命名：`feat/*`、`fix/*`、`refactor/*`、`docs/*`、`ci/*`、`chore/*`。
3. PR 阶段 CI 只跑 `flutter analyze` / `flutter test`，**不打包**。
4. 只有 PR 合并进 `main`（或手动 `workflow_dispatch`）才构建 APK 并上传 Artifact。
5. 不提交 `key.properties`、`*.jks`、`*.keystore`。
6. 提交信息使用 Conventional Commits。
7. 不要修改 `main` 的分支保护规则或强制推送 `main`。

流程细节见 [CONTRIBUTING.md](CONTRIBUTING.md)，CI 说明见 [docs/CI.md](docs/CI.md)。
