import 'dart:math' as math;

import '../../../core/domain/enums.dart';
import '../../../core/domain/vehicle.dart';
import '../../ledger/domain/ledger_models.dart';
import 'report_models.dart';

/// 本期无真实云端校验时的中性文案。
const String kLocalVerificationText = '数据由车小记本地账本汇总 · 请核对后使用';

/// 由记录聚合出月度报表。
///
/// 聚合口径与账单页一致：同一 `month + vehicleId` 的总额、笔数与
/// 分类金额必须相等。纯函数，便于单测与 Mock / 后端 DTO 共用。
MonthlyReport buildMonthlyReport({
  required ReportScope scope,
  required List<LedgerRecord> records,
  required List<Vehicle> vehicles,
  required DateTime now,
  int? previousTotalCents,
}) {
  final month = DateTime(scope.month.year, scope.month.month);
  final days = DateTime(month.year, month.month + 1, 0).day;
  final isCurrent = month.year == now.year && month.month == now.month;
  final lastDay = isCurrent ? now.day : days;

  final totalCents = records.fold(0, (sum, record) => sum + record.amountCents);
  final distance = computeDistanceKmByVehicle(records);
  final energyKwh = records
      .where((record) => record.category == ExpenseCategory.charging)
      .fold(0.0, (sum, record) => sum + (record.metrics.kwh ?? 0));
  final fuelLiters = records
      .where((record) => record.category == ExpenseCategory.fuel)
      .fold(0.0, (sum, record) => sum + (record.metrics.liters ?? 0));

  final scopedVehicles = scope.vehicleId == null
      ? vehicles
      : vehicles
            .where((vehicle) => vehicle.id == scope.vehicleId)
            .toList(growable: false);

  final momPercent = momPercentFor(totalCents, previousTotalCents);

  return MonthlyReport(
    scope: ReportScope(month: month, vehicleId: scope.vehicleId),
    reportNo: reportNoFor(scope),
    status: isCurrent ? ReportStatus.recording : ReportStatus.issued,
    generatedAt: now,
    updatedAt: isCurrent
        ? now
        : DateTime(month.year, month.month, days, 23, 59),
    settledAt: isCurrent
        ? null
        : DateTime(month.year, month.month, days, 23, 59, 59),
    totalCents: totalCents,
    recordCount: records.length,
    distanceKm: distance.km,
    distanceSource: distance.source,
    days: days,
    costPerKmCents: distance.km <= 0
        ? null
        : (totalCents / distance.km).round(),
    energyKwh: energyKwh,
    fuelLiters: fuelLiters,
    kwhPer100km: distance.km <= 0 ? null : energyKwh / distance.km * 100,
    litersPer100km: distance.km <= 0 ? null : fuelLiters / distance.km * 100,
    momPercent: momPercent,
    momTrend: trendFor(totalCents, previousTotalCents),
    vehicles: [
      for (final vehicle in scopedVehicles)
        ReportVehicleBrief(
          id: vehicle.id,
          name: vehicle.name,
          shortName: vehicle.name,
          plate: vehicle.plate,
          powertrain: vehicle.powertrain,
          powertrainLabel: vehicle.powertrainLabel,
          odometerKm: vehicle.odometerKm,
          recordCount: records
              .where((record) => record.vehicleId == vehicle.id)
              .length,
        ),
    ],
    categories: buildCategoryGroups(records, totalCents),
    daily: buildDailyPoints(records, month, lastDay),
    verified: false,
    verificationText: kLocalVerificationText,
  );
}

/// 月度里程：按车分组取里程表读数极差；不足两条时用单笔距离求和。
({int km, DistanceSource source}) computeDistanceKmByVehicle(
  List<LedgerRecord> records,
) {
  return computeDistance([
    for (final record in records)
      DistanceSample(
        vehicleId: record.vehicleId,
        odometerKm: record.metrics.odometerKm,
        distanceKm: record.metrics.distanceKm,
      ),
  ]);
}

/// 按 6 个报表分组汇总金额与百分比。
List<ReportCategoryGroup> buildCategoryGroups(
  List<LedgerRecord> records,
  int totalCents,
) {
  final amounts = <ReportCategoryKey, int>{
    for (final key in ReportCategoryKey.values) key: 0,
  };
  final counts = <ReportCategoryKey, int>{
    for (final key in ReportCategoryKey.values) key: 0,
  };

  for (final record in records) {
    final key = reportCategoryKeyFor(record.category);
    amounts.update(key, (value) => value + record.amountCents);
    counts.update(key, (value) => value + 1);
  }

  final ordered = ReportCategoryKey.values;
  final hasNegative = ordered.any((key) => amounts[key]! < 0);
  final percents = totalCents > 0 && !hasNegative
      ? largestRemainderPercents([for (final key in ordered) amounts[key]!])
      : null;

  return [
    for (var index = 0; index < ordered.length; index++)
      ReportCategoryGroup(
        key: ordered[index],
        label: ordered[index].label,
        amountCents: amounts[ordered[index]]!,
        count: counts[ordered[index]]!,
        percent: percents?[index],
      ),
  ];
}

/// 最大余数法：整数百分比之和固定为 100；总额为 0 时全部为 0。
List<int> largestRemainderPercents(List<int> amounts) {
  final total = amounts.fold(0, (sum, amount) => sum + amount);
  if (total <= 0 || amounts.isEmpty) {
    return List<int>.filled(amounts.length, 0);
  }

  final raw = [for (final amount in amounts) amount / total * 100];
  final floors = [for (final value in raw) value.floor()];
  final remainder = 100 - floors.fold(0, (sum, value) => sum + value);

  final order = List<int>.generate(amounts.length, (index) => index)
    ..sort((a, b) {
      final fractionCompare = (raw[b] - floors[b]).compareTo(
        raw[a] - floors[a],
      );
      return fractionCompare != 0
          ? fractionCompare
          : amounts[b].compareTo(amounts[a]);
    });

  for (var index = 0; index < remainder && index < order.length; index++) {
    floors[order[index]] += 1;
  }
  return floors;
}

/// 逐日开支：充电与其他两条序列，覆盖 1 日至 [lastDay]。
List<ReportDailyPoint> buildDailyPoints(
  List<LedgerRecord> records,
  DateTime month,
  int lastDay,
) {
  final byDay = <int, List<LedgerRecord>>{};
  for (final record in records) {
    if (record.occurredAt.year != month.year ||
        record.occurredAt.month != month.month) {
      continue;
    }
    byDay
        .putIfAbsent(record.occurredAt.day, () => <LedgerRecord>[])
        .add(record);
  }

  return [
    for (var day = 1; day <= lastDay; day++)
      _dailyPoint(
        DateTime(month.year, month.month, day),
        byDay[day] ?? const <LedgerRecord>[],
      ),
  ];
}

ReportDailyPoint _dailyPoint(DateTime date, List<LedgerRecord> records) {
  var chargingCents = 0;
  var otherCents = 0;
  for (final record in records) {
    if (record.category == ExpenseCategory.charging) {
      chargingCents += record.amountCents;
    } else {
      otherCents += record.amountCents;
    }
  }

  return ReportDailyPoint(
    date: date,
    chargingCents: chargingCents,
    otherCents: otherCents,
    recordCount: records.length,
    dominantCategory: _dominantCategory(records),
  );
}

ExpenseCategory? _dominantCategory(List<LedgerRecord> records) {
  final totals = <ExpenseCategory, int>{};
  for (final record in records) {
    totals.update(
      record.category,
      (value) => value + record.amountCents,
      ifAbsent: () => record.amountCents,
    );
  }
  if (totals.isEmpty) {
    return null;
  }
  var best = totals.entries.first;
  for (final entry in totals.entries) {
    if (entry.value > best.value) {
      best = entry;
    }
  }
  return best.value > 0 ? best.key : null;
}

ReportCategoryKey reportCategoryKeyFor(ExpenseCategory category) =>
    switch (category) {
      ExpenseCategory.charging => ReportCategoryKey.charging,
      ExpenseCategory.fuel => ReportCategoryKey.fuel,
      ExpenseCategory.maintenance => ReportCategoryKey.maintenance,
      ExpenseCategory.parking => ReportCategoryKey.parking,
      ExpenseCategory.toll => ReportCategoryKey.toll,
      ExpenseCategory.carWash ||
      ExpenseCategory.other => ReportCategoryKey.carWashOther,
    };

double? momPercentFor(int totalCents, int? previousTotalCents) {
  if (previousTotalCents == null || previousTotalCents == 0) {
    return null;
  }
  return (totalCents - previousTotalCents) / previousTotalCents * 100;
}

TrendDirection trendFor(int totalCents, int? previousTotalCents) {
  if (previousTotalCents == null || previousTotalCents == 0) {
    return TrendDirection.none;
  }
  if (totalCents > previousTotalCents) {
    return TrendDirection.up;
  }
  if (totalCents < previousTotalCents) {
    return TrendDirection.down;
  }
  return TrendDirection.flat;
}

/// 报表单号：`RP-YYYYMM-XXXX`，同一范围长期稳定。
///
/// 使用 FNV-1a 而不是 `String.hashCode`，保证跨平台、跨版本可复现。
String reportNoFor(ReportScope scope) {
  final seed = '${scope.monthKey}|${scope.vehicleId ?? 'all'}';
  final sequence = _fnv1a(seed) % 10000;
  return 'RP-${scope.monthKey.replaceAll('-', '')}-'
      '${sequence.toString().padLeft(4, '0')}';
}

int _fnv1a(String input) {
  var hash = 0x811C9DC5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7FFFFFFF;
  }
  return hash;
}

/// 车牌脱敏：`粤B·D82K6` → `粤B·D****`。
String maskPlate(String plate) {
  final runes = plate.runes.toList(growable: false);
  if (runes.length <= 3) {
    return '***';
  }

  final dotIndex = runes.indexOf('·'.runes.first);
  final keep = dotIndex >= 0 ? math.min(dotIndex + 2, runes.length) : 2;
  final prefix = String.fromCharCodes(runes.take(keep));
  return '$prefix${'*' * (runes.length - keep)}';
}
