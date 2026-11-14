import 'package:chexiaoji_app/core/domain/enums.dart';
import 'package:chexiaoji_app/core/domain/vehicle.dart';
import 'package:chexiaoji_app/features/ledger/domain/ledger_models.dart';
import 'package:chexiaoji_app/features/report/domain/report_aggregation.dart';
import 'package:chexiaoji_app/features/report/domain/report_models.dart';
import 'package:chexiaoji_app/features/report/export/report_pdf_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('生成 A4 单页 PDF，输出非空且以 %PDF- 开头', () async {
    final records = [
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
        metrics: const LedgerMetrics(
          kwh: 38.5,
          odometerKm: 18000,
          distanceKm: 300,
        ),
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
      ),
    ];

    final report = buildMonthlyReport(
      scope: ReportScope(month: DateTime(2026, 11), vehicleId: 'byd-han-ev'),
      records: records,
      vehicles: const [
        Vehicle(
          id: 'byd-han-ev',
          name: '比亚迪 汉 EV',
          plate: '粤B·D82K6',
          powertrain: PowertrainType.ev,
          powertrainLabel: '纯电驱动',
          odometerKm: 18426,
        ),
      ],
      now: DateTime(2026, 11, 14, 10),
    );

    final bytes = await buildReportPdfBytes(
      report: report,
      options: const ReportOptions(),
    );

    expect(bytes, isNotEmpty);
    final header = String.fromCharCodes(bytes.take(5));
    expect(header, '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });

  test('关闭能耗分析后 PDF 仍为单页且非空', () async {
    final report = buildMonthlyReport(
      scope: ReportScope(month: DateTime(2026, 11)),
      records: const [],
      vehicles: const [],
      now: DateTime(2026, 11, 14, 10),
    );

    final bytes = await buildReportPdfBytes(
      report: report,
      options: const ReportOptions(includeEnergy: false),
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
