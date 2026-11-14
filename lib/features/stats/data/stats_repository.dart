import '../domain/stats_models.dart';
import '../domain/stats_period.dart';

/// 统计页数据仓库。当前由 `MockStatsRepository` 提供本地数据，
/// 接入接口时替换实现，UI 与 provider 不需要改动。
abstract class StatsRepository {
  Future<StatsOverview> fetchOverview(StatsScope scope);

  Future<StatsBreakdown> fetchBreakdown(StatsScope scope);

  Future<StatsTrend> fetchTrend(StatsTrendQuery query);

  Future<List<StatsRecord>> fetchRecent(StatsScope scope, {int limit = 3});
}
