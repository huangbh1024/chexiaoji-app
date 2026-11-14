import 'package:material_ui/material_ui.dart';

/// 统计页的分析周期。
enum StatsPeriod {
  week('week', '周'),
  month('month', '月度'),
  halfYear('half_year', '半年'),
  year('year', '年度'),
  all('all', '全部');

  const StatsPeriod(this.apiValue, this.chipLabel);

  final String apiValue;
  final String chipLabel;
}

/// 趋势卡的走势窗口，独立于页面周期。
enum StatsTrendRange {
  d7('7d', '7天', '近 7 天'),
  d30('30d', '30天', '近 30 天'),
  halfYear('6m', '半年', '近 6 个月'),
  year('1y', '1年', '近 1 年');

  const StatsTrendRange(this.apiValue, this.label, this.windowLabel);

  final String apiValue;
  final String label;
  final String windowLabel;
}

/// 解析后的周期范围与展示标签。
@immutable
class StatsRange {
  const StatsRange({
    required this.start,
    required this.end,
    required this.label,
    required this.shortLabel,
    required this.comparisonLabel,
  });

  final DateTime start;
  final DateTime end;

  /// 日期胶囊文案：`本周 (6/24–6/30)`、`2024年6月`、`2024上半年`、`累计至今`。
  final String label;

  /// 子指标前缀：本周 / 本月 / 上半年 / 下半年 / 全年 / 累计。
  final String shortLabel;

  /// 环比前缀：较上周 / 较上月 / 较去年同期 / 较去年 / 累计。
  final String comparisonLabel;

  String get rangeKey => '${_dateKey(start)}_${_dateKey(end)}';
}

/// 页面筛选：vehicleId == null 表示全部车辆。
@immutable
class StatsFilter {
  const StatsFilter({
    this.vehicleId,
    this.period = StatsPeriod.month,
    required this.anchor,
  });

  final String? vehicleId;
  final StatsPeriod period;
  final DateTime anchor;

  StatsScope toScope() =>
      StatsScope(vehicleId: vehicleId, period: period, anchor: anchor);

  StatsFilter copyWith({
    String? vehicleId,
    bool clearVehicle = false,
    StatsPeriod? period,
    DateTime? anchor,
  }) {
    return StatsFilter(
      vehicleId: clearVehicle ? null : (vehicleId ?? this.vehicleId),
      period: period ?? this.period,
      anchor: anchor ?? this.anchor,
    );
  }
}

/// 概览 / 构成 / 最近记录的查询范围。
@immutable
class StatsScope {
  const StatsScope({
    required this.vehicleId,
    required this.period,
    required this.anchor,
  });

  final String? vehicleId;
  final StatsPeriod period;
  final DateTime anchor;

  String get key =>
      '${vehicleId ?? 'all'}|${period.apiValue}|${_dateKey(anchor)}';

  StatsScope copyWith({
    String? vehicleId,
    bool clearVehicle = false,
    StatsPeriod? period,
    DateTime? anchor,
  }) {
    return StatsScope(
      vehicleId: clearVehicle ? null : (vehicleId ?? this.vehicleId),
      period: period ?? this.period,
      anchor: anchor ?? this.anchor,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StatsScope &&
      other.vehicleId == vehicleId &&
      other.period == period &&
      other.anchor.year == anchor.year &&
      other.anchor.month == anchor.month &&
      other.anchor.day == anchor.day;

  @override
  int get hashCode =>
      Object.hash(vehicleId, period, anchor.year, anchor.month, anchor.day);
}

/// 趋势查询：窗口独立于页面周期。
@immutable
class StatsTrendQuery {
  const StatsTrendQuery({
    required this.vehicleId,
    required this.range,
    required this.anchor,
  });

  final String? vehicleId;
  final StatsTrendRange range;
  final DateTime anchor;

  String get key =>
      '${vehicleId ?? 'all'}|${range.apiValue}|${_dateKey(anchor)}';

  @override
  bool operator ==(Object other) =>
      other is StatsTrendQuery &&
      other.vehicleId == vehicleId &&
      other.range == range &&
      other.anchor.year == anchor.year &&
      other.anchor.month == anchor.month &&
      other.anchor.day == anchor.day;

  @override
  int get hashCode =>
      Object.hash(vehicleId, range, anchor.year, anchor.month, anchor.day);
}

/// 解析周期范围。[firstRecordAt] 仅 `all` 使用。
StatsRange resolveStatsRange(
  StatsPeriod period,
  DateTime anchor, {
  DateTime? now,
  DateTime? firstRecordAt,
}) {
  final current = now ?? DateTime.now();
  final effectiveAnchor = anchor.isAfter(current) ? current : anchor;

  switch (period) {
    case StatsPeriod.week:
      final day = DateTime(
        effectiveAnchor.year,
        effectiveAnchor.month,
        effectiveAnchor.day,
      );
      final monday = DateTime(day.year, day.month, day.day - (day.weekday - 1));
      final nextMonday = DateTime(monday.year, monday.month, monday.day + 7);
      final end = nextMonday.subtract(const Duration(milliseconds: 1));
      final isCurrent = !current.isBefore(monday) && !current.isAfter(end);
      final rangeText = '${monday.month}/${monday.day}–${end.month}/${end.day}';
      return StatsRange(
        start: monday,
        end: end,
        label: isCurrent ? '本周 ($rangeText)' : rangeText,
        shortLabel: isCurrent ? '本周' : '该周',
        comparisonLabel: '较上周',
      );
    case StatsPeriod.month:
      final start = DateTime(effectiveAnchor.year, effectiveAnchor.month);
      final end = DateTime(
        effectiveAnchor.year,
        effectiveAnchor.month + 1,
        0,
        23,
        59,
        59,
        999,
      );
      final isCurrent =
          current.year == effectiveAnchor.year &&
          current.month == effectiveAnchor.month;
      return StatsRange(
        start: start,
        end: end,
        label: '${effectiveAnchor.year}年${effectiveAnchor.month}月',
        shortLabel: isCurrent ? '本月' : '${effectiveAnchor.month}月',
        comparisonLabel: '较上月',
      );
    case StatsPeriod.halfYear:
      final firstHalf = effectiveAnchor.month <= 6;
      final startMonth = firstHalf ? 1 : 7;
      final start = DateTime(effectiveAnchor.year, startMonth);
      final end = firstHalf
          ? DateTime(effectiveAnchor.year, 7, 0, 23, 59, 59, 999)
          : DateTime(effectiveAnchor.year, 13, 0, 23, 59, 59, 999);
      return StatsRange(
        start: start,
        end: end,
        label: '${effectiveAnchor.year}${firstHalf ? '上半年' : '下半年'}',
        shortLabel: firstHalf ? '上半年' : '下半年',
        comparisonLabel: '较去年同期',
      );
    case StatsPeriod.year:
      return StatsRange(
        start: DateTime(effectiveAnchor.year),
        end: DateTime(effectiveAnchor.year, 12, 31, 23, 59, 59, 999),
        label: '${effectiveAnchor.year}年',
        shortLabel: '全年',
        comparisonLabel: '较去年',
      );
    case StatsPeriod.all:
      final start = firstRecordAt ?? current;
      return StatsRange(
        start: start,
        end: current,
        label: '累计至今',
        shortLabel: '累计',
        comparisonLabel: '累计',
      );
  }
}

/// 上一个可比周期；`all` 返回 null。
StatsRange? previousStatsRange(
  StatsPeriod period,
  StatsRange current, {
  DateTime? now,
}) {
  switch (period) {
    case StatsPeriod.week:
      final start = current.start.subtract(const Duration(days: 7));
      final end = current.end.subtract(const Duration(days: 7));
      final rangeText = '${start.month}/${start.day}–${end.month}/${end.day}';
      return StatsRange(
        start: start,
        end: end,
        label: rangeText,
        shortLabel: '上周',
        comparisonLabel: '较上周',
      );
    case StatsPeriod.month:
      return resolveStatsRange(
        StatsPeriod.month,
        DateTime(current.start.year, current.start.month - 1),
        now: now,
      );
    case StatsPeriod.halfYear:
      return resolveStatsRange(
        StatsPeriod.halfYear,
        DateTime(current.start.year - 1, current.start.month),
        now: now,
      );
    case StatsPeriod.year:
      return resolveStatsRange(
        StatsPeriod.year,
        DateTime(current.start.year - 1),
        now: now,
      );
    case StatsPeriod.all:
      return null;
  }
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
