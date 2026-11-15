import 'package:flutter/foundation.dart';

import '../../../core/domain/vehicle.dart';

/// 车辆管理域内的可变记录：基础车辆信息 + 档案 / 归档 / 排序。
@immutable
class VehicleRecord {
  const VehicleRecord({
    required this.vehicle,
    required this.specLabel,
    required this.sortOrder,
    this.isArchived = false,
    this.archivedAt,
    this.nickname,
    this.officialConsumption,
    this.electricRangeKm,
    this.purchaseDate,
    this.purchasePriceCents,
    this.nextMaintenanceKm,
    this.batteryHealthPercent,
    this.insuranceExpiry,
    this.inspectionExpiry,
  });

  final Vehicle vehicle;
  final String specLabel;
  final int sortOrder;
  final bool isArchived;
  final DateTime? archivedAt;

  /// 档案别名；不替换 [Vehicle.name]。
  final String? nickname;

  /// 官方标称电耗 / 亏电油耗 / 综合油耗 / 标称油耗。
  /// 单位与展示标签由动力类型决定。
  final double? officialConsumption;

  /// 纯电续航（PHEV），km。
  final int? electricRangeKm;

  /// 首次上牌 / 购车日期，只取 y/m/d。
  final DateTime? purchaseDate;

  /// 购车落地价，整数分；26.8 万元 = 26800000。
  final int? purchasePriceCents;

  /// 下次保养的绝对表显里程。
  final int? nextMaintenanceKm;

  /// 电池健康（SOH），0–100；缺失为 null。
  final int? batteryHealthPercent;

  /// 商业险到期日；缺失为 null。
  final DateTime? insuranceExpiry;

  /// 年检到期日；缺失为 null。
  final DateTime? inspectionExpiry;

  String get id => vehicle.id;

  VehicleRecord copyWith({
    Vehicle? vehicle,
    String? specLabel,
    bool? isArchived,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
    String? nickname,
    bool clearNickname = false,
    int? sortOrder,
    int? batteryHealthPercent,
    DateTime? insuranceExpiry,
    DateTime? inspectionExpiry,
  }) {
    return VehicleRecord(
      vehicle: vehicle ?? this.vehicle,
      specLabel: specLabel ?? this.specLabel,
      sortOrder: sortOrder ?? this.sortOrder,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
      nickname: clearNickname ? null : (nickname ?? this.nickname),
      officialConsumption: officialConsumption,
      electricRangeKm: electricRangeKm,
      purchaseDate: purchaseDate,
      purchasePriceCents: purchasePriceCents,
      nextMaintenanceKm: nextMaintenanceKm,
      batteryHealthPercent: batteryHealthPercent ?? this.batteryHealthPercent,
      insuranceExpiry: insuranceExpiry ?? this.insuranceExpiry,
      inspectionExpiry: inspectionExpiry ?? this.inspectionExpiry,
    );
  }
}

enum VehicleStoreError {
  notFound,
  archived,
  notArchived,
  isPrimary,
  duplicatePlate,
  limitReached,
}

class VehicleStoreException implements Exception {
  const VehicleStoreException(this.error);

  final VehicleStoreError error;

  @override
  String toString() => 'VehicleStoreException($error)';
}

/// 车库内存状态：在库 / 归档 / 默认主驾 / 排序的唯一来源。
///
/// Mock 阶段只存在内存；接入接口后由服务端持有，客户端只保留快照。
class VehicleStore {
  VehicleStore({required List<VehicleRecord> records, String? primaryVehicleId})
    : _records = [...records] {
    _primaryVehicleId = primaryVehicleId;
  }

  static const maxActiveVehicles = 10;

  final List<VehicleRecord> _records;
  String? _primaryVehicleId;

  String? get primaryVehicleId => _primaryVehicleId;

  /// 在库车辆：默认主驾置顶，其余按 sortOrder 升序。
  List<VehicleRecord> get active {
    final list = _records.where((record) => !record.isArchived).toList()
      ..sort(_compare);
    return List<VehicleRecord>.unmodifiable(list);
  }

  /// 归档车辆：最近归档的在前。
  List<VehicleRecord> get archived {
    final list = _records.where((record) => record.isArchived).toList()
      ..sort((a, b) {
        final aAt = a.archivedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bAt = b.archivedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bAt.compareTo(aAt);
      });
    return List<VehicleRecord>.unmodifiable(list);
  }

  int get nextSortOrder =>
      _records.fold<int>(
        -1,
        (max, record) => record.sortOrder > max ? record.sortOrder : max,
      ) +
      1;

  VehicleRecord require(String id) {
    for (final record in _records) {
      if (record.id == id) {
        return record;
      }
    }
    throw const VehicleStoreException(VehicleStoreError.notFound);
  }

  VehicleRecord? byId(String id) {
    for (final record in _records) {
      if (record.id == id) {
        return record;
      }
    }
    return null;
  }

  /// 车牌冲突检查；包含归档车辆。
  VehicleRecord? byPlate(String plate) {
    final normalized = _normalizePlate(plate);
    for (final record in _records) {
      if (_normalizePlate(record.vehicle.plate) == normalized) {
        return record;
      }
    }
    return null;
  }

  /// 新增在库车辆；[sortOrder] 由 store 分配。
  VehicleRecord add(VehicleRecord record, {bool makePrimary = false}) {
    if (record.isArchived) {
      throw const VehicleStoreException(VehicleStoreError.archived);
    }
    if (active.length >= maxActiveVehicles) {
      throw const VehicleStoreException(VehicleStoreError.limitReached);
    }
    if (byPlate(record.vehicle.plate) != null) {
      throw const VehicleStoreException(VehicleStoreError.duplicatePlate);
    }
    final created = VehicleRecord(
      vehicle: record.vehicle,
      specLabel: record.specLabel,
      sortOrder: nextSortOrder,
      nickname: record.nickname,
      officialConsumption: record.officialConsumption,
      electricRangeKm: record.electricRangeKm,
      purchaseDate: record.purchaseDate,
      purchasePriceCents: record.purchasePriceCents,
      nextMaintenanceKm: record.nextMaintenanceKm,
      insuranceExpiry: record.insuranceExpiry,
      inspectionExpiry: record.inspectionExpiry,
    );
    _records.add(created);
    if (makePrimary || _primaryVehicleId == null) {
      _primaryVehicleId = created.id;
    }
    return created;
  }

  /// 更新在库车辆档案；保留排序、归档状态、SOH 与年检。
  VehicleRecord update(
    String id,
    VehicleRecord updated, {
    bool makePrimary = false,
  }) {
    final current = require(id);
    if (current.isArchived) {
      throw const VehicleStoreException(VehicleStoreError.archived);
    }
    final owner = byPlate(updated.vehicle.plate);
    if (owner != null && owner.id != id) {
      throw const VehicleStoreException(VehicleStoreError.duplicatePlate);
    }
    final next = VehicleRecord(
      vehicle: updated.vehicle,
      specLabel: updated.specLabel,
      sortOrder: current.sortOrder,
      isArchived: current.isArchived,
      archivedAt: current.archivedAt,
      nickname: updated.nickname,
      officialConsumption: updated.officialConsumption,
      electricRangeKm: updated.electricRangeKm,
      purchaseDate: updated.purchaseDate,
      purchasePriceCents: updated.purchasePriceCents,
      nextMaintenanceKm: updated.nextMaintenanceKm,
      batteryHealthPercent: current.batteryHealthPercent,
      insuranceExpiry: updated.insuranceExpiry,
      inspectionExpiry: current.inspectionExpiry,
    );
    _replace(next);
    if (makePrimary) {
      _primaryVehicleId = id;
    }
    return next;
  }

  int _compare(VehicleRecord a, VehicleRecord b) {
    if (a.id == _primaryVehicleId) {
      return -1;
    }
    if (b.id == _primaryVehicleId) {
      return 1;
    }
    final byOrder = a.sortOrder.compareTo(b.sortOrder);
    return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
  }

  /// 归档 [id] 后应由谁接任默认主驾；没有剩余车辆时为 null。
  String? successorOf(String id) {
    final remaining = active.where((record) => record.id != id).toList();
    return remaining.isEmpty ? null : remaining.first.id;
  }

  void setPrimary(String id) {
    final record = require(id);
    if (record.isArchived) {
      throw const VehicleStoreException(VehicleStoreError.archived);
    }
    _primaryVehicleId = id;
  }

  void archive(String id, {DateTime? at}) {
    final record = require(id);
    if (record.isArchived) {
      return;
    }
    final wasPrimary = _primaryVehicleId == id;
    final successor = wasPrimary ? successorOf(id) : null;
    _replace(
      record.copyWith(isArchived: true, archivedAt: at ?? DateTime.now()),
    );
    if (wasPrimary) {
      _primaryVehicleId = successor;
    }
  }

  void restore(String id) {
    final record = require(id);
    if (!record.isArchived) {
      throw const VehicleStoreException(VehicleStoreError.notArchived);
    }
    _replace(
      record.copyWith(
        isArchived: false,
        clearArchivedAt: true,
        sortOrder: nextSortOrder,
      ),
    );
    _primaryVehicleId ??= id;
  }

  /// 删除归档车辆档案。仅归档记录可删除；在库车辆走 [delete] 规则。
  void purge(String id) {
    final record = require(id);
    if (!record.isArchived) {
      throw const VehicleStoreException(VehicleStoreError.notArchived);
    }
    _records.removeWhere((item) => item.id == id);
    if (_primaryVehicleId == id) {
      _primaryVehicleId = null;
    }
  }

  void delete(String id) {
    final record = require(id);
    if (_primaryVehicleId == id && active.length > 1) {
      throw const VehicleStoreException(VehicleStoreError.isPrimary);
    }
    _records.removeWhere((item) => item.id == record.id);
    if (_primaryVehicleId == id) {
      _primaryVehicleId = null;
    }
  }

  void _replace(VehicleRecord record) {
    final index = _records.indexWhere((item) => item.id == record.id);
    if (index < 0) {
      throw const VehicleStoreException(VehicleStoreError.notFound);
    }
    _records[index] = record;
  }

  String _normalizePlate(String plate) =>
      plate.toUpperCase().replaceAll(RegExp(r'[\s·•\-]'), '');
}
