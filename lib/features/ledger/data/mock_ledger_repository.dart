import '../../../core/domain/enums.dart';
import '../domain/ledger_models.dart';
import 'ledger_repository.dart';

/// 本地账单 Mock：按月份确定性生成数据，便于验证月份切换、筛选、
/// 分页与滚动性能；汇总由同一批记录聚合，保证「总额 = 分组之和」。
class MockLedgerRepository implements LedgerRepository {
  MockLedgerRepository({this.delay = const Duration(milliseconds: 160)});

  final Duration delay;

  final Map<String, List<LedgerRecord>> _monthCache = {};
  final Map<String, LedgerRecord> _idIndex = {};
  final Set<String> _deletedIds = {};

  @override
  Future<LedgerMonthSummary> fetchSummary(LedgerScope scope) async {
    await Future<void>.delayed(delay);
    final now = DateTime.now();
    final month = DateTime(scope.month.year, scope.month.month);
    final records = _recordsFor(month)
        .where((record) => !_deletedIds.contains(record.id))
        .where(
          (record) =>
              scope.vehicleId == null || record.vehicleId == scope.vehicleId,
        )
        .toList(growable: false);

    final total = _sum(records);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final isCurrentMonth = month.year == now.year && month.month == now.month;
    final lastDay = isCurrentMonth ? now.day : daysInMonth;
    final daily = <LedgerDailyPoint>[];
    for (var day = 1; day <= lastDay; day++) {
      final date = DateTime(month.year, month.month, day);
      final dayRecords = records
          .where((record) => isSameDay(record.occurredAt, date))
          .toList(growable: false);
      daily.add(
        LedgerDailyPoint(
          date: date,
          amountCents: _sum(dayRecords),
          dominantCategory: _dominantCategory(dayRecords),
        ),
      );
    }

    final previousMonth = DateTime(month.year, month.month - 1);
    final previousTotal = _sum(
      _recordsFor(previousMonth)
          .where((record) => !_deletedIds.contains(record.id))
          .where(
            (record) =>
                scope.vehicleId == null || record.vehicleId == scope.vehicleId,
          ),
    );

    final momPercent = previousTotal == 0
        ? null
        : (total - previousTotal) / previousTotal * 100;
    final momTrend = previousTotal == 0
        ? TrendDirection.none
        : total > previousTotal
        ? TrendDirection.up
        : total < previousTotal
        ? TrendDirection.down
        : TrendDirection.flat;

    return LedgerMonthSummary(
      month: month,
      totalCents: total,
      count: records.length,
      energyCents: records
          .where(
            (record) =>
                record.category == ExpenseCategory.charging ||
                record.category == ExpenseCategory.fuel,
          )
          .fold(0, (sum, record) => sum + record.amountCents),
      serviceCents: records
          .where(
            (record) =>
                record.category == ExpenseCategory.maintenance ||
                record.category == ExpenseCategory.carWash,
          )
          .fold(0, (sum, record) => sum + record.amountCents),
      dailyAverageCents: total == 0 ? 0 : (total / daysInMonth).round(),
      daily: daily,
      momPercent: momPercent,
      momTrend: momTrend,
    );
  }

  @override
  Future<LedgerRecordsPage> fetchRecords(
    LedgerQuery query, {
    String? cursor,
    int limit = 30,
  }) async {
    await Future<void>.delayed(delay);
    final records = _recordsFor(DateTime(query.month.year, query.month.month))
        .where((record) => !_deletedIds.contains(record.id))
        .where(
          (record) =>
              query.vehicleId == null || record.vehicleId == query.vehicleId,
        )
        .where(
          (record) =>
              query.category == null || record.category == query.category,
        )
        .toList();

    switch (query.sort) {
      case LedgerSort.timeDesc:
        records.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      case LedgerSort.amountDesc:
        records.sort((a, b) {
          final byAmount = b.amountCents.compareTo(a.amountCents);
          return byAmount != 0
              ? byAmount
              : b.occurredAt.compareTo(a.occurredAt);
        });
      case LedgerSort.category:
        records.sort((a, b) {
          final byCategory = a.category.index.compareTo(b.category.index);
          return byCategory != 0
              ? byCategory
              : b.occurredAt.compareTo(a.occurredAt);
        });
    }

    final start = (cursor == null ? 0 : int.tryParse(cursor) ?? 0)
        .clamp(0, records.length)
        .toInt();
    final end = (start + limit).clamp(0, records.length).toInt();
    final items = records.sublist(start, end);
    final hasMore = end < records.length;

    return LedgerRecordsPage(
      items: items,
      hasMore: hasMore,
      nextCursor: hasMore ? end.toString() : null,
    );
  }

  /// 按 id 查找记录：先查索引，再回扫最近 24 个月。
  ///
  /// 已删除的记录返回 null。
  LedgerRecord? recordById(String id) {
    if (_deletedIds.contains(id)) {
      return null;
    }
    final cached = _idIndex[id];
    if (cached != null) {
      return cached;
    }
    final now = DateTime.now();
    for (var i = 0; i < 24; i++) {
      final month = DateTime(now.year, now.month - i);
      for (final record in _recordsFor(month)) {
        if (record.id == id) {
          _idIndex[id] = record;
          return record;
        }
      }
    }
    return null;
  }

  /// 标记记录已删除，后续列表 / 汇总 / 详情都不再返回。
  void markDeleted(String id) {
    _deletedIds.add(id);
    _idIndex.remove(id);
  }

  List<LedgerRecord> _recordsFor(DateTime month) {
    final key = '${month.year}-${month.month}';
    final cached = _monthCache[key];
    if (cached != null) {
      return cached;
    }
    final records = _generate(month);
    _monthCache[key] = records;
    return records;
  }

  List<LedgerRecord> _generate(DateTime month) {
    final now = DateTime.now();
    final isCurrentMonth = month.year == now.year && month.month == now.month;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lastDay = isCurrentMonth ? now.day : daysInMonth;
    final random = _Lcg(month.year * 372 + month.month * 31 + 7);
    final records = <LedgerRecord>[];
    var serial = 0;

    for (var day = 1; day <= lastDay; day++) {
      final count = _recordsForDay(day, random);
      for (var i = 0; i < count; i++) {
        final minuteOfDay = 7 * 60 + random.next(14 * 60);
        final time = DateTime(
          month.year,
          month.month,
          day,
          minuteOfDay ~/ 60,
          minuteOfDay % 60,
        );
        if (isCurrentMonth && time.isAfter(now)) {
          continue;
        }
        final category = _pickCategory(random);
        final vehicle = _pickVehicle(category, random);
        records.add(_buildRecord(serial++, vehicle, category, time, random));
      }
    }

    if (isCurrentMonth) {
      records.addAll(_anchors(now));
    } else {
      records.addAll(_historicalAnchors(month));
    }
    _ensureAllCategories(records, month, now, isCurrentMonth);

    records.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return List<LedgerRecord>.unmodifiable(records);
  }

  /// 保证每种分类至少有一条记录，避免分类筛选出现「整月无数据」，
  /// 也保证 Mock 能稳定覆盖七类记录卡的展示规则。
  void _ensureAllCategories(
    List<LedgerRecord> records,
    DateTime month,
    DateTime now,
    bool isCurrentMonth,
  ) {
    final covered = records.map((record) => record.category).toSet();
    for (final category in ExpenseCategory.values) {
      if (covered.contains(category)) {
        continue;
      }
      final fallbackDay = DateTime(month.year, month.month, 1, 8, 0);
      var time = fallbackDay;
      if (isCurrentMonth && time.isAfter(now)) {
        time = now.subtract(const Duration(minutes: 45));
        if (time.month != month.month) {
          continue;
        }
      }
      final vehicle = _pickVehicle(category, _Lcg(month.month * 17 + 3));
      records.add(
        _buildRecord(9000 + category.index, vehicle, category, time, _Lcg(7)),
      );
    }
  }

  int _recordsForDay(int day, _Lcg random) {
    if (day % 3 == 0) {
      return 2;
    }
    if (day.isEven) {
      return 1;
    }
    return random.next(10) < 4 ? 1 : 0;
  }

  List<LedgerRecord> _anchors(DateTime now) {
    final records = <LedgerRecord>[];
    final today = DateTime(now.year, now.month, now.day);
    final chargingTime = _safeTime(today, 8, 42, now);
    if (chargingTime.month == now.month) {
      records.add(
        _buildCharging(
          id: 'anchor-charging',
          vehicle: _vehicles.first,
          time: chargingTime,
          kwh: 38.5,
          unitPriceCents: 133,
        ),
      );
    }
    final parkingTime = _safeTime(today, 16, 45, now);
    if (parkingTime.month == now.month) {
      records.add(
        LedgerRecord(
          id: 'anchor-parking',
          vehicleId: _vehicles.first.id,
          vehicleShortName: _vehicles.first.shortName,
          vehicleName: _vehicles.first.name,
          powertrain: _vehicles.first.powertrain,
          category: ExpenseCategory.parking,
          title: '万象城地下停车场',
          amountCents: 2400,
          occurredAt: parkingTime,
          badgeText: 'B2区',
          badgeKind: LedgerBadgeKind.meta,
          metrics: LedgerMetrics(
            durationMinutes: 210,
            plate: _vehicles.first.plate,
            paymentMethod: '无感支付',
          ),
          statusText: '${(parkingTime.hour + 3) % 24}:45 离场',
        ),
      );
    }
    final maintenanceDay = now.day >= 15 ? 15 : null;
    if (maintenanceDay != null) {
      records.add(
        _buildMaintenanceAnchor(
          DateTime(now.year, now.month, maintenanceDay, 14, 30),
          _vehicles.first,
          48000,
          '二保小保养 + CN95空调滤芯更换',
        ),
      );
    }
    if (now.day >= 20) {
      records.add(
        _buildFuelAnchor(
          DateTime(now.year, now.month, 20, 18, 20),
          _vehicles[1],
          24.51,
          816,
        ),
      );
    }
    return records;
  }

  List<LedgerRecord> _historicalAnchors(DateTime month) {
    final random = _Lcg(month.year * 97 + month.month * 13);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    return [
      _buildMaintenanceAnchor(
        DateTime(month.year, month.month, 15, 14, 30),
        _vehicles[random.next(_vehicles.length)],
        48000,
        '二保小保养 + CN95空调滤芯更换',
      ),
      _buildCharging(
        id: 'anchor-charging',
        vehicle: _vehicles.first,
        time: DateTime(month.year, month.month, daysInMonth, 8, 42),
        kwh: 38.5,
        unitPriceCents: 133,
      ),
    ];
  }

  DateTime _safeTime(DateTime day, int hour, int minute, DateTime now) {
    final candidate = DateTime(day.year, day.month, day.day, hour, minute);
    return candidate.isAfter(now)
        ? candidate.subtract(const Duration(days: 1))
        : candidate;
  }

  LedgerRecord _buildRecord(
    int serial,
    _MockVehicle vehicle,
    ExpenseCategory category,
    DateTime time,
    _Lcg random,
  ) {
    final id =
        'ledger-${time.year}'
        '${time.month.toString().padLeft(2, '0')}'
        '${time.day.toString().padLeft(2, '0')}-$serial';
    switch (category) {
      case ExpenseCategory.charging:
        return _buildCharging(
          id: id,
          vehicle: vehicle,
          time: time,
          kwh: 20 + random.next(300) / 10,
          unitPriceCents: 120 + random.next(60),
        );
      case ExpenseCategory.fuel:
        return _buildFuelAnchor(
          time,
          vehicle,
          20 + random.next(300) / 10,
          780 + random.next(80),
          id: id,
        );
      case ExpenseCategory.maintenance:
        return _buildMaintenanceAnchor(
          time,
          vehicle,
          20000 + random.next(40000),
          _maintenanceProjects[random.next(_maintenanceProjects.length)],
          id: id,
        );
      case ExpenseCategory.parking:
        final duration = 45 + random.next(240);
        final departure = time.add(Duration(minutes: duration));
        return LedgerRecord(
          id: id,
          vehicleId: vehicle.id,
          vehicleShortName: vehicle.shortName,
          vehicleName: vehicle.name,
          powertrain: vehicle.powertrain,
          category: category,
          title: _parkingTitles[random.next(_parkingTitles.length)],
          amountCents: 500 + random.next(3000),
          occurredAt: time,
          badgeText: 'B2区',
          badgeKind: LedgerBadgeKind.meta,
          metrics: LedgerMetrics(
            durationMinutes: duration,
            plate: vehicle.plate,
            paymentMethod: '无感支付',
          ),
          statusText:
              '${departure.hour.toString().padLeft(2, '0')}:'
              '${departure.minute.toString().padLeft(2, '0')} 离场',
        );
      case ExpenseCategory.toll:
        return LedgerRecord(
          id: id,
          vehicleId: vehicle.id,
          vehicleShortName: vehicle.shortName,
          vehicleName: vehicle.name,
          powertrain: vehicle.powertrain,
          category: category,
          title: _tollTitles[random.next(_tollTitles.length)],
          amountCents: 2000 + random.next(6000),
          occurredAt: time,
          badgeText: vehicle.shortName,
          badgeKind: LedgerBadgeKind.vehicle,
          description: _tollDescriptions[random.next(_tollDescriptions.length)],
          metrics: const LedgerMetrics(paymentMethod: 'ETC'),
          statusText: '粤通卡ETC',
        );
      case ExpenseCategory.carWash:
        return LedgerRecord(
          id: id,
          vehicleId: vehicle.id,
          vehicleShortName: vehicle.shortName,
          vehicleName: vehicle.name,
          powertrain: vehicle.powertrain,
          category: category,
          title: _carWashTitles[random.next(_carWashTitles.length)],
          amountCents: 2000 + random.next(4000),
          occurredAt: time,
          badgeText: vehicle.shortName,
          badgeKind: LedgerBadgeKind.vehicle,
          description:
              _carWashDescriptions[random.next(_carWashDescriptions.length)],
          metrics: const LedgerMetrics(paymentMethod: '微信'),
          statusText: '微信支付',
        );
      case ExpenseCategory.other:
        return LedgerRecord(
          id: id,
          vehicleId: vehicle.id,
          vehicleShortName: vehicle.shortName,
          vehicleName: vehicle.name,
          powertrain: vehicle.powertrain,
          category: category,
          title: _otherTitles[random.next(_otherTitles.length)],
          amountCents: 5000 + random.next(30000),
          occurredAt: time,
          badgeText: vehicle.shortName,
          badgeKind: LedgerBadgeKind.vehicle,
          description:
              _otherDescriptions[random.next(_otherDescriptions.length)],
          metrics: const LedgerMetrics(paymentMethod: '支付宝'),
          statusText: '支付宝',
        );
    }
  }

  LedgerRecord _buildCharging({
    required String id,
    required _MockVehicle vehicle,
    required DateTime time,
    required double kwh,
    required int unitPriceCents,
  }) {
    return LedgerRecord(
      id: id,
      vehicleId: vehicle.id,
      vehicleShortName: vehicle.shortName,
      vehicleName: vehicle.name,
      powertrain: vehicle.powertrain,
      category: ExpenseCategory.charging,
      title: _chargingTitles[id.hashCode.abs() % _chargingTitles.length],
      amountCents: (kwh * unitPriceCents).round(),
      occurredAt: time,
      badgeText: vehicle.shortName,
      badgeKind: LedgerBadgeKind.vehicle,
      metrics: LedgerMetrics(
        kwh: kwh,
        odometerKm: vehicle.odometerKm - id.hashCode.abs() % 4000,
        distanceKm: 180 + id.hashCode.abs() % 420,
        paymentMethod: '微信',
      ),
    );
  }

  LedgerRecord _buildFuelAnchor(
    DateTime time,
    _MockVehicle vehicle,
    double liters,
    int unitPriceCents, {
    String? id,
  }) {
    return LedgerRecord(
      id: id ?? 'anchor-fuel',
      vehicleId: vehicle.id,
      vehicleShortName: vehicle.shortName,
      vehicleName: vehicle.name,
      powertrain: vehicle.powertrain,
      category: ExpenseCategory.fuel,
      title: _fuelTitles[time.day % _fuelTitles.length],
      amountCents: (liters * unitPriceCents).round(),
      occurredAt: time,
      badgeText: vehicle.shortName,
      badgeKind: LedgerBadgeKind.vehicle,
      metrics: LedgerMetrics(
        liters: liters,
        odometerKm: vehicle.odometerKm - time.day * 37,
        distanceKm: 220 + (id ?? time.day.toString()).hashCode.abs() % 480,
        paymentMethod: '云闪付',
      ),
    );
  }

  LedgerRecord _buildMaintenanceAnchor(
    DateTime time,
    _MockVehicle vehicle,
    int amountCents,
    String project, {
    String? id,
  }) {
    return LedgerRecord(
      id: id ?? 'anchor-maintenance',
      vehicleId: vehicle.id,
      vehicleShortName: vehicle.shortName,
      vehicleName: vehicle.name,
      powertrain: vehicle.powertrain,
      category: ExpenseCategory.maintenance,
      title: "${vehicle.name.split(' ').first} 4S 售后中心",
      amountCents: amountCents,
      occurredAt: time,
      badgeText: vehicle.shortName,
      badgeKind: LedgerBadgeKind.vehicle,
      description: project,
      metrics: const LedgerMetrics(paymentMethod: '支付宝'),
      statusText: '工单已归档',
    );
  }

  ExpenseCategory _pickCategory(_Lcg random) {
    final roll = random.next(100);
    if (roll < 32) {
      return ExpenseCategory.charging;
    }
    if (roll < 52) {
      return ExpenseCategory.fuel;
    }
    if (roll < 72) {
      return ExpenseCategory.parking;
    }
    if (roll < 82) {
      return ExpenseCategory.toll;
    }
    if (roll < 90) {
      return ExpenseCategory.maintenance;
    }
    if (roll < 95) {
      return ExpenseCategory.carWash;
    }
    return ExpenseCategory.other;
  }

  _MockVehicle _pickVehicle(ExpenseCategory category, _Lcg random) {
    final candidates = _vehicles
        .where((vehicle) {
          switch (category) {
            case ExpenseCategory.charging:
              return vehicle.powertrain == PowertrainType.ev ||
                  vehicle.powertrain == PowertrainType.phev;
            case ExpenseCategory.fuel:
              return vehicle.powertrain != PowertrainType.ev;
            case ExpenseCategory.maintenance:
            case ExpenseCategory.parking:
            case ExpenseCategory.toll:
            case ExpenseCategory.carWash:
            case ExpenseCategory.other:
              return true;
          }
        })
        .toList(growable: false);
    return candidates[random.next(candidates.length)];
  }

  static int _sum(Iterable<LedgerRecord> records) =>
      records.fold(0, (total, record) => total + record.amountCents);

  static ExpenseCategory? _dominantCategory(List<LedgerRecord> records) {
    final totals = <ExpenseCategory, int>{};
    for (final record in records) {
      totals.update(
        record.category,
        (value) => value + record.amountCents,
        ifAbsent: () => record.amountCents,
      );
    }
    if (totals.isEmpty) {
      return null;
    }
    var best = totals.entries.first;
    for (final entry in totals.entries) {
      if (entry.value > best.value) {
        best = entry;
      }
    }
    return best.value > 0 ? best.key : null;
  }
}

class _MockVehicle {
  const _MockVehicle({
    required this.id,
    required this.name,
    required this.shortName,
    required this.plate,
    required this.powertrain,
    required this.odometerKm,
  });

  final String id;
  final String name;
  final String shortName;
  final String plate;
  final PowertrainType powertrain;
  final int odometerKm;
}

const _vehicles = <_MockVehicle>[
  _MockVehicle(
    id: 'byd-han-ev',
    name: '比亚迪 汉 EV',
    shortName: '汉 EV',
    plate: '粤B·D82K6',
    powertrain: PowertrainType.ev,
    odometerKm: 18426,
  ),
  _MockVehicle(
    id: 'toyota-camry-hev',
    name: '丰田 凯美瑞 双擎',
    shortName: '凯美瑞',
    plate: '粤B·7Q315',
    powertrain: PowertrainType.hev,
    odometerKm: 46210,
  ),
  _MockVehicle(
    id: 'byd-song-plus-dmi',
    name: '宋PLUS DM-i',
    shortName: '宋PLUS',
    plate: '粤B·9X521',
    powertrain: PowertrainType.phev,
    odometerKm: 31520,
  ),
  _MockVehicle(
    id: 'bmw-325li',
    name: '宝马 3系 325Li',
    shortName: '3系',
    plate: '粤B·88K32',
    powertrain: PowertrainType.ice,
    odometerKm: 58940,
  ),
];

const _chargingTitles = [
  '特来电快充 · 科技园站',
  '国家电网 · 深南充电站',
  '小桔充电 · 万象城站',
  '星星充电 · 高新园站',
];

const _fuelTitles = ['中国石油 · 92#汽油', '中国石化 · 95#汽油', '中海油 · 92#汽油'];

const _maintenanceProjects = ['更换机油机滤', '四轮定位 + 刹车检查', '空调滤芯 + 制动液更换'];

const _parkingTitles = ['万象城地下停车场', '市民中心停车场', '科技园 P3 停车场'];

const _tollTitles = ['广深沿江高速 ETC', '南光高速 ETC', '深岑高速 ETC'];
const _tollDescriptions = ['宝安入口 → 南沙出口 · 95折自动扣费', '西丽入口 → 前海出口 · ETC 95折'];

const _carWashTitles = ['途虎养车 · 精细洗车', '车享家 · 标准洗车'];
const _carWashDescriptions = ['高压精洗+内饰除尘 · 会员优惠', '标准普洗 · 含轮胎清洁'];

const _otherTitles = ['平安车险 · 商业险', '车管所 · 年检代办'];
const _otherDescriptions = ['机动车交通事故责任强制保险', '年检代办服务费'];

/// 简单线性同余随机数，保证同一个月每次生成的数据一致。
class _Lcg {
  _Lcg(this._state);

  int _state;

  int next(int max) {
    _state = (_state * 1103515245 + 12345) & 0x7FFFFFFF;
    return max <= 0 ? 0 : _state % max;
  }
}
