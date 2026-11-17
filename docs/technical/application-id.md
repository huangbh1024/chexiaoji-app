# 应用标识（Application ID / Bundle ID）

> 当前默认值：`top.huangbh.chexiaoji_app`（Android）、`top.huangbh.chexiaojiApp`（iOS）。
>
> 正式域名确定后，按本文修改；**首次上架/发布后不要再改**，否则设备与商店会
> 把它当成另一个 App，无法覆盖升级。

## 1. Android

| 位置 | 当前值 | 说明 |
| --- | --- | --- |
| `android/gradle.properties` → `chexiaojiApplicationId` | `top.huangbh.chexiaoji_app` | **对外应用标识**，优先改这里 |
| `android/app/build.gradle.kts` → `applicationId` | 读取上面的属性 | 也可用 `-PchexiaojiApplicationId=...` 临时覆盖 |
| `android/app/build.gradle.kts` → `namespace` | `top.huangbh.chexiaoji_app` | 内部代码命名空间 |
| `android/app/src/main/kotlin/top/huangbh/chexiaoji_app/MainActivity.kt` | `package top.huangbh.chexiaoji_app` | 与 namespace 保持一致 |

`applicationId` 是安装到设备、上架应用商店时使用的唯一身份；`namespace`
只影响代码中的 `R` 类、Manifest 相对类名等，二者可以不同。正式域名到位后，
通常只需要改 `chexiaojiApplicationId`，不必移动 Kotlin 包目录。

FileProvider authority 使用 `${applicationId}.fileprovider`，Kotlin 侧用运行时
`packageName` 拼同样的值，因此会跟随 `applicationId` 自动变化。

## 2. iOS

`ios/Runner.xcodeproj/project.pbxproj` 中所有：

```text
PRODUCT_BUNDLE_IDENTIFIER = top.huangbh.chexiaojiApp;
PRODUCT_BUNDLE_IDENTIFIER = top.huangbh.chexiaojiApp.RunnerTests;
```

正式域名确定后统一替换。Flutter 不会在构建时自动读取 Android 的
`chexiaojiApplicationId`，iOS 需要单独改。

## 3. 更新清单地址

`UPDATE_MANIFEST_URL` 与应用标识无关，单独通过构建参数配置：

```bash
flutter build apk --dart-define=UPDATE_MANIFEST_URL=https://cdn.example.com/update.json
```

## 4. 修改检查清单

- [ ] 确认新标识是可控域名反写，且未被占用。
- [ ] 修改 `android/gradle.properties` 的 `chexiaojiApplicationId`。
- [ ] 如需要，同步修改 Android `namespace` 与 Kotlin 包目录（一般不必）。
- [ ] 修改 iOS `PRODUCT_BUNDLE_IDENTIFIER` 的 6 处引用。
- [ ] 检查 FileProvider authority、MethodChannel 名称（当前为
      `chexiaoji/app_update`，与包名解耦）。
- [ ] 重新生成签名配置与商店资料。
- [ ] 在真机上验证覆盖安装、更新检查与系统安装器。
