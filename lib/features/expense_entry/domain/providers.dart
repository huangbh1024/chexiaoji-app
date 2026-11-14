import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/domain/enums.dart';
import '../../../core/domain/vehicle.dart';
import '../../home/domain/providers.dart';
import '../../ledger/domain/providers.dart';
import '../../profile/domain/providers.dart';
import '../../report/domain/providers.dart';
import '../../stats/domain/providers.dart';
import '../data/expense_entry_repository.dart';
import '../data/mock_expense_entry_repository.dart';
import '../data/receipt_picker.dart';
import 'expense_entry_detail.dart';
import 'expense_entry_math.dart';
import 'expense_entry_models.dart';
import 'expense_entry_presenter.dart';
import 'expense_entry_validation.dart';

final receiptPickerProvider = Provider<ReceiptPicker>(
  (ref) => const ImagePickerReceiptPicker(),
);

final expenseEntryRepositoryProvider = Provider<ExpenseEntryRepository>((ref) {
  return MockExpenseEntryRepository(
    ref.watch(mockLedgerRepositoryProvider),
    ref.watch(homeRepositoryProvider),
  );
});

@immutable
class ExpenseEntryState {
  const ExpenseEntryState({
    required this.args,
    required this.draft,
    required this.defaults,
    this.vehicles = const <Vehicle>[],
    this.vehicle,
    this.isLoadingDefaults = true,
    this.isLoadingBaseline = false,
    this.hasNoVehicles = false,
    this.defaultsError,
    this.baselineError,
    this.isSaving = false,
    this.saveError,
    this.validation = const EntryValidation.none(),
    this.isCategoryManuallySelected = false,
    this.hasUnsavedChanges = false,
    this.uploadedReceipts = 0,
    this.totalReceipts = 0,
  });

  final ExpenseEntryArgs args;
  final ExpenseEntryDraft draft;
  final ExpenseEntryDefaults defaults;
  final List<Vehicle> vehicles;
  final Vehicle? vehicle;
  final bool isLoadingDefaults;
  final bool isLoadingBaseline;
  final bool hasNoVehicles;
  final Object? defaultsError;
  final Object? baselineError;
  final bool isSaving;
  final Object? saveError;
  final EntryValidation validation;
  final bool isCategoryManuallySelected;
  final bool hasUnsavedChanges;
  final int uploadedReceipts;
  final int totalReceipts;

  bool get canSave =>
      !isSaving &&
      !isLoadingDefaults &&
      !isLoadingBaseline &&
      !hasNoVehicles &&
      vehicle != null &&
      draft.amountCents > 0;

  ExpenseEntryState copyWith({
    ExpenseEntryDraft? draft,
    ExpenseEntryDefaults? defaults,
    List<Vehicle>? vehicles,
    Vehicle? vehicle,
    bool? isLoadingDefaults,
    bool? isLoadingBaseline,
    bool? hasNoVehicles,
    Object? defaultsError,
    bool clearDefaultsError = false,
    Object? baselineError,
    bool clearBaselineError = false,
    bool? isSaving,
    Object? saveError,
    bool clearSaveError = false,
    EntryValidation? validation,
    bool? isCategoryManuallySelected,
    bool? hasUnsavedChanges,
    int? uploadedReceipts,
    int? totalReceipts,
  }) {
    return ExpenseEntryState(
      args: args,
      draft: draft ?? this.draft,
      defaults: defaults ?? this.defaults,
      vehicles: vehicles ?? this.vehicles,
      vehicle: vehicle ?? this.vehicle,
      isLoadingDefaults: isLoadingDefaults ?? this.isLoadingDefaults,
      isLoadingBaseline: isLoadingBaseline ?? this.isLoadingBaseline,
      hasNoVehicles: hasNoVehicles ?? this.hasNoVehicles,
      defaultsError: clearDefaultsError
          ? null
          : (defaultsError ?? this.defaultsError),
      baselineError: clearBaselineError
          ? null
          : (baselineError ?? this.baselineError),
      isSaving: isSaving ?? this.isSaving,
      saveError: clearSaveError ? null : (saveError ?? this.saveError),
      validation: validation ?? this.validation,
      isCategoryManuallySelected:
          isCategoryManuallySelected ?? this.isCategoryManuallySelected,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      uploadedReceipts: uploadedReceipts ?? this.uploadedReceipts,
      totalReceipts: totalReceipts ?? this.totalReceipts,
    );
  }
}

final expenseEntryControllerProvider = NotifierProvider.autoDispose
    .family<ExpenseEntryController, ExpenseEntryState, ExpenseEntryArgs>(
      ExpenseEntryController.new,
    );

class ExpenseEntryController extends Notifier<ExpenseEntryState> {
  ExpenseEntryController(this.args);

  final ExpenseEntryArgs args;

  int _baselineGeneration = 0;
  bool _saving = false;
  bool _odometerManuallyEdited = false;
  ExpenseEntryDraft? _initialDraft;

  @override
  ExpenseEntryState build() {
    _bootstrap();
    return ExpenseEntryState(
      args: args,
      draft: ExpenseEntryDraft.empty(args),
      defaults: const ExpenseEntryDefaults(),
    );
  }

  ExpenseEntryRepository get _repository =>
      ref.read(expenseEntryRepositoryProvider);

  Future<void> _bootstrap() async {
    try {
      final vehicles = await ref.read(vehiclesProvider.future);
      if (!ref.mounted) {
        return;
      }
      if (vehicles.isEmpty) {
        state = state.copyWith(
          vehicles: vehicles,
          isLoadingDefaults: false,
          hasNoVehicles: true,
        );
        return;
      }
      final initialId =
          args.initialVehicleId ?? ref.read(selectedVehicleIdProvider);
      final vehicle = _findVehicle(vehicles, initialId) ?? vehicles.first;
      final defaultsResult = await _loadDefaults(vehicle);
      if (!ref.mounted) {
        return;
      }
      final defaults = defaultsResult.defaults;

      if (args.mode == ExpenseEntryMode.edit && args.recordId != null) {
        final loaded = await _repository.fetchDraft(args.recordId!);
        if (!ref.mounted) {
          return;
        }
        final editVehicle = _findVehicle(vehicles, loaded.vehicleId) ?? vehicle;
        final editDefaults = editVehicle.id == vehicle.id
            ? defaults
            : (await _loadDefaults(editVehicle)).defaults;
        final draft = loaded
            .copyWith(vehicleId: editVehicle.id)
            .copyWith(
              detail: recomputeDetail(
                loaded.detail,
                loaded.amountCents,
                batteryCapacityKwh: editDefaults.batteryCapacityKwh,
              ),
            );
        _odometerManuallyEdited = draft.odometerKm != null;
        state = state.copyWith(
          vehicles: vehicles,
          vehicle: editVehicle,
          defaults: editDefaults,
          draft: draft,
          isLoadingDefaults: false,
          defaultsError: defaultsResult.error,
          clearDefaultsError: defaultsResult.error == null,
        );
        await _loadBaseline(
          editVehicle,
          draft.occurredAt,
          excludeRecordId: args.recordId,
        );
      } else {
        final category =
            args.initialCategory ??
            defaults.defaultCategory ??
            _defaultCategory(vehicle.powertrain);
        final place = args.initialPlace ?? defaults.lastPlace;
        var draft = state.draft.copyWith(
          vehicleId: vehicle.id,
          category: category,
          occurredAt: _minuteOf(args.initialOccurredAt ?? DateTime.now()),
          paymentChannel: defaults.paymentChannel,
          paymentLabel: defaults.paymentLabel,
          place: place,
          clearPlace: place == null,
          detail: defaultDetailFor(
            category,
            unitPrices: defaults.unitPrices,
            fuelGrade: defaults.fuelGrade,
            socStart: defaults.lastSoc ?? 20,
            place: place,
          ),
        );
        draft = draft.copyWith(
          detail: recomputeDetail(
            draft.detail,
            0,
            batteryCapacityKwh: defaults.batteryCapacityKwh,
          ),
        );
        state = state.copyWith(
          vehicles: vehicles,
          vehicle: vehicle,
          defaults: defaults,
          draft: draft,
          isLoadingDefaults: false,
          defaultsError: defaultsResult.error,
          clearDefaultsError: defaultsResult.error == null,
        );
        await _loadBaseline(vehicle, draft.occurredAt);
      }
      if (!ref.mounted) {
        return;
      }
      _initialDraft = state.draft;
      state = state.copyWith(hasUnsavedChanges: false);
    } catch (error) {
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(isLoadingDefaults: false, defaultsError: error);
    }
  }

  Future<({ExpenseEntryDefaults defaults, Object? error})> _loadDefaults(
    Vehicle vehicle,
  ) async {
    try {
      final defaults = await _repository.fetchDefaults(vehicle.id);
      return (defaults: defaults, error: null);
    } catch (error) {
      return (defaults: _fallbackDefaults(vehicle), error: error);
    }
  }

  ExpenseEntryDefaults _fallbackDefaults(Vehicle vehicle) {
    return ExpenseEntryDefaults(
      defaultCategory: _defaultCategory(vehicle.powertrain),
      fuelGrade: vehicle.defaultFuelGrade ?? 95,
      batteryCapacityKwh: vehicle.batteryCapacityKwh,
      tankCapacityL: vehicle.tankCapacityL,
    );
  }

  ExpenseCategory _defaultCategory(PowertrainType powertrain) {
    return switch (powertrain) {
      PowertrainType.ev || PowertrainType.phev => ExpenseCategory.charging,
      PowertrainType.hev || PowertrainType.ice => ExpenseCategory.fuel,
    };
  }

  Vehicle? _findVehicle(List<Vehicle> vehicles, String? id) {
    if (id == null) {
      return null;
    }
    for (final vehicle in vehicles) {
      if (vehicle.id == id) {
        return vehicle;
      }
    }
    return null;
  }

  Future<void> _loadBaseline(
    Vehicle vehicle,
    DateTime occurredAt, {
    String? excludeRecordId,
  }) async {
    final generation = ++_baselineGeneration;
    state = state.copyWith(isLoadingBaseline: true, clearBaselineError: true);
    try {
      final baseline = await _repository.fetchOdometerBaseline(
        vehicleId: vehicle.id,
        before: occurredAt,
        excludeRecordId: excludeRecordId,
      );
      if (!ref.mounted || generation != _baselineGeneration) {
        return;
      }
      final last = baseline.lastReadingKm;
      var draft = state.draft.copyWith(
        lastOdometerKm: last,
        clearLastOdometer: last == null,
      );
      if (!_odometerManuallyEdited) {
        if (!categoryUsesOdometer(state.draft.category)) {
          draft = draft.copyWith(clearOdometer: true);
        } else {
          final current = [
            ?baseline.currentOdometerKm,
            if (vehicle.odometerKm > 0) vehicle.odometerKm,
            ?last,
          ].fold<int>(0, (value, item) => item > value ? item : value);
          draft = draft.copyWith(odometerKm: current);
          if (draft.detail is MaintenanceDetail) {
            draft = draft.copyWith(
              detail: (draft.detail as MaintenanceDetail).copyWith(
                odometerKm: current,
              ),
            );
          }
        }
      }
      state = state.copyWith(
        draft: draft,
        isLoadingBaseline: false,
        clearBaselineError: true,
      );
      _updateDirty();
    } catch (error) {
      if (!ref.mounted || generation != _baselineGeneration) {
        return;
      }
      state = state.copyWith(isLoadingBaseline: false, baselineError: error);
    }
  }

  Future<void> selectVehicle(String vehicleId) async {
    final vehicle = _findVehicle(state.vehicles, vehicleId);
    if (vehicle == null || state.vehicle?.id == vehicleId) {
      return;
    }
    final defaultsResult = await _loadDefaults(vehicle);
    if (!ref.mounted) {
      return;
    }
    final defaults = defaultsResult.defaults;
    final category = state.isCategoryManuallySelected
        ? state.draft.category
        : (defaults.defaultCategory ?? _defaultCategory(vehicle.powertrain));
    final detail = defaultDetailFor(
      category,
      unitPrices: defaults.unitPrices,
      fuelGrade: defaults.fuelGrade,
      socStart: defaults.lastSoc ?? 20,
      place: state.draft.place ?? defaults.lastPlace,
    );
    _odometerManuallyEdited = false;
    state = state.copyWith(
      vehicle: vehicle,
      defaults: defaults,
      defaultsError: defaultsResult.error,
      clearDefaultsError: defaultsResult.error == null,
      draft: state.draft.copyWith(
        vehicleId: vehicle.id,
        category: category,
        detail: recomputeDetail(
          detail,
          state.draft.amountCents,
          batteryCapacityKwh: defaults.batteryCapacityKwh,
        ),
        clearOdometer: true,
        clearLastOdometer: true,
      ),
    );
    _updateDirty();
    await _loadBaseline(
      vehicle,
      state.draft.occurredAt,
      excludeRecordId: args.mode == ExpenseEntryMode.edit
          ? args.recordId
          : null,
    );
  }

  void selectCategory(ExpenseCategory category) {
    if (state.draft.category == category) {
      return;
    }
    final detail = defaultDetailFor(
      category,
      unitPrices: state.defaults.unitPrices,
      fuelGrade: state.defaults.fuelGrade,
      socStart: state.defaults.lastSoc ?? 20,
      place: state.draft.place,
    );
    final keepOdometer = categoryUsesOdometer(category);
    if (!keepOdometer) {
      _odometerManuallyEdited = false;
    }
    state = state.copyWith(
      isCategoryManuallySelected: true,
      validation: const EntryValidation.none(),
      draft: state.draft.copyWith(
        category: category,
        detail: recomputeDetail(
          detail,
          state.draft.amountCents,
          batteryCapacityKwh: state.defaults.batteryCapacityKwh,
        ),
        clearOdometer: !keepOdometer,
        clearLastOdometer: false,
      ),
    );
    _updateDirty();
    final vehicle = state.vehicle;
    if (keepOdometer && state.draft.odometerKm == null && vehicle != null) {
      _loadBaseline(
        vehicle,
        state.draft.occurredAt,
        excludeRecordId: args.mode == ExpenseEntryMode.edit
            ? args.recordId
            : null,
      );
    }
  }

  void setAmountCents(int cents) {
    final amount = cents < 0 ? 0 : cents;
    state = state.copyWith(
      validation: const EntryValidation.none(),
      draft: state.draft.copyWith(
        amountCents: amount,
        detail: recomputeDetail(
          state.draft.detail,
          amount,
          batteryCapacityKwh: state.defaults.batteryCapacityKwh,
        ),
      ),
    );
    _updateDirty();
  }

  void applyPreset(EntryPreset preset) {
    final amount = presetAmountCents(
      preset,
      draft: state.draft,
      batteryCapacityKwh: state.defaults.batteryCapacityKwh,
      tankCapacityL: state.defaults.tankCapacityL,
    );
    if (amount != null && amount > 0) {
      setAmountCents(amount);
    }
  }

  void setDetail(EntryCategoryDetail detail) {
    state = state.copyWith(
      validation: const EntryValidation.none(),
      draft: state.draft.copyWith(
        detail: recomputeDetail(
          detail,
          state.draft.amountCents,
          batteryCapacityKwh: state.defaults.batteryCapacityKwh,
        ),
      ),
    );
    _updateDirty();
  }

  void setChargingPrice(int centsPerKwh) {
    final detail = state.draft.detail;
    if (detail is! ChargingDetail) {
      return;
    }
    setDetail(detail.copyWith(unitPriceCentsPerKwh: centsPerKwh));
  }

  void setSocStart(int value) {
    final detail = state.draft.detail;
    if (detail is! ChargingDetail) {
      return;
    }
    setDetail(detail.copyWith(socStart: value.clamp(0, 100)));
  }

  void setFuelPrice(int centsPerLiter) {
    final detail = state.draft.detail;
    if (detail is! FuelDetail) {
      return;
    }
    setDetail(detail.copyWith(unitPriceCentsPerLiter: centsPerLiter));
  }

  void setFuelGrade(int grade) {
    final detail = state.draft.detail;
    if (detail is! FuelDetail || !const [92, 95, 98].contains(grade)) {
      return;
    }
    setDetail(detail.copyWith(fuelGrade: grade));
  }

  void setParkingRate(int centsPerHour) {
    final detail = state.draft.detail;
    if (detail is! ParkingDetail) {
      return;
    }
    setDetail(detail.copyWith(rateCentsPerHour: centsPerHour));
  }

  void setPlace(String? place) {
    final value = _limit(_trim(place), 30);
    var detail = state.draft.detail;
    detail = switch (detail) {
      ParkingDetail d => d.copyWith(
        lotName: value,
        clearLotName: value == null,
      ),
      MaintenanceDetail d => d.copyWith(
        shopName: value,
        clearShopName: value == null,
      ),
      CarWashDetail d => d.copyWith(
        shopName: value,
        clearShopName: value == null,
      ),
      _ => detail,
    };
    state = state.copyWith(
      draft: state.draft.copyWith(
        place: value,
        clearPlace: value == null,
        detail: detail,
      ),
    );
    _updateDirty();
  }

  void setPayment(PaymentChannel channel, String label) {
    state = state.copyWith(
      draft: state.draft.copyWith(paymentChannel: channel, paymentLabel: label),
    );
    _updateDirty();
  }

  void setOccurredAt(DateTime time) {
    final normalized = _minuteOf(time);
    if (normalized.isAtSameMomentAs(state.draft.occurredAt)) {
      return;
    }
    state = state.copyWith(
      draft: state.draft.copyWith(occurredAt: normalized),
      validation: const EntryValidation.none(),
    );
    _updateDirty();
    final vehicle = state.vehicle;
    if (vehicle != null) {
      _loadBaseline(
        vehicle,
        normalized,
        excludeRecordId: args.mode == ExpenseEntryMode.edit
            ? args.recordId
            : null,
      );
    }
  }

  void setOdometerKm(int? value) {
    _odometerManuallyEdited = state.draft.odometerKm != value;
    var detail = state.draft.detail;
    if (detail is MaintenanceDetail) {
      detail = detail.copyWith(odometerKm: value, clearOdometer: value == null);
    }
    state = state.copyWith(
      validation: const EntryValidation.none(),
      draft: state.draft.copyWith(
        odometerKm: value,
        clearOdometer: value == null,
        detail: detail,
      ),
    );
    _updateDirty();
  }

  void setNote(String? note) {
    final value = _limit(note == null ? null : _trim(note), 200);
    state = state.copyWith(
      draft: state.draft.copyWith(note: value, clearNote: value == null),
    );
    _updateDirty();
  }

  void addReceipt(ReceiptAttachment receipt) {
    final current = state.draft.receipts
        .where((item) => !item.isDeleted)
        .toList(growable: true);
    if (current.length >= 4) {
      return;
    }
    current.add(receipt);
    state = state.copyWith(draft: state.draft.copyWith(receipts: current));
    _updateDirty();
  }

  void removeReceipt(ReceiptAttachment receipt) {
    final receipts = state.draft.receipts
        .where((item) => item != receipt)
        .toList(growable: true);
    if (receipt.remoteId != null) {
      receipts.add(
        ReceiptAttachment(
          localPath: receipt.localPath,
          remoteId: receipt.remoteId,
          isDeleted: true,
        ),
      );
    }
    state = state.copyWith(draft: state.draft.copyWith(receipts: receipts));
    _updateDirty();
  }

  Future<void> retryDefaults() async {
    final vehicle = state.vehicle;
    if (vehicle == null) {
      return;
    }
    state = state.copyWith(isLoadingDefaults: true, clearDefaultsError: true);
    final result = await _loadDefaults(vehicle);
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      defaults: result.defaults,
      isLoadingDefaults: false,
      defaultsError: result.error,
      clearDefaultsError: result.error == null,
    );
  }

  Future<void> retryBaseline() async {
    final vehicle = state.vehicle;
    if (vehicle == null) {
      return;
    }
    await _loadBaseline(
      vehicle,
      state.draft.occurredAt,
      excludeRecordId: args.mode == ExpenseEntryMode.edit
          ? args.recordId
          : null,
    );
  }

  Future<ExpenseEntryResult?> save({bool forceOdometer = false}) async {
    if (_saving || !state.canSave) {
      return null;
    }
    final validation = validateDraft(state.draft);
    if (validation.needsOdometerConfirm && !forceOdometer) {
      state = state.copyWith(validation: validation);
      return null;
    }
    if (!validation.isValid) {
      state = state.copyWith(validation: validation);
      return null;
    }

    _saving = true;
    state = state.copyWith(
      isSaving: true,
      clearSaveError: true,
      validation: const EntryValidation.none(),
      uploadedReceipts: 0,
      totalReceipts: state.draft.receipts
          .where((item) => !item.isDeleted)
          .length,
    );
    try {
      final repository = ref.read(expenseEntryRepositoryProvider);
      final uploaded = await repository.uploadReceipts(
        state.draft.receipts,
        onProgress: (path, progress) {
          if (!ref.mounted) {
            return;
          }
          state = state.copyWith(uploadedReceipts: state.uploadedReceipts + 1);
        },
      );
      if (!ref.mounted) {
        return null;
      }
      final draft = state.draft.copyWith(receipts: uploaded);
      final record = args.mode == ExpenseEntryMode.create
          ? await repository.createExpense(draft)
          : await repository.updateExpense(args.recordId!, draft);
      if (!ref.mounted) {
        return null;
      }
      _invalidateDependents();
      _markClean();
      state = state.copyWith(isSaving: false, draft: draft);
      return ExpenseEntrySaved(
        recordId: record.id,
        isNew: args.mode == ExpenseEntryMode.create,
      );
    } on ExpenseEntryConflictException {
      if (!ref.mounted) {
        return null;
      }
      state = state.copyWith(isSaving: false);
      rethrow;
    } catch (error) {
      if (!ref.mounted) {
        return null;
      }
      state = state.copyWith(isSaving: false, saveError: error);
      return null;
    } finally {
      _saving = false;
    }
  }

  void _invalidateDependents() {
    ref.invalidate(ledgerRecordsProvider);
    ref.invalidate(ledgerSummaryProvider);
    ref.invalidate(homeDashboardProvider);
    ref.invalidate(breakdownProvider);
    ref.invalidate(recordsProvider);
    ref.invalidate(trendProvider);
    ref.invalidate(statsOverviewProvider);
    ref.invalidate(statsBreakdownProvider);
    ref.invalidate(statsRecentProvider);
    ref.invalidate(statsTrendProvider);
    ref.invalidate(monthlyReportProvider);
    ref.invalidate(profileOverviewProvider);
    ref.invalidate(vehiclesProvider);
  }

  void _updateDirty() {
    final initial = _initialDraft;
    if (initial == null) {
      return;
    }
    state = state.copyWith(hasUnsavedChanges: state.draft != initial);
  }

  void _markClean() {
    _initialDraft = state.draft;
    state = state.copyWith(hasUnsavedChanges: false);
  }

  DateTime _minuteOf(DateTime time) {
    final local = time.toLocal();
    return DateTime(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
    );
  }

  String? _trim(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  String? _limit(String? value, int max) {
    if (value == null || value.length <= max) {
      return value;
    }
    return value.substring(0, max);
  }
}
