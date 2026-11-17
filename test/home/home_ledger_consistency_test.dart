import 'package:chexiaoji_app/features/expense_entry/data/mock_expense_entry_repository.dart';
import 'package:chexiaoji_app/features/expense_entry/domain/expense_entry_detail.dart';
import 'package:chexiaoji_app/features/expense_entry/domain/expense_entry_models.dart';
import 'package:chexiaoji_app/features/home/data/mock_home_repository.dart';
import 'package:chexiaoji_app/features/home/domain/providers.dart';
import 'package:chexiaoji_app/features/home/domain/home_models.dart';
import 'package:chexiaoji_app/features/ledger/data/mock_ledger_repository.dart';
import 'package:chexiaoji_app/features/ledger/domain/ledger_analytics.dart';
import 'package:chexiaoji_app/features/ledger/domain/ledger_models.dart';
import 'package:chexiaoji_app/features/ledger/domain/providers.dart';
import 'package:chexiaoji_app/features/profile/data/mock_profile_repository.dart';
import 'package:chexiaoji_app/features/report/data/mock_report_repository.dart';
import 'package:chexiaoji_app/features/report/domain/report_models.dart'
    show ReportScope;
import 'package:chexiaoji_app/features/stats/data/mock_stats_repository.dart';
import 'package:chexiaoji_app/features/stats/domain/stats_period.dart';
import 'package:chexiaoji_app/features/vehicles/data/mock_vehicle_repository.dart';
import 'package:chexiaoji_app/features/vehicles/data/vehicle_store_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chexiaoji_app/features/vehicles/data/vehicle_seed_data.dart';
import 'package:chexiaoji_app/features/vehicles/data/vehicle_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 16, 12);
  late MockLedgerRepository ledger;
  late VehicleStore store;
  late MockHomeRepository home;

  setUp(() {
    ledger = MockLedgerRepository(delay: Duration.zero, clock: () => now);
    store = seededVehicleStore(now: now);
    home = MockHomeRepository(
      ledger: ledger,
      store: store,
      odometerResolver: ledger.latestOdometer,
      clock: () => now,
    );
  });

  List<LedgerRecord> monthRecords(String vehicleId) {
    final end = DateTime(
      now.year,
      now.month + 1,
    ).subtract(const Duration(milliseconds: 1));
    return ledger
        .recordsBetween(monthStart(now), end)
        .where((record) => record.vehicleId == vehicleId)
        .toList(growable: false);
  }

  test('首页汇总与账单同月同车一致', () async {
    const vehicleId = 'byd-han-ev';
    final dashboard = await home.fetchDashboard(vehicleId);
    final records = monthRecords(vehicleId);
    final km = distanceOf(records).km;

    expect(dashboard.summary.monthSpendCents, totalCentsOf(records));
    expect(dashboard.summary.monthMileageKm, km);
    expect(
      dashboard.summary.costPerKm,
      closeTo(km <= 0 ? 0 : totalCentsOf(records) / 100 / km, 0.0001),
    );
    expect(
      dashboard.summary.energyCostPerKm,
      closeTo(km <= 0 ? 0 : energyCentsOf(records) / 100 / km, 0.0001),
    );
  });

  test('首页分类构成与统计页构成同源', () async {
    const vehicleId = 'byd-han-ev';
    final breakdown = await home.fetchBreakdown(vehicleId);
    final expected = buildCategoryBreakdown(monthRecords(vehicleId));

    expect(breakdown.totalCents, expected.totalCents);
    expect(breakdown.count, expected.count);
    expect(
      breakdown.categories.map((item) => item.category).toList(),
      expected.items.map((item) => item.category).toList(),
    );
    expect(
      breakdown.categories.map((item) => item.amountCents).toList(),
      expected.items.map((item) => item.amountCents).toList(),
    );
    expect(
      breakdown.categories.fold<int>(0, (sum, item) => sum + item.percent),
      expected.items.isEmpty ? 0 : 100,
    );
  });

  test('首页趋势合计等于窗口内账单流水之和', () async {
    const vehicleId = 'byd-han-ev';
    final trend = await home.fetchTrend(vehicleId, TrendRange.d30);
    final from = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 29));
    final to = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final records = ledger
        .recordsBetween(from, to)
        .where((record) => record.vehicleId == vehicleId);

    expect(trend.totalCents, totalCentsOf(records));
    expect(trend.points.length, 30);
    expect(
      trend.points.fold(
        0,
        (sum, point) => sum + point.energyCents + point.otherCents,
      ),
      trend.totalCents,
    );
  });

  test('首页与「我的」每公里能源成本同源', () async {
    const vehicleId = 'byd-han-ev';
    final dashboard = await home.fetchDashboard(vehicleId);
    final profile = MockProfileRepository(
      home: home,
      ledger: ledger,
      delay: Duration.zero,
    );
    final garage = await profile.fetchGarage(vehicleId: vehicleId);
    final vehicle = garage.vehicles.firstWhere((item) => item.id == vehicleId);

    expect(
      vehicle.energyCostPerKmCents,
      (dashboard.summary.energyCostPerKm * 100).round(),
    );
  });

  test('新增流水后首页看板与账单汇总同步增加', () async {
    final container = ProviderContainer(
      overrides: [
        mockLedgerRepositoryProvider.overrideWithValue(ledger),
        vehicleStoreProvider.overrideWithValue(store),
        homeRepositoryProvider.overrideWithValue(home),
      ],
    );
    addTearDown(container.dispose);

    final before = await container.read(
      homeDashboardProvider('byd-han-ev').future,
    );
    final entry = MockExpenseEntryRepository(
      ledger,
      home,
      delay: Duration.zero,
    );
    await entry.createExpense(
      ExpenseEntryDraft(
        vehicleId: 'byd-han-ev',
        category: ExpenseCategory.charging,
        amountCents: 12345,
        occurredAt: now,
        paymentChannel: PaymentChannel.wechat,
        paymentLabel: '微信支付',
        odometerKm: 19000,
        lastOdometerKm: 18400,
        detail: const ChargingDetail(unitPriceCentsPerKwh: 120),
      ),
    );
    container.invalidate(homeDashboardProvider('byd-han-ev'));

    final after = await container.read(
      homeDashboardProvider('byd-han-ev').future,
    );
    final summary = await ledger.fetchSummary(
      LedgerScope(
        month: DateTime(now.year, now.month),
        vehicleId: 'byd-han-ev',
      ),
    );

    expect(
      after.summary.monthSpendCents,
      before.summary.monthSpendCents + 12345,
    );
    expect(after.summary.monthSpendCents, summary.totalCents);
  });

  test('四辆车：首页 / 账单 / 统计 / 月报 / 我的 同月一致', () async {
    final stats = MockStatsRepository(
      ledger: ledger,
      home: home,
      delay: Duration.zero,
      clock: () => now,
    );
    final report = MockReportRepository(
      ledger: ledger,
      home: home,
      delay: Duration.zero,
    );
    final profile = MockProfileRepository(
      home: home,
      ledger: ledger,
      delay: Duration.zero,
    );
    final garageRepository = MockVehicleRepository(
      store: store,
      home: home,
      ledger: ledger,
      now: () => now,
      delay: Duration.zero,
    );
    final month = DateTime(now.year, now.month);
    final garage = await garageRepository.fetchGarage();

    for (final vehicleId in const [
      'byd-han-ev',
      'toyota-camry-hev',
      'byd-song-plus-dmi',
      'bmw-325li',
    ]) {
      final summary = await ledger.fetchSummary(
        LedgerScope(month: month, vehicleId: vehicleId),
      );
      final dashboard = await home.fetchDashboard(vehicleId);
      final overview = await stats.fetchOverview(
        StatsScope(
          vehicleId: vehicleId,
          period: StatsPeriod.month,
          anchor: now,
        ),
      );
      final monthly = await report.fetchReport(
        ReportScope(month: month, vehicleId: vehicleId),
      );
      final garageData = await profile.fetchGarage(vehicleId: vehicleId);
      final managed = garage.vehicles.firstWhere(
        (item) => item.id == vehicleId,
      );

      expect(dashboard.summary.monthSpendCents, summary.totalCents);
      expect(overview.summary.totalCents, summary.totalCents);
      expect(monthly.totalCents, summary.totalCents);
      expect(monthly.recordCount, summary.count);
      expect(
        monthly.categories.fold(0, (sum, item) => sum + item.amountCents),
        summary.totalCents,
      );
      expect(garageData.snapshot.monthEnergy.amountCents, summary.energyCents);
      expect(managed.monthSpendCents, summary.totalCents);

      final homeBreakdown = await home.fetchBreakdown(vehicleId);
      final statsBreakdown = await stats.fetchBreakdown(
        StatsScope(
          vehicleId: vehicleId,
          period: StatsPeriod.month,
          anchor: now,
        ),
      );
      expect(homeBreakdown.totalCents, statsBreakdown.totalCents);
      expect(
        homeBreakdown.categories.map((item) => item.category).toList(),
        statsBreakdown.categories.map((item) => item.category).toList(),
      );
      expect(
        homeBreakdown.categories.map((item) => item.amountCents).toList(),
        statsBreakdown.categories.map((item) => item.amountCents).toList(),
      );
    }
  });

  test('首页保养进度与里程来自同一批流水', () async {
    final dashboard = await home.fetchDashboard('byd-han-ev');

    expect(dashboard.maintenance.enabled, isTrue);
    expect(dashboard.maintenance.remainingKm, 20000 - 18426);
    expect(dashboard.maintenance.progressPercent, inInclusiveRange(0, 100));
  });
}
