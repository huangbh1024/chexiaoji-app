import 'dart:math' as math;

import '../../../core/domain/distance.dart';
import '../../../core/domain/enums.dart';
import '../../../core/format/formatters.dart';
import '../../ledger/domain/ledger_models.dart';
import '../../ledger/domain/ledger_presenter.dart';
import 'stats_models.dart';
import 'stats_period.dart';

int totalCentsOf(Iterable<LedgerRecord> records) =>
    records.fold(0, (sum, record) => sum + record.amountCents);

int energyCentsOf(Iterable<LedgerRecord> records) => records
    .where(
      (record) =>
          record.category == ExpenseCategory.charging ||
          record.category == ExpenseCategory.fuel,
    )
    .fold(0, (sum, record) => sum + record.amountCents);

({int km, DistanceSource source}) distanceOf(List<LedgerRecord> records) {
  return computeDistance([
    for (final record in records)
      DistanceSample(
        vehicleId: record.vehicleId,
        odometerKm: record.metrics.odometerKm,
        distanceKm: record.metrics.distanceKm,
      ),
  ]);
}

/// 周期汇总：总额、里程、每公里成本与环比。
StatsSummary buildStatsSummary({
  required StatsPeriod period,
  required List<LedgerRecord> records,
  required List<LedgerRecord> previousRecords,
  required DateTime now,
  DateTime? firstRecordAt,
}) {
  final totalCents = totalCentsOf(records);
  final energyCents = energyCentsOf(records);
  final distance = distanceOf(records);
  final previousTotal = previousRecords.isEmpty
      ? (period == StatsPeriod.all ? null : 0)
      : totalCentsOf(previousRecords);

  final change = compareTotals(totalCents, previousTotal);

  String? changeText;
  double? cumulativeYears;
  int? cumulativeDays;
  if (period == StatsPeriod.all) {
    final start = firstRecordAt;
    if (start == null) {
      changeText = '累计 0 天';
      cumulativeDays = 0;
    } else {
      final days = math.max(0, now.difference(start).inDays);
      cumulativeDays = days;
      if (days >= 30) {
        cumulativeYears = days / 365.25;
        changeText = '累计 ${cumulativeYears.toStringAsFixed(1)} 年';
      } else {
        changeText = '累计 $days 天';
      }
    }
  }

  return StatsSummary(
    totalCents: totalCents,
    distanceKm: distance.km,
    distanceSource: distance.source,
    costPerKmCents: distance.km <= 0
        ? null
        : (totalCents / distance.km).round(),
    energyCents: energyCents,
    energyCostPerKmCents: distance.km <= 0
        ? null
        : (energyCents / distance.km).round(),
    previousTotalCents: period == StatsPeriod.all ? null : previousTotal,
    changePercent: period == StatsPeriod.all ? null : change.percent,
    changeTrend: period == StatsPeriod.all ? TrendDirection.none : change.trend,
    changeText: changeText,
    cumulativeYears: cumulativeYears,
    cumulativeDays: cumulativeDays,
  );
}

({double? percent, TrendDirection trend}) compareTotals(
  int currentCents,
  int? previousCents,
) {
  if (previousCents == null || previousCents == 0) {
    return (percent: null, trend: TrendDirection.none);
  }
  final percent = (currentCents - previousCents) / previousCents * 100;
  if (percent.abs() < 0.05) {
    return (percent: 0, trend: TrendDirection.flat);
  }
  return (
    percent: percent,
    trend: percent > 0 ? TrendDirection.up : TrendDirection.down,
  );
}

/// 周期能耗：电耗、油耗与综合成本。
({double? kwhPer100km, double? litersPer100km}) consumptionOf(
  List<LedgerRecord> records,
  int distanceKm,
) {
  if (distanceKm <= 0) {
    return (kwhPer100km: null, litersPer100km: null);
  }
  final kwh = records
      .where((record) => record.category == ExpenseCategory.charging)
      .fold(0.0, (sum, record) => sum + (record.metrics.kwh ?? 0));
  final liters = records
      .where((record) => record.category == ExpenseCategory.fuel)
      .fold(0.0, (sum, record) => sum + (record.metrics.liters ?? 0));
  return (
    kwhPer100km: kwh > 0 ? kwh / distanceKm * 100 : null,
    litersPer100km: liters > 0 ? liters / distanceKm * 100 : null,
  );
}

/// 相对过去同长度周期均值的评级。
StatsRating ratingFor(double? current, double? baseline) {
  if (current == null || baseline == null || baseline <= 0) {
    return StatsRating.none;
  }
  final delta = (current - baseline) / baseline;
  if (delta <= -0.05) {
    return StatsRating.excellent;
  }
  if (delta >= 0.05) {
    return StatsRating.high;
  }
  return StatsRating.good;
}

/// 开销构成：金额降序、最多 6 类、<2% 并入「其他」、百分比最大余数法。
StatsBreakdown buildStatsBreakdown(List<LedgerRecord> records) {
  final totalCents = totalCentsOf(records);
  final sums = <ExpenseCategory, int>{};
  final counts = <ExpenseCategory, int>{};
  for (final record in records) {
    if (record.amountCents <= 0) {
      continue;
    }
    sums.update(
      record.category,
      (value) => value + record.amountCents,
      ifAbsent: () => record.amountCents,
    );
    counts.update(record.category, (value) => value + 1, ifAbsent: () => 1);
  }

  var entries =
      sums.entries
          .where((entry) => entry.value > 0)
          .map(
            (entry) => _Slice(entry.key, entry.value, counts[entry.key] ?? 0),
          )
          .toList()
        ..sort((a, b) => b.amountCents.compareTo(a.amountCents));

  var otherMerged = false;
  if (entries.length > 6) {
    final keep = entries.take(5).toList();
    final rest = entries.skip(5);
    keep.add(
      _Slice(
        ExpenseCategory.other,
        rest.fold(0, (sum, slice) => sum + slice.amountCents),
        rest.fold(0, (sum, slice) => sum + slice.count),
      ),
    );
    entries = keep;
    otherMerged = true;
  }

  if (entries.length > 2 && totalCents > 0) {
    final small = entries
        .where(
          (slice) =>
              slice.category != ExpenseCategory.other &&
              slice.amountCents * 100 < totalCents * 2,
        )
        .toList();
    if (small.isNotEmpty) {
      final other = entries.firstWhere(
        (slice) => slice.category == ExpenseCategory.other,
        orElse: () => const _Slice(ExpenseCategory.other, 0, 0),
      );
      entries = entries.where((slice) => !small.contains(slice)).toList()
        ..add(
          _Slice(
            ExpenseCategory.other,
            other.amountCents +
                small.fold(0, (sum, slice) => sum + slice.amountCents),
            other.count + small.fold(0, (sum, slice) => sum + slice.count),
          ),
        )
        ..sort((a, b) => b.amountCents.compareTo(a.amountCents));
      otherMerged = true;
    }
  }

  final percents = largestRemainder([
    for (final slice in entries) slice.amountCents,
  ], totalCents);

  return StatsBreakdown(
    totalCents: totalCents,
    count: records.length,
    categories: [
      for (var index = 0; index < entries.length; index++)
        StatsCategorySlice(
          category: entries[index].category,
          amountCents: entries[index].amountCents,
          count: entries[index].count,
          percent: percents[index],
        ),
    ],
    otherMerged: otherMerged,
  );
}

/// 最大余数法：保证百分比合计恰好 100。
List<int> largestRemainder(List<int> amounts, int total) {
  if (total <= 0 || amounts.isEmpty) {
    return List<int>.filled(amounts.length, 0);
  }
  final exact = [for (final amount in amounts) amount * 100 / total];
  final floors = [for (final value in exact) value.floor()];
  var diff = 100 - floors.fold(0, (sum, value) => sum + value);
  final order = List<int>.generate(amounts.length, (index) => index)
    ..sort((a, b) {
      final byFraction = (exact[b] - floors[b]).compareTo(exact[a] - floors[a]);
      return byFraction != 0 ? byFraction : a.compareTo(b);
    });
  for (var index = 0; index < diff; index++) {
    floors[order[index % order.length]]++;
  }
  return floors;
}

class _Slice {
  const _Slice(this.category, this.amountCents, this.count);

  final ExpenseCategory category;
  final int amountCents;
  final int count;
}

/// 趋势窗口的分桶。
List<StatsBucket> buildStatsBuckets({
  required StatsTrendRange range,
  required DateTime anchor,
  required List<LedgerRecord> records,
}) {
  final today = DateTime(anchor.year, anchor.month, anchor.day);
  switch (range) {
    case StatsTrendRange.d7:
    case StatsTrendRange.d30:
      final days = range == StatsTrendRange.d7 ? 7 : 30;
      final start = today.subtract(Duration(days: days - 1));
      return [
        for (var index = 0; index < days; index++)
          _dayBucket(
            records,
            DateTime(start.year, start.month, start.day + index),
          ),
      ];
    case StatsTrendRange.halfYear:
    case StatsTrendRange.year:
      final months = range == StatsTrendRange.halfYear ? 6 : 12;
      final start = DateTime(today.year, today.month - (months - 1));
      final spansYears = start.year != today.year;
      return [
        for (var index = 0; index < months; index++)
          _monthBucket(
            records,
            DateTime(start.year, start.month + index),
            spansYears: spansYears,
          ),
      ];
  }
}

/// 趋势窗口的起止时间。
({DateTime from, DateTime to}) statsTrendWindow(
  StatsTrendRange range,
  DateTime anchor,
) {
  final today = DateTime(anchor.year, anchor.month, anchor.day);
  switch (range) {
    case StatsTrendRange.d7:
    case StatsTrendRange.d30:
      final days = range == StatsTrendRange.d7 ? 7 : 30;
      final start = today.subtract(Duration(days: days - 1));
      return (
        from: start,
        to: DateTime(today.year, today.month, today.day, 23, 59, 59, 999),
      );
    case StatsTrendRange.halfYear:
    case StatsTrendRange.year:
      final months = range == StatsTrendRange.halfYear ? 6 : 12;
      final start = DateTime(today.year, today.month - (months - 1));
      final end = DateTime(today.year, today.month + 1, 0, 23, 59, 59, 999);
      return (from: start, to: end);
  }
}

/// 趋势窗口的上一个等长窗口。
({DateTime from, DateTime to}) previousStatsTrendWindow(
  StatsTrendRange range,
  DateTime anchor,
) {
  final window = statsTrendWindow(range, anchor);
  switch (range) {
    case StatsTrendRange.d7:
    case StatsTrendRange.d30:
      final days = range == StatsTrendRange.d7 ? 7 : 30;
      return (
        from: window.from.subtract(Duration(days: days)),
        to: window.from.subtract(const Duration(milliseconds: 1)),
      );
    case StatsTrendRange.halfYear:
    case StatsTrendRange.year:
      final months = range == StatsTrendRange.halfYear ? 6 : 12;
      return (
        from: DateTime(window.from.year, window.from.month - months),
        to: window.from.subtract(const Duration(milliseconds: 1)),
      );
  }
}

StatsTrend buildStatsTrend({
  required StatsTrendQuery query,
  required List<LedgerRecord> records,
  required List<LedgerRecord> previousRecords,
  required DateTime now,
}) {
  final window = statsTrendWindow(query.range, now);
  final buckets = buildStatsBuckets(
    range: query.range,
    anchor: now,
    records: records,
  );
  final totalCents = buckets.fold(0, (sum, bucket) => sum + bucket.totalCents);
  final previousTotal = previousRecords.isEmpty
      ? 0
      : totalCentsOf(previousRecords);
  final change = compareTotals(totalCents, previousTotal);

  int? peakIndex;
  var peakTotal = 0;
  for (var index = 0; index < buckets.length; index++) {
    if (buckets[index].totalCents >= peakTotal) {
      peakTotal = buckets[index].totalCents;
      peakIndex = index;
    }
  }
  if (peakTotal <= 0) {
    peakIndex = null;
  }

  return StatsTrend(
    query: query,
    from: window.from,
    to: window.to,
    totalCents: totalCents,
    previousTotalCents: previousTotal,
    changePercent: change.percent,
    changeTrend: change.trend,
    axis: buildStatsAxis(buckets),
    peakIndex: peakIndex,
    buckets: buckets,
  );
}

StatsAxis buildStatsAxis(List<StatsBucket> buckets) {
  final maxBucket = buckets.fold(
    0,
    (maxValue, bucket) => math.max(maxValue, bucket.totalCents),
  );
  if (maxBucket <= 0) {
    return const StatsAxis(
      maxCents: 10000,
      ticksCents: [0, 2500, 5000, 7500, 10000],
    );
  }
  final step = _niceCeil(maxBucket / 3);
  return StatsAxis(
    maxCents: step * 3,
    ticksCents: [0, step, step * 2, step * 3],
  );
}

int _niceCeil(double value) {
  if (value <= 0) {
    return 1;
  }
  final magnitude = math
      .pow(10, (math.log(value) / math.ln10).floor())
      .toDouble();
  for (final multiplier in const [1.0, 2.0, 5.0, 10.0]) {
    if (value <= multiplier * magnitude) {
      return (multiplier * magnitude).round();
    }
  }
  return (10 * magnitude).round();
}

StatsBucket _dayBucket(List<LedgerRecord> records, DateTime date) {
  final dayRecords = _recordsOnDay(records, date);
  return StatsBucket(
    start: date,
    label: '${date.month}/${date.day}',
    energyCents: energyCentsOf(dayRecords),
    otherCents: totalCentsOf(dayRecords) - energyCentsOf(dayRecords),
    count: dayRecords.length,
    dominantCategory: _dominantCategory(dayRecords),
  );
}

StatsBucket _monthBucket(
  List<LedgerRecord> records,
  DateTime month, {
  required bool spansYears,
}) {
  final monthRecords = records
      .where(
        (record) =>
            record.occurredAt.year == month.year &&
            record.occurredAt.month == month.month,
      )
      .toList(growable: false);
  final label = spansYears
      ? '${month.year % 100}/${month.month}'
      : '${month.month}月';
  return StatsBucket(
    start: month,
    label: label,
    energyCents: energyCentsOf(monthRecords),
    otherCents: totalCentsOf(monthRecords) - energyCentsOf(monthRecords),
    count: monthRecords.length,
    dominantCategory: _dominantCategory(monthRecords),
  );
}

List<LedgerRecord> _recordsOnDay(List<LedgerRecord> records, DateTime day) {
  return records
      .where(
        (record) =>
            record.occurredAt.year == day.year &&
            record.occurredAt.month == day.month &&
            record.occurredAt.day == day.day,
      )
      .toList(growable: false);
}

ExpenseCategory? _dominantCategory(List<LedgerRecord> records) {
  final sums = <ExpenseCategory, int>{};
  for (final record in records) {
    if (record.amountCents <= 0) {
      continue;
    }
    sums.update(
      record.category,
      (value) => value + record.amountCents,
      ifAbsent: () => record.amountCents,
    );
  }
  if (sums.isEmpty) {
    return null;
  }
  var best = sums.entries.first;
  for (final entry in sums.entries) {
    if (entry.value > best.value) {
      best = entry;
    }
  }
  return best.key;
}

/// 单条记录 → 统计页最近记录。
StatsRecord buildStatsRecord(LedgerRecord record, {bool showVehicle = false}) {
  final subtitle = record.subtitle;
  final day = formatDayTitle(record.occurredAt);
  final parts = <String>[
    if (showVehicle) record.vehicleShortName,
    day,
    if (subtitle != null && subtitle.isNotEmpty) subtitle,
  ];
  return StatsRecord(
    id: record.id,
    vehicleId: record.vehicleId,
    vehicleShortName: record.vehicleShortName,
    category: record.category,
    title: '${record.category.label} · ${record.title}',
    subtitle: parts.join(' · '),
    amountCents: record.amountCents,
    occurredAt: record.occurredAt,
    tag: statsRecordTag(record),
  );
}

String? statsRecordTag(LedgerRecord record) {
  switch (record.category) {
    case ExpenseCategory.charging:
    case ExpenseCategory.fuel:
      final distance = record.metrics.distanceKm;
      if (distance == null || distance <= 0) {
        return null;
      }
      final perKm = record.amountCents / 100 / distance;
      return '¥${formatTwoDecimals(perKm)}/km';
    case ExpenseCategory.maintenance:
      final description = record.description ?? '';
      return description.contains('大') ? '大保养' : '小保养';
    case ExpenseCategory.parking:
      return '临时停车';
    case ExpenseCategory.toll:
    case ExpenseCategory.carWash:
    case ExpenseCategory.other:
      return null;
  }
}

/// 最近 [limit] 条记录（已按时间倒序）。
List<StatsRecord> recentStatsRecords(
  List<LedgerRecord> records, {
  int limit = 3,
  bool showVehicle = false,
}) {
  final sorted = [...records]
    ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  return [
    for (final record in sorted.take(limit))
      buildStatsRecord(record, showVehicle: showVehicle),
  ];
}

/// 生成周期内最多 7 个点的能耗迷你走势，无有效点时返回空。
List<double> consumptionSparkline(
  List<LedgerRecord> records,
  StatsRange range, {
  required bool useKwh,
}) {
  if (distanceOf(records).km <= 0) {
    return const <double>[];
  }
  final values = <double>[];
  final days = math.max(1, range.end.difference(range.start).inDays + 1);
  final step = math.max(1, (days / 7).ceil());
  for (
    var day = DateTime(range.start.year, range.start.month, range.start.day);
    !day.isAfter(range.end);
    day = DateTime(day.year, day.month, day.day + step)
  ) {
    final next = DateTime(day.year, day.month, day.day + step);
    final windowRecords = records
        .where(
          (record) =>
              !record.occurredAt.isBefore(day) &&
              record.occurredAt.isBefore(next),
        )
        .toList(growable: false);
    if (windowRecords.isEmpty) {
      continue;
    }
    final windowDistance = distanceOf(windowRecords).km;
    if (windowDistance <= 0) {
      continue;
    }
    final consumption = consumptionOf(windowRecords, windowDistance);
    final value = useKwh ? consumption.kwhPer100km : consumption.litersPer100km;
    if (value != null) {
      values.add(value);
    }
  }
  return values.length >= 2 ? values : const <double>[];
}

/// 车队综合能源成本 /km 的迷你走势。
List<double> energyCostSparkline(List<LedgerRecord> records, StatsRange range) {
  final values = <double>[];
  final days = math.max(1, range.end.difference(range.start).inDays + 1);
  final step = math.max(1, (days / 7).ceil());
  for (
    var day = DateTime(range.start.year, range.start.month, range.start.day);
    !day.isAfter(range.end);
    day = DateTime(day.year, day.month, day.day + step)
  ) {
    final next = DateTime(day.year, day.month, day.day + step);
    final windowRecords = records
        .where(
          (record) =>
              !record.occurredAt.isBefore(day) &&
              record.occurredAt.isBefore(next),
        )
        .toList(growable: false);
    final distance = distanceOf(windowRecords).km;
    if (distance <= 0) {
      continue;
    }
    final energy = energyCentsOf(windowRecords);
    if (energy <= 0) {
      continue;
    }
    values.add(energy / distance);
  }
  return values.length >= 2 ? values : const <double>[];
}
