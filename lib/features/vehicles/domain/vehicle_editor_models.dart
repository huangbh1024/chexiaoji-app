import 'package:flutter/foundation.dart';

import '../../../core/domain/enums.dart';

/// 编辑器参数：`vehicleId == null` 为新增。
@immutable
class VehicleEditorArgs {
  const VehicleEditorArgs.create() : vehicleId = null;
  const VehicleEditorArgs.edit(this.vehicleId);

  final String? vehicleId;

  bool get isCreate => vehicleId == null;

  @override
  bool operator ==(Object other) =>
      other is VehicleEditorArgs && other.vehicleId == vehicleId;

  @override
  int get hashCode => vehicleId.hashCode;
}

@immutable
class VehicleEditorResult {
  const VehicleEditorResult({
    required this.vehicleId,
    required this.created,
    this.archived = false,
  });

  final String vehicleId;
  final bool created;
  final bool archived;
}

enum VehicleEditorMode { create, edit }

enum VehicleEditorStatus { loading, ready, notFound, archived, error }

enum VehicleEditorField {
  name,
  specLabel,
  nickname,
  plate,
  odometer,
  battery,
  officialConsumption,
  electricRange,
  tank,
  fuelGrade,
  purchaseDate,
  purchasePrice,
  nextMaintenance,
  insuranceExpiry,
}

/// 编辑页表单的不可变值对象。
@immutable
class VehicleEditorDraft {
  const VehicleEditorDraft({
    this.name = '',
    this.specLabel = '',
    this.nickname = '',
    this.province = '粤',
    this.plateBody = '',
    this.isGreenPlate = true,
    this.odometerKm,
    this.powertrain = PowertrainType.ev,
    this.batteryCapacityKwh,
    this.officialConsumption,
    this.electricRangeKm,
    this.tankCapacityL,
    this.defaultFuelGrade,
    this.purchaseDate,
    this.purchasePriceCents,
    this.nextMaintenanceKm,
    this.insuranceExpiry,
    this.makePrimary = false,
  });

  final String name;
  final String specLabel;
  final String nickname;
  final String province;

  /// 已规范化：大写、去分隔符、不含「·」。
  final String plateBody;
  final bool isGreenPlate;
  final int? odometerKm;
  final PowertrainType powertrain;

  final double? batteryCapacityKwh;

  /// EV 为官方电耗；PHEV 为亏电油耗；HEV / ICE 为综合 / 标称油耗。
  final double? officialConsumption;

  final int? electricRangeKm;
  final double? tankCapacityL;
  final int? defaultFuelGrade;
  final DateTime? purchaseDate;
  final int? purchasePriceCents;
  final int? nextMaintenanceKm;
  final DateTime? insuranceExpiry;
  final bool makePrimary;

  String get plate {
    final normalized = plateBody.toUpperCase().replaceAll(
      RegExp(r'[\s·•\-]'),
      '',
    );
    if (normalized.length <= 1) {
      return '$province$normalized';
    }
    return '$province${normalized[0]}·${normalized.substring(1)}';
  }

  VehicleEditorDraft copyWith({
    String? name,
    String? specLabel,
    String? nickname,
    String? province,
    String? plateBody,
    bool? isGreenPlate,
    int? odometerKm,
    bool clearOdometer = false,
    PowertrainType? powertrain,
    double? batteryCapacityKwh,
    bool clearBattery = false,
    double? officialConsumption,
    bool clearOfficialConsumption = false,
    int? electricRangeKm,
    bool clearElectricRange = false,
    double? tankCapacityL,
    bool clearTank = false,
    int? defaultFuelGrade,
    bool clearFuelGrade = false,
    DateTime? purchaseDate,
    bool clearPurchaseDate = false,
    int? purchasePriceCents,
    bool clearPurchasePrice = false,
    int? nextMaintenanceKm,
    bool clearNextMaintenance = false,
    DateTime? insuranceExpiry,
    bool clearInsurance = false,
    bool? makePrimary,
  }) {
    return VehicleEditorDraft(
      name: name ?? this.name,
      specLabel: specLabel ?? this.specLabel,
      nickname: nickname ?? this.nickname,
      province: province ?? this.province,
      plateBody: plateBody ?? this.plateBody,
      isGreenPlate: isGreenPlate ?? this.isGreenPlate,
      odometerKm: clearOdometer ? null : (odometerKm ?? this.odometerKm),
      powertrain: powertrain ?? this.powertrain,
      batteryCapacityKwh: clearBattery
          ? null
          : (batteryCapacityKwh ?? this.batteryCapacityKwh),
      officialConsumption: clearOfficialConsumption
          ? null
          : (officialConsumption ?? this.officialConsumption),
      electricRangeKm: clearElectricRange
          ? null
          : (electricRangeKm ?? this.electricRangeKm),
      tankCapacityL: clearTank ? null : (tankCapacityL ?? this.tankCapacityL),
      defaultFuelGrade: clearFuelGrade
          ? null
          : (defaultFuelGrade ?? this.defaultFuelGrade),
      purchaseDate: clearPurchaseDate
          ? null
          : (purchaseDate ?? this.purchaseDate),
      purchasePriceCents: clearPurchasePrice
          ? null
          : (purchasePriceCents ?? this.purchasePriceCents),
      nextMaintenanceKm: clearNextMaintenance
          ? null
          : (nextMaintenanceKm ?? this.nextMaintenanceKm),
      insuranceExpiry: clearInsurance
          ? null
          : (insuranceExpiry ?? this.insuranceExpiry),
      makePrimary: makePrimary ?? this.makePrimary,
    );
  }

  Map<String, Object?> toMap() => {
    'name': name,
    'specLabel': specLabel,
    'nickname': nickname,
    'province': province,
    'plateBody': plateBody,
    'isGreenPlate': isGreenPlate,
    'odometerKm': odometerKm,
    'powertrain': powertrain.name,
    'batteryCapacityKwh': batteryCapacityKwh,
    'officialConsumption': officialConsumption,
    'electricRangeKm': electricRangeKm,
    'tankCapacityL': tankCapacityL,
    'defaultFuelGrade': defaultFuelGrade,
    'purchaseDate': purchaseDate?.toIso8601String(),
    'purchasePriceCents': purchasePriceCents,
    'nextMaintenanceKm': nextMaintenanceKm,
    'insuranceExpiry': insuranceExpiry?.toIso8601String(),
    'makePrimary': makePrimary,
  };

  @override
  bool operator ==(Object other) =>
      other is VehicleEditorDraft && mapEquals(toMap(), other.toMap());

  @override
  int get hashCode => Object.hashAll(toMap().values);
}

@immutable
class VehicleEditorSnapshot {
  const VehicleEditorSnapshot({
    required this.vehicleId,
    required this.draft,
    required this.isPrimary,
    required this.activeVehicleCount,
    required this.maxActiveVehicles,
    required this.version,
    this.latestOdometerKm,
    this.successorName,
    this.isOnlyActiveVehicle = false,
  });

  final String vehicleId;
  final VehicleEditorDraft draft;
  final bool isPrimary;
  final int activeVehicleCount;
  final int maxActiveVehicles;
  final int version;
  final int? latestOdometerKm;
  final String? successorName;
  final bool isOnlyActiveVehicle;
}

@immutable
class VehicleEditorState {
  const VehicleEditorState({
    required this.args,
    required this.draft,
    this.status = VehicleEditorStatus.loading,
    this.initialDraft,
    this.fieldErrors = const {},
    this.formError,
    this.isSaving = false,
    this.isPrimaryLocked = false,
    this.activeVehicleCount = 0,
    this.maxActiveVehicles = 10,
    this.latestOdometerKm,
    this.version,
    this.successorName,
    this.isOnlyActiveVehicle = false,
  });

  final VehicleEditorArgs args;
  final VehicleEditorDraft draft;
  final VehicleEditorStatus status;
  final VehicleEditorDraft? initialDraft;
  final Map<VehicleEditorField, String> fieldErrors;
  final String? formError;
  final bool isSaving;
  final bool isPrimaryLocked;
  final int activeVehicleCount;
  final int maxActiveVehicles;
  final int? latestOdometerKm;
  final int? version;
  final String? successorName;
  final bool isOnlyActiveVehicle;

  VehicleEditorMode get mode =>
      args.isCreate ? VehicleEditorMode.create : VehicleEditorMode.edit;

  bool get isDirty => initialDraft != null && draft != initialDraft;
  bool get isReady => status == VehicleEditorStatus.ready;
  bool get canSubmit => isReady && !isSaving;

  VehicleEditorState copyWith({
    VehicleEditorDraft? draft,
    VehicleEditorStatus? status,
    VehicleEditorDraft? initialDraft,
    Map<VehicleEditorField, String>? fieldErrors,
    String? formError,
    bool clearFormError = false,
    bool? isSaving,
    bool? isPrimaryLocked,
    int? activeVehicleCount,
    int? maxActiveVehicles,
    int? latestOdometerKm,
    int? version,
    String? successorName,
    bool? isOnlyActiveVehicle,
  }) {
    return VehicleEditorState(
      args: args,
      draft: draft ?? this.draft,
      status: status ?? this.status,
      initialDraft: initialDraft ?? this.initialDraft,
      fieldErrors: fieldErrors ?? this.fieldErrors,
      formError: clearFormError ? null : (formError ?? this.formError),
      isSaving: isSaving ?? this.isSaving,
      isPrimaryLocked: isPrimaryLocked ?? this.isPrimaryLocked,
      activeVehicleCount: activeVehicleCount ?? this.activeVehicleCount,
      maxActiveVehicles: maxActiveVehicles ?? this.maxActiveVehicles,
      latestOdometerKm: latestOdometerKm ?? this.latestOdometerKm,
      version: version ?? this.version,
      successorName: successorName ?? this.successorName,
      isOnlyActiveVehicle: isOnlyActiveVehicle ?? this.isOnlyActiveVehicle,
    );
  }
}
