import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/home_repository.dart';
import '../data/mock_home_repository.dart';
import 'home_models.dart';

/// 静态阶段使用本地 Mock；接入接口时只需替换这里的实现。
final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => MockHomeRepository(),
);

final vehiclesProvider = FutureProvider<List<Vehicle>>((ref) {
  return ref.watch(homeRepositoryProvider).fetchVehicles();
});

/// 当前选中的车辆；首次进入选中默认车辆。
final selectedVehicleIdProvider =
    NotifierProvider<SelectedVehicleIdNotifier, String>(
      SelectedVehicleIdNotifier.new,
    );

class SelectedVehicleIdNotifier extends Notifier<String> {
  @override
  String build() => ref.watch(homeRepositoryProvider).defaultVehicleId;

  void select(String vehicleId) {
    if (state == vehicleId) {
      return;
    }
    state = vehicleId;
  }
}

/// Hero / 能耗 / 保养数据。
final homeDashboardProvider = FutureProvider.autoDispose
    .family<HomeDashboard, String>((ref, vehicleId) {
      return ref.watch(homeRepositoryProvider).fetchDashboard(vehicleId);
    });

final breakdownProvider = FutureProvider.autoDispose.family<Breakdown, String>((
  ref,
  vehicleId,
) {
  return ref.watch(homeRepositoryProvider).fetchBreakdown(vehicleId);
});

final recordsProvider = FutureProvider.autoDispose
    .family<List<RecordItem>, String>((ref, vehicleId) {
      return ref.watch(homeRepositoryProvider).fetchRecords(vehicleId);
    });

final trendRangeProvider = NotifierProvider<TrendRangeNotifier, TrendRange>(
  TrendRangeNotifier.new,
);

class TrendRangeNotifier extends Notifier<TrendRange> {
  @override
  TrendRange build() => TrendRange.d30;

  void select(TrendRange range) {
    if (state == range) {
      return;
    }
    state = range;
  }
}

final trendProvider = FutureProvider.autoDispose
    .family<TrendData, ({String vehicleId, TrendRange range})>((ref, key) {
      return ref
          .watch(homeRepositoryProvider)
          .fetchTrend(key.vehicleId, key.range);
    });

final unreadCountProvider = Provider<int>((ref) => 1);

/// 深色设计稿尚未提供：这里先按设计系统推导一套临时深色 token，
/// 仅用于验证主题切换链路，后续以正式深色稿替换 [AppPalette.dark]。
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light;

  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }
}
