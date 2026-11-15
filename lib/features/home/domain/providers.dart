import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ledger/domain/providers.dart';
import '../../vehicles/data/vehicle_store_provider.dart';
import '../data/home_repository.dart';
import '../data/mock_home_repository.dart';
import 'home_models.dart';

/// 静态阶段使用本地 Mock；接入接口时只需替换这里的实现。
final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => MockHomeRepository(
    ledger: ref.watch(ledgerRepositoryProvider),
    odometerResolver: ref.watch(mockLedgerRepositoryProvider).latestOdometer,
    store: ref.watch(vehicleStoreProvider),
  ),
);

final vehiclesProvider = FutureProvider<List<Vehicle>>((ref) {
  return ref.watch(homeRepositoryProvider).fetchVehicles();
});

/// 当前选中的车辆；空车库时为 null。
final selectedVehicleIdProvider =
    NotifierProvider<SelectedVehicleIdNotifier, String?>(
      SelectedVehicleIdNotifier.new,
    );

class SelectedVehicleIdNotifier extends Notifier<String?> {
  @override
  String? build() => ref.watch(vehicleStoreProvider).primaryVehicleId;

  void select(String? vehicleId) {
    if (state == vehicleId) {
      return;
    }
    state = vehicleId;
  }
}

/// 当前可用的车辆 id：优先用户选择，其次第一辆在库车，空车库为 null。
final effectiveVehicleIdProvider = Provider<String?>((ref) {
  final vehiclesAsync = ref.watch(vehiclesProvider);
  final selected = ref.watch(selectedVehicleIdProvider);
  if (!vehiclesAsync.hasValue) {
    // 加载中 / 失败时沿用默认主驾，让各模块展示骨架或自己的错误态。
    return selected;
  }
  final vehicles = vehiclesAsync.value ?? const <Vehicle>[];
  if (vehicles.isEmpty) {
    return null;
  }
  return vehicles.any((vehicle) => vehicle.id == selected)
      ? selected
      : vehicles.first.id;
});

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
