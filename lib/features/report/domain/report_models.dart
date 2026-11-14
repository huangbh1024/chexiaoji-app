import 'package:material_ui/material_ui.dart';

import '../../../core/domain/distance.dart';
import '../../../core/domain/enums.dart';

export '../../../core/domain/distance.dart';

/// 报表范围：月份 + 车辆（null = 全部车辆）。
///
/// 与账单的 `LedgerScope` 结构相似但不复用：报表不含分类与排序，
/// 语义更窄，避免两个页面的筛选字段互相影响。
@immutable
class ReportScope {
  const ReportScope({required this.month, this.vehicleId});

  /// 归一化到当月 1 日 00:00（本地时区）。
  final DateTime month;

  /// null 表示全部车辆。
  final String? vehicleId;

  String get monthKey =>
      '${month.year.toString().padLeft(4, '0')}-'
      '${month.month.toString().padLeft(2, '0')}';

  ReportScope copyWith({
    DateTime? month,
    String? vehicleId,
    bool clearVehicle = false,
  }) {
    return ReportScope(
      month: month ?? this.month,
      vehicleId: clearVehicle ? null : (vehicleId ?? this.vehicleId),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReportScope &&
      other.month.year == month.year &&
      other.month.month == month.month &&
      other.vehicleId == vehicleId;

  @override
  int get hashCode => Object.hash(month.year, month.month, vehicleId);
}

/// 报表状态：当前月记录中，历史月已出账。
enum ReportStatus { recording, issued }

/// 报表分类分组，固定 6 组。
enum ReportCategoryKey {
  charging,
  fuel,
  maintenance,
  parking,
  toll,
  carWashOther;

  String get label => switch (this) {
    ReportCategoryKey.charging => '充电动能',
    ReportCategoryKey.fuel => '燃油加注',
    ReportCategoryKey.maintenance => '常规保养',
    ReportCategoryKey.parking => '临停泊车',
    ReportCategoryKey.toll => '高速通行',
    ReportCategoryKey.carWashOther => '洗车及其他',
  };
}

/// 导出格式。长图海报为 P1。
enum ReportFormat { pdf, csv, poster }

/// 导出配置。开关变化只影响预览与导出，不重新请求报表。
@immutable
class ReportOptions {
  const ReportOptions({
    this.format = ReportFormat.pdf,
    this.includeEnergy = true,
    this.includeInvoices = false,
    this.maskPlate = false,
  });

  final ReportFormat format;

  /// 是否展示「综合每公里」与走势图。
  final bool includeEnergy;

  /// 发票 / 凭证附件；当前无附件能力，恒为 false。
  final bool includeInvoices;

  /// 车牌脱敏，作用于预览、PDF 与 CSV。
  final bool maskPlate;

  ReportOptions copyWith({
    ReportFormat? format,
    bool? includeEnergy,
    bool? includeInvoices,
    bool? maskPlate,
  }) {
    return ReportOptions(
      format: format ?? this.format,
      includeEnergy: includeEnergy ?? this.includeEnergy,
      includeInvoices: includeInvoices ?? this.includeInvoices,
      maskPlate: maskPlate ?? this.maskPlate,
    );
  }
}

/// 报表中的车辆摘要。
@immutable
class ReportVehicleBrief {
  const ReportVehicleBrief({
    required this.id,
    required this.name,
    required this.shortName,
    required this.plate,
    required this.powertrain,
    required this.powertrainLabel,
    required this.odometerKm,
    required this.recordCount,
  });

  final String id;
  final String name;
  final String shortName;
  final String plate;
  final PowertrainType powertrain;
  final String powertrainLabel;
  final int odometerKm;
  final int recordCount;
}

/// 分类核算分组。
@immutable
class ReportCategoryGroup {
  const ReportCategoryGroup({
    required this.key,
    required this.label,
    required this.amountCents,
    required this.count,
    this.percent,
  });

  final ReportCategoryKey key;
  final String label;

  /// 组内净额，退款为负。
  final int amountCents;
  final int count;

  /// 0–100 的整数；总额 ≤ 0 或存在负组时为 null。
  final int? percent;
}

/// 某一天的开支，用于报表走势图。
@immutable
class ReportDailyPoint {
  const ReportDailyPoint({
    required this.date,
    required this.chargingCents,
    required this.otherCents,
    this.recordCount = 0,
    this.dominantCategory,
  });

  final DateTime date;
  final int chargingCents;
  final int otherCents;
  final int recordCount;
  final ExpenseCategory? dominantCategory;

  int get totalCents => chargingCents + otherCents;
}

/// 月度报表聚合结果。
@immutable
class MonthlyReport {
  const MonthlyReport({
    required this.scope,
    required this.reportNo,
    required this.status,
    required this.generatedAt,
    required this.updatedAt,
    required this.totalCents,
    required this.recordCount,
    required this.distanceKm,
    required this.distanceSource,
    required this.days,
    required this.costPerKmCents,
    required this.energyKwh,
    required this.fuelLiters,
    required this.kwhPer100km,
    required this.litersPer100km,
    required this.momPercent,
    required this.momTrend,
    required this.vehicles,
    required this.categories,
    required this.daily,
    required this.verified,
    required this.verificationText,
    this.settledAt,
    this.isOffline = false,
  });

  final ReportScope scope;
  final String reportNo;
  final ReportStatus status;
  final DateTime generatedAt;

  /// 范围内记录的最后更新时间；用于离线提示与缓存。
  final DateTime updatedAt;
  final DateTime? settledAt;

  final int totalCents;
  final int recordCount;
  final int distanceKm;
  final DistanceSource distanceSource;
  final int days;
  final int? costPerKmCents;

  final double energyKwh;
  final double fuelLiters;
  final double? kwhPer100km;
  final double? litersPer100km;

  final double? momPercent;
  final TrendDirection momTrend;

  final List<ReportVehicleBrief> vehicles;
  final List<ReportCategoryGroup> categories;
  final List<ReportDailyPoint> daily;
  final bool verified;
  final String verificationText;
  final bool isOffline;

  bool get isRecording => status == ReportStatus.recording;

  bool get isEmpty => recordCount == 0;

  /// 是否有充电 / 加油能耗数据，用于决定 KPI 辅助行。
  bool get hasEnergy => energyKwh > 0 || fuelLiters > 0;

  MonthlyReport copyWith({
    ReportScope? scope,
    String? reportNo,
    ReportStatus? status,
    DateTime? generatedAt,
    DateTime? updatedAt,
    DateTime? settledAt,
    bool clearSettledAt = false,
    int? totalCents,
    int? recordCount,
    int? distanceKm,
    DistanceSource? distanceSource,
    int? days,
    int? costPerKmCents,
    bool clearCostPerKm = false,
    double? energyKwh,
    double? fuelLiters,
    double? kwhPer100km,
    bool clearKwhPer100km = false,
    double? litersPer100km,
    bool clearLitersPer100km = false,
    double? momPercent,
    bool clearMomPercent = false,
    TrendDirection? momTrend,
    List<ReportVehicleBrief>? vehicles,
    List<ReportCategoryGroup>? categories,
    List<ReportDailyPoint>? daily,
    bool? verified,
    String? verificationText,
    bool? isOffline,
  }) {
    return MonthlyReport(
      scope: scope ?? this.scope,
      reportNo: reportNo ?? this.reportNo,
      status: status ?? this.status,
      generatedAt: generatedAt ?? this.generatedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      settledAt: clearSettledAt ? null : (settledAt ?? this.settledAt),
      totalCents: totalCents ?? this.totalCents,
      recordCount: recordCount ?? this.recordCount,
      distanceKm: distanceKm ?? this.distanceKm,
      distanceSource: distanceSource ?? this.distanceSource,
      days: days ?? this.days,
      costPerKmCents: clearCostPerKm
          ? null
          : (costPerKmCents ?? this.costPerKmCents),
      energyKwh: energyKwh ?? this.energyKwh,
      fuelLiters: fuelLiters ?? this.fuelLiters,
      kwhPer100km: clearKwhPer100km ? null : (kwhPer100km ?? this.kwhPer100km),
      litersPer100km: clearLitersPer100km
          ? null
          : (litersPer100km ?? this.litersPer100km),
      momPercent: clearMomPercent ? null : (momPercent ?? this.momPercent),
      momTrend: momTrend ?? this.momTrend,
      vehicles: vehicles ?? this.vehicles,
      categories: categories ?? this.categories,
      daily: daily ?? this.daily,
      verified: verified ?? this.verified,
      verificationText: verificationText ?? this.verificationText,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

/// 当月 1 日 00:00。
DateTime monthStart(DateTime date) => DateTime(date.year, date.month);
