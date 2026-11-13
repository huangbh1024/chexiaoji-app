## 变更内容

<!-- 简要说明这个 PR 做了什么、为什么 -->

## 检查

- [ ] `flutter analyze` 通过
- [ ] `flutter test` 通过
- [ ] 未提交 `key.properties`、`*.jks`、`*.keystore`
- [ ] 本地或文档中已说明需要后端配合的改动（如有）

## 说明

- PR 阶段 CI 只跑检查，不产出 APK。
- 合并进 `main` 后会自动构建 release arm64 APK 并上传 Artifact。
