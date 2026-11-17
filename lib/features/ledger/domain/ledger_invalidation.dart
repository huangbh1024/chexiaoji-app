import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/domain/providers.dart';
import '../../profile/domain/providers.dart';
import '../../report/domain/providers.dart';
import '../../stats/domain/providers.dart';
import '../../vehicles/domain/providers.dart';
import 'providers.dart';

/// 流水写操作（新增 / 编辑 / 删除）后需要刷新的所有数据视图。
///
/// 账单、首页看板、统计、报表、我的页车库卡与车辆管理都从同一批流水派生，
/// 集中在 one place 维护，避免某个入口漏失效导致页面间数字不一致。
void invalidateLedgerDependents(Ref ref) {
  ref.invalidate(ledgerRecordsProvider);
  ref.invalidate(ledgerSummaryProvider);
  ref.invalidate(homeDashboardProvider);
  ref.invalidate(breakdownProvider);
  ref.invalidate(recordsProvider);
  ref.invalidate(trendProvider);
  ref.invalidate(statsOverviewProvider);
  ref.invalidate(statsBreakdownProvider);
  ref.invalidate(statsRecentProvider);
  ref.invalidate(statsTrendProvider);
  ref.invalidate(monthlyReportProvider);
  ref.invalidate(profileOverviewProvider);
  ref.invalidate(profileGarageProvider);
  ref.invalidate(garageProvider);
  ref.invalidate(archivedGarageProvider);
  ref.invalidate(vehiclesProvider);
}
