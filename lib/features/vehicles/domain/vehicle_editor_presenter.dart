import 'dart:math';

import '../../../core/domain/enums.dart';
import '../../../core/domain/vehicle.dart';
import '../../../core/format/formatters.dart';
import '../data/vehicle_editor_catalog.dart';
import '../data/vehicle_repository.dart';
import '../data/vehicle_store.dart';
import 'vehicle_editor_models.dart';

class PlateOwner {
  const PlateOwner({required this.plate, required this.name});

  final String plate;
  final String name;
}

/// 编辑器纯函数：车牌、校验、展示文案与模型映射。
abstract final class VehicleEditorPresenter {
  static const commonProvinces = VehicleEditorCatalog.commonProvinces;
  static const allProvinces = VehicleEditorCatalog.allProvinces;
  static const quickModels = VehicleEditorCatalog.quickModels;
  static const fuelGrades = VehicleEditorCatalog.fuelGrades;

  static String normalizePlateBody(String raw) =>
      raw.toUpperCase().replaceAll(RegExp(r'[\s·•\-]'), '');

  static String formatPlateBody(String body) {
    final normalized = normalizePlateBody(body);
    if (normalized.length <= 1) {
      return normalized;
    }
    return '${normalized[0]}·${normalized.substring(1)}';
  }

  static String fullPlate(String province, String body) =>
      '$province${formatPlateBody(body)}';

  static ({String province, String body}) splitPlate(String plate) {
    final trimmed = plate.trim();
    if (trimmed.isEmpty) {
      return (province: '粤', body: '');
    }
    final province = trimmed.substring(0, 1);
    final rest = normalizePlateBody(trimmed.substring(1));
    return (province: province, body: rest);
  }

  static bool samePlate(String a, String b) =>
      _normalizeFullPlate(a) == _normalizeFullPlate(b);

  static String _normalizeFullPlate(String plate) =>
      normalizePlateBody(plate).toUpperCase();

  static bool isElectric(PowertrainType type) =>
      type == PowertrainType.ev || type == PowertrainType.phev;

  static bool isFuel(PowertrainType type) => type != PowertrainType.ev;

  static bool defaultGreenPlate(PowertrainType type) => isElectric(type);

  static int plateBodyMaxLength(bool green) => green ? 7 : 6;

  static String powertrainSublabel(PowertrainType type) => switch (type) {
    PowertrainType.ev => '电耗核算',
    PowertrainType.phev => '双模计量',
    PowertrainType.hev => '油混计量',
    PowertrainType.ice => '标称油耗',
  };

  static String fuelConsumptionLabel(PowertrainType type) => switch (type) {
    PowertrainType.ev => '官方百公里电耗',
    PowertrainType.phev => '百公里亏电油耗',
    PowertrainType.hev => '综合油耗',
    PowertrainType.ice => '标称综合油耗',
  };

  static String fuelConsumptionUnit(PowertrainType type) =>
      type == PowertrainType.ev ? 'kWh/100km' : 'L/100km';

  static String titleOf(VehicleEditorMode mode) =>
      mode == VehicleEditorMode.create ? '添加爱车档案' : '编辑爱车档案';

  static String subtitleOf(VehicleEditorState state) {
    if (state.isSaving) {
      return '正在保存…';
    }
    if (state.status == VehicleEditorStatus.loading) {
      return '正在读取档案…';
    }
    if (state.formError != null) {
      return '保存失败，请重试';
    }
    if (state.isDirty) {
      return '有未保存的修改';
    }
    if (state.mode == VehicleEditorMode.create) {
      return '新建车辆档案 · 保存至本地';
    }
    return '档案编号 #${shortCodeOf(state.args.vehicleId)} · 本地档案';
  }

  static String shortCodeOf(String? id) {
    final normalized = (id ?? '').replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (normalized.isEmpty) {
      return '';
    }
    final tail = normalized.length <= 5
        ? normalized
        : normalized.substring(normalized.length - 5);
    return tail.toUpperCase();
  }

  static String successMessageOf({
    required String name,
    required bool created,
    required bool primary,
    required bool archived,
  }) {
    if (archived) {
      return '已将「$name」归档';
    }
    if (created) {
      return primary ? '「$name」已添加到车库，并设为默认主驾' : '「$name」已添加到车库';
    }
    return primary ? '「$name」档案已更新，并设为默认主驾' : '「$name」档案已更新';
  }

  static String errorMessageFor(VehicleErrorCode code) => switch (code) {
    VehicleErrorCode.duplicatePlate => '该车牌已在车库中',
    VehicleErrorCode.limitReached => '车库车辆已达上限（10 辆），请先归档不再使用的车辆',
    VehicleErrorCode.notFound => '车辆已不存在，请返回车库刷新',
    VehicleErrorCode.notArchived => '该车辆已归档，请在已归档车辆中恢复后再修改',
    VehicleErrorCode.conflict => '车辆信息已更新，请刷新后重试',
    VehicleErrorCode.isPrimary => '默认主驾需在车辆管理中切换',
    VehicleErrorCode.invalidField => '请检查填写内容',
    VehicleErrorCode.hasRecords => '该车辆有历史流水，请先归档',
    VehicleErrorCode.plateTailMismatch => '车牌尾号不匹配',
    VehicleErrorCode.unknown => '保存失败，请重试',
  };

  /// 按字段顺序返回错误，调用方可直接定位第一个错误。
  static Map<VehicleEditorField, String> validate(
    VehicleEditorDraft draft, {
    required DateTime now,
    int? latestOdometerKm,
    List<PlateOwner> knownVehicles = const [],
  }) {
    final errors = <VehicleEditorField, String>{};
    final type = draft.powertrain;
    final electric = isElectric(type);
    final fuel = isFuel(type);

    final name = draft.name.trim();
    if (name.isEmpty) {
      errors[VehicleEditorField.name] = '请填写品牌与车型';
    } else if (name.length < 2 || name.length > 40) {
      errors[VehicleEditorField.name] = '品牌与车型需为 2–40 个字符';
    }

    if (draft.specLabel.trim().length > 30) {
      errors[VehicleEditorField.specLabel] = '配置版本不能超过 30 个字符';
    }
    if (draft.nickname.trim().length > 12) {
      errors[VehicleEditorField.nickname] = '昵称不能超过 12 个字符';
    }

    final body = normalizePlateBody(draft.plateBody);
    final expected = plateBodyMaxLength(draft.isGreenPlate);
    final pattern = draft.isGreenPlate
        ? RegExp(r'^[A-Z][A-Z0-9]{6}$')
        : RegExp(r'^[A-Z][A-Z0-9]{5}$');
    if (body.isEmpty) {
      errors[VehicleEditorField.plate] = '请填写车牌号码';
    } else if (body.length != expected || !pattern.hasMatch(body)) {
      errors[VehicleEditorField.plate] = draft.isGreenPlate
          ? '新能源车牌需为城市字母 + 6 位字母数字'
          : '燃油车牌需为城市字母 + 5 位字母数字';
    } else {
      final full = fullPlate(draft.province, body);
      for (final owner in knownVehicles) {
        if (samePlate(owner.plate, full)) {
          errors[VehicleEditorField.plate] = '该车牌已在车库中（${owner.name}）';
          break;
        }
      }
    }

    final odometer = draft.odometerKm;
    if (odometer == null) {
      errors[VehicleEditorField.odometer] = '请填写当前总里程';
    } else if (odometer < 0 || odometer > 9999999) {
      errors[VehicleEditorField.odometer] = '请输入 0–9,999,999 之间的里程';
    } else if (latestOdometerKm != null && odometer < latestOdometerKm) {
      errors[VehicleEditorField.odometer] =
          '当前总里程不能小于最近记账里程 ${formatKmValue(latestOdometerKm)} km';
    }

    if (electric) {
      _validateRange(
        errors,
        VehicleEditorField.battery,
        draft.batteryCapacityKwh,
        1,
        300,
        '电池容量需在 1–300 kWh 之间',
      );
    }
    _validateRange(
      errors,
      VehicleEditorField.officialConsumption,
      draft.officialConsumption,
      0.1,
      100,
      '${fuelConsumptionLabel(type)}需在 0.1–100 之间',
    );
    if (type == PowertrainType.phev) {
      _validateRange(
        errors,
        VehicleEditorField.electricRange,
        draft.electricRangeKm?.toDouble(),
        1,
        2000,
        '纯电续航需在 1–2,000 km 之间',
      );
    }
    if (fuel) {
      _validateRange(
        errors,
        VehicleEditorField.tank,
        draft.tankCapacityL,
        1,
        300,
        '油箱容积需在 1–300 L 之间',
      );
    }

    final purchaseDate = draft.purchaseDate;
    if (purchaseDate != null) {
      final date = _dateOnly(purchaseDate);
      if (date.isAfter(_dateOnly(now))) {
        errors[VehicleEditorField.purchaseDate] = '购车时间不能晚于今天';
      } else if (date.isBefore(DateTime(1980))) {
        errors[VehicleEditorField.purchaseDate] = '购车时间不能早于 1980 年';
      }
    }

    final price = draft.purchasePriceCents;
    if (price != null && (price < 0 || price > 1000000000)) {
      errors[VehicleEditorField.purchasePrice] = '购车价格需在 0–1,000 万元之间';
    }

    final next = draft.nextMaintenanceKm;
    if (next != null && (next < 0 || next > 9999999)) {
      errors[VehicleEditorField.nextMaintenance] = '请输入有效里程';
    }

    final insurance = draft.insuranceExpiry;
    if (insurance != null && (insurance.year < 1980 || insurance.year > 2100)) {
      errors[VehicleEditorField.insuranceExpiry] = '请选择有效日期';
    }

    return errors;
  }

  static VehicleEditorDraft draftOf(
    VehicleRecord record, {
    int? latestOdometerKm,
    bool isPrimary = false,
  }) {
    final split = splitPlate(record.vehicle.plate);
    return VehicleEditorDraft(
      name: record.vehicle.name,
      specLabel: record.specLabel,
      nickname: record.nickname ?? '',
      province: split.province,
      plateBody: split.body,
      isGreenPlate: split.body.length >= 7,
      odometerKm: max(record.vehicle.odometerKm, latestOdometerKm ?? 0),
      powertrain: record.vehicle.powertrain,
      batteryCapacityKwh: record.vehicle.batteryCapacityKwh,
      officialConsumption: record.officialConsumption,
      electricRangeKm: record.electricRangeKm,
      tankCapacityL: record.vehicle.tankCapacityL,
      defaultFuelGrade: record.vehicle.defaultFuelGrade,
      purchaseDate: record.purchaseDate,
      purchasePriceCents: record.purchasePriceCents,
      nextMaintenanceKm: record.nextMaintenanceKm,
      insuranceExpiry: record.insuranceExpiry,
      makePrimary: isPrimary,
    );
  }

  static Vehicle buildVehicle({
    required VehicleEditorDraft draft,
    required String id,
    String? badge,
  }) {
    final type = draft.powertrain;
    final electric = isElectric(type);
    final fuel = isFuel(type);
    return Vehicle(
      id: id,
      name: draft.name.trim(),
      plate: draft.plate,
      powertrain: type,
      powertrainLabel: type.label,
      odometerKm: draft.odometerKm!,
      badge: badge,
      batteryCapacityKwh: electric ? draft.batteryCapacityKwh : null,
      tankCapacityL: fuel ? draft.tankCapacityL : null,
      defaultFuelGrade: fuel ? draft.defaultFuelGrade : null,
    );
  }

  static VehicleRecord buildRecord({
    required Vehicle vehicle,
    required VehicleEditorDraft draft,
    required int sortOrder,
    VehicleRecord? existing,
  }) {
    final type = draft.powertrain;
    return VehicleRecord(
      vehicle: vehicle,
      specLabel: draft.specLabel.trim(),
      sortOrder: existing?.sortOrder ?? sortOrder,
      isArchived: existing?.isArchived ?? false,
      archivedAt: existing?.archivedAt,
      nickname: _nullIfBlank(draft.nickname),
      officialConsumption: draft.officialConsumption,
      electricRangeKm: type == PowertrainType.phev
          ? draft.electricRangeKm
          : null,
      purchaseDate: draft.purchaseDate,
      purchasePriceCents: draft.purchasePriceCents,
      nextMaintenanceKm: draft.nextMaintenanceKm,
      batteryHealthPercent: existing?.batteryHealthPercent,
      insuranceExpiry: draft.insuranceExpiry,
      inspectionExpiry: existing?.inspectionExpiry,
    );
  }

  static int? parseWanToCents(String text) {
    final value = double.tryParse(text.trim());
    if (value == null) {
      return null;
    }
    return (value * 1000000).round();
  }

  static String formatWanInput(int? cents) {
    if (cents == null) {
      return '';
    }
    final text = (cents / 1000000).toStringAsFixed(2);
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  static String formatInputDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static void _validateRange(
    Map<VehicleEditorField, String> errors,
    VehicleEditorField field,
    double? value,
    double min,
    double max,
    String message,
  ) {
    if (value == null) {
      return;
    }
    if (value < min || value > max) {
      errors[field] = message;
    }
  }

  static String? _nullIfBlank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
