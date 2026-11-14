import '../../../core/domain/enums.dart';

/// 基础枚举与车辆模型已迁到 `core/domain`，这里 re-export 保持历史 import 可用。
export '../../../core/domain/enums.dart';
export '../../../core/domain/vehicle.dart';

enum MaintenanceStatus { normal, warning, overdue }

enum TrendRange {
  d7('7d', '7天'),
  d30('30d', '30天'),
  halfYear('6m', '半年'),
  year('1y', '1年');

  const TrendRange(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

class EnergyValue {
  const EnergyValue({required this.value, required this.unit});

  final double value;
  final String unit;
}

class Consumption {
  const Consumption({
    required this.label,
    required this.typeLabel,
    required this.primary,
    required this.primarySparkline,
    this.secondary,
    this.secondarySparkline = const <double>[],
  });

  final String label;
  final String typeLabel;
  final EnergyValue primary;
  final EnergyValue? secondary;
  final List<double> primarySparkline;
  final List<double> secondarySparkline;
}

class Maintenance {
  const Maintenance({
    required this.enabled,
    required this.remainingKm,
    required this.progressPercent,
    required this.status,
    this.remainingDays,
  });

  final bool enabled;
  final int remainingKm;
  final int? remainingDays;

  /// 0–100，表示保养周期已使用的比例。
  final int progressPercent;
  final MaintenanceStatus status;

  bool get isOverdue => status == MaintenanceStatus.overdue || remainingKm < 0;

  bool get isWarning =>
      status == MaintenanceStatus.warning || progressPercent > 80;
}

class HomeSummary {
  const HomeSummary({
    required this.costPerKm,
    required this.monthSpendCents,
    required this.monthMileageKm,
    required this.energyCostPerKm,
    required this.momTrend,
    this.momChangePercent,
  });

  final double costPerKm;
  final int monthSpendCents;
  final int monthMileageKm;
  final double energyCostPerKm;
  final double? momChangePercent;
  final TrendDirection momTrend;
}

class HomeDashboard {
  const HomeDashboard({
    required this.vehicle,
    required this.summary,
    required this.consumption,
    required this.maintenance,
  });

  final Vehicle vehicle;
  final HomeSummary summary;
  final Consumption consumption;
  final Maintenance maintenance;
}

class BreakdownCategory {
  const BreakdownCategory({
    required this.category,
    required this.amountCents,
    required this.percent,
  });

  final ExpenseCategory category;
  final int amountCents;
  final int percent;
}

class Breakdown {
  const Breakdown({
    required this.totalCents,
    required this.count,
    required this.categories,
  });

  final int totalCents;
  final int count;
  final List<BreakdownCategory> categories;
}

class RecordItem {
  const RecordItem({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.amountCents,
    this.subLabel,
  });

  final String id;
  final ExpenseCategory category;
  final String title;
  final String subtitle;
  final int amountCents;

  /// 充电为 `¥/kWh`（单价），加油为 `¥/L`（单价），其他分类为空。
  final String? subLabel;
}

class TrendPoint {
  const TrendPoint({
    required this.date,
    required this.energyCents,
    required this.otherCents,
  });

  final DateTime date;
  final int energyCents;
  final int otherCents;
}

class TrendData {
  const TrendData({
    required this.range,
    required this.points,
    required this.totalCents,
    required this.previousTotalCents,
  });

  final TrendRange range;
  final List<TrendPoint> points;
  final int totalCents;
  final int previousTotalCents;

  int get diffCents => totalCents - previousTotalCents;

  TrendDirection get direction {
    if (totalCents == previousTotalCents) {
      return TrendDirection.flat;
    }
    return totalCents > previousTotalCents
        ? TrendDirection.up
        : TrendDirection.down;
  }
}
