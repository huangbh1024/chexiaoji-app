/// 应用静态信息。
///
/// 版本号需与 `pubspec.yaml` 的 `version` 保持一致；接入打包信息后
/// 改为运行时读取（需要新增依赖，届时再评审）。
class AppInfo {
  const AppInfo._();

  static const name = '车小记';
  static const version = '1.0.0';
  static const tagline = '记录每一公里，算清每一笔';
}
