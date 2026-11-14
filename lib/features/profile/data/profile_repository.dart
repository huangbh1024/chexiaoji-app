import '../domain/profile_models.dart';

/// 我的页数据仓库。当前由 `MockProfileRepository` 提供本地数据，
/// 接入接口时替换实现，UI 与 provider 不需要改动。
abstract class ProfileRepository {
  Future<ProfileOverview> fetchOverview();

  Future<GarageData> fetchGarage({String? vehicleId, DateTime? month});

  Future<ProfileServices> fetchServices();

  Future<ProfilePreferences> fetchPreferences();

  /// P1：设置保存；P0 不调用。
  Future<ProfilePreferences> updatePreferences(ProfilePreferences preferences);

  /// P1：退出登录；P0 不调用。
  Future<void> logout();
}
