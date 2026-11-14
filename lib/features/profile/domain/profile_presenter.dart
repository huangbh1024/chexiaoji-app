import 'package:material_ui/material_ui.dart';

import '../../../core/domain/enums.dart';
import '../../../core/format/formatters.dart';
import 'profile_models.dart';

@immutable
class ProfileSummaryView {
  const ProfileSummaryView({
    required this.initial,
    required this.nickname,
    required this.tagline,
    required this.verifiedOwner,
    required this.accountDaysText,
    required this.recordCountText,
    required this.vehicleCountText,
    this.phoneText,
  });

  final String initial;
  final String nickname;
  final String tagline;
  final bool verifiedOwner;
  final String accountDaysText;
  final String recordCountText;
  final String vehicleCountText;
  final String? phoneText;
}

@immutable
class GarageCardView {
  const GarageCardView({
    required this.badge,
    required this.plateText,
    required this.title,
    required this.subtitle,
    required this.odometerText,
    required this.energyAmountText,
    required this.energySubText,
    required this.maintenanceValue,
    required this.maintenanceUnit,
    required this.maintenanceStatus,
    required this.tipText,
    required this.tipKind,
  });

  final String badge;
  final String plateText;
  final String title;
  final String subtitle;
  final String odometerText;
  final String energyAmountText;
  final String energySubText;
  final String maintenanceValue;
  final String maintenanceUnit;
  final MaintenanceStatus maintenanceStatus;
  final String tipText;
  final GarageTipKind tipKind;
}

ProfileSummaryView buildProfileSummaryView({
  required ProfileOverview overview,
  required int? vehicleCount,
}) {
  final user = overview.user;
  final stats = overview.stats;
  return ProfileSummaryView(
    initial: _firstGrapheme(user.nickname),
    nickname: user.nickname,
    tagline: user.tagline,
    verifiedOwner: user.verifiedOwner,
    accountDaysText: stats.accountDays > 0
        ? '${formatCount(stats.accountDays)} 天'
        : '— 天',
    recordCountText: '${formatCount(stats.recordCount)} 笔',
    vehicleCountText: vehicleCount == null
        ? '— 辆'
        : '${formatCount(vehicleCount)} 辆',
    phoneText: user.phoneMasked,
  );
}

GarageCardView buildGarageCardView(GarageSnapshot snapshot) {
  return GarageCardView(
    badge: snapshot.badge,
    plateText: snapshot.plateText,
    title: snapshot.title,
    subtitle: snapshot.subtitle,
    odometerText: formatKmValue(snapshot.odometerKm),
    energyAmountText: formatYuanOneDecimal(snapshot.monthEnergy.amountCents),
    energySubText: _energySubText(snapshot),
    maintenanceValue: _maintenanceValue(snapshot),
    maintenanceUnit: _maintenanceUnit(snapshot),
    maintenanceStatus: snapshot.maintenance.status,
    tipText: snapshot.tip.text,
    tipKind: snapshot.tip.kind,
  );
}

String _energySubText(GarageSnapshot snapshot) {
  final energy = snapshot.monthEnergy;
  if (energy.count == 0) {
    return '本月暂无能耗记录';
  }
  final kwh = energy.kwh == null
      ? null
      : formatEnergyQuantity(energy.kwh!, unit: 'kWh');
  final liters = energy.liters == null
      ? null
      : formatEnergyQuantity(energy.liters!, unit: 'L');
  final countText = formatCount(energy.count);

  if (snapshot.isAllAssets) {
    if (kwh != null) {
      return '$kwh · 共 $countText 笔';
    }
    if (liters != null) {
      return '$liters · 共 $countText 笔';
    }
    return '共 $countText 笔';
  }

  if (kwh != null && liters != null) {
    return '电 $kwh · 油 $liters';
  }
  if (kwh != null) {
    return '$kwh · $countText 笔';
  }
  if (liters != null) {
    return '$liters · $countText 笔';
  }
  return '$countText 笔';
}

String _maintenanceValue(GarageSnapshot snapshot) {
  final maintenance = snapshot.maintenance;
  if (!maintenance.enabled) {
    return '—';
  }
  final remaining = maintenance.remainingKm ?? 0;
  if (remaining <= 0) {
    return '已超期 ${formatKmValue(-remaining)}';
  }
  return formatKmValue(remaining);
}

String _maintenanceUnit(GarageSnapshot snapshot) {
  final maintenance = snapshot.maintenance;
  if (!maintenance.enabled) {
    return '未设置保养周期';
  }
  final name = snapshot.isAllAssets ? maintenance.vehicleName : null;
  final remaining = maintenance.remainingKm ?? 0;
  if (remaining <= 0) {
    return name == null ? 'km' : '$name · km';
  }
  final suffix = maintenance.status == MaintenanceStatus.warning
      ? 'km 后 · 即将保养'
      : 'km 后';
  return name == null ? suffix : '$name · $suffix';
}

String _firstGrapheme(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '?';
  }
  return String.fromCharCodes(trimmed.runes.take(1));
}
