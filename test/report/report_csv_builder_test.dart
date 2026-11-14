import 'package:chexiaoji_app/core/domain/enums.dart';
import 'package:chexiaoji_app/features/ledger/domain/ledger_models.dart';
import 'package:chexiaoji_app/features/report/domain/report_aggregation.dart';
import 'package:chexiaoji_app/features/report/domain/report_models.dart';
import 'package:chexiaoji_app/features/report/export/report_csv_builder.dart';
import 'package:flutter_test/flutter_test.dart';

LedgerRecord _record({
  required String id,
  required ExpenseCategory category,
  required DateTime occurredAt,
  int amountCents = 5110,
  String title = '特来电快充 · 科技园站',
  String vehicleName = '比亚迪 汉 EV',
  double? kwh,
  double? liters,
  int? odometerKm,
  int? durationMinutes,
  String? paymentMethod,
  String? note,
}) {
  return LedgerRecord(
    id: id,
    vehicleId: 'byd-han-ev',
    vehicleShortName: '汉 EV',
    vehicleName: vehicleName,
    powertrain: PowertrainType.ev,
    category: category,
    title: title,
    amountCents: amountCents,
    occurredAt: occurredAt,
    metrics: LedgerMetrics(
      kwh: kwh,
      liters: liters,
      odometerKm: odometerKm,
      durationMinutes: durationMinutes,
      paymentMethod: paymentMethod,
    ),
    note: note,
  );
}

MonthlyReport _report(List<LedgerRecord> records) {
  return buildMonthlyReport(
    scope: ReportScope(month: DateTime(2026, 11)),
    records: records,
    vehicles: const [],
    now: DateTime(2026, 11, 14, 10),
  );
}

void main() {
  group('buildReportCsv', () {
    test('包含 UTF-8 BOM 与完整表头', () {
      final csv = buildReportCsv(
        report: _report(const []),
        records: const [],
        options: const ReportOptions(),
      );

      expect(csv.startsWith('﻿'), isTrue);
      expect(
        csv,
        contains(
          '日期,时间,分类,车辆,车牌,标题,金额(元),电量(kWh),加油量(L),里程(km),时长(分钟),支付方式,备注',
        ),
      );
    });

    test('记录按时间正序输出，金额带符号且无千分位', () {
      final csv = buildReportCsv(
        report: _report([
          _record(
            id: 'b',
            category: ExpenseCategory.charging,
            occurredAt: DateTime(2026, 11, 20, 8, 0),
            amountCents: 123456,
            kwh: 38.5,
            odometerKm: 18426,
          ),
          _record(
            id: 'a',
            category: ExpenseCategory.parking,
            occurredAt: DateTime(2026, 11, 1, 16, 45),
            amountCents: -2400,
            durationMinutes: 210,
            paymentMethod: '微信',
          ),
        ]),
        records: [
          _record(
            id: 'b',
            category: ExpenseCategory.charging,
            occurredAt: DateTime(2026, 11, 20, 8, 0),
            amountCents: 123456,
            kwh: 38.5,
            odometerKm: 18426,
          ),
          _record(
            id: 'a',
            category: ExpenseCategory.parking,
            occurredAt: DateTime(2026, 11, 1, 16, 45),
            amountCents: -2400,
            durationMinutes: 210,
            paymentMethod: '微信',
          ),
        ],
        options: const ReportOptions(),
      );

      final lines = csv.split('\r\n');
      expect(lines[1], contains('2026-11-01'));
      expect(lines[2], contains('2026-11-20'));
      expect(lines[2], contains('1234.56'));
      expect(lines[1], contains('-24.00'));
    });

    test('文本列转义逗号、引号与公式注入，数值列不加前缀', () {
      final csv = buildReportCsv(
        report: _report([
          _record(
            id: 'a',
            category: ExpenseCategory.other,
            occurredAt: DateTime(2026, 11, 5, 10),
            amountCents: 100,
            title: '=SUM(A1)',
            note: '备注,含"引号"',
          ),
        ]),
        records: [
          _record(
            id: 'a',
            category: ExpenseCategory.other,
            occurredAt: DateTime(2026, 11, 5, 10),
            amountCents: 100,
            title: '=SUM(A1)',
            note: '备注,含"引号"',
          ),
        ],
        options: const ReportOptions(),
      );

      final line = csv.split('\r\n')[1];
      expect(line, contains("'=SUM(A1)"));
      expect(line, contains('"备注,含""引号"""'));
      expect(line, contains(',1.00,'));
    });

    test('隐私开关脱敏车牌', () {
      final csv = buildReportCsv(
        report: _report(const []).copyWith(
          vehicles: const [
            ReportVehicleBrief(
              id: 'byd-han-ev',
              name: '比亚迪 汉 EV',
              shortName: '汉 EV',
              plate: '粤B·D82K6',
              powertrain: PowertrainType.ev,
              powertrainLabel: '纯电驱动',
              odometerKm: 18426,
              recordCount: 1,
            ),
          ],
        ),
        records: [
          _record(
            id: 'a',
            category: ExpenseCategory.charging,
            occurredAt: DateTime(2026, 11, 5, 10),
          ),
        ],
        options: const ReportOptions(maskPlate: true),
      );

      expect(csv, contains('粤B·D****'));
      expect(csv, isNot(contains('粤B·D82K6')));
    });

    test('按 id 去重，无重复行', () {
      final record = _record(
        id: 'dup',
        category: ExpenseCategory.charging,
        occurredAt: DateTime(2026, 11, 5, 10),
      );
      final csv = buildReportCsv(
        report: _report([record, record]),
        records: [record, record],
        options: const ReportOptions(),
      );

      final lines = csv.split('\r\n');
      expect(lines.length, 3); // BOM + 表头 + 1 行
    });
  });
}
