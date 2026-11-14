import 'dart:io';
import 'dart:typed_data';

import 'package:chexiaoji_app/core/domain/enums.dart';
import 'package:chexiaoji_app/features/report/domain/report_models.dart';
import 'package:chexiaoji_app/features/report/export/report_export_controller.dart';
import 'package:chexiaoji_app/features/report/export/report_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeExporter implements ReportExporter {
  int pdfCalls = 0;
  int csvCalls = 0;
  int imageCalls = 0;
  int shareCalls = 0;
  int printCalls = 0;
  Object? failWith;

  @override
  Future<File> buildPdf(MonthlyReport report, ReportOptions options) async {
    pdfCalls++;
    if (failWith != null) {
      throw failWith!;
    }
    return File('/tmp/test.pdf');
  }

  @override
  Future<File> buildCsv(MonthlyReport report, ReportOptions options) async {
    csvCalls++;
    return File('/tmp/test.csv');
  }

  @override
  Future<File> buildImage(
    MonthlyReport report,
    ReportOptions options,
    Uint8List bytes,
  ) async {
    imageCalls++;
    return File('/tmp/test.png');
  }

  @override
  Future<void> share(File file, {String? subject}) async {
    shareCalls++;
  }

  @override
  Future<void> print(File file, {String? name}) async {
    printCalls++;
  }
}

MonthlyReport _report() => buildMonthlyReportForTest();

MonthlyReport buildMonthlyReportForTest() {
  // 最小可用的 MonthlyReport，只关心导出流程。
  return MonthlyReport(
    scope: ReportScope(month: _FixedMonth.november),
    reportNo: 'RP-202611-0001',
    status: ReportStatus.recording,
    generatedAt: DateTime(2026, 11, 14),
    updatedAt: DateTime(2026, 11, 14),
    totalCents: 128600,
    recordCount: 6,
    distanceKm: 2140,
    distanceSource: DistanceSource.odometer,
    days: 30,
    costPerKmCents: 60,
    energyKwh: 316.7,
    fuelLiters: 0,
    kwhPer100km: 14.8,
    litersPer100km: null,
    momPercent: -8.2,
    momTrend: TrendDirection.down,
    vehicles: const [],
    categories: const [],
    daily: const [],
    verified: false,
    verificationText: '数据由车小记本地账本汇总 · 请核对后使用',
  );
}

abstract final class _FixedMonth {
  static final november = DateTime(2026, 11);
}

void main() {
  test('导出 PDF 调用 buildPdf 与 share', () async {
    final exporter = _FakeExporter();
    final controller = ReportExportController(exporter: exporter);

    await controller.export(
      report: _report(),
      options: const ReportOptions(),
      action: ReportExportAction.export,
    );

    expect(exporter.pdfCalls, 1);
    expect(exporter.shareCalls, 1);
    expect(controller.state.phase, ReportExportPhase.done);
  });

  test('导出 CSV 调用 buildCsv', () async {
    final exporter = _FakeExporter();
    final controller = ReportExportController(exporter: exporter);

    await controller.export(
      report: _report(),
      options: const ReportOptions(format: ReportFormat.csv),
      action: ReportExportAction.export,
    );

    expect(exporter.csvCalls, 1);
    expect(controller.state.phase, ReportExportPhase.done);
  });

  test('打印动作调用 print 而非 share', () async {
    final exporter = _FakeExporter();
    final controller = ReportExportController(exporter: exporter);

    await controller.export(
      report: _report(),
      options: const ReportOptions(),
      action: ReportExportAction.print,
    );

    expect(exporter.printCalls, 1);
    expect(exporter.shareCalls, 0);
  });

  test('导出失败进入 failed，可重试', () async {
    final exporter = _FakeExporter()..failWith = Exception('boom');
    final controller = ReportExportController(exporter: exporter);

    await controller.export(
      report: _report(),
      options: const ReportOptions(),
      action: ReportExportAction.export,
    );

    expect(controller.state.phase, ReportExportPhase.failed);
    expect(controller.state.error, isNotNull);

    exporter.failWith = null;
    await controller.export(
      report: _report(),
      options: const ReportOptions(),
      action: ReportExportAction.export,
    );
    expect(controller.state.phase, ReportExportPhase.done);
  });

  test('长图海报调用 capture 与 buildImage', () async {
    final exporter = _FakeExporter();
    final controller = ReportExportController(exporter: exporter);
    var captured = 0;

    await controller.export(
      report: _report(),
      options: const ReportOptions(format: ReportFormat.poster),
      action: ReportExportAction.export,
      capturePoster: (report, options) async {
        captured++;
        return Uint8List.fromList(const [1, 2, 3]);
      },
    );

    expect(captured, 1);
    expect(exporter.imageCalls, 1);
    expect(exporter.shareCalls, 1);
    expect(controller.state.phase, ReportExportPhase.done);
  });

  test('长图缺少渲染回调时进入 failed', () async {
    final exporter = _FakeExporter();
    final controller = ReportExportController(exporter: exporter);

    await controller.export(
      report: _report(),
      options: const ReportOptions(format: ReportFormat.poster),
      action: ReportExportAction.export,
    );

    expect(exporter.imageCalls, 0);
    expect(controller.state.phase, ReportExportPhase.failed);
  });

  test('分享完成后回调触发', () async {
    var done = 0;
    final exporter = _FakeExporter();
    final controller = ReportExportController(
      exporter: exporter,
      onShareDone: () => done++,
    );

    await controller.export(
      report: _report(),
      options: const ReportOptions(),
      action: ReportExportAction.export,
    );

    expect(done, 1);
  });
}
