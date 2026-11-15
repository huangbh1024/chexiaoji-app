import 'package:chexiaoji_app/features/home/domain/home_models.dart';
import 'package:chexiaoji_app/features/vehicles/domain/vehicle_models.dart';
import 'package:chexiaoji_app/features/vehicles/domain/vehicle_presenter.dart';
import 'package:flutter_test/flutter_test.dart';

ArchivedVehicleSummary _summary({
  PowertrainType powertrain = PowertrainType.ev,
  int recordCount = 38,
  int spendCents = 964000,
  EnergyValue? consumption = const EnergyValue(value: 13.6, unit: 'kWh/百公里'),
  DateTime? archivedAt,
  DateTime? latestRecordAt,
}) {
  return ArchivedVehicleSummary(
    vehicle: Vehicle(
      id: 'tesla-model-3',
      name: '特斯拉 Model 3',
      plate: '粤B·5K888',
      powertrain: powertrain,
      powertrainLabel: powertrain.label,
      odometerKm: 52380,
    ),
    specLabel: '2021款',
    sortOrder: 0,
    archivedAt: archivedAt ?? DateTime(2026, 11, 15),
    lifetimeSpendCents: spendCents,
    recordCount: recordCount,
    energyRecordCount: 28,
    averageConsumption: consumption,
    latestRecordAt: latestRecordAt ?? DateTime(2026, 11, 14),
  );
}

void main() {
  group('plateTailOf', () {
    test('取去掉分隔符后的末 5 位', () {
      expect(ArchivedVehiclePresenter.plateTailOf('粤B·5K888'), '5K888');
      expect(ArchivedVehiclePresenter.plateTailOf('粤B D82K6'), 'D82K6');
    });

    test('新能源 8 位车牌取末 5 位', () {
      expect(ArchivedVehiclePresenter.plateTailOf('粤BD12345'), '12345');
    });

    test('不足 5 位取全部，空车牌返回空串', () {
      expect(ArchivedVehiclePresenter.plateTailOf('粤B·12'), '粤B12');
      expect(ArchivedVehiclePresenter.plateTailOf('   '), '');
    });
  });

  group('archiveDurationLabel', () {
    final now = DateTime(2026, 11, 15);

    test('当天显示今日封存', () {
      expect(
        ArchivedVehiclePresenter.archiveDurationLabel(now, now: now),
        '今日封存',
      );
    });

    test('按自然日计算封存天数', () {
      expect(
        ArchivedVehiclePresenter.archiveDurationLabel(
          DateTime(2026, 11, 15, 23, 59),
          now: DateTime(2026, 11, 16, 0, 1),
        ),
        '封存 1 天',
      );
      expect(
        ArchivedVehiclePresenter.archiveDurationLabel(
          DateTime(2026, 10, 4),
          now: now,
        ),
        '封存 42 天',
      );
    });

    test('未来时间按今日封存处理', () {
      expect(
        ArchivedVehiclePresenter.archiveDurationLabel(
          DateTime(2026, 12, 1),
          now: now,
        ),
        '今日封存',
      );
    });
  });

  group('metricsOf', () {
    test('EV 显示历史平均电耗', () {
      final metrics = ArchivedVehiclePresenter.metricsOf(_summary());

      expect(metrics[0].label, '封存总里程');
      expect(metrics[0].value, '52,380');
      expect(metrics[0].unit, 'km');
      expect(metrics[1].label, '累计记账花费');
      expect(metrics[1].value, '¥9,640');
      expect(metrics[2].label, '历史平均电耗');
      expect(metrics[2].value, '13.6');
      expect(metrics[2].unit, 'kWh/百公里');
    });

    test('ICE 显示历史综合油耗', () {
      final metrics = ArchivedVehiclePresenter.metricsOf(
        _summary(
          powertrain: PowertrainType.ice,
          consumption: const EnergyValue(value: 6.5, unit: 'L/100km'),
        ),
      );

      expect(metrics[2].label, '历史综合油耗');
      expect(metrics[2].value, '6.5');
    });

    test('缺失能耗显示未录入，不伪造数值', () {
      final metrics = ArchivedVehiclePresenter.metricsOf(
        _summary(consumption: null),
      );

      expect(metrics[2].value, '—');
      expect(metrics[2].unit, '未录入');
      expect(metrics[2].missing, isTrue);
    });
  });

  test('canOpenReports 要求有流水与最近记录时间', () {
    expect(ArchivedVehiclePresenter.canOpenReports(_summary()), isTrue);
    expect(
      ArchivedVehiclePresenter.canOpenReports(_summary(recordCount: 0)),
      isFalse,
    );
  });

  test('impactRecordsText 区分有无流水', () {
    expect(
      ArchivedVehiclePresenter.impactRecordsText(_summary()),
      contains('38 笔记账'),
    );
    expect(
      ArchivedVehiclePresenter.impactRecordsText(_summary()),
      contains('¥9,640'),
    );
    expect(
      ArchivedVehiclePresenter.impactRecordsText(
        _summary(recordCount: 0, spendCents: 0),
      ),
      '该车暂无记账流水，账单不受影响。',
    );
  });
}
