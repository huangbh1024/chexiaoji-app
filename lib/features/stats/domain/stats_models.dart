import 'package:material_ui/material_ui.dart';

import '../../../core/domain/distance.dart';
import '../../../core/domain/enums.dart';
import 'stats_period.dart';

/// 能耗评级；`fleet` 仅用于全部车辆。
enum StatsRating { excellent, good, high, fleet, none }

@immutable
class StatsEnergyValue {
  const StatsEnergyValue({required this.value, required this.unit});

  /// null 表示无法计算，界面显示「—」。
  final double? value;

  /// `kWh/100km`、`L/100km`、`CNY/km`。
  final String unit;
}

@immutable
class StatsOverview {
  const StatsOverview({
    required this.scope,
    required this.range,
    required this.powertrain,
    required this.summary,
    required this.consumption,
    required this.maintenance,
    required this.dataUpdatedAt,
  });

  final StatsScope scope;
  final StatsRange range;

  /// null 表示全部车辆。
  final PowertrainType? powertrain;
  final StatsSummary summary;
  final StatsConsumption consumption;
  final StatsMaintenance? maintenance;
  final DateTime? dataUpdatedAt;
}

@immutable
class StatsSummary {
  const StatsSummary({
    required this.totalCents,
    required this.distanceKm,
    required this.distanceSource,
    required this.costPerKmCents,
    required this.energyCents,
    required this.energyCostPerKmCents,
    required this.previousTotalCents,
    required this.changePercent,
    required this.changeTrend,
    this.changeText,
    this.cumulativeYears,
    this.cumulativeDays,
  });

  final int totalCents;
  final int distanceKm;
  final DistanceSource distanceSource;

  /// 分 / 公里；里程为 0 时为 null。
  final int? costPerKmCents;
  final int energyCents;
  final int? energyCostPerKmCents;
  final int? previousTotalCents;
  final double? changePercent;
  final TrendDirection changeTrend;

  /// 全部范围时为「累计 2.1 年」。
  final String? changeText;
  final double? cumulativeYears;

  /// 不足 30 天时的累计天数。
  final int? cumulativeDays;
}

@immutable
class StatsConsumption {
  const StatsConsumption({
    required this.rating,
    required this.primary,
    this.secondary,
    this.sparkline = const <double>[],
  });

  final StatsRating rating;
  final StatsEnergyValue primary;
  final StatsEnergyValue? secondary;
  final List<double> sparkline;
}

@immutable
class StatsMaintenance {
  const StatsMaintenance({
    required this.enabled,
    required this.vehicleId,
    required this.vehicleName,
    required this.tag,
    required this.remainingKm,
    required this.progressPercent,
    required this.status,
    this.remainingDays,
  });

  final bool enabled;
  final String vehicleId;
  final String vehicleName;
  final String tag;
  final int remainingKm;
  final int progressPercent;
  final MaintenanceStatus status;
  final int? remainingDays;

  bool get isOverdue => status == MaintenanceStatus.overdue || remainingKm < 0;
  bool get isWarning =>
      status == MaintenanceStatus.warning || progressPercent > 80;
}

@immutable
class StatsBreakdown {
  const StatsBreakdown({
    required this.totalCents,
    required this.count,
    required this.categories,
    required this.otherMerged,
  });

  final int totalCents;
  final int count;
  final List<StatsCategorySlice> categories;
  final bool otherMerged;

  bool get isEmpty => categories.isEmpty || totalCents <= 0;
}

@immutable
class StatsCategorySlice {
  const StatsCategorySlice({
    required this.category,
    required this.amountCents,
    required this.count,
    required this.percent,
  });

  final ExpenseCategory category;
  final int amountCents;
  final int count;
  final int percent;
}

@immutable
class StatsTrend {
  const StatsTrend({
    required this.query,
    required this.from,
    required this.to,
    required this.totalCents,
    required this.previousTotalCents,
    required this.changePercent,
    required this.changeTrend,
    required this.axis,
    required this.peakIndex,
    required this.buckets,
  });

  final StatsTrendQuery query;
  final DateTime from;
  final DateTime to;
  final int totalCents;
  final int? previousTotalCents;
  final double? changePercent;
  final TrendDirection changeTrend;
  final StatsAxis axis;
  final int? peakIndex;
  final List<StatsBucket> buckets;

  bool get isEmpty => totalCents <= 0;
}

@immutable
class StatsBucket {
  const StatsBucket({
    required this.start,
    required this.label,
    required this.energyCents,
    required this.otherCents,
    required this.count,
    this.dominantCategory,
  });

  final DateTime start;
  final String label;
  final int energyCents;
  final int otherCents;
  final int count;
  final ExpenseCategory? dominantCategory;

  int get totalCents => energyCents + otherCents;
}

@immutable
class StatsAxis {
  const StatsAxis({required this.maxCents, required this.ticksCents});

  final int maxCents;
  final List<int> ticksCents;
}

@immutable
class StatsRecord {
  const StatsRecord({
    required this.id,
    required this.vehicleId,
    required this.vehicleShortName,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.amountCents,
    required this.occurredAt,
    this.tag,
  });

  final String id;
  final String vehicleId;
  final String vehicleShortName;
  final ExpenseCategory category;
  final String title;
  final String? subtitle;
  final int amountCents;
  final DateTime occurredAt;
  final String? tag;
}
