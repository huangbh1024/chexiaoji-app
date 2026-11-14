import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_tokens.dart';
import '../app/theme/app_typography.dart';
import '../core/widgets/app_bottom_nav.dart';
import '../features/home/presentation/home_page.dart';
import '../features/ledger/presentation/ledger_page.dart';
import '../features/stats/presentation/stats_page.dart';
import 'tab.dart';

/// 应用主壳：Tab 容器 + 底部导航 + 中央 FAB。
///
/// - 使用 [IndexedStack] 保留各 Tab 的滚动位置与页面状态；
/// - 未访问过的 Tab 不构建，避免启动时提前发起账单 / 统计请求；
/// - 重复点击当前 Tab 滚动回顶部；
/// - 选中项由 [appTabProvider] 持有，页面可跨 Tab 跳转。
class AppTabShell extends ConsumerStatefulWidget {
  const AppTabShell({super.key});

  @override
  ConsumerState<AppTabShell> createState() => _AppTabShellState();
}

class _AppTabShellState extends ConsumerState<AppTabShell> {
  final _scrollControllers = <AppTab, ScrollController>{
    for (final tab in AppTab.values) tab: ScrollController(),
  };
  final _visitedTabs = <AppTab>{AppTab.home};

  @override
  void dispose() {
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onTabSelected(int index) {
    final tab = AppTab.values[index];
    if (tab == ref.read(appTabProvider)) {
      _scrollToTop(tab);
      return;
    }
    _visitedTabs.add(tab);
    ref.read(appTabProvider.notifier).select(tab);
  }

  void _scrollToTop(AppTab tab) {
    final controller = _scrollControllers[tab];
    if (controller == null || !controller.hasClients) {
      return;
    }
    controller.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
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
    final current = ref.watch(appTabProvider);
    ref.listen<AppTab>(appTabProvider, (previous, next) {
      _visitedTabs.add(next);
    });

    bool visited(AppTab tab) => _visitedTabs.contains(tab) || current == tab;

    return Scaffold(
      extendBody: true,
      backgroundColor: palette.background,
      body: Stack(
        children: [
          IndexedStack(
            index: current.index,
            children: [
              HomePage(scrollController: _scrollControllers[AppTab.home]!),
              if (visited(AppTab.ledger))
                LedgerPage(scrollController: _scrollControllers[AppTab.ledger]!)
              else
                const SizedBox.shrink(),
              if (visited(AppTab.stats))
                StatsPage(scrollController: _scrollControllers[AppTab.stats]!)
              else
                const SizedBox.shrink(),
              if (visited(AppTab.profile))
                const _ComingSoonTab(label: '我的', icon: Icons.person_rounded)
              else
                const SizedBox.shrink(),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 448),
                child: AppBottomNav(
                  selectedIndex: current.index,
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
