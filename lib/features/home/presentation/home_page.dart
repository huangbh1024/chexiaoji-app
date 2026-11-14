import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/blurred_header_delegate.dart';
import '../domain/providers.dart';
import 'widgets/breakdown_card.dart';
import 'widgets/consumption_card.dart';
import 'widgets/hero_card.dart';
import 'widgets/home_header.dart';
import 'widgets/maintenance_card.dart';
import 'widgets/recent_records.dart';
import 'widgets/trend_card.dart';
import 'widgets/vehicle_switcher.dart';

/// 首页 Tab。底部导航与 FAB 由 [AppTabShell] 统一持有。
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return _HomeView(scrollController: scrollController);
  }
}

class _HomeView extends ConsumerWidget {
  const _HomeView({required this.scrollController});

  final ScrollController scrollController;

  Future<void> _refresh(WidgetRef ref) async {
    final vehicleId = ref.read(selectedVehicleIdProvider);
    final range = ref.read(trendRangeProvider);
    ref.invalidate(vehiclesProvider);
    ref.invalidate(homeDashboardProvider(vehicleId));
    ref.invalidate(breakdownProvider(vehicleId));
    ref.invalidate(recordsProvider(vehicleId));
    ref.invalidate(trendProvider((vehicleId: vehicleId, range: range)));
    try {
      await ref.read(homeDashboardProvider(vehicleId).future);
    } catch (_) {
      // 错误态由各模块自行展示。
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 448),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: context.palette.primary,
            onRefresh: () => _refresh(ref),
            child: CustomScrollView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: BlurredHeaderDelegate(
                    height: tokens.headerHeight,
                    child: const HomeHeader(),
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
                      const VehicleSwitcher(),
                      SizedBox(height: tokens.spaceLg),
                      const HeroCard(),
                      SizedBox(height: tokens.spaceLg),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Expanded(child: ConsumptionCard()),
                            SizedBox(width: tokens.gutter),
                            const Expanded(child: MaintenanceCard()),
                          ],
                        ),
                      ),
                      SizedBox(height: tokens.spaceLg),
                      const TrendCard(),
                      SizedBox(height: tokens.spaceLg),
                      const BreakdownCard(),
                      SizedBox(height: tokens.spaceLg),
                      const RecentRecords(),
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
