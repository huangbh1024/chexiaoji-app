import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/vehicle.dart';
import '../../home/domain/providers.dart';
import '../../ledger/domain/providers.dart';
import '../data/mock_stats_repository.dart';
import '../data/stats_repository.dart';
import 'stats_models.dart';
import 'stats_period.dart';

/// 当前阶段用 Mock；接入接口时只替换这里的实现。
final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => MockStatsRepository(
    ledger: ref.watch(mockLedgerRepositoryProvider),
    home: ref.watch(homeRepositoryProvider),
  ),
);

/// 页面筛选：车辆范围 + 周期 + 锚点。切 Tab 回来保留。
final statsFilterProvider = NotifierProvider<StatsFilterNotifier, StatsFilter>(
  StatsFilterNotifier.new,
);

class StatsFilterNotifier extends Notifier<StatsFilter> {
  @override
  StatsFilter build() => StatsFilter(
    // 只读取一次初始值，不跟踪首页选中车辆。
    vehicleId: ref.read(selectedVehicleIdProvider),
    anchor: DateTime.now(),
  );

  void selectVehicle(String? vehicleId) {
    if (vehicleId == state.vehicleId) {
      return;
    }
    state = vehicleId == null
        ? state.copyWith(clearVehicle: true)
        : state.copyWith(vehicleId: vehicleId);
    if (vehicleId != null) {
      ref.read(selectedVehicleIdProvider.notifier).select(vehicleId);
    }
  }

  void selectPeriod(StatsPeriod period) {
    if (period == state.period) {
      return;
    }
    state = state.copyWith(period: period);
  }

  void selectAnchor(DateTime anchor) {
    if (anchor.year == state.anchor.year &&
        anchor.month == state.anchor.month &&
        anchor.day == state.anchor.day) {
      return;
    }
    state = state.copyWith(anchor: anchor);
  }

  void reset() {
    state = StatsFilter(
      vehicleId: ref.read(selectedVehicleIdProvider),
      anchor: DateTime.now(),
    );
  }
}

final statsOverviewProvider = FutureProvider.autoDispose
    .family<StatsOverview, StatsScope>((ref, scope) {
      return ref.watch(statsRepositoryProvider).fetchOverview(scope);
    });

final statsBreakdownProvider = FutureProvider.autoDispose
    .family<StatsBreakdown, StatsScope>((ref, scope) {
      return ref.watch(statsRepositoryProvider).fetchBreakdown(scope);
    });

final statsRecentProvider = FutureProvider.autoDispose
    .family<List<StatsRecord>, StatsScope>((ref, scope) {
      return ref.watch(statsRepositoryProvider).fetchRecent(scope);
    });

/// 趋势粒度独立于页面周期；默认 30 天。
final statsTrendRangeProvider =
    NotifierProvider<StatsTrendRangeNotifier, StatsTrendRange>(
      StatsTrendRangeNotifier.new,
    );

class StatsTrendRangeNotifier extends Notifier<StatsTrendRange> {
  @override
  StatsTrendRange build() => StatsTrendRange.d30;

  void select(StatsTrendRange range) {
    if (state == range) {
      return;
    }
    state = range;
  }

  /// 页面周期切换时的默认映射。
  void applyPeriodDefault(StatsPeriod period) {
    final next = switch (period) {
      StatsPeriod.week => StatsTrendRange.d7,
      StatsPeriod.month => StatsTrendRange.d30,
      StatsPeriod.halfYear => StatsTrendRange.halfYear,
      StatsPeriod.year || StatsPeriod.all => StatsTrendRange.year,
    };
    state = next;
  }
}

final statsTrendProvider = FutureProvider.autoDispose
    .family<StatsTrend, StatsTrendQuery>((ref, query) {
      return ref.watch(statsRepositoryProvider).fetchTrend(query);
    });

/// 当前选中的车辆；全部车辆时为 null。
final statsCurrentVehicleProvider = Provider<Vehicle?>((ref) {
  final vehicleId = ref.watch(
    statsFilterProvider.select((filter) => filter.vehicleId),
  );
  if (vehicleId == null) {
    return null;
  }
  final vehicles = ref.watch(vehiclesProvider).value ?? const <Vehicle>[];
  for (final vehicle in vehicles) {
    if (vehicle.id == vehicleId) {
      return vehicle;
    }
  }
  return null;
});
