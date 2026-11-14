import 'package:chexiaoji_app/features/home/data/mock_home_repository.dart';
import 'package:chexiaoji_app/features/ledger/data/mock_ledger_repository.dart';
import 'package:chexiaoji_app/features/ledger/domain/ledger_models.dart';
import 'package:chexiaoji_app/features/report/data/mock_report_repository.dart';
import 'package:chexiaoji_app/features/report/domain/report_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockLedgerRepository ledger;
  late MockReportRepository reportRepository;
  final month = DateTime.now();
  final scope = ReportScope(month: DateTime(month.year, month.month));

  setUp(() {
    ledger = MockLedgerRepository(delay: Duration.zero);
    reportRepository = MockReportRepository(
      ledger: ledger,
      home: MockHomeRepository(),
      delay: Duration.zero,
    );
  });

  test('报表总额、笔数与账单页汇总一致（全部车辆）', () async {
    final summary = await ledger.fetchSummary(LedgerScope(month: scope.month));
    final report = await reportRepository.fetchReport(scope);

    expect(report.totalCents, summary.totalCents);
    expect(report.recordCount, summary.count);
    expect(report.energyKwh, greaterThan(0));
    expect(
      report.categories.fold(0, (sum, group) => sum + group.amountCents),
      report.totalCents,
    );
  });

  test('单车报表与账单页单车汇总一致', () async {
    const vehicleId = 'byd-han-ev';
    final summary = await ledger.fetchSummary(
      LedgerScope(month: scope.month, vehicleId: vehicleId),
    );
    final report = await reportRepository.fetchReport(
      ReportScope(month: scope.month, vehicleId: vehicleId),
    );

    expect(report.totalCents, summary.totalCents);
    expect(report.recordCount, summary.count);
    expect(report.vehicles, hasLength(1));
    expect(report.vehicles.single.id, vehicleId);
  });

  test('缓存命中不重复请求，清空后重新聚合', () async {
    final first = await reportRepository.fetchReport(scope);
    final second = await reportRepository.fetchReport(scope);

    expect(identical(first, second), isTrue);

    reportRepository.clearCache();
    final third = await reportRepository.fetchReport(scope);
    expect(identical(first, third), isFalse);
    expect(third.totalCents, first.totalCents);
  });
}
