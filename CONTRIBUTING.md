# 开发与分支规范

## 分支命名

所有新功能、修复、文档和 CI 改动都从 `main` 新开分支，不直接提交到 `main`。

| 类型 | 命名示例 |
| --- | --- |
| 新功能 | `feat/vehicle-list`、`feat/sms-login` |
| 修复 | `fix/login-timeout` |
| 重构 | `refactor/api-client` |
| 文档 | `docs/ci-flow` |
| 工程/CI | `ci/package-on-main`、`chore/upgrade-flutter` |

## 开发流程

```bash
git switch main
git pull
git switch -c feat/your-feature

# 开发、提交
git add .
git commit -m "feat: 实现 xxx"
git push -u origin feat/your-feature

# 开 PR（目标 main）
gh pr create --base main --head feat/your-feature --fill
```

## CI 规则

- **PR 阶段**：只运行 `flutter pub get`、`flutter analyze`、`flutter test`，**不打包**。
- **合并进 `main` 后**：自动运行完整检查，并构建 `release` arm64 APK，上传到 Actions Artifact。
- **只改文档时**：合并进 `main` 若只涉及 `**.md`、`docs/**`、`LICENSE`、`.gitignore`、
  `.idea/**`、`.vscode/**` 等非代码文件，**不会触发**工作流，也不产出 APK；
  需要出包时在 Actions 页面手动 `Run workflow`。详见 [docs/CI.md](docs/CI.md)。
- **手动触发**：Actions 页面 `Run workflow` 也会执行打包。

也就是说：**只有 PR 合并进主分支后才产出 APK**。

## 合并要求

`main` 分支启用保护规则：

- 必须通过 PR 合并，禁止直接 push；
- 必须通过 `verify` 状态检查；
- 分支需与 `main` 同步后才能合并；
- 禁止 force push 和删除分支。

PR 检查通过后，使用 GitHub 的 **Merge pull request** 或 **Squash and merge** 合并即可。

## 提交信息

建议使用 Conventional Commits：

```text
feat: 新功能
fix: 修复
refactor: 重构
docs: 文档
ci: CI/构建
chore: 其他工程改动
```

## 签名与密钥

- `android/key.properties`、`*.jks`、`*.keystore` 不要提交；
- 正式签名使用 GitHub Actions Secrets：`ANDROID_KEYSTORE_BASE64`、`ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD`；
- 未配置时 release 包使用 debug 签名，仅适合内测。

## 下载 APK

合并进 `main` 后：

1. 打开 GitHub → **Actions** → 最近一次 `Flutter Android`；
2. 页面底部 **Artifacts** 下载；
3. 或使用 CLI：

```bash
gh run list --repo huangbh1024/chexiaoji-app
gh run download <run-id> --repo huangbh1024/chexiaoji-app --dir ~/Downloads
```
