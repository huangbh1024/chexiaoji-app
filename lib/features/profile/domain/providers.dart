import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/domain/providers.dart';
import '../../ledger/domain/providers.dart';
import '../data/mock_profile_repository.dart';
import '../data/profile_repository.dart';
import 'profile_models.dart';

/// 静态阶段使用本地 Mock；接入接口时只替换这里的实现。
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return MockProfileRepository(
    home: ref.watch(homeRepositoryProvider),
    ledger: ref.watch(ledgerRepositoryProvider),
  );
});

final profileOverviewProvider = FutureProvider.autoDispose<ProfileOverview>((
  ref,
) {
  return ref.watch(profileRepositoryProvider).fetchOverview();
});

/// 车库当前范围：null = 全部资产。独立于首页选中车辆。
final profileGarageVehicleIdProvider =
    NotifierProvider<ProfileGarageVehicleIdNotifier, String?>(
      ProfileGarageVehicleIdNotifier.new,
    );

class ProfileGarageVehicleIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? vehicleId) {
    if (state == vehicleId) {
      return;
    }
    state = vehicleId;
  }
}

final profileGarageProvider = FutureProvider.autoDispose
    .family<GarageData, String?>((ref, vehicleId) {
      return ref
          .watch(profileRepositoryProvider)
          .fetchGarage(vehicleId: vehicleId);
    });

final profileServicesProvider = FutureProvider.autoDispose<ProfileServices>((
  ref,
) {
  return ref.watch(profileRepositoryProvider).fetchServices();
});

final profilePreferencesProvider =
    FutureProvider.autoDispose<ProfilePreferences>((ref) {
      return ref.watch(profileRepositoryProvider).fetchPreferences();
    });
