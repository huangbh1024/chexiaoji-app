/// 账本聚合的公共口径。
///
/// 首页、统计页、月度报表与「我的」共用这些纯函数：同一个月 + 同一辆车的
/// 总额、里程、能耗与分类构成必须由同一套规则算出，避免各页面各写一份公式
/// 导致数字对不上。
library;

import '../../../core/domain/distance.dart';
import '../../../core/domain/enums.dart';
import 'ledger_models.dart';

/// 记录金额合计：支出为正、退款为负。
int totalCentsOf(Iterable<LedgerRecord> records) =>
    records.fold(0, (sum, record) => sum + record.amountCents);

/// 充电 + 加油金额合计。
int energyCentsOf(Iterable<LedgerRecord> records) => records
    .where(
      (record) =>
          record.category == ExpenseCategory.charging ||
          record.category == ExpenseCategory.fuel,
    )
    .fold(0, (sum, record) => sum + record.amountCents);

/// 周期里程：每辆车优先取里程表读数极差，读数不足时用单笔距离求和。
({int km, DistanceSource source}) distanceOf(Iterable<LedgerRecord> records) {
  return computeDistance([
    for (final record in records)
      DistanceSample(
        vehicleId: record.vehicleId,
        odometerKm: record.metrics.odometerKm,
        distanceKm: record.metrics.distanceKm,
      ),
  ]);
}

/// 周期能耗：百公里电耗 / 油耗。
({double? kwhPer100km, double? litersPer100km}) consumptionOf(
  Iterable<LedgerRecord> records,
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

/// 环比：[previousCents] 为 null 或 0 时返回「无对比」。
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

/// 最大余数法：百分比合计恰好等于 [total]（默认 100）。
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

/// 分类构成中的一行。
class CategoryAmount {
  const CategoryAmount({
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

/// 分类构成聚合结果。
class CategoryBreakdown {
  const CategoryBreakdown({
    required this.totalCents,
    required this.count,
    required this.items,
    required this.otherMerged,
  });

  final int totalCents;
  final int count;
  final List<CategoryAmount> items;
  final bool otherMerged;

  bool get isEmpty => items.isEmpty || totalCents <= 0;
}

/// 分类构成：金额降序、最多 [maxCategories] 类、<2% 并入「其他」、
/// 百分比用最大余数法保证合计 100。
///
/// 「其他」永远只出现一次：若合并过程中已经有「其他」，新并入的金额会
/// 累加到同一个切片，而不是再追加一行。
CategoryBreakdown buildCategoryBreakdown(
  Iterable<LedgerRecord> records, {
  int maxCategories = 6,
}) {
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
  if (entries.length > maxCategories) {
    final keep = <_Slice>[];
    var otherAmount = 0;
    var otherCount = 0;
    for (final slice in entries) {
      if (slice.category == ExpenseCategory.other) {
        otherAmount += slice.amountCents;
        otherCount += slice.count;
      } else if (keep.length < maxCategories - 1) {
        keep.add(slice);
      } else {
        otherAmount += slice.amountCents;
        otherCount += slice.count;
      }
    }
    keep.add(_Slice(ExpenseCategory.other, otherAmount, otherCount));
    entries = keep;
    otherMerged = true;
  }

  if (entries.length > 2) {
    final small = entries
        .where(
          (slice) =>
              slice.category != ExpenseCategory.other &&
              totalCents > 0 &&
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
        );
      otherMerged = true;
    }
  }

  entries.sort((a, b) => b.amountCents.compareTo(a.amountCents));

  final sliceTotal = entries.fold(0, (sum, slice) => sum + slice.amountCents);
  final percents = largestRemainder([
    for (final slice in entries) slice.amountCents,
  ], sliceTotal);

  return CategoryBreakdown(
    totalCents: totalCents,
    count: records.length,
    items: [
      for (var index = 0; index < entries.length; index++)
        CategoryAmount(
          category: entries[index].category,
          amountCents: entries[index].amountCents,
          count: entries[index].count,
          percent: percents[index],
        ),
    ],
    otherMerged: otherMerged,
  );
}

class _Slice {
  const _Slice(this.category, this.amountCents, this.count);

  final ExpenseCategory category;
  final int amountCents;
  final int count;
}

/// 一个时间桶：日或月。
class LedgerBucket {
  const LedgerBucket({
    required this.start,
    required this.end,
    required this.records,
  });

  final DateTime start;
  final DateTime end;
  final List<LedgerRecord> records;

  int get totalCents => totalCentsOf(records);
  int get energyCents => energyCentsOf(records);
  int get otherCents => totalCents - energyCents;
}

/// 按本地自然日分桶，覆盖 [from] 到 [to] 的每一天（含空桶）。
List<LedgerBucket> bucketRecordsByDay(
  Iterable<LedgerRecord> records, {
  required DateTime from,
  required DateTime to,
}) {
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);
  final buckets = <LedgerBucket>[];
  var cursor = start;
  while (!cursor.isAfter(end)) {
    final next = DateTime(cursor.year, cursor.month, cursor.day + 1);
    buckets.add(
      LedgerBucket(
        start: cursor,
        end: next,
        records: _within(records, cursor, next),
      ),
    );
    cursor = next;
  }
  return buckets;
}

/// 按本地自然月分桶，覆盖 [from] 到 [to] 的每一月（含空桶）。
List<LedgerBucket> bucketRecordsByMonth(
  Iterable<LedgerRecord> records, {
  required DateTime from,
  required DateTime to,
}) {
  final start = DateTime(from.year, from.month);
  final end = DateTime(to.year, to.month);
  final buckets = <LedgerBucket>[];
  var cursor = start;
  while (!cursor.isAfter(end)) {
    final next = DateTime(cursor.year, cursor.month + 1);
    buckets.add(
      LedgerBucket(
        start: cursor,
        end: next,
        records: _within(records, cursor, next),
      ),
    );
    cursor = next;
  }
  return buckets;
}

List<LedgerRecord> _within(
  Iterable<LedgerRecord> records,
  DateTime from,
  DateTime to,
) {
  return [
    for (final record in records)
      if (!record.occurredAt.isBefore(from) && record.occurredAt.isBefore(to))
        record,
  ];
}

/// 时刻是否落在 [from, to]（两端含）。
bool isWithinRange(DateTime time, DateTime from, DateTime to) =>
    !time.isBefore(from) && !time.isAfter(to);
