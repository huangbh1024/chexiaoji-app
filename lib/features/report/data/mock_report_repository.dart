import '../../home/data/home_repository.dart';
import '../../ledger/data/ledger_repository.dart';
import '../../ledger/domain/ledger_models.dart';
import '../domain/report_aggregation.dart';
import '../domain/report_models.dart';
import 'report_repository.dart';

/// 本地报表 Mock：复用账单 Mock 的同一批记录，保证报表与账单页
/// 同月同车的总额、笔数、分类金额完全一致。
class MockReportRepository implements ReportRepository {
  MockReportRepository({
    required this.ledger,
    required this.home,
    this.delay = const Duration(milliseconds: 160),
    this.cacheTtl = const Duration(minutes: 2),
  });

  final LedgerRepository ledger;
  final HomeRepository home;
  final Duration delay;
  final Duration cacheTtl;

  final Map<String, ({MonthlyReport report, DateTime cachedAt})> _cache = {};

  @override
  Future<MonthlyReport> fetchReport(ReportScope scope) async {
    final key = _cacheKey(scope);
    final cached = _cache[key];
    if (cached != null &&
        DateTime.now().difference(cached.cachedAt) < cacheTtl) {
      return cached.report;
    }

    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }

    final records = await fetchAllRecords(scope);
    final vehicles = await home.fetchVehicles();
    final previousTotal = await _fetchPreviousTotal(scope);

    final report = buildMonthlyReport(
      scope: scope,
      records: records,
      vehicles: vehicles,
      now: DateTime.now(),
      previousTotalCents: previousTotal,
    );
    _cache[key] = (report: report, cachedAt: DateTime.now());
    return report;
  }

  @override
  Future<List<LedgerRecord>> fetchAllRecords(ReportScope scope) async {
    final query = LedgerQuery(month: scope.month, vehicleId: scope.vehicleId);
    final records = <LedgerRecord>[];
    String? cursor;

    for (var pageIndex = 0; pageIndex < 200; pageIndex++) {
      final page = await ledger.fetchRecords(query, cursor: cursor, limit: 100);
      records.addAll(page.items);
      cursor = page.nextCursor;
      if (!page.hasMore || cursor == null) {
        break;
      }
    }
    return records;
  }

  Future<int?> _fetchPreviousTotal(ReportScope scope) async {
    final previousMonth = DateTime(scope.month.year, scope.month.month - 1);
    final records = await fetchAllRecords(
      ReportScope(month: previousMonth, vehicleId: scope.vehicleId),
    );
    if (records.isEmpty) {
      return null;
    }
    return records.fold<int>(0, (sum, record) => sum + record.amountCents);
  }

  String _cacheKey(ReportScope scope) =>
      '${scope.monthKey}|${scope.vehicleId ?? 'all'}';

  void clearCache() => _cache.clear();
}
