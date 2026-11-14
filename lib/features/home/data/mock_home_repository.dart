import '../../../core/format/formatters.dart';
import '../../ledger/domain/ledger_models.dart';
import '../../ledger/domain/ledger_presenter.dart';
import '../../ledger/data/ledger_repository.dart';
import '../domain/home_models.dart';
import 'home_repository.dart';

class MockHomeRepository implements HomeRepository {
  MockHomeRepository({this.ledger});

  final LedgerRepository? ledger;

  @override
  String get defaultVehicleId => _cars.first.vehicle.id;

  @override
  Future<List<Vehicle>> fetchVehicles() async => [
    for (final car in _cars) car.vehicle,
  ];

  @override
  Future<HomeDashboard> fetchDashboard(String vehicleId) async {
    final car = _carById(vehicleId);
    return HomeDashboard(
      vehicle: car.vehicle,
      summary: car.summary,
      consumption: car.consumption,
      maintenance: car.maintenance,
    );
  }

  @override
  Future<Breakdown> fetchBreakdown(String vehicleId) async =>
      _carById(vehicleId).breakdown;

  @override
  Future<List<RecordItem>> fetchRecords(String vehicleId) async {
    final ledger = this.ledger;
    if (ledger == null) {
      return _carById(vehicleId).records.take(5).toList(growable: false);
    }
    final page = await ledger.fetchRecords(
      LedgerQuery(month: monthStart(DateTime.now()), vehicleId: vehicleId),
      limit: 20,
    );
    return page.items
        .take(5)
        .map(_toRecordItem)
        .toList(growable: false);
  }

  RecordItem _toRecordItem(LedgerRecord record) {
    final subtitle = record.subtitle;
    return RecordItem(
      id: record.id,
      category: record.category,
      title: '${record.category.label} · ${record.title}',
      subtitle: subtitle == null
          ? formatDayTitle(record.occurredAt)
          : '${formatDayTitle(record.occurredAt)} · $subtitle',
      amountCents: record.amountCents,
      subLabel: record.unitPricePillText,
    );
  }

  @override
  Future<TrendData> fetchTrend(String vehicleId, TrendRange range) async {
    final car = _carById(vehicleId);
    return _buildTrend(car, range);
  }

  _CarMock _carById(String vehicleId) =>
      _cars.firstWhere((car) => car.vehicle.id == vehicleId);
}

class _CarMock {
  const _CarMock({
    required this.vehicle,
    required this.summary,
    required this.consumption,
    required this.maintenance,
    required this.breakdown,
    required this.records,
    required this.previous30Cents,
    required this.otherDailyWeights,
  });

  final Vehicle vehicle;
  final HomeSummary summary;
  final Consumption consumption;
  final Maintenance maintenance;
  final Breakdown breakdown;
  final List<RecordItem> records;
  final int previous30Cents;

  /// 30 天「其他开销」的走势权重，用于生成接近设计稿的峰值曲线。
  final List<double> otherDailyWeights;

  int get energyCents => breakdown.categories
      .where(
        (item) =>
            item.category == ExpenseCategory.charging ||
            item.category == ExpenseCategory.fuel,
      )
      .fold(0, (sum, item) => sum + item.amountCents);
}

final List<_CarMock> _cars = [
  _CarMock(
    vehicle: const Vehicle(
      id: 'byd-han-ev',
      name: '比亚迪 汉 EV',
      plate: '粤B·D82K6',
      powertrain: PowertrainType.ev,
      powertrainLabel: '纯电',
      odometerKm: 18426,
    ),
    summary: const HomeSummary(
      costPerKm: 0.60,
      monthSpendCents: 128600,
      monthMileageKm: 2140,
      energyCostPerKm: 0.18,
      momChangePercent: -8.2,
      momTrend: TrendDirection.down,
    ),
    consumption: const Consumption(
      label: '平均能耗',
      typeLabel: '纯电电耗',
      primary: EnergyValue(value: 14.8, unit: 'kWh/百公里'),
      primarySparkline: [15.8, 15.3, 15.5, 14.9, 15.1, 14.4, 14.6, 14.8],
    ),
    maintenance: const Maintenance(
      enabled: true,
      remainingKm: 1574,
      remainingDays: 22,
      progressPercent: 78,
      status: MaintenanceStatus.normal,
    ),
    breakdown: const Breakdown(
      totalCents: 128600,
      count: 6,
      categories: [
        BreakdownCategory(
          category: ExpenseCategory.charging,
          amountCents: 38600,
          percent: 30,
        ),
        BreakdownCategory(
          category: ExpenseCategory.maintenance,
          amountCents: 48000,
          percent: 37,
        ),
        BreakdownCategory(
          category: ExpenseCategory.parking,
          amountCents: 16800,
          percent: 13,
        ),
        BreakdownCategory(
          category: ExpenseCategory.toll,
          amountCents: 13200,
          percent: 10,
        ),
        BreakdownCategory(
          category: ExpenseCategory.carWash,
          amountCents: 9000,
          percent: 7,
        ),
        BreakdownCategory(
          category: ExpenseCategory.other,
          amountCents: 3000,
          percent: 2,
        ),
      ],
    ),
    records: const [
      RecordItem(
        id: 'ev-1',
        category: ExpenseCategory.charging,
        title: '充电 · 特来电科技园站',
        subtitle: '今天 08:42 · 42.6 kWh · 里程 18,426',
        amountCents: 5110,
        subLabel: '¥1.20/kWh',
      ),
      RecordItem(
        id: 'ev-2',
        category: ExpenseCategory.parking,
        title: '停车费 · 万象城 B2',
        subtitle: '昨天 21:15 · 3 小时',
        amountCents: 2400,
      ),
      RecordItem(
        id: 'ev-3',
        category: ExpenseCategory.maintenance,
        title: '保养 · 比亚迪 4S 店',
        subtitle: '6月12日 · 定期电池健康检查',
        amountCents: 48000,
      ),
      RecordItem(
        id: 'ev-4',
        category: ExpenseCategory.toll,
        title: '过路费 · 广深沿江高速',
        subtitle: '6月10日 · 宝安 → 南沙',
        amountCents: 3800,
      ),
    ],
    previous30Cents: 140200,
    otherDailyWeights: [
      0.4,
      0.5,
      0.4,
      0.6,
      0.5,
      0.7,
      0.4,
      0.5,
      0.6,
      0.4,
      6.0,
      8.0,
      0.8,
      0.6,
      0.5,
      0.7,
      0.4,
      0.5,
      0.4,
      0.6,
      0.5,
      0.7,
      0.4,
      2.5,
      0.5,
      0.4,
      0.6,
      0.5,
      0.4,
      0.5,
    ],
  ),
  _CarMock(
    vehicle: const Vehicle(
      id: 'toyota-camry-hev',
      name: '丰田 凯美瑞 双擎',
      plate: '粤B·7Q315',
      powertrain: PowertrainType.hev,
      powertrainLabel: '油电混动',
      odometerKm: 46210,
      badge: '油电双模',
    ),
    summary: const HomeSummary(
      costPerKm: 0.52,
      monthSpendCents: 145000,
      monthMileageKm: 2780,
      energyCostPerKm: 0.42,
      momChangePercent: -3.5,
      momTrend: TrendDirection.down,
    ),
    consumption: const Consumption(
      label: '综合能耗',
      typeLabel: '超低油耗',
      primary: EnergyValue(value: 4.5, unit: 'L/百公里'),
      primarySparkline: [4.9, 4.7, 4.8, 4.6, 4.7, 4.4, 4.6, 4.5],
    ),
    maintenance: const Maintenance(
      enabled: true,
      remainingKm: 3200,
      remainingDays: 45,
      progressPercent: 42,
      status: MaintenanceStatus.normal,
    ),
    breakdown: const Breakdown(
      totalCents: 145000,
      count: 4,
      categories: [
        BreakdownCategory(
          category: ExpenseCategory.fuel,
          amountCents: 118000,
          percent: 81,
        ),
        BreakdownCategory(
          category: ExpenseCategory.parking,
          amountCents: 15000,
          percent: 10,
        ),
        BreakdownCategory(
          category: ExpenseCategory.toll,
          amountCents: 8000,
          percent: 6,
        ),
        BreakdownCategory(
          category: ExpenseCategory.carWash,
          amountCents: 4000,
          percent: 3,
        ),
      ],
    ),
    records: const [
      RecordItem(
        id: 'hev-1',
        category: ExpenseCategory.fuel,
        title: '加油 · 中海油 科技园站',
        subtitle: '今天 16:40 · 92# 汽油 46.2L · 里程 46,210',
        amountCents: 38000,
        subLabel: '¥8.22/L',
      ),
      RecordItem(
        id: 'hev-2',
        category: ExpenseCategory.parking,
        title: '停车费 · 市民中心',
        subtitle: '前天 14:20 · 2 小时',
        amountCents: 1500,
      ),
      RecordItem(
        id: 'hev-3',
        category: ExpenseCategory.toll,
        title: '过路费 · 深岑高速',
        subtitle: '6月14日 · 中山 → 深圳',
        amountCents: 4200,
      ),
      RecordItem(
        id: 'hev-4',
        category: ExpenseCategory.carWash,
        title: '洗车 · 途虎养车',
        subtitle: '6月8日 · 标准普洗',
        amountCents: 3500,
      ),
    ],
    previous30Cents: 151800,
    otherDailyWeights: [
      0.5,
      0.6,
      0.5,
      0.7,
      0.5,
      0.6,
      0.5,
      0.7,
      0.6,
      0.5,
      0.6,
      0.8,
      0.5,
      0.6,
      0.5,
      0.7,
      2.2,
      0.6,
      0.5,
      0.6,
      0.7,
      0.5,
      0.6,
      0.5,
      0.7,
      0.6,
      0.5,
      0.6,
      0.5,
      0.6,
    ],
  ),
  _CarMock(
    vehicle: const Vehicle(
      id: 'byd-song-plus-dmi',
      name: '宋PLUS DM-i',
      plate: '粤B·9X521',
      powertrain: PowertrainType.phev,
      powertrainLabel: '插电混动',
      odometerKm: 31520,
      badge: '绿牌插混',
    ),
    summary: const HomeSummary(
      costPerKm: 0.45,
      monthSpendCents: 112000,
      monthMileageKm: 2480,
      energyCostPerKm: 0.26,
      momChangePercent: -12.1,
      momTrend: TrendDirection.down,
    ),
    consumption: const Consumption(
      label: '综合能耗',
      typeLabel: '双模混动',
      primary: EnergyValue(value: 12.5, unit: 'kWh/百公里'),
      secondary: EnergyValue(value: 2.8, unit: 'L/百公里'),
      primarySparkline: [13.6, 13.2, 13.4, 12.9, 13.1, 12.6, 12.8, 12.5],
      secondarySparkline: [3.1, 3.0, 3.0, 2.9, 2.9, 2.8, 2.8, 2.8],
    ),
    maintenance: const Maintenance(
      enabled: true,
      remainingKm: 4500,
      remainingDays: 60,
      progressPercent: 30,
      status: MaintenanceStatus.normal,
    ),
    breakdown: const Breakdown(
      totalCents: 112000,
      count: 5,
      categories: [
        BreakdownCategory(
          category: ExpenseCategory.fuel,
          amountCents: 42000,
          percent: 38,
        ),
        BreakdownCategory(
          category: ExpenseCategory.charging,
          amountCents: 26000,
          percent: 23,
        ),
        BreakdownCategory(
          category: ExpenseCategory.maintenance,
          amountCents: 20000,
          percent: 18,
        ),
        BreakdownCategory(
          category: ExpenseCategory.parking,
          amountCents: 14000,
          percent: 12,
        ),
        BreakdownCategory(
          category: ExpenseCategory.toll,
          amountCents: 10000,
          percent: 9,
        ),
      ],
    ),
    records: const [
      RecordItem(
        id: 'phev-1',
        category: ExpenseCategory.charging,
        title: '充电 · 国家电网快充',
        subtitle: '昨天 19:20 · 28.5 kWh · 里程 31,520',
        amountCents: 4230,
        subLabel: '¥1.48/kWh',
      ),
      RecordItem(
        id: 'phev-2',
        category: ExpenseCategory.fuel,
        title: '加油 · 中国石油 92#',
        subtitle: '6月15日 · 92#汽油 24.5L',
        amountCents: 20000,
        subLabel: '¥8.16/L',
      ),
      RecordItem(
        id: 'phev-3',
        category: ExpenseCategory.parking,
        title: '停车费 · 高新南区',
        subtitle: '6月13日 · 临时停车 4 小时',
        amountCents: 2000,
      ),
    ],
    previous30Cents: 127400,
    otherDailyWeights: [
      0.4,
      0.5,
      0.6,
      0.5,
      0.7,
      0.5,
      0.6,
      0.8,
      0.6,
      0.5,
      2.4,
      3.2,
      0.8,
      0.6,
      0.7,
      0.5,
      0.6,
      0.5,
      0.7,
      0.6,
      0.5,
      0.8,
      0.6,
      0.5,
      0.7,
      0.6,
      0.5,
      0.8,
      0.6,
      0.5,
    ],
  ),
  _CarMock(
    vehicle: const Vehicle(
      id: 'bmw-325li',
      name: '宝马 3系 325Li',
      plate: '粤B·88K32',
      powertrain: PowertrainType.ice,
      powertrainLabel: '纯燃油',
      odometerKm: 58940,
      badge: '95号汽油',
    ),
    summary: const HomeSummary(
      costPerKm: 0.92,
      monthSpendCents: 238000,
      monthMileageKm: 2580,
      energyCostPerKm: 0.75,
      momChangePercent: 4.2,
      momTrend: TrendDirection.up,
    ),
    consumption: const Consumption(
      label: '综合油耗',
      typeLabel: '95号汽油',
      primary: EnergyValue(value: 8.6, unit: 'L/百公里'),
      primarySparkline: [9.2, 9.0, 8.9, 8.8, 8.7, 8.9, 8.6, 8.6],
    ),
    maintenance: const Maintenance(
      enabled: true,
      remainingKm: 850,
      remainingDays: 10,
      progressPercent: 92,
      status: MaintenanceStatus.warning,
    ),
    breakdown: const Breakdown(
      totalCents: 238000,
      count: 5,
      categories: [
        BreakdownCategory(
          category: ExpenseCategory.fuel,
          amountCents: 193500,
          percent: 81,
        ),
        BreakdownCategory(
          category: ExpenseCategory.parking,
          amountCents: 24000,
          percent: 10,
        ),
        BreakdownCategory(
          category: ExpenseCategory.toll,
          amountCents: 14000,
          percent: 6,
        ),
        BreakdownCategory(
          category: ExpenseCategory.carWash,
          amountCents: 6500,
          percent: 3,
        ),
      ],
    ),
    records: const [
      RecordItem(
        id: 'ice-1',
        category: ExpenseCategory.fuel,
        title: '加油 · 中国石化 95#',
        subtitle: '今天 17:30 · 95#汽油 42.5L · 里程 58,940',
        amountCents: 35020,
        subLabel: '¥8.24/L',
      ),
      RecordItem(
        id: 'ice-2',
        category: ExpenseCategory.parking,
        title: '停车费 · 海岸城 VIP 停车',
        subtitle: '昨天 19:45 · 5 小时',
        amountCents: 4500,
      ),
      RecordItem(
        id: 'ice-3',
        category: ExpenseCategory.carWash,
        title: '洗车 · 精洗护理',
        subtitle: '6月11日 · 内饰精洗 + 纳米镀膜',
        amountCents: 6500,
      ),
    ],
    previous30Cents: 218800,
    otherDailyWeights: [
      0.5,
      0.6,
      0.5,
      0.7,
      0.6,
      0.8,
      0.6,
      0.7,
      0.6,
      0.8,
      0.7,
      0.9,
      2.0,
      0.8,
      0.7,
      0.9,
      0.8,
      0.7,
      0.9,
      0.8,
      0.7,
      0.9,
      0.8,
      0.7,
      0.8,
      0.9,
      0.8,
      0.7,
      0.9,
      0.8,
    ],
  ),
];

List<double> _energyDailyWeights(_CarMock car) {
  final base = [for (var i = 0; i < 30; i++) 0.35 + (i % 4) * 0.05];
  switch (car.vehicle.powertrain) {
    case PowertrainType.ev:
      return List<double>.filled(30, 1);
    case PowertrainType.hev:
      base[6] = 12;
      base[20] = 14;
      return base;
    case PowertrainType.phev:
      base[4] = 6;
      base[18] = 8;
      return base;
    case PowertrainType.ice:
      base[6] = 12;
      base[20] = 14;
      return base;
  }
}

int _energyTarget(_CarMock car, int totalCents) {
  final ratio = car.energyCents / car.summary.monthSpendCents;
  return (totalCents * ratio).round();
}

TrendData _buildTrend(_CarMock car, TrendRange range) {
  switch (range) {
    case TrendRange.d30:
      final total = car.summary.monthSpendCents;
      final energy = _energyTarget(car, total);
      return _series(
        range: range,
        dates: [for (var i = 0; i < 30; i++) DateTime(2026, 6, 1 + i)],
        energyCents: energy,
        otherCents: total - energy,
        total: total,
        previousTotal: car.previous30Cents,
        energyWeights: _energyDailyWeights(car),
        otherWeights: car.otherDailyWeights,
      );
    case TrendRange.d7:
      final total = (car.summary.monthSpendCents * 0.24).round();
      final energy = _energyTarget(car, total);
      final factor = car.summary.momTrend == TrendDirection.up ? 0.95 : 1.08;
      return _series(
        range: range,
        dates: [for (var i = 0; i < 7; i++) DateTime(2026, 6, 24 + i)],
        energyCents: energy,
        otherCents: total - energy,
        total: total,
        previousTotal: (total * factor).round(),
        energyWeights: _energyDailyWeights(car).sublist(23),
        otherWeights: car.otherDailyWeights.sublist(23),
      );
    case TrendRange.halfYear:
      final total = (car.summary.monthSpendCents * 5.2).round();
      final energy = _energyTarget(car, total);
      final factor = car.summary.momTrend == TrendDirection.up ? 0.93 : 1.07;
      return _series(
        range: range,
        dates: [for (var m = 1; m <= 6; m++) DateTime(2026, m, 28)],
        energyCents: energy,
        otherCents: total - energy,
        total: total,
        previousTotal: (total * factor).round(),
        energyWeights: const [0.8, 0.9, 1.0, 1.05, 1.1, 1.15],
        otherWeights: const [0.7, 1.0, 0.9, 1.2, 0.8, 1.3],
      );
    case TrendRange.year:
      final total = (car.summary.monthSpendCents * 10.5).round();
      final energy = _energyTarget(car, total);
      final factor = car.summary.momTrend == TrendDirection.up ? 0.92 : 1.06;
      return _series(
        range: range,
        dates: [for (var i = 0; i < 12; i++) DateTime(2025, 7 + i, 28)],
        energyCents: energy,
        otherCents: total - energy,
        total: total,
        previousTotal: (total * factor).round(),
        energyWeights: const [
          0.7,
          0.75,
          0.8,
          0.85,
          0.9,
          0.95,
          1.0,
          1.05,
          1.1,
          1.15,
          1.2,
          1.25,
        ],
        otherWeights: const [
          0.8,
          0.9,
          1.0,
          0.9,
          1.1,
          1.2,
          0.85,
          0.95,
          1.05,
          1.15,
          1.25,
          1.35,
        ],
      );
  }
}

TrendData _series({
  required TrendRange range,
  required List<DateTime> dates,
  required int energyCents,
  required int otherCents,
  required int total,
  required int previousTotal,
  required List<double> energyWeights,
  required List<double> otherWeights,
}) {
  final energy = _allocate(energyWeights, energyCents, dates.length);
  final other = _allocate(otherWeights, otherCents, dates.length);
  return TrendData(
    range: range,
    points: [
      for (var i = 0; i < dates.length; i++)
        TrendPoint(
          date: dates[i],
          energyCents: energy[i],
          otherCents: other[i],
        ),
    ],
    totalCents: total,
    previousTotalCents: previousTotal,
  );
}

/// 按权重把 [totalCents] 拆成整数金额，保证求和精确等于目标值。
List<int> _allocate(List<double> weights, int totalCents, int length) {
  final source = weights.length >= length
      ? weights.sublist(0, length)
      : [
          ...weights,
          for (var i = weights.length; i < length; i++)
            weights.isEmpty ? 1 : weights.last,
        ];
  final sum = source.fold<double>(0, (acc, value) => acc + value);
  if (sum <= 0 || totalCents <= 0) {
    return List<int>.filled(length, 0);
  }
  final raw = [for (final weight in source) weight / sum * totalCents];
  final result = [for (final value in raw) value.floor()];
  var remainder = totalCents - result.fold<int>(0, (acc, value) => acc + value);
  final order = List<int>.generate(length, (index) => index)
    ..sort(
      (a, b) => (raw[b] - raw[b].floor()).compareTo(raw[a] - raw[a].floor()),
    );
  var cursor = 0;
  while (remainder > 0) {
    result[order[cursor % length]] += 1;
    remainder--;
    cursor++;
  }
  return result;
}
