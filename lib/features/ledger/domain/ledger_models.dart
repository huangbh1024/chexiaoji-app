import 'package:material_ui/material_ui.dart';

import '../../../core/domain/enums.dart';

/// 账单列表排序方式。
enum LedgerSort { timeDesc, amountDesc, category }

/// 汇总查询范围：月份 + 车辆（null = 全部车辆）。
@immutable
class LedgerScope {
  const LedgerScope({required this.month, this.vehicleId});

  /// 归一化到当月 1 日 00:00（本地时区）。
  final DateTime month;

  /// null 表示全部车辆。
  final String? vehicleId;

  String get monthKey =>
      '${month.year.toString().padLeft(4, '0')}-'
      '${month.month.toString().padLeft(2, '0')}';

  LedgerScope copyWith({
    DateTime? month,
    String? vehicleId,
    bool clearVehicle = false,
  }) {
    return LedgerScope(
      month: month ?? this.month,
      vehicleId: clearVehicle ? null : (vehicleId ?? this.vehicleId),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LedgerScope &&
      other.runtimeType == runtimeType &&
      other.month.year == month.year &&
      other.month.month == month.month &&
      other.vehicleId == vehicleId;

  @override
  int get hashCode => Object.hash(month.year, month.month, vehicleId);
}

/// 列表查询范围：在 [LedgerScope] 上追加分类与排序。
@immutable
class LedgerQuery extends LedgerScope {
  const LedgerQuery({
    required super.month,
    super.vehicleId,
    this.category,
    this.sort = LedgerSort.timeDesc,
  });

  /// null 表示全部类型。
  final ExpenseCategory? category;
  final LedgerSort sort;

  @override
  LedgerQuery copyWith({
    DateTime? month,
    String? vehicleId,
    bool clearVehicle = false,
    ExpenseCategory? category,
    bool clearCategory = false,
    LedgerSort? sort,
  }) {
    return LedgerQuery(
      month: month ?? this.month,
      vehicleId: clearVehicle ? null : (vehicleId ?? this.vehicleId),
      category: clearCategory ? null : (category ?? this.category),
      sort: sort ?? this.sort,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LedgerQuery &&
      other.month.year == month.year &&
      other.month.month == month.month &&
      other.vehicleId == vehicleId &&
      other.category == category &&
      other.sort == sort;

  @override
  int get hashCode =>
      Object.hash(month.year, month.month, vehicleId, category, sort);
}

/// 某一天的日开销，用于汇总卡的迷你柱状图。
class LedgerDailyPoint {
  const LedgerDailyPoint({
    required this.date,
    required this.amountCents,
    this.dominantCategory,
  });

  final DateTime date;
  final int amountCents;
  final ExpenseCategory? dominantCategory;
}

class LedgerMonthSummary {
  const LedgerMonthSummary({
    required this.month,
    required this.totalCents,
    required this.count,
    required this.energyCents,
    required this.serviceCents,
    required this.dailyAverageCents,
    required this.daily,
    this.momPercent,
    this.momTrend = TrendDirection.none,
  });

  final DateTime month;
  final int totalCents;
  final int count;

  /// 充电 + 加油。
  final int energyCents;

  /// 保养 + 洗车。
  final int serviceCents;

  final int dailyAverageCents;
  final List<LedgerDailyPoint> daily;

  /// null 表示上月无数据。
  final double? momPercent;
  final TrendDirection momTrend;

  int get peakCents {
    if (daily.isEmpty) {
      return 0;
    }
    return daily
        .map((point) => point.amountCents)
        .reduce((a, b) => a > b ? a : b);
  }

  DateTime? get peakDate {
    final peak = peakCents;
    if (peak <= 0) {
      return null;
    }
    for (final point in daily) {
      if (point.amountCents == peak) {
        return point.date;
      }
    }
    return null;
  }
}

enum LedgerBadgeKind { none, vehicle, meta }

class LedgerMetrics {
  const LedgerMetrics({
    this.kwh,
    this.liters,
    this.odometerKm,
    this.durationMinutes,
    this.plate,
    this.paymentMethod,
  });

  final double? kwh;
  final double? liters;
  final int? odometerKm;
  final int? durationMinutes;
  final String? plate;
  final String? paymentMethod;
}

class LedgerRecord {
  const LedgerRecord({
    required this.id,
    required this.vehicleId,
    required this.vehicleShortName,
    required this.powertrain,
    required this.category,
    required this.title,
    required this.amountCents,
    required this.occurredAt,
    this.badgeText,
    this.badgeKind = LedgerBadgeKind.none,
    this.description,
    this.metrics = const LedgerMetrics(),
    this.statusText,
    this.note,
  });

  final String id;
  final String vehicleId;
  final String vehicleShortName;
  final PowertrainType powertrain;
  final ExpenseCategory category;
  final String title;

  /// 支出为正数、退款为负数；展示时支出加 `-`。
  final int amountCents;
  final DateTime occurredAt;

  /// 标题右侧徽标：车辆简称或元信息（如「B2区」）。
  final String? badgeText;
  final LedgerBadgeKind badgeKind;

  /// 副标题中的业务描述（保养项目、路线、服务内容等）。
  final String? description;
  final LedgerMetrics metrics;

  /// 右侧辅助文案：工单已归档、微信支付、16:45 离场等。
  final String? statusText;
  final String? note;
}

class LedgerRecordsPage {
  const LedgerRecordsPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<LedgerRecord> items;
  final bool hasMore;
  final String? nextCursor;
}

/// 列表行：组头、筛选提示条、记录卡。
sealed class LedgerRow {
  const LedgerRow();
}

class LedgerDayHeaderRow extends LedgerRow {
  const LedgerDayHeaderRow({
    required this.day,
    required this.count,
    required this.totalCents,
    this.dominantCategory,
    this.isToday = false,
  });

  final DateTime day;
  final int count;
  final int totalCents;
  final ExpenseCategory? dominantCategory;
  final bool isToday;
}

class LedgerResultBarRow extends LedgerRow {
  const LedgerResultBarRow({
    required this.category,
    required this.count,
    required this.totalCents,
  });

  final ExpenseCategory category;
  final int count;
  final int totalCents;
}

class LedgerRecordRow extends LedgerRow {
  const LedgerRecordRow(this.record);

  final LedgerRecord record;
}

/// 账单列表的完整状态。
class LedgerListState {
  const LedgerListState({
    required this.items,
    required this.rows,
    required this.cursor,
    required this.hasMore,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isNextPageFailed = false,
    this.errorMessage,
  });

  const LedgerListState.loading()
    : items = const <LedgerRecord>[],
      rows = const <LedgerRow>[],
      cursor = null,
      hasMore = true,
      isLoading = true,
      isLoadingMore = false,
      isNextPageFailed = false,
      errorMessage = null;

  const LedgerListState.empty()
    : items = const <LedgerRecord>[],
      rows = const <LedgerRow>[],
      cursor = null,
      hasMore = false,
      isLoading = false,
      isLoadingMore = false,
      isNextPageFailed = false,
      errorMessage = null;

  final List<LedgerRecord> items;
  final List<LedgerRow> rows;
  final String? cursor;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isNextPageFailed;
  final String? errorMessage;

  bool get isEmpty => !isLoading && errorMessage == null && items.isEmpty;

  LedgerListState copyWith({
    List<LedgerRecord>? items,
    List<LedgerRow>? rows,
    String? cursor,
    bool clearCursor = false,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isNextPageFailed,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LedgerListState(
      items: items ?? this.items,
      rows: rows ?? this.rows,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isNextPageFailed: isNextPageFailed ?? this.isNextPageFailed,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// 日期是否同一天。
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 当月 1 日 00:00。
DateTime monthStart(DateTime date) => DateTime(date.year, date.month);
