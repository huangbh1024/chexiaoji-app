import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/blurred_header_delegate.dart';
import '../domain/providers.dart';
import '../domain/stats_period.dart';
import 'stats_breakdown_card.dart';
import 'stats_energy_card.dart';
import 'stats_header.dart';
import 'stats_hero_card.dart';
import 'stats_maintenance_card.dart';
import 'stats_period_bar.dart';
import 'stats_recent_records.dart';
import 'stats_trend_card.dart';

/// 统计 Tab：周期分析 + 走势 + 构成 + 最近记录。
///
/// 底部导航与 FAB 由 [AppTabShell] 统一持有。
class StatsPage extends ConsumerWidget {
  const StatsPage({super.key, required this.scrollController});

  final ScrollController scrollController;

  Future<void> _refresh(WidgetRef ref) async {
    final filter = ref.read(statsFilterProvider);
    final scope = filter.toScope();
    final range = ref.read(statsTrendRangeProvider);
    final query = StatsTrendQuery(
      vehicleId: filter.vehicleId,
      range: range,
      anchor: filter.anchor,
    );
    ref.invalidate(statsOverviewProvider(scope));
    ref.invalidate(statsBreakdownProvider(scope));
    ref.invalidate(statsRecentProvider(scope));
    ref.invalidate(statsTrendProvider(query));
    try {
      await ref.read(statsOverviewProvider(scope).future);
    } catch (_) {
      // 各模块自行展示错误态。
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const gap = 16.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 448),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: context.palette.primary,
            onRefresh: () => _refresh(ref),
            child: CustomScrollView(
              key: const Key('stats-scroll'),
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: BlurredHeaderDelegate(
                    height: tokens.headerHeight,
                    child: const StatsHeader(),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    tokens.pagePadding,
                    4,
                    tokens.pagePadding,
                    tokens.contentBottomPadding + bottomInset,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const StatsPeriodBar(),
                      const SizedBox(height: gap),
                      const StatsHeroCard(),
                      const SizedBox(height: gap),
                      const IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: StatsEnergyCard()),
                            SizedBox(width: 12),
                            Expanded(child: StatsMaintenanceCard()),
                          ],
                        ),
                      ),
                      const SizedBox(height: gap),
                      const StatsTrendCard(),
                      const SizedBox(height: gap),
                      const StatsBreakdownCard(),
                      const SizedBox(height: gap),
                      const StatsRecentRecords(),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
