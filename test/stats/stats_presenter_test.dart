import 'package:chexiaoji_app/core/domain/enums.dart';
import 'package:chexiaoji_app/features/stats/domain/stats_models.dart';
import 'package:chexiaoji_app/features/stats/domain/stats_period.dart';
import 'package:chexiaoji_app/features/stats/domain/stats_presenter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final range = StatsRange(
    start: DateTime(2026, 11),
    end: DateTime(2026, 11, 30, 23, 59, 59),
    label: '2026年11月',
    shortLabel: '本月',
    comparisonLabel: '较上月',
  );

  test('Hero 周期与子指标文案', () {
    expect(heroPeriodLabel(StatsPeriod.month, range), '综合每公里成本 · 2026年11月');
    expect(periodSubLabel(range), '本月总开销');
    expect(periodMileageLabel(range), '本月行驶');
  });

  test('环比文案', () {
    expect(
      changeLabel(
        range: range,
        trend: TrendDirection.down,
        percent: -8.2,
        changeText: null,
      ),
      '较上月 -8.2%',
    );
    expect(
      changeLabel(
        range: range,
        trend: TrendDirection.up,
        percent: 4.2,
        changeText: null,
      ),
      '较上月 +4.2%',
    );
    expect(
      changeLabel(
        range: range,
        trend: TrendDirection.none,
        percent: null,
        changeText: null,
      ),
      '暂无对比',
    );
    expect(
      changeLabel(
        range: range,
        trend: TrendDirection.none,
        percent: null,
        changeText: '累计 2.1 年',
      ),
      '累计 2.1 年',
    );
  });

  test('四类动力的能耗与能源成本标题', () {
    expect(consumptionTitle(PowertrainType.ev), '平均百公里电耗');
    expect(consumptionTitle(PowertrainType.hev), '平均百公里油耗');
    expect(consumptionTitle(PowertrainType.phev), '平均百公里电耗');
    expect(consumptionTitle(PowertrainType.ice), '平均百公里油耗');
    expect(consumptionTitle(null), '综合能耗成本');

    expect(energyCostTitle(PowertrainType.ev), '纯电能源成本');
    expect(energyCostTitle(PowertrainType.hev), '燃油能源成本');
    expect(energyCostTitle(null), '综合能源成本');
  });

  test('单位与评论文案', () {
    expect(consumptionUnit('kWh/100km'), 'kWh/百公里');
    expect(consumptionUnit('L/100km'), 'L/百公里');
    expect(consumptionUnit('CNY/km'), '/km');
    expect(ratingLabel(StatsRating.excellent), '优异');
    expect(ratingLabel(StatsRating.high), '偏高');
    expect(ratingLabel(StatsRating.fleet), '车队');
    expect(ratingLabel(StatsRating.none), '—');
  });

  test('金额与能耗格式化', () {
    expect(costPerKmText(null), '—');
    expect(costPerKmText(60), '¥0.60');
    expect(formatEnergyValue(14.8, 'kWh/100km'), '14.8');
    expect(formatEnergyValue(0.3, 'CNY/km'), '¥0.30');
    expect(formatYuanAxis(600), '¥600');
    expect(formatYuanAxis(12000), '¥12k');
  });

  test('构成徽章与保养文案', () {
    expect(breakdownBadge(range, 6), '本月 · 共 6 笔');

    StatsMaintenance maintenance({
      int remainingKm = 1574,
      int progress = 72,
      MaintenanceStatus status = MaintenanceStatus.normal,
      int? days = 22,
      bool enabled = true,
    }) {
      return StatsMaintenance(
        enabled: enabled,
        vehicleId: 'byd-han-ev',
        vehicleName: '比亚迪 汉 EV',
        tag: '小保养',
        remainingKm: remainingKm,
        progressPercent: progress,
        status: status,
        remainingDays: days,
      );
    }

    expect(maintenanceDescription(maintenance()), '预计约 22 天');
    expect(
      maintenanceDescription(
        maintenance(progress: 90, status: MaintenanceStatus.warning),
      ),
      '预计约 22 天 · 即将保养',
    );
    expect(
      maintenanceDescription(
        maintenance(
          remainingKm: -320,
          progress: 100,
          status: MaintenanceStatus.overdue,
        ),
      ),
      '已超期 320 km',
    );
    expect(maintenanceDescription(maintenance(enabled: false)), '未设置保养计划');
  });

  test('趋势对比文案', () {
    StatsTrend trend({
      int total = 128600,
      int previous = 140000,
      TrendDirection direction = TrendDirection.down,
      double? percent = -8.2,
    }) {
      return StatsTrend(
        query: StatsTrendQuery(
          vehicleId: 'byd-han-ev',
          range: StatsTrendRange.d30,
          anchor: DateTime(2026, 11, 14),
        ),
        from: DateTime(2026, 10, 16),
        to: DateTime(2026, 11, 14),
        totalCents: total,
        previousTotalCents: previous,
        changePercent: percent,
        changeTrend: direction,
        axis: const StatsAxis(
          maxCents: 60000,
          ticksCents: [0, 20000, 40000, 60000],
        ),
        peakIndex: null,
        buckets: const [],
      );
    }

    expect(trendChangeLabel(trend()), '比上期少 ¥114');
    expect(
      trendChangeLabel(
        trend(
          total: 150000,
          previous: 140000,
          direction: TrendDirection.up,
          percent: 7.1,
        ),
      ),
      '比上期多 ¥100',
    );
    expect(
      trendChangeLabel(
        trend(total: 0, previous: 0, direction: TrendDirection.none),
      ),
      '暂无对比',
    );
  });
}
