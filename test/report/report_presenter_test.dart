import 'package:chexiaoji_app/core/domain/enums.dart';
import 'package:chexiaoji_app/core/domain/vehicle.dart';
import 'package:chexiaoji_app/features/ledger/domain/ledger_models.dart';
import 'package:chexiaoji_app/features/report/domain/report_aggregation.dart';
import 'package:chexiaoji_app/features/report/domain/report_models.dart';
import 'package:chexiaoji_app/features/report/domain/report_presenter.dart';
import 'package:flutter_test/flutter_test.dart';

Vehicle _vehicle() => const Vehicle(
  id: 'byd-han-ev',
  name: '比亚迪 汉 EV',
  plate: '粤B·D82K6',
  powertrain: PowertrainType.ev,
  powertrainLabel: '纯电驱动',
  odometerKm: 18426,
);

List<LedgerRecord> _records() => [
  LedgerRecord(
    id: 'a',
    vehicleId: 'byd-han-ev',
    vehicleShortName: '汉 EV',
    vehicleName: '比亚迪 汉 EV',
    powertrain: PowertrainType.ev,
    category: ExpenseCategory.charging,
    title: '特来电快充 · 科技园站',
    amountCents: 5110,
    occurredAt: DateTime(2026, 11, 14, 8, 42),
    metrics: const LedgerMetrics(kwh: 38.5, odometerKm: 18000, distanceKm: 300),
  ),
  LedgerRecord(
    id: 'b',
    vehicleId: 'byd-han-ev',
    vehicleShortName: '汉 EV',
    vehicleName: '比亚迪 汉 EV',
    powertrain: PowertrainType.ev,
    category: ExpenseCategory.maintenance,
    title: '比亚迪 4S 售后中心',
    amountCents: 48000,
    occurredAt: DateTime(2026, 11, 15, 14, 30),
    metrics: const LedgerMetrics(odometerKm: 18100),
  ),
];

MonthlyReport _report() => buildMonthlyReport(
  scope: ReportScope(month: DateTime(2026, 11)),
  records: _records(),
  vehicles: [_vehicle()],
  now: DateTime(2026, 11, 20, 9, 30),
);

void main() {
  group('页脚与截止时间', () {
    test('当前月标注数据截止时间与记录中', () {
      final report = _report();

      expect(report.dataCutoffText, '2026-11-20 09:30');
      expect(
        report.footerMetaText(maskPlate: false),
        '数据截至 2026-11-20 09:30 · 记录中',
      );
    });

    test('隐私开关开启时追加车牌已脱敏', () {
      expect(
        _report().footerMetaText(maskPlate: true),
        '数据截至 2026-11-20 09:30 · 记录中 · 车牌已脱敏',
      );
    });

    test('历史月不重复截止时间，只保留脱敏提示', () {
      final report = buildMonthlyReport(
        scope: ReportScope(month: DateTime(2026, 10)),
        records: const [],
        vehicles: const [],
        now: DateTime(2026, 11, 20),
      );

      expect(report.footerMetaText(maskPlate: false), isEmpty);
      expect(report.footerMetaText(maskPlate: true), '车牌已脱敏');
    });
  });

  group('无障碍摘要', () {
    test('覆盖金额、里程、笔数、每公里与峰值', () {
      final label = _report().paperSemanticsLabel(const ReportOptions());

      expect(label, contains('2026年11月'));
      expect(label, contains('比亚迪 汉 EV'));
      expect(label, contains('总开销¥531.10'));
      expect(label, contains('行驶100公里'));
      expect(label, contains('2笔记录'));
      expect(label, contains('综合每公里¥5.31'));
      expect(label, contains('峰值11月15日¥480.00'));
    });

    test('关闭能耗分析后不再朗读每公里', () {
      final label = _report().paperSemanticsLabel(
        const ReportOptions(includeEnergy: false),
      );

      expect(label, isNot(contains('综合每公里')));
    });

    test('隐私开关开启时补充脱敏说明', () {
      final label = _report().paperSemanticsLabel(
        const ReportOptions(maskPlate: true),
      );

      expect(label, contains('车牌已脱敏'));
    });

    test('无数据时峰值与里程使用未知描述', () {
      final report = buildMonthlyReport(
        scope: ReportScope(month: DateTime(2026, 11)),
        records: const [],
        vehicles: const [],
        now: DateTime(2026, 11, 20),
      );
      final label = report.paperSemanticsLabel(const ReportOptions());

      expect(report.peakDay, isNull);
      expect(label, contains('行驶里程未知'));
      expect(label, isNot(contains('峰值')));
    });
  });
}
