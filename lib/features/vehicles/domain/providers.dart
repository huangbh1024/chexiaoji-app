import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/domain/providers.dart';
import '../../ledger/domain/providers.dart';
import '../../profile/domain/providers.dart';
import '../../report/domain/providers.dart';
import '../../stats/domain/providers.dart';
import '../data/mock_vehicle_repository.dart';
import '../data/vehicle_repository.dart';
import '../data/vehicle_store_provider.dart';
import 'vehicle_models.dart';

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  return MockVehicleRepository(
    store: ref.watch(vehicleStoreProvider),
    home: ref.watch(homeRepositoryProvider),
    ledger: ref.watch(ledgerRepositoryProvider),
  );
});

/// 车库快照：在库 / 归档 / 汇总。页面唯一读取入口。
final garageProvider = FutureProvider<GarageOverview>((ref) {
  return ref.watch(vehicleRepositoryProvider).fetchGarage();
});

enum VehicleCommandKind { setPrimary, archive, restore, delete }

@immutable
class VehicleCommandState {
  const VehicleCommandState({this.pending, this.errorCode, this.errorMessage});

  final VehicleCommandKind? pending;
  final VehicleErrorCode? errorCode;
  final String? errorMessage;

  bool get isBusy => pending != null;
}

final vehicleCommandProvider =
    NotifierProvider<VehicleCommandNotifier, VehicleCommandState>(
      VehicleCommandNotifier.new,
    );

class VehicleCommandNotifier extends Notifier<VehicleCommandState> {
  @override
  VehicleCommandState build() => const VehicleCommandState();

  Future<bool> setPrimary(String vehicleId) {
    return _run(
      VehicleCommandKind.setPrimary,
      () => ref.read(vehicleRepositoryProvider).setPrimary(vehicleId),
      affectedVehicleId: vehicleId,
      selectVehicle: true,
    );
  }

  Future<bool> archive(String vehicleId) {
    return _run(
      VehicleCommandKind.archive,
      () => ref.read(vehicleRepositoryProvider).archive(vehicleId),
      affectedVehicleId: vehicleId,
    );
  }

  Future<bool> restore(String vehicleId) {
    return _run(
      VehicleCommandKind.restore,
      () => ref.read(vehicleRepositoryProvider).restore(vehicleId),
      affectedVehicleId: vehicleId,
    );
  }

  Future<bool> delete(String vehicleId) {
    return _run(
      VehicleCommandKind.delete,
      () => ref.read(vehicleRepositoryProvider).delete(vehicleId),
      affectedVehicleId: vehicleId,
    );
  }

  Future<bool> _run(
    VehicleCommandKind kind,
    Future<void> Function() action, {
    String? affectedVehicleId,
    bool selectVehicle = false,
  }) async {
    if (state.isBusy) {
      return false;
    }
    state = VehicleCommandState(pending: kind);
    try {
      await action();
      if (selectVehicle && affectedVehicleId != null) {
        ref.read(selectedVehicleIdProvider.notifier).select(affectedVehicleId);
      }
      _normalizeScopes(affectedVehicleId);
      _invalidateAll();
      state = const VehicleCommandState();
      return true;
    } on VehicleOperationException catch (error) {
      state = VehicleCommandState(
        errorCode: error.code,
        errorMessage: _messageFor(error.code),
      );
      return false;
    } catch (_) {
      state = const VehicleCommandState(
        errorCode: VehicleErrorCode.unknown,
        errorMessage: '操作失败，请重试',
      );
      return false;
    }
  }

  void _normalizeScopes(String? affectedVehicleId) {
    if (affectedVehicleId == null) {
      return;
    }
    final primary = ref.read(vehicleRepositoryProvider).primaryVehicleId;

    if (ref.read(selectedVehicleIdProvider) == affectedVehicleId) {
      ref.read(selectedVehicleIdProvider.notifier).select(primary);
    }
    if (ref.read(ledgerFilterProvider).vehicleId == affectedVehicleId) {
      ref.read(ledgerFilterProvider.notifier).selectVehicle(null);
    }
    if (ref.read(statsFilterProvider).vehicleId == affectedVehicleId) {
      ref.read(statsFilterProvider.notifier).selectVehicle(primary);
    }
    if (ref.read(profileGarageVehicleIdProvider) == affectedVehicleId) {
      ref.read(profileGarageVehicleIdProvider.notifier).select(null);
    }
  }

  void _invalidateAll() {
    ref.invalidate(garageProvider);
    ref.invalidate(vehiclesProvider);
    ref.invalidate(homeDashboardProvider);
    ref.invalidate(breakdownProvider);
    ref.invalidate(recordsProvider);
    ref.invalidate(trendProvider);
    ref.invalidate(ledgerSummaryProvider);
    ref.invalidate(ledgerRecordsProvider);
    ref.invalidate(statsOverviewProvider);
    ref.invalidate(statsBreakdownProvider);
    ref.invalidate(statsRecentProvider);
    ref.invalidate(statsTrendProvider);
    ref.invalidate(profileGarageProvider);
    ref.invalidate(monthlyReportProvider);
  }

  String _messageFor(VehicleErrorCode code) {
    return switch (code) {
      VehicleErrorCode.isPrimary => '请先将其他座驾设为主驾后再删除。',
      VehicleErrorCode.hasRecords => '该车辆有历史流水，请先归档。',
      VehicleErrorCode.notFound => '车辆已不存在，请刷新车库。',
      VehicleErrorCode.conflict => '车辆信息已更新，请重试。',
      VehicleErrorCode.limitReached => '车库车辆已达上限。',
      VehicleErrorCode.unknown => '操作失败，请重试',
    };
  }
}
