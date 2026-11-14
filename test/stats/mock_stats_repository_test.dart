import 'package:chexiaoji_app/features/home/data/mock_home_repository.dart';
import 'package:chexiaoji_app/features/ledger/data/mock_ledger_repository.dart';
import 'package:chexiaoji_app/features/stats/data/mock_stats_repository.dart';
import 'package:chexiaoji_app/features/stats/domain/stats_aggregation.dart';
import 'package:chexiaoji_app/features/stats/domain/stats_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 14, 12);

  late MockLedgerRepository ledger;
  late MockStatsRepository repository;

  setUp(() {
    ledger = MockLedgerRepository(delay: Duration.zero);
    repository = MockStatsRepository(
      ledger: ledger,
      home: MockHomeRepository(ledger: ledger),
      delay: Duration.zero,
      clock: () => now,
    );
  });

  StatsScope scope(String? vehicleId) =>
      StatsScope(vehicleId: vehicleId, period: StatsPeriod.month, anchor: now);

  test('概览与构成来自同一批记录', () async {
    final overview = await repository.fetchOverview(scope('byd-han-ev'));
    final breakdown = await repository.fetchBreakdown(scope('byd-han-ev'));

    expect(overview.summary.totalCents, breakdown.totalCents);
    expect(breakdown.count, greaterThan(0));
    expect(
      overview.summary.totalCents,
      totalCentsOf(
        ledger
            .recordsBetween(overview.range.start, overview.range.end)
            .where((record) => record.vehicleId == 'byd-han-ev'),
      ),
    );
  });

  test('全部车辆是各车之和', () async {
    final all = await repository.fetchOverview(scope(null));
    var sum = 0;
    for (final vehicleId in const [
      'byd-han-ev',
      'toyota-camry-hev',
      'byd-song-plus-dmi',
      'bmw-325li',
    ]) {
      final item = await repository.fetchOverview(scope(vehicleId));
      sum += item.summary.totalCents;
    }
    expect(all.summary.totalCents, sum);
  });

  test('最近记录倒序且最多 3 条', () async {
    final recent = await repository.fetchRecent(scope('byd-han-ev'));
    expect(recent.length, lessThanOrEqualTo(3));
    for (var index = 1; index < recent.length; index++) {
      expect(
        recent[index - 1].occurredAt.isBefore(recent[index].occurredAt),
        isFalse,
      );
    }
  });

  test('保养取当前车辆或最紧迫车辆', () async {
    final single = await repository.fetchOverview(scope('byd-han-ev'));
    expect(single.maintenance?.vehicleId, 'byd-han-ev');

    final all = await repository.fetchOverview(scope(null));
    expect(all.maintenance, isNotNull);
    expect(all.maintenance!.enabled, isTrue);
  });

  test('趋势合计等于窗口内记录之和', () async {
    final query = StatsTrendQuery(
      vehicleId: 'byd-han-ev',
      range: StatsTrendRange.d30,
      anchor: now,
    );
    final trend = await repository.fetchTrend(query);
    final window = statsTrendWindow(StatsTrendRange.d30, now);
    final records = ledger
        .recordsBetween(window.from, window.to)
        .where((record) => record.vehicleId == 'byd-han-ev');
    expect(trend.totalCents, totalCentsOf(records));
    expect(
      trend.buckets.fold(0, (sum, bucket) => sum + bucket.totalCents),
      trend.totalCents,
    );
  });

  test('注入失败时抛出异常', () async {
    final failing = MockStatsRepository(
      ledger: ledger,
      home: MockHomeRepository(ledger: ledger),
      delay: Duration.zero,
      failures: const {StatsMockFailure.overview},
      clock: () => now,
    );
    expect(
      () => failing.fetchOverview(scope('byd-han-ev')),
      throwsA(isA<StateError>()),
    );
  });
}
