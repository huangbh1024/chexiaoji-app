import '../../../core/domain/enums.dart';
import '../../../core/format/formatters.dart';
import 'stats_models.dart';
import 'stats_period.dart';

String heroPeriodLabel(StatsPeriod period, StatsRange range) =>
    '综合每公里成本 · ${range.label}';

String changeLabel({
  required StatsRange range,
  required TrendDirection trend,
  required double? percent,
  required String? changeText,
}) {
  if (changeText != null && changeText.isNotEmpty) {
    return changeText;
  }
  if (percent == null) {
    return '暂无对比';
  }
  return '${range.comparisonLabel} ${formatSignedPercent(percent)}';
}

String periodSubLabel(StatsRange range) => '${range.shortLabel}总开销';

String periodMileageLabel(StatsRange range) => '${range.shortLabel}行驶';

String energyCostTitle(PowertrainType? powertrain) {
  if (powertrain == null) {
    return '综合能源成本';
  }
  return switch (powertrain) {
    PowertrainType.ev => '纯电能源成本',
    PowertrainType.hev => '燃油能源成本',
    PowertrainType.ice => '燃油能源成本',
    PowertrainType.phev => '综合能源成本',
  };
}

String consumptionTitle(PowertrainType? powertrain) {
  if (powertrain == null) {
    return '综合能耗成本';
  }
  return switch (powertrain) {
    PowertrainType.ev || PowertrainType.phev => '平均百公里电耗',
    PowertrainType.hev || PowertrainType.ice => '平均百公里油耗',
  };
}

String consumptionUnit(String apiUnit) {
  return switch (apiUnit) {
    'kWh/100km' => 'kWh/百公里',
    'L/100km' => 'L/百公里',
    'CNY/km' => '/km',
    _ => apiUnit,
  };
}

String ratingLabel(StatsRating rating) {
  return switch (rating) {
    StatsRating.excellent => '优异',
    StatsRating.good => '良好',
    StatsRating.high => '偏高',
    StatsRating.fleet => '车队',
    StatsRating.none => '—',
  };
}

String costPerKmText(int? cents) =>
    cents == null ? '—' : '¥${formatTwoDecimals(cents / 100)}';

String breakdownBadge(StatsRange range, int count) =>
    '${range.shortLabel} · 共 $count 笔';

String maintenanceDescription(StatsMaintenance maintenance) {
  if (!maintenance.enabled) {
    return '未设置保养计划';
  }
  if (maintenance.isOverdue) {
    return '已超期 ${formatKmValue(maintenance.remainingKm.abs())} km';
  }
  final days = maintenance.remainingDays;
  final base = days == null ? 'km 后' : '预计约 $days 天';
  if (maintenance.isWarning) {
    return '$base · 即将保养';
  }
  return base;
}

String maintenanceValue(StatsMaintenance maintenance) {
  if (!maintenance.enabled) {
    return '—';
  }
  return formatKmValue(maintenance.remainingKm.abs());
}

String trendChangeLabel(StatsTrend trend) {
  if (trend.previousTotalCents == 0) {
    return '暂无对比';
  }
  if (trend.changePercent == null) {
    return '暂无对比';
  }
  final diff = trend.totalCents - (trend.previousTotalCents ?? 0);
  final direction = trend.changeTrend;
  final abs = formatYuanCompact(diff.abs());
  return switch (direction) {
    TrendDirection.down => '比上期少 $abs',
    TrendDirection.up => '比上期多 $abs',
    TrendDirection.flat || TrendDirection.none => '与上期持平',
  };
}

String formatYuanAxis(double value) {
  if (value >= 10000) {
    final k = value / 1000;
    final text = k == k.roundToDouble()
        ? k.toStringAsFixed(0)
        : k.toStringAsFixed(1);
    return '¥${text}k';
  }
  return '¥${value.toInt()}';
}

String formatEnergyValue(double value, String apiUnit) {
  if (apiUnit == 'CNY/km') {
    return '¥${formatTwoDecimals(value)}';
  }
  return formatOneDecimal(value);
}

String costPerKmValue(int cents) => formatTwoDecimals(cents / 100);

String trendBucketTooltip(StatsBucket bucket) {
  final date = bucket.start;
  final label = bucket.label.contains('/')
      ? '${date.month}/${date.day}'
      : '${date.month}月';
  final category = bucket.dominantCategory?.label ?? '开销';
  return '$label $category ${formatYuanCompact(bucket.totalCents)}';
}
