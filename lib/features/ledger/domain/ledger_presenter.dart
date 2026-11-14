import '../../../core/domain/enums.dart';
import '../../../core/format/formatters.dart';
import 'ledger_models.dart';

/// 记录卡的展示文案推导。
///
/// 单位与取值跨页统一：充电用 `¥/kWh`、加油用 `¥/L`，与首页
/// 「最近记录」的副指标一致；每公里成本不再出现在列表卡片上。
extension LedgerRecordPresentation on LedgerRecord {
  /// 支出带 `-`，退款 / 报销显示正数。
  String get expenseText => amountCents >= 0
      ? '-${formatYuanDetail(amountCents)}'
      : '+${formatYuanDetail(amountCents.abs())}';

  /// 单价胶囊：充电 `¥/kWh`、加油 `¥/L`，其余分类为 null。
  String? get unitPricePillText {
    switch (category) {
      case ExpenseCategory.charging:
        final kwh = metrics.kwh;
        if (kwh == null || kwh <= 0) {
          return null;
        }
        return formatUnitPrice((amountCents / kwh).round(), 'kWh');
      case ExpenseCategory.fuel:
        final liters = metrics.liters;
        if (liters == null || liters <= 0) {
          return null;
        }
        return formatUnitPrice((amountCents / liters).round(), 'L');
      case ExpenseCategory.maintenance:
      case ExpenseCategory.parking:
      case ExpenseCategory.toll:
      case ExpenseCategory.carWash:
      case ExpenseCategory.other:
        return null;
    }
  }

  /// 右侧辅助文案：有单价胶囊时不再显示。
  String? get trailingText => unitPricePillText == null ? statusText : null;

  /// 副标题：按分类拼装，缺失字段自动跳过。
  String? get subtitle {
    final parts = <String>[];
    switch (category) {
      case ExpenseCategory.charging:
        final kwh = metrics.kwh;
        if (kwh != null && kwh > 0) {
          parts.add(formatKwh(kwh));
        }
        final odometer = metrics.odometerKm;
        if (odometer != null) {
          parts.add('里程 ${formatKm(odometer)}');
        }
      case ExpenseCategory.fuel:
        final liters = metrics.liters;
        if (liters != null && liters > 0) {
          parts.add(formatLiters(liters));
        }
        final odometer = metrics.odometerKm;
        if (odometer != null) {
          parts.add('里程 ${formatKm(odometer)}');
        }
      case ExpenseCategory.parking:
        final duration = metrics.durationMinutes;
        if (duration != null && duration > 0) {
          parts.add('停车时长 ${formatDuration(duration)}');
        }
        final plate = metrics.plate;
        if (plate != null && plate.isNotEmpty) {
          parts.add(plate);
        }
      case ExpenseCategory.maintenance:
      case ExpenseCategory.carWash:
      case ExpenseCategory.toll:
      case ExpenseCategory.other:
        final description = _description;
        if (description != null && description.isNotEmpty) {
          parts.add(description);
        }
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String? get _description => description ?? note;
}
