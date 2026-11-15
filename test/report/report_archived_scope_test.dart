import 'package:chexiaoji_app/features/ledger/data/mock_ledger_repository.dart';
import 'package:chexiaoji_app/features/ledger/domain/ledger_models.dart';
import 'package:chexiaoji_app/features/report/domain/report_aggregation.dart';
import 'package:chexiaoji_app/features/report/domain/report_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockLedgerRepository ledger;
  final now = DateTime.now();
  final month = DateTime(now.year, now.month);

  setUp(() {
    ledger = MockLedgerRepository(delay: Duration.zero);
  });

  List<LedgerRecord> recordsFor(String vehicleId) {
    return ledger
        .recordsBetween(
          month,
          DateTime(
            month.year,
            month.month + 1,
          ).subtract(const Duration(milliseconds: 1)),
        )
        .where((record) => record.vehicleId == vehicleId)
        .toList(growable: false);
  }

  test('归档车辆不在在库列表时用流水快照补全报表简报', () {
    const vehicleId = 'byd-han-ev';
    final records = recordsFor(vehicleId);
    final report = buildMonthlyReport(
      scope: ReportScope(month: month, vehicleId: vehicleId),
      records: records,
      vehicles: const [],
      now: now,
    );

    expect(report.vehicles, hasLength(1));
    expect(report.vehicles.single.id, vehicleId);
    expect(report.vehicles.single.name, isNotEmpty);
    expect(report.vehicles.single.powertrainLabel, '纯电');
    expect(
      report.totalCents,
      records.fold<int>(0, (sum, record) => sum + record.amountCents),
    );
  });

  test('无流水时不合成车辆简报，不崩溃', () {
    final report = buildMonthlyReport(
      scope: ReportScope(month: DateTime(2020, 1), vehicleId: 'byd-han-ev'),
      records: const [],
      vehicles: const [],
      now: now,
    );

    expect(report.vehicles, isEmpty);
    expect(report.totalCents, 0);
  });
}
