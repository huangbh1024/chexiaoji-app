import 'package:chexiaoji_app/features/stats/domain/stats_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 14, 12, 30);

  test('月度范围与标签', () {
    final range = resolveStatsRange(StatsPeriod.month, now, now: now);
    expect(range.start, DateTime(2026, 11));
    expect(range.end.year, 2026);
    expect(range.end.month, 11);
    expect(range.end.day, 30);
    expect(range.label, '2026年11月');
    expect(range.shortLabel, '本月');
    expect(range.comparisonLabel, '较上月');
  });

  test('历史周期的子指标标签不写「本月 / 本周」', () {
    final month = resolveStatsRange(
      StatsPeriod.month,
      DateTime(2026, 6, 15),
      now: now,
    );
    expect(month.shortLabel, '6月');

    final week = resolveStatsRange(
      StatsPeriod.week,
      DateTime(2026, 10, 5),
      now: now,
    );
    expect(week.shortLabel, '该周');
  });

  test('周范围以周一为起点', () {
    final range = resolveStatsRange(StatsPeriod.week, now, now: now);
    expect(range.start, DateTime(2026, 11, 9));
    expect(range.end.day, 15);
    expect(range.label, contains('本周'));
  });

  test('半年 H1 / H2 边界', () {
    final h1 = resolveStatsRange(
      StatsPeriod.halfYear,
      DateTime(2026, 3, 5),
      now: now,
    );
    expect(h1.start, DateTime(2026, 1));
    expect(h1.end.month, 6);
    expect(h1.end.day, 30);
    expect(h1.label, '2026上半年');

    final h2 = resolveStatsRange(
      StatsPeriod.halfYear,
      DateTime(2026, 8, 5),
      now: now,
    );
    expect(h2.start, DateTime(2026, 7));
    expect(h2.end.month, 12);
    expect(h2.end.day, 31);
    expect(h2.label, '2026下半年');
    expect(h2.shortLabel, '下半年');
  });

  test('年度范围', () {
    final range = resolveStatsRange(StatsPeriod.year, now, now: now);
    expect(range.start, DateTime(2026));
    expect(range.end.month, 12);
    expect(range.end.day, 31);
    expect(range.label, '2026年');
    expect(range.shortLabel, '全年');
  });

  test('全部范围使用首条记录时间', () {
    final first = DateTime(2024, 9, 1, 8);
    final range = resolveStatsRange(
      StatsPeriod.all,
      now,
      now: now,
      firstRecordAt: first,
    );
    expect(range.start, first);
    expect(range.end, now);
    expect(range.label, '累计至今');
    expect(range.shortLabel, '累计');
    expect(range.comparisonLabel, '累计');
  });

  test('未来锚点钳制到当前周期', () {
    final range = resolveStatsRange(
      StatsPeriod.month,
      DateTime(2027, 1, 20),
      now: now,
    );
    expect(range.start, DateTime(2026, 11));
  });

  test('上一周期：月 / 周 / 半年 / 年', () {
    final month = resolveStatsRange(StatsPeriod.month, now, now: now);
    final previousMonth = previousStatsRange(
      StatsPeriod.month,
      month,
      now: now,
    )!;
    expect(previousMonth.start, DateTime(2026, 10));

    final week = resolveStatsRange(StatsPeriod.week, now, now: now);
    final previousWeek = previousStatsRange(StatsPeriod.week, week, now: now)!;
    expect(previousWeek.start, DateTime(2026, 11, 2));
    expect(previousWeek.end.day, 8);

    final h1 = resolveStatsRange(
      StatsPeriod.halfYear,
      DateTime(2026, 3, 5),
      now: now,
    );
    final previousHalf = previousStatsRange(
      StatsPeriod.halfYear,
      h1,
      now: now,
    )!;
    expect(previousHalf.start, DateTime(2025, 1));
    expect(previousHalf.end.month, 6);

    final year = resolveStatsRange(StatsPeriod.year, now, now: now);
    final previousYear = previousStatsRange(StatsPeriod.year, year, now: now)!;
    expect(previousYear.start, DateTime(2025));
    expect(previousYear.end.month, 12);
  });

  test('全部周期没有上一周期', () {
    final range = resolveStatsRange(StatsPeriod.all, now, now: now);
    expect(previousStatsRange(StatsPeriod.all, range, now: now), isNull);
  });

  test('StatsScope 按日期与枚举判等', () {
    final a = StatsScope(
      vehicleId: 'byd-han-ev',
      period: StatsPeriod.month,
      anchor: DateTime(2026, 11, 14, 8),
    );
    final b = StatsScope(
      vehicleId: 'byd-han-ev',
      period: StatsPeriod.month,
      anchor: DateTime(2026, 11, 14, 20),
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}
