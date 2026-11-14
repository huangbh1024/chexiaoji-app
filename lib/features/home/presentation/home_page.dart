import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../domain/providers.dart';
import 'widgets/breakdown_card.dart';
import 'widgets/consumption_card.dart';
import 'widgets/hero_card.dart';
import 'widgets/home_bottom_nav.dart';
import 'widgets/home_header.dart';
import 'widgets/maintenance_card.dart';
import 'widgets/recent_records.dart';
import 'widgets/trend_card.dart';
import 'widgets/vehicle_switcher.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _homeScrollController = ScrollController();
  int _selectedTab = 0;

  @override
  void dispose() {
    _homeScrollController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (index == _selectedTab && index == 0) {
      _homeScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    setState(() => _selectedTab = index);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      extendBody: true,
      backgroundColor: palette.background,
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedTab,
            children: [
              _HomeView(scrollController: _homeScrollController),
              const _ComingSoonTab(
                label: '账单',
                icon: Icons.receipt_long_rounded,
              ),
              const _ComingSoonTab(label: '统计', icon: Icons.pie_chart_rounded),
              const _ComingSoonTab(label: '我的', icon: Icons.person_rounded),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 448),
                child: HomeBottomNav(
                  selectedIndex: _selectedTab,
                  onTap: _onTabSelected,
                  onFab: () => _toast('记账页待接入'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
                  delegate: _HeaderDelegate(height: tokens.headerHeight),
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

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  const _HeaderDelegate({required this.height});

  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final palette = context.palette;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: ColoredBox(
          color: palette.background.withValues(alpha: 0.86),
          child: const HomeHeader(),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HeaderDelegate oldDelegate) => true;
}

class _ComingSoonTab extends StatelessWidget {
  const _ComingSoonTab({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: palette.outline),
          const SizedBox(height: 12),
          Text(
            label,
            style: AppTypography.headlineMd.copyWith(color: palette.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            '页面待接入',
            style: AppTypography.bodyMd.copyWith(color: palette.outline),
          ),
          SizedBox(height: tokens.contentBottomPadding),
        ],
      ),
    );
  }
}
