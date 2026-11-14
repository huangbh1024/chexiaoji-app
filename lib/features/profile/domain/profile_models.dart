import 'package:material_ui/material_ui.dart';

import '../../../core/domain/enums.dart';

/// 单位制：P0 固定公制，P1 支持英制。
enum UnitSystem { metric, imperial }

/// 货币：当前仅人民币，预留扩展。
enum CurrencyCode { cny }

/// 云端同步状态。
enum SyncState { local, syncing, synced, failed }

/// 车辆卡底部提示的语义类型。
enum GarageTipKind { charging, fuel, mixed, energySummary, empty }

@immutable
class ProfileUser {
  const ProfileUser({
    required this.id,
    required this.nickname,
    required this.verifiedOwner,
    required this.tagline,
    this.avatarUrl,
    this.phoneMasked,
  });

  final String id;
  final String nickname;

  /// 预留：P1 头像上传后使用；P0 为 null，UI 走首字头像。
  final String? avatarUrl;
  final bool verifiedOwner;
  final String tagline;

  /// 服务端掩码后的手机号，客户端不拼接完整号码。
  final String? phoneMasked;
}

@immutable
class ProfileStats {
  const ProfileStats({
    required this.accountDays,
    required this.recordCount,
    this.firstRecordAt,
  });

  final int accountDays;
  final int recordCount;
  final DateTime? firstRecordAt;
}

@immutable
class ProfileOverview {
  const ProfileOverview({
    required this.user,
    required this.stats,
    this.dataUpdatedAt,
  });

  final ProfileUser user;
  final ProfileStats stats;
  final DateTime? dataUpdatedAt;
}

@immutable
class GarageVehicle {
  const GarageVehicle({
    required this.id,
    required this.name,
    required this.shortName,
    required this.plate,
    required this.powertrain,
    required this.powertrainLabel,
    required this.odometerKm,
    this.energyCostPerKmCents,
  });

  final String id;
  final String name;
  final String shortName;
  final String plate;
  final PowertrainType powertrain;
  final String powertrainLabel;
  final int odometerKm;

  /// 历史平均每公里能源成本（分），用于车辆副标题；null 时回退「本月已记 n 笔」。
  final int? energyCostPerKmCents;
}

@immutable
class MonthEnergy {
  const MonthEnergy({
    required this.amountCents,
    required this.count,
    this.kwh,
    this.liters,
  });

  final int amountCents;
  final int count;

  /// 单能源或可比较时返回；全部资产混合能源时为 null。
  final double? kwh;
  final double? liters;
}

@immutable
class GarageMaintenance {
  const GarageMaintenance({
    required this.enabled,
    required this.status,
    this.vehicleId,
    this.vehicleName,
    this.remainingKm,
    this.remainingDays,
  });

  final bool enabled;
  final MaintenanceStatus status;
  final String? vehicleId;
  final String? vehicleName;
  final int? remainingKm;
  final int? remainingDays;

  bool get isOverdue => enabled && (remainingKm ?? 0) <= 0;
}

@immutable
class GarageTip {
  const GarageTip({required this.kind, required this.text});

  final GarageTipKind kind;
  final String text;
}

@immutable
class GarageSnapshot {
  const GarageSnapshot({
    required this.badge,
    required this.plateText,
    required this.title,
    required this.subtitle,
    required this.odometerKm,
    required this.monthEnergy,
    required this.maintenance,
    required this.tip,
    this.vehicleId,
    this.powertrain,
  });

  /// null = 全部资产。
  final String? vehicleId;
  final String badge;
  final String plateText;
  final String title;
  final String subtitle;
  final PowertrainType? powertrain;
  final int odometerKm;
  final MonthEnergy monthEnergy;
  final GarageMaintenance maintenance;
  final GarageTip tip;

  bool get isAllAssets => vehicleId == null;
}

@immutable
class GarageData {
  const GarageData({
    required this.vehicles,
    required this.snapshot,
    this.dataUpdatedAt,
  });

  final List<GarageVehicle> vehicles;
  final GarageSnapshot snapshot;
  final DateTime? dataUpdatedAt;
}

@immutable
class ProfileServiceStatus {
  const ProfileServiceStatus({
    required this.available,
    this.count,
    this.state,
    this.lastSyncAt,
    this.pendingCount,
  });

  final bool available;
  final int? count;
  final SyncState? state;
  final DateTime? lastSyncAt;
  final int? pendingCount;
}

@immutable
class ProfileServices {
  const ProfileServices({
    required this.report,
    required this.voucher,
    required this.sync,
    required this.offline,
  });

  final ProfileServiceStatus report;
  final ProfileServiceStatus voucher;
  final ProfileServiceStatus sync;
  final ProfileServiceStatus offline;
}

@immutable
class ProfilePreferences {
  const ProfilePreferences({
    this.unitSystem = UnitSystem.metric,
    this.currency = CurrencyCode.cny,
    this.notificationsEnabled = false,
    this.maskSensitive = false,
  });

  final UnitSystem unitSystem;
  final CurrencyCode currency;
  final bool notificationsEnabled;
  final bool maskSensitive;
}
