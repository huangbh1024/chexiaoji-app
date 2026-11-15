import 'package:chexiaoji_app/features/ledger/data/mock_ledger_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockLedgerRepository ledger;

  setUp(() {
    ledger = MockLedgerRepository(delay: Duration.zero);
  });

  test('单车统计与 countRecords 口径一致', () async {
    const vehicleId = 'byd-han-ev';
    final stats = await ledger.fetchVehicleStats(vehicleId);
    final count = await ledger.countRecords(vehicleId: vehicleId);

    expect(stats.recordCount, count);
    expect(stats.totalSpendCents, greaterThan(0));
    expect(stats.energyRecordCount, greaterThan(0));
    expect(stats.energyRecordCount, lessThanOrEqualTo(stats.recordCount));
    expect(stats.firstRecordAt, isNotNull);
    expect(stats.latestRecordAt, isNotNull);
    expect(stats.latestRecordAt!.isAfter(stats.firstRecordAt!), isTrue);
  });

  test('未知车辆返回空统计', () async {
    final stats = await ledger.fetchVehicleStats('missing-vehicle');

    expect(stats.recordCount, 0);
    expect(stats.totalSpendCents, 0);
    expect(stats.energyRecordCount, 0);
    expect(stats.firstRecordAt, isNull);
    expect(stats.latestRecordAt, isNull);
  });
}
