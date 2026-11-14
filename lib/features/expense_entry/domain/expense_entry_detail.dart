import 'package:material_ui/material_ui.dart';

import '../../../core/domain/enums.dart';

/// 分类参数的默认单价，单位均为「分 / 计量单位」。
@immutable
class EntryUnitPrices {
  const EntryUnitPrices({
    this.chargingCentsPerKwh = 120,
    this.fuelCentsPerLiter = 785,
    this.parkingCentsPerHour = 800,
  });

  final int chargingCentsPerKwh;
  final int fuelCentsPerLiter;
  final int parkingCentsPerHour;

  EntryUnitPrices copyWith({
    int? chargingCentsPerKwh,
    int? fuelCentsPerLiter,
    int? parkingCentsPerHour,
  }) {
    return EntryUnitPrices(
      chargingCentsPerKwh: chargingCentsPerKwh ?? this.chargingCentsPerKwh,
      fuelCentsPerLiter: fuelCentsPerLiter ?? this.fuelCentsPerLiter,
      parkingCentsPerHour: parkingCentsPerHour ?? this.parkingCentsPerHour,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EntryUnitPrices &&
      other.chargingCentsPerKwh == chargingCentsPerKwh &&
      other.fuelCentsPerLiter == fuelCentsPerLiter &&
      other.parkingCentsPerHour == parkingCentsPerHour;

  @override
  int get hashCode =>
      Object.hash(chargingCentsPerKwh, fuelCentsPerLiter, parkingCentsPerHour);
}

/// 分类专属参数。与 [ExpenseCategory] 一一对应，保存时序列化为 `detail`。
sealed class EntryCategoryDetail {
  const EntryCategoryDetail();

  ExpenseCategory get category;

  Map<String, Object?> toJson();
}

/// 构造期占位，不会被渲染。
class EmptyEntryDetail extends EntryCategoryDetail {
  const EmptyEntryDetail();

  @override
  ExpenseCategory get category => ExpenseCategory.other;

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};
}

class ChargingDetail extends EntryCategoryDetail {
  const ChargingDetail({
    this.unitPriceCentsPerKwh = 120,
    this.socStart = 20,
    this.kwh,
    this.socEnd,
  });

  final int unitPriceCentsPerKwh;
  final int socStart;

  /// 由金额 ÷ 单价推导，保存前重算。
  final double? kwh;
  final int? socEnd;

  ChargingDetail copyWith({
    int? unitPriceCentsPerKwh,
    int? socStart,
    double? kwh,
    int? socEnd,
    bool clearDerived = false,
  }) {
    return ChargingDetail(
      unitPriceCentsPerKwh: unitPriceCentsPerKwh ?? this.unitPriceCentsPerKwh,
      socStart: socStart ?? this.socStart,
      kwh: clearDerived ? null : (kwh ?? this.kwh),
      socEnd: clearDerived ? null : (socEnd ?? this.socEnd),
    );
  }

  @override
  ExpenseCategory get category => ExpenseCategory.charging;

  @override
  Map<String, Object?> toJson() => {
    'type': 'charging',
    'kwh': kwh,
    'unitPriceCentsPerKwh': unitPriceCentsPerKwh,
    'socStart': socStart,
    'socEnd': socEnd,
  };

  @override
  bool operator ==(Object other) =>
      other is ChargingDetail &&
      other.unitPriceCentsPerKwh == unitPriceCentsPerKwh &&
      other.socStart == socStart &&
      other.kwh == kwh &&
      other.socEnd == socEnd;

  @override
  int get hashCode => Object.hash(unitPriceCentsPerKwh, socStart, kwh, socEnd);
}

class FuelDetail extends EntryCategoryDetail {
  const FuelDetail({
    this.unitPriceCentsPerLiter = 785,
    this.fuelGrade = 95,
    this.liters,
  });

  final int unitPriceCentsPerLiter;
  final int fuelGrade;
  final double? liters;

  FuelDetail copyWith({
    int? unitPriceCentsPerLiter,
    int? fuelGrade,
    double? liters,
    bool clearDerived = false,
  }) {
    return FuelDetail(
      unitPriceCentsPerLiter:
          unitPriceCentsPerLiter ?? this.unitPriceCentsPerLiter,
      fuelGrade: fuelGrade ?? this.fuelGrade,
      liters: clearDerived ? null : (liters ?? this.liters),
    );
  }

  @override
  ExpenseCategory get category => ExpenseCategory.fuel;

  @override
  Map<String, Object?> toJson() => {
    'type': 'fuel',
    'liters': liters,
    'unitPriceCentsPerLiter': unitPriceCentsPerLiter,
    'fuelGrade': fuelGrade,
  };

  @override
  bool operator ==(Object other) =>
      other is FuelDetail &&
      other.unitPriceCentsPerLiter == unitPriceCentsPerLiter &&
      other.fuelGrade == fuelGrade &&
      other.liters == liters;

  @override
  int get hashCode => Object.hash(unitPriceCentsPerLiter, fuelGrade, liters);
}

class ParkingDetail extends EntryCategoryDetail {
  const ParkingDetail({
    this.rateCentsPerHour = 800,
    this.durationMinutes,
    this.lotName,
  });

  final int rateCentsPerHour;
  final int? durationMinutes;
  final String? lotName;

  ParkingDetail copyWith({
    int? rateCentsPerHour,
    int? durationMinutes,
    String? lotName,
    bool clearDerived = false,
    bool clearLotName = false,
  }) {
    return ParkingDetail(
      rateCentsPerHour: rateCentsPerHour ?? this.rateCentsPerHour,
      durationMinutes: clearDerived
          ? null
          : (durationMinutes ?? this.durationMinutes),
      lotName: clearLotName ? null : (lotName ?? this.lotName),
    );
  }

  @override
  ExpenseCategory get category => ExpenseCategory.parking;

  @override
  Map<String, Object?> toJson() => {
    'type': 'parking',
    'durationMinutes': durationMinutes,
    'rateCentsPerHour': rateCentsPerHour,
    'lotName': lotName,
  };

  @override
  bool operator ==(Object other) =>
      other is ParkingDetail &&
      other.rateCentsPerHour == rateCentsPerHour &&
      other.durationMinutes == durationMinutes &&
      other.lotName == lotName;

  @override
  int get hashCode => Object.hash(rateCentsPerHour, durationMinutes, lotName);
}

class TollDetail extends EntryCategoryDetail {
  const TollDetail({
    this.entryStation,
    this.exitStation,
    this.roadName,
    this.distanceKm,
  });

  final String? entryStation;
  final String? exitStation;
  final String? roadName;
  final int? distanceKm;

  TollDetail copyWith({
    String? entryStation,
    String? exitStation,
    String? roadName,
    int? distanceKm,
    bool clearEntryStation = false,
    bool clearExitStation = false,
    bool clearRoadName = false,
    bool clearDistance = false,
  }) {
    return TollDetail(
      entryStation: clearEntryStation
          ? null
          : (entryStation ?? this.entryStation),
      exitStation: clearExitStation ? null : (exitStation ?? this.exitStation),
      roadName: clearRoadName ? null : (roadName ?? this.roadName),
      distanceKm: clearDistance ? null : (distanceKm ?? this.distanceKm),
    );
  }

  @override
  ExpenseCategory get category => ExpenseCategory.toll;

  @override
  Map<String, Object?> toJson() => {
    'type': 'toll',
    'entryStation': entryStation,
    'exitStation': exitStation,
    'roadName': roadName,
    'distanceKm': distanceKm,
  };

  @override
  bool operator ==(Object other) =>
      other is TollDetail &&
      other.entryStation == entryStation &&
      other.exitStation == exitStation &&
      other.roadName == roadName &&
      other.distanceKm == distanceKm;

  @override
  int get hashCode =>
      Object.hash(entryStation, exitStation, roadName, distanceKm);
}

class MaintenanceDetail extends EntryCategoryDetail {
  const MaintenanceDetail({this.item, this.shopName, this.odometerKm});

  final String? item;
  final String? shopName;
  final int? odometerKm;

  MaintenanceDetail copyWith({
    String? item,
    String? shopName,
    int? odometerKm,
    bool clearItem = false,
    bool clearShopName = false,
    bool clearOdometer = false,
  }) {
    return MaintenanceDetail(
      item: clearItem ? null : (item ?? this.item),
      shopName: clearShopName ? null : (shopName ?? this.shopName),
      odometerKm: clearOdometer ? null : (odometerKm ?? this.odometerKm),
    );
  }

  @override
  ExpenseCategory get category => ExpenseCategory.maintenance;

  @override
  Map<String, Object?> toJson() => {
    'type': 'maintenance',
    'item': item,
    'shopName': shopName,
    'odometerKm': odometerKm,
  };

  @override
  bool operator ==(Object other) =>
      other is MaintenanceDetail &&
      other.item == item &&
      other.shopName == shopName &&
      other.odometerKm == odometerKm;

  @override
  int get hashCode => Object.hash(item, shopName, odometerKm);
}

class CarWashDetail extends EntryCategoryDetail {
  const CarWashDetail({this.serviceType = '标准洗车', this.shopName});

  final String serviceType;
  final String? shopName;

  CarWashDetail copyWith({
    String? serviceType,
    String? shopName,
    bool clearShopName = false,
  }) {
    return CarWashDetail(
      serviceType: serviceType ?? this.serviceType,
      shopName: clearShopName ? null : (shopName ?? this.shopName),
    );
  }

  @override
  ExpenseCategory get category => ExpenseCategory.carWash;

  @override
  Map<String, Object?> toJson() => {
    'type': 'carWash',
    'serviceType': serviceType,
    'shopName': shopName,
  };

  @override
  bool operator ==(Object other) =>
      other is CarWashDetail &&
      other.serviceType == serviceType &&
      other.shopName == shopName;

  @override
  int get hashCode => Object.hash(serviceType, shopName);
}

class InsuranceDetail extends EntryCategoryDetail {
  const InsuranceDetail({
    this.coverageType = '商业险',
    this.policyNo,
    this.periodStart,
    this.periodEnd,
  });

  final String coverageType;
  final String? policyNo;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  InsuranceDetail copyWith({
    String? coverageType,
    String? policyNo,
    DateTime? periodStart,
    DateTime? periodEnd,
    bool clearPolicyNo = false,
    bool clearPeriod = false,
  }) {
    return InsuranceDetail(
      coverageType: coverageType ?? this.coverageType,
      policyNo: clearPolicyNo ? null : (policyNo ?? this.policyNo),
      periodStart: clearPeriod ? null : (periodStart ?? this.periodStart),
      periodEnd: clearPeriod ? null : (periodEnd ?? this.periodEnd),
    );
  }

  @override
  ExpenseCategory get category => ExpenseCategory.other;

  @override
  Map<String, Object?> toJson() => {
    'type': 'insurance',
    'coverageType': coverageType,
    'policyNo': policyNo,
    'periodStart': periodStart?.toIso8601String(),
    'periodEnd': periodEnd?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is InsuranceDetail &&
      other.coverageType == coverageType &&
      other.policyNo == policyNo &&
      other.periodStart == periodStart &&
      other.periodEnd == periodEnd;

  @override
  int get hashCode =>
      Object.hash(coverageType, policyNo, periodStart, periodEnd);
}

/// 根据分类构造默认参数。切换分类时整组替换。
EntryCategoryDetail defaultDetailFor(
  ExpenseCategory category, {
  EntryUnitPrices unitPrices = const EntryUnitPrices(),
  int fuelGrade = 95,
  int socStart = 20,
  String? place,
}) {
  return switch (category) {
    ExpenseCategory.charging => ChargingDetail(
      unitPriceCentsPerKwh: unitPrices.chargingCentsPerKwh,
      socStart: socStart,
    ),
    ExpenseCategory.fuel => FuelDetail(
      unitPriceCentsPerLiter: unitPrices.fuelCentsPerLiter,
      fuelGrade: fuelGrade,
    ),
    ExpenseCategory.parking => ParkingDetail(
      rateCentsPerHour: unitPrices.parkingCentsPerHour,
      lotName: place,
    ),
    ExpenseCategory.toll => const TollDetail(),
    ExpenseCategory.maintenance => MaintenanceDetail(
      shopName: place,
      odometerKm: null,
    ),
    ExpenseCategory.carWash => CarWashDetail(shopName: place),
    ExpenseCategory.other => const InsuranceDetail(),
  };
}
