import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/domain/enums.dart';
import '../../../core/format/formatters.dart';
import '../../../core/presentation/category_style.dart';
import 'expense_entry_detail.dart';
import 'expense_entry_math.dart';
import 'expense_entry_models.dart';

/// 录入页的分类文案。账单页使用 [ExpenseCategoryLabel.filterLabel]。
extension ExpenseCategoryEntryText on ExpenseCategory {
  String get entryLabel => switch (this) {
    ExpenseCategory.charging => '充电',
    ExpenseCategory.fuel => '加油',
    ExpenseCategory.parking => '停车',
    ExpenseCategory.toll => '过路费',
    ExpenseCategory.maintenance => '保养维修',
    ExpenseCategory.carWash => '洗车美容',
    ExpenseCategory.other => '车险车税',
  };

  String get entryHint => switch (this) {
    ExpenseCategory.charging || ExpenseCategory.fuel => '已开启智能能耗折算',
    ExpenseCategory.parking => '按停车费率折算',
    ExpenseCategory.toll => 'ETC 通行记录',
    ExpenseCategory.maintenance ||
    ExpenseCategory.carWash ||
    ExpenseCategory.other => '明细选填',
  };

  String get entryCaption => switch (this) {
    ExpenseCategory.charging => '新能源补能',
    ExpenseCategory.fuel => '燃油加注',
    ExpenseCategory.parking => '停车缴费',
    ExpenseCategory.toll => '路桥通行',
    ExpenseCategory.maintenance => '常规保养',
    ExpenseCategory.carWash => '美容清洗',
    ExpenseCategory.other => '车险车税',
  };
}

@immutable
class TelemetrySegment {
  const TelemetrySegment({
    required this.prefix,
    required this.value,
    required this.suffix,
  });

  final String prefix;
  final String value;
  final String suffix;
}

abstract final class EntryTelemetryPresenter {
  static List<TelemetrySegment> build(
    ExpenseEntryDraft draft, {
    double? batteryCapacityKwh,
  }) {
    final amount = draft.amountCents;
    final distance = draft.distanceKm;
    final perKm = costPerKm(amount, distance);
    return switch (draft.detail) {
      ChargingDetail d => [
        if (perKm != null)
          TelemetrySegment(
            prefix: '约 ',
            value: '¥${formatTwoDecimals(perKm)}',
            suffix: ' / km',
          ),
        if (d.kwh != null)
          TelemetrySegment(
            prefix: '充入约 ',
            value: formatOneDecimal(d.kwh!),
            suffix: ' kWh',
          ),
      ],
      FuelDetail d => [
        if (perKm != null)
          TelemetrySegment(
            prefix: '约 ',
            value: '¥${formatTwoDecimals(perKm)}',
            suffix: ' / km',
          ),
        if (d.liters != null)
          TelemetrySegment(
            prefix: '加注约 ',
            value: formatTwoDecimals(d.liters!),
            suffix: ' 升',
          ),
      ],
      ParkingDetail d => [
        if (d.durationMinutes != null)
          TelemetrySegment(
            prefix: '时长约 ',
            value: formatDuration(d.durationMinutes!),
            suffix: '',
          ),
        if (d.rateCentsPerHour > 0)
          TelemetrySegment(
            prefix: '费率 ',
            value: formatYuanDetail(d.rateCentsPerHour),
            suffix: ' / h',
          ),
      ],
      TollDetail d => [
        if (d.distanceKm != null)
          TelemetrySegment(
            prefix: '通行里程约 ',
            value: formatCount(d.distanceKm!),
            suffix: ' km',
          ),
      ],
      _ => const <TelemetrySegment>[],
    };
  }
}

/// 分类的快捷金额；「充满 / 加满」依赖车辆容量，容量未知时隐藏。
List<EntryPreset> presetsFor({
  required ExpenseEntryDraft draft,
  double? batteryCapacityKwh,
  double? tankCapacityL,
}) {
  final category = draft.category;
  final amounts = switch (category) {
    ExpenseCategory.charging => const [3000, 5000, 10000, 20000],
    ExpenseCategory.fuel => const [20000, 30000, 40000, 50000],
    ExpenseCategory.parking => const [500, 1000, 2000, 3000, 5000],
    ExpenseCategory.toll => const [1000, 2000, 3000, 5000, 10000],
    ExpenseCategory.maintenance => const [20000, 50000, 100000, 200000, 300000],
    ExpenseCategory.carWash => const [3000, 5000, 8000, 10000, 15000],
    ExpenseCategory.other => const [50000, 100000, 200000, 300000, 500000],
  };
  final presets = [for (final amount in amounts) EntryPreset.amount(amount)];
  if (category == ExpenseCategory.charging) {
    final detail = draft.detail is ChargingDetail
        ? draft.detail as ChargingDetail
        : const ChargingDetail();
    final full = fullChargeCents(
      batteryCapacityKwh: batteryCapacityKwh,
      socStart: detail.socStart,
      unitPriceCentsPerKwh: detail.unitPriceCentsPerKwh,
    );
    if (full != null) {
      presets.add(const EntryPreset.full('充满'));
    }
  }
  if (category == ExpenseCategory.fuel) {
    final detail = draft.detail is FuelDetail
        ? draft.detail as FuelDetail
        : const FuelDetail();
    final full = fullTankCents(
      tankCapacityL: tankCapacityL,
      unitPriceCentsPerLiter: detail.unitPriceCentsPerLiter,
    );
    if (full != null) {
      presets.add(const EntryPreset.full('加满'));
    }
  }
  return presets;
}

/// 快捷金额点击后得到的金额（分）。
int? presetAmountCents(
  EntryPreset preset, {
  required ExpenseEntryDraft draft,
  double? batteryCapacityKwh,
  double? tankCapacityL,
}) {
  if (preset.kind == EntryPresetKind.amount) {
    return preset.amountCents;
  }
  if (draft.category == ExpenseCategory.charging) {
    final detail = draft.detail;
    if (detail is! ChargingDetail) {
      return null;
    }
    return fullChargeCents(
      batteryCapacityKwh: batteryCapacityKwh,
      socStart: detail.socStart,
      unitPriceCentsPerKwh: detail.unitPriceCentsPerKwh,
    );
  }
  if (draft.category == ExpenseCategory.fuel) {
    final detail = draft.detail;
    if (detail is! FuelDetail) {
      return null;
    }
    return fullTankCents(
      tankCapacityL: tankCapacityL,
      unitPriceCentsPerLiter: detail.unitPriceCentsPerLiter,
    );
  }
  return null;
}

/// 分类参数卡标题与右侧提示。
({String title, String hint}) paramsHeader(ExpenseEntryDraft draft) {
  return switch (draft.detail) {
    ChargingDetail _ => (title: '补能明细参数', hint: '充电桩结算数据'),
    FuelDetail _ => (title: '加油明细参数', hint: '加油枪计量数据'),
    ParkingDetail _ => (title: '停车计费明细', hint: '按停车费率折算'),
    TollDetail _ => (title: '过路通行参数', hint: '按实际缴费记录'),
    MaintenanceDetail _ => (title: '保养项目与门店', hint: '保养记录'),
    CarWashDetail _ => (title: '洗车服务', hint: '美容清洗'),
    InsuranceDetail _ => (title: '保单与周期', hint: '车险车税'),
    EmptyEntryDetail _ => (
      title: draft.category.entryCaption,
      hint: draft.category.entryHint,
    ),
  };
}

/// 车辆卡的动力徽标底色 / 文字色。
Color powertrainBadgeColor(PowertrainType type, AppPalette palette) =>
    type.badgeTextColor(palette);

String categoryIconCaption(ExpenseCategory category) => category.captionLabel;
