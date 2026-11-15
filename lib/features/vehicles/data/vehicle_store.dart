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
    this.batteryHealthPercent,
    this.insuranceExpiry,
    this.inspectionExpiry,
  });

  final Vehicle vehicle;
  final String specLabel;
  final int sortOrder;
  final bool isArchived;
  final DateTime? archivedAt;

  /// 电池健康（SOH），0–100；缺失为 null。
  final int? batteryHealthPercent;

  /// 商业险到期日；缺失为 null。
  final DateTime? insuranceExpiry;

  /// 年检到期日；缺失为 null。
  final DateTime? inspectionExpiry;

  String get id => vehicle.id;

  VehicleRecord copyWith({
    bool? isArchived,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
    int? sortOrder,
    int? batteryHealthPercent,
    DateTime? insuranceExpiry,
    DateTime? inspectionExpiry,
  }) {
    return VehicleRecord(
      vehicle: vehicle,
      specLabel: specLabel,
      sortOrder: sortOrder ?? this.sortOrder,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
      batteryHealthPercent: batteryHealthPercent ?? this.batteryHealthPercent,
      insuranceExpiry: insuranceExpiry ?? this.insuranceExpiry,
      inspectionExpiry: inspectionExpiry ?? this.inspectionExpiry,
    );
  }
}

enum VehicleStoreError { notFound, archived, notArchived, isPrimary }

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
}
