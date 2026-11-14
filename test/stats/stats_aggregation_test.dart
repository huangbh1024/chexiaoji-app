import 'package:chexiaoji_app/core/domain/distance.dart';
import 'package:chexiaoji_app/core/domain/enums.dart';
import 'package:chexiaoji_app/features/stats/domain/stats_aggregation.dart';
import 'package:chexiaoji_app/features/stats/domain/stats_models.dart';
import 'package:chexiaoji_app/features/stats/domain/stats_period.dart';
import 'package:flutter_test/flutter_test.dart';

import 'stats_test_helpers.dart';

void main() {
  final now = DateTime(2026, 11, 14, 12);

  group('汇总', () {
    test('总额、能源、里程与每公里成本', () {
      final records = [
        statsRecord(
          id: 'a',
          amountCents: 10000,
          category: ExpenseCategory.charging,
          occurredAt: DateTime(2026, 11, 1),
          odometerKm: 1000,
        ),
        statsRecord(
          id: 'b',
          amountCents: 5000,
          category: ExpenseCategory.fuel,
          occurredAt: DateTime(2026, 11, 10),
          odometerKm: 1100,
        ),
      ];
      final range = resolveStatsRange(StatsPeriod.month, now, now: now);
      final summary = buildStatsSummary(
        period: StatsPeriod.month,
        records: records,
        previousRecords: [statsRecord(id: 'prev', amountCents: 10000)],
        now: now,
      );

      expect(summary.totalCents, 15000);
      expect(summary.energyCents, 15000);
      expect(summary.distanceKm, 100);
      expect(summary.distanceSource, DistanceSource.odometer);
      expect(summary.costPerKmCents, 150);
      expect(summary.energyCostPerKmCents, 150);
      expect(summary.changePercent, 50);
      expect(summary.changeTrend, TrendDirection.up);
      expect(range.start, DateTime(2026, 11));
    });

    test('读数不足时使用单笔距离求和', () {
      final records = [
        statsRecord(id: 'a', distanceKm: 120),
        statsRecord(id: 'b', distanceKm: 80),
      ];
      final distance = distanceOf(records);
      expect(distance.km, 200);
      expect(distance.source, DistanceSource.records);
    });

    test('里程为 0 时每公里成本为 null', () {
      final summary = buildStatsSummary(
        period: StatsPeriod.month,
        records: [statsRecord(amountCents: 10000)],
        previousRecords: const [],
        now: now,
      );
      expect(summary.distanceKm, 0);
      expect(summary.costPerKmCents, isNull);
      expect(summary.energyCostPerKmCents, isNull);
      expect(summary.changePercent, isNull);
      expect(summary.changeTrend, TrendDirection.none);
    });

    test('全部范围返回累计文案且无环比', () {
      final first = DateTime(2024, 11, 14);
      final summary = buildStatsSummary(
        period: StatsPeriod.all,
        records: [statsRecord(amountCents: 10000)],
        previousRecords: const [],
        now: now,
        firstRecordAt: first,
      );
      expect(summary.previousTotalCents, isNull);
      expect(summary.changePercent, isNull);
      expect(summary.changeTrend, TrendDirection.none);
      expect(summary.cumulativeYears, closeTo(2, 0.01));
      expect(summary.changeText, '累计 2.0 年');
    });
  });

  group('能耗', () {
    test('电耗与油耗按每百公里计算', () {
      final records = [
        statsRecord(id: 'a', category: ExpenseCategory.charging, kwh: 40),
        statsRecord(id: 'b', category: ExpenseCategory.fuel, liters: 10),
      ];
      final values = consumptionOf(records, 200);
      expect(values.kwhPer100km, closeTo(20, 0.001));
      expect(values.litersPer100km, closeTo(5, 0.001));
    });

    test('里程为 0 时不计算能耗', () {
      final values = consumptionOf([], 0);
      expect(values.kwhPer100km, isNull);
      expect(values.litersPer100km, isNull);
    });

    test('评级阈值', () {
      expect(ratingFor(9, 10), StatsRating.excellent);
      expect(ratingFor(10, 10), StatsRating.good);
      expect(ratingFor(11, 10), StatsRating.high);
      expect(ratingFor(null, 10), StatsRating.none);
      expect(ratingFor(10, null), StatsRating.none);
    });
  });

  group('构成', () {
    test('百分比合计 100，金额合计等于总额', () {
      final records = [
        statsRecord(
          id: 'm',
          category: ExpenseCategory.maintenance,
          amountCents: 48000,
        ),
        statsRecord(
          id: 'c',
          category: ExpenseCategory.charging,
          amountCents: 38600,
        ),
        statsRecord(
          id: 'p',
          category: ExpenseCategory.parking,
          amountCents: 16800,
        ),
        statsRecord(
          id: 't',
          category: ExpenseCategory.toll,
          amountCents: 13200,
        ),
        statsRecord(
          id: 'w',
          category: ExpenseCategory.carWash,
          amountCents: 9000,
        ),
        statsRecord(
          id: 'o',
          category: ExpenseCategory.other,
          amountCents: 3000,
        ),
      ];
      final breakdown = buildStatsBreakdown(records);
      expect(breakdown.totalCents, 128600);
      expect(breakdown.count, 6);
      expect(
        breakdown.categories.fold(0, (sum, slice) => sum + slice.percent),
        100,
      );
      expect(
        breakdown.categories.fold(0, (sum, slice) => sum + slice.amountCents),
        breakdown.totalCents,
      );
      expect(breakdown.categories.first.category, ExpenseCategory.maintenance);
    });

    test('超过 6 类时保留前 5 类并合并其他', () {
      final categories = [
        (ExpenseCategory.charging, 7000),
        (ExpenseCategory.fuel, 6000),
        (ExpenseCategory.maintenance, 5000),
        (ExpenseCategory.parking, 4000),
        (ExpenseCategory.toll, 3000),
        (ExpenseCategory.carWash, 2000),
        (ExpenseCategory.other, 1000),
      ];
      final records = [
        for (var index = 0; index < categories.length; index++)
          statsRecord(
            id: '$index',
            category: categories[index].$1,
            amountCents: categories[index].$2,
          ),
      ];
      final breakdown = buildStatsBreakdown(records);
      expect(breakdown.categories.length, lessThanOrEqualTo(6));
      expect(breakdown.otherMerged, isTrue);
      final other = breakdown.categories.firstWhere(
        (slice) => slice.category == ExpenseCategory.other,
      );
      expect(other.amountCents, 3000);
    });

    test('小于 2% 的分类并入其他', () {
      final records = [
        statsRecord(
          id: 'a',
          category: ExpenseCategory.charging,
          amountCents: 9800,
        ),
        statsRecord(id: 'b', category: ExpenseCategory.fuel, amountCents: 100),
        statsRecord(
          id: 'c',
          category: ExpenseCategory.parking,
          amountCents: 100,
        ),
      ];
      final breakdown = buildStatsBreakdown(records);
      expect(breakdown.categories.length, 2);
      expect(breakdown.categories.last.category, ExpenseCategory.other);
      expect(breakdown.categories.last.amountCents, 200);
      expect(breakdown.categories.last.percent, 2);
    });

    test('最大余数法', () {
      expect(largestRemainder([1, 1, 1], 3), [34, 33, 33]);
      expect(largestRemainder([1, 2], 3), [33, 67]);
      expect(largestRemainder([], 0), <int>[]);
    });
  });

  group('趋势', () {
    test('7 天固定 7 个桶', () {
      final buckets = buildStatsBuckets(
        range: StatsTrendRange.d7,
        anchor: now,
        records: const [],
      );
      expect(buckets.length, 7);
      expect(buckets.first.start, DateTime(2026, 11, 8));
      expect(buckets.last.label, '11/14');
    });

    test('30 天 / 半年 / 1 年桶数量', () {
      expect(
        buildStatsBuckets(
          range: StatsTrendRange.d30,
          anchor: now,
          records: const [],
        ).length,
        30,
      );
      expect(
        buildStatsBuckets(
          range: StatsTrendRange.halfYear,
          anchor: now,
          records: const [],
        ).length,
        6,
      );
      expect(
        buildStatsBuckets(
          range: StatsTrendRange.year,
          anchor: now,
          records: const [],
        ).length,
        12,
      );
    });

    test('趋势合计、峰值与环比', () {
      final records = [
        statsRecord(
          id: 'a',
          category: ExpenseCategory.maintenance,
          amountCents: 48000,
          occurredAt: DateTime(2026, 11, 10),
        ),
        statsRecord(
          id: 'b',
          category: ExpenseCategory.charging,
          amountCents: 6000,
          occurredAt: DateTime(2026, 11, 14),
        ),
      ];
      final trend = buildStatsTrend(
        query: StatsTrendQuery(
          vehicleId: 'byd-han-ev',
          range: StatsTrendRange.d7,
          anchor: now,
        ),
        records: records,
        previousRecords: [
          statsRecord(
            id: 'prev',
            amountCents: 10000,
            occurredAt: DateTime(2026, 11, 1),
          ),
        ],
        now: now,
      );

      expect(trend.totalCents, 54000);
      expect(trend.previousTotalCents, 10000);
      expect(trend.changeTrend, TrendDirection.up);
      expect(trend.peakIndex, 2);
      expect(trend.buckets[2].dominantCategory, ExpenseCategory.maintenance);
      expect(trend.axis.maxCents, 60000);
      expect(trend.axis.ticksCents, [0, 20000, 40000, 60000]);
    });

    test('空数据坐标轴使用默认上限', () {
      final axis = buildStatsAxis(const []);
      expect(axis.maxCents, 10000);
      expect(axis.ticksCents.last, 10000);
    });

    test('坐标轴按 1/2/5 取整', () {
      final axis = buildStatsAxis([
        StatsBucket(
          start: DateTime(2026, 11, 14),
          label: '11/14',
          energyCents: 53700,
          otherCents: 0,
          count: 1,
        ),
      ]);
      expect(axis.maxCents, 60000);
      expect(axis.ticksCents, [0, 20000, 40000, 60000]);
    });
  });

  group('最近记录', () {
    test('衍生标签按分类生成', () {
      final charging = statsRecord(
        category: ExpenseCategory.charging,
        amountCents: 5110,
        distanceKm: 300,
      );
      expect(statsRecordTag(charging), '¥0.17/km');

      final maintenance = statsRecord(
        category: ExpenseCategory.maintenance,
        description: '大保养与刹车油',
      );
      expect(statsRecordTag(maintenance), '大保养');

      final parking = statsRecord(category: ExpenseCategory.parking);
      expect(statsRecordTag(parking), '临时停车');
    });

    test('按时间倒序取前 N 条，全部车辆带车辆名', () {
      final records = [
        statsRecord(id: 'a', occurredAt: DateTime(2026, 11, 1)),
        statsRecord(id: 'b', occurredAt: DateTime(2026, 11, 3)),
        statsRecord(id: 'c', occurredAt: DateTime(2026, 11, 2)),
      ];
      final recent = recentStatsRecords(records, limit: 2, showVehicle: true);
      expect(recent.length, 2);
      expect(recent.first.id, 'b');
      expect(recent.first.subtitle, contains('汉 EV'));
    });
  });
}
