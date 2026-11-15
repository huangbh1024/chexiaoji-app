import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/enums.dart';
import '../../home/domain/providers.dart';
import '../data/vehicle_repository.dart';
import '../data/vehicle_store.dart';
import 'providers.dart';
import 'vehicle_editor_models.dart';
import 'vehicle_editor_presenter.dart';

final vehicleEditorRepositoryProvider = Provider<VehicleRepository>((ref) {
  return ref.watch(vehicleRepositoryProvider);
});

final vehicleEditorControllerProvider = NotifierProvider.autoDispose
    .family<VehicleEditorController, VehicleEditorState, VehicleEditorArgs>(
      VehicleEditorController.new,
    );

class _SpecValues {
  const _SpecValues({
    this.battery,
    this.officialConsumption,
    this.electricRange,
    this.tank,
    this.fuelGrade,
  });

  factory _SpecValues.fromDraft(VehicleEditorDraft draft) {
    return _SpecValues(
      battery: draft.batteryCapacityKwh,
      officialConsumption: draft.officialConsumption,
      electricRange: draft.electricRangeKm,
      tank: draft.tankCapacityL,
      fuelGrade: draft.powertrain == PowertrainType.ev
          ? null
          : draft.defaultFuelGrade,
    );
  }

  final double? battery;
  final double? officialConsumption;
  final int? electricRange;
  final double? tank;
  final int? fuelGrade;
}

class VehicleEditorController extends Notifier<VehicleEditorState> {
  VehicleEditorController(this.args);

  final VehicleEditorArgs args;

  bool _submitting = false;
  final Map<PowertrainType, _SpecValues> _specCache = {};

  @override
  VehicleEditorState build() {
    final initial = const VehicleEditorDraft(
      province: '粤',
      powertrain: PowertrainType.ev,
      isGreenPlate: true,
    );
    _bootstrap();
    return VehicleEditorState(
      args: args,
      draft: initial,
      initialDraft: args.isCreate ? initial : null,
      status: args.isCreate
          ? VehicleEditorStatus.ready
          : VehicleEditorStatus.loading,
    );
  }

  Future<void> _bootstrap() async {
    if (args.isCreate) {
      try {
        final garage = await ref.read(garageProvider.future);
        if (!ref.mounted) {
          return;
        }
        final empty = garage.vehicles.isEmpty;
        final full = garage.vehicles.length >= VehicleStore.maxActiveVehicles;
        if (state.draft != state.initialDraft) {
          state = state.copyWith(
            isPrimaryLocked: empty,
            activeVehicleCount: garage.vehicles.length,
            maxActiveVehicles: VehicleStore.maxActiveVehicles,
            formError: full ? '车库车辆已达上限（10 辆），请先归档不再使用的车辆' : null,
            clearFormError: !full,
          );
          return;
        }
        final draft = state.draft.copyWith(makePrimary: empty);
        state = state.copyWith(
          draft: draft,
          initialDraft: draft,
          isPrimaryLocked: empty,
          activeVehicleCount: garage.vehicles.length,
          maxActiveVehicles: VehicleStore.maxActiveVehicles,
          formError: full ? '车库车辆已达上限（10 辆），请先归档不再使用的车辆' : null,
          clearFormError: !full,
        );
      } catch (_) {
        if (!ref.mounted) {
          return;
        }
        state = state.copyWith(formError: '未能读取车库状态，保存时将由服务端校验。');
      }
      return;
    }

    try {
      final snapshot = await ref
          .read(vehicleEditorRepositoryProvider)
          .fetchVehicleEditor(args.vehicleId!);
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(
        status: VehicleEditorStatus.ready,
        draft: snapshot.draft,
        initialDraft: snapshot.draft,
        isPrimaryLocked: snapshot.isPrimary,
        activeVehicleCount: snapshot.activeVehicleCount,
        maxActiveVehicles: snapshot.maxActiveVehicles,
        latestOdometerKm: snapshot.latestOdometerKm,
        version: snapshot.version,
        successorName: snapshot.successorName,
        isOnlyActiveVehicle: snapshot.isOnlyActiveVehicle,
      );
    } on VehicleOperationException catch (error) {
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(
        status: error.code == VehicleErrorCode.notArchived
            ? VehicleEditorStatus.archived
            : VehicleEditorStatus.notFound,
        formError: error.message,
      );
    } catch (_) {
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(status: VehicleEditorStatus.error);
    }
  }

  void update(
    VehicleEditorDraft Function(VehicleEditorDraft draft) transform, {
    VehicleEditorField? field,
  }) {
    if (state.isSaving || !state.isReady) {
      return;
    }
    final next = transform(state.draft);
    if (next == state.draft) {
      return;
    }
    final errors = field == null
        ? state.fieldErrors
        : (Map<VehicleEditorField, String>.of(state.fieldErrors)
            ..remove(field));
    state = state.copyWith(
      draft: next,
      fieldErrors: errors,
      clearFormError: true,
    );
  }

  void setName(String value) =>
      update((d) => d.copyWith(name: value), field: VehicleEditorField.name);
  void setSpecLabel(String value) => update(
    (d) => d.copyWith(specLabel: value),
    field: VehicleEditorField.specLabel,
  );
  void setNickname(String value) => update(
    (d) => d.copyWith(nickname: value),
    field: VehicleEditorField.nickname,
  );
  void setProvince(String value) => update(
    (d) => d.copyWith(province: value),
    field: VehicleEditorField.plate,
  );
  void setOdometer(int? value) => update(
    (d) => value == null
        ? d.copyWith(clearOdometer: true)
        : d.copyWith(odometerKm: value),
    field: VehicleEditorField.odometer,
  );

  void setPlateBody(String raw) {
    var value = raw;
    if (value.startsWith(state.draft.province)) {
      value = value.substring(1);
    }
    final body = VehicleEditorPresenter.normalizePlateBody(value);
    update((d) => d.copyWith(plateBody: body), field: VehicleEditorField.plate);
  }

  void toggleGreenPlate() {
    if (state.isSaving || !state.isReady) {
      return;
    }
    update(
      (d) => d.copyWith(isGreenPlate: !d.isGreenPlate),
      field: VehicleEditorField.plate,
    );
  }

  void setPowertrain(PowertrainType type) {
    if (state.isSaving || !state.isReady || state.draft.powertrain == type) {
      return;
    }
    _specCache[state.draft.powertrain] = _SpecValues.fromDraft(state.draft);
    final cached = _specCache[type] ?? const _SpecValues();
    final draft = state.draft.copyWith(
      powertrain: type,
      isGreenPlate: VehicleEditorPresenter.defaultGreenPlate(type),
      batteryCapacityKwh: cached.battery,
      clearBattery: cached.battery == null,
      officialConsumption: cached.officialConsumption,
      clearOfficialConsumption: cached.officialConsumption == null,
      electricRangeKm: cached.electricRange,
      clearElectricRange: cached.electricRange == null,
      tankCapacityL: cached.tank,
      clearTank: cached.tank == null,
      defaultFuelGrade: cached.fuelGrade,
      clearFuelGrade: cached.fuelGrade == null,
    );
    state = state.copyWith(
      draft: draft,
      fieldErrors: const {},
      clearFormError: true,
    );
  }

  void setBattery(double? value) => update(
    (d) => value == null
        ? d.copyWith(clearBattery: true)
        : d.copyWith(batteryCapacityKwh: value),
  );

  void setOfficialConsumption(double? value) => update(
    (d) => value == null
        ? d.copyWith(clearOfficialConsumption: true)
        : d.copyWith(officialConsumption: value),
  );

  void setElectricRange(int? value) => update(
    (d) => value == null
        ? d.copyWith(clearElectricRange: true)
        : d.copyWith(electricRangeKm: value),
  );

  void setTank(double? value) => update(
    (d) => value == null
        ? d.copyWith(clearTank: true)
        : d.copyWith(tankCapacityL: value),
  );

  void setFuelGrade(int? value) => update(
    (d) => value == null
        ? d.copyWith(clearFuelGrade: true)
        : d.copyWith(defaultFuelGrade: value),
  );

  void setPurchaseDate(DateTime? value) => update(
    (d) => value == null
        ? d.copyWith(clearPurchaseDate: true)
        : d.copyWith(purchaseDate: VehicleEditorPresenter.dateOnly(value)),
  );

  void setPurchasePrice(int? cents) => update(
    (d) => cents == null
        ? d.copyWith(clearPurchasePrice: true)
        : d.copyWith(purchasePriceCents: cents),
  );

  void setNextMaintenance(int? km) => update(
    (d) => km == null
        ? d.copyWith(clearNextMaintenance: true)
        : d.copyWith(nextMaintenanceKm: km),
  );

  void setInsuranceExpiry(DateTime? date) => update(
    (d) => date == null
        ? d.copyWith(clearInsurance: true)
        : d.copyWith(insuranceExpiry: VehicleEditorPresenter.dateOnly(date)),
  );

  void togglePrimary() {
    if (state.isPrimaryLocked) {
      return;
    }
    update((d) => d.copyWith(makePrimary: !d.makePrimary));
  }

  List<PlateOwner> _knownPlateOwners() {
    final vehicles = ref.read(vehiclesProvider).value ?? const [];
    return [
      for (final vehicle in vehicles)
        if (vehicle.id != args.vehicleId)
          PlateOwner(plate: vehicle.plate, name: vehicle.name),
    ];
  }

  Future<VehicleEditorResult?> save() async {
    if (_submitting || !state.isReady) {
      return null;
    }
    final errors = VehicleEditorPresenter.validate(
      state.draft,
      now: DateTime.now(),
      latestOdometerKm: state.latestOdometerKm,
      knownVehicles: _knownPlateOwners(),
    );
    if (errors.isNotEmpty) {
      state = state.copyWith(fieldErrors: errors, clearFormError: true);
      return null;
    }

    _submitting = true;
    state = state.copyWith(
      isSaving: true,
      fieldErrors: const {},
      clearFormError: true,
    );

    try {
      final repository = ref.read(vehicleEditorRepositoryProvider);
      final result = args.isCreate
          ? await repository.createVehicle(state.draft)
          : await repository.updateVehicle(
              args.vehicleId!,
              state.draft,
              version: state.version,
            );
      if (!ref.mounted) {
        return result;
      }
      final scopes = ref.read(vehicleScopeInvalidatorProvider);
      scopes.invalidateAll();
      scopes.normalizeScopes(
        result.vehicleId,
        select: args.isCreate || state.draft.makePrimary,
      );
      state = state.copyWith(
        isSaving: false,
        initialDraft: state.draft,
        clearFormError: true,
      );
      return result;
    } on VehicleOperationException catch (error) {
      if (!ref.mounted) {
        return null;
      }
      if (error.code == VehicleErrorCode.duplicatePlate) {
        state = state.copyWith(
          isSaving: false,
          fieldErrors: {
            VehicleEditorField.plate: '该车牌已在车库中（${error.message ?? '已有车辆'}）',
          },
        );
      } else {
        state = state.copyWith(
          isSaving: false,
          formError: VehicleEditorPresenter.errorMessageFor(error.code),
        );
      }
      return null;
    } catch (_) {
      if (!ref.mounted) {
        return null;
      }
      state = state.copyWith(isSaving: false, formError: '保存失败，请重试');
      return null;
    } finally {
      _submitting = false;
    }
  }
}
