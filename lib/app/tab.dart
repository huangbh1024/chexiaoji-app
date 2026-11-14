import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 一级 Tab。顺序与 [AppBottomNav] 的 4 个入口一致。
enum AppTab { home, ledger, stats, profile }

/// 当前 Tab。由 [AppTabShell] 监听；页面可通过它跨 Tab 跳转。
final appTabProvider = NotifierProvider<AppTabNotifier, AppTab>(
  AppTabNotifier.new,
);

class AppTabNotifier extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.home;

  void select(AppTab tab) {
    if (state == tab) {
      return;
    }
    state = tab;
  }
}
