import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/enums.dart';
import '../data/ledger_repository.dart';
import '../data/mock_ledger_repository.dart';
import 'ledger_grouping.dart';
import 'ledger_models.dart';

/// 静态阶段使用本地 Mock；接入接口时替换这里的实现。
final ledgerRepositoryProvider = Provider<LedgerRepository>(
  (ref) => MockLedgerRepository(),
);

/// 当前筛选：月份 / 车辆 / 分类 / 排序。
///
/// 非 autoDispose，切到其他 Tab 再回来时保留筛选。
final ledgerFilterProvider = NotifierProvider<LedgerFilterNotifier, LedgerQuery>(
  LedgerFilterNotifier.new,
);

class LedgerFilterNotifier extends Notifier<LedgerQuery> {
  @override
  LedgerQuery build() => LedgerQuery(month: monthStart(DateTime.now()));

  void selectMonth(DateTime month) {
    final normalized = monthStart(month);
    if (state.month.year == normalized.year &&
        state.month.month == normalized.month) {
      return;
    }
    state = state.copyWith(month: normalized);
  }

  void selectVehicle(String? vehicleId) {
    if (state.vehicleId == vehicleId) {
      return;
    }
    state = vehicleId == null
        ? state.copyWith(clearVehicle: true)
        : state.copyWith(vehicleId: vehicleId);
  }

  void selectCategory(ExpenseCategory? category) {
    if (state.category == category) {
      return;
    }
    state = category == null
        ? state.copyWith(clearCategory: true)
        : state.copyWith(category: category);
  }

  void selectSort(LedgerSort sort) {
    if (state.sort == sort) {
      return;
    }
    state = state.copyWith(sort: sort);
  }

  void reset() {
    state = LedgerQuery(month: monthStart(DateTime.now()));
  }
}

/// 月度汇总只跟随月份 + 车辆。
final ledgerSummaryProvider = FutureProvider.autoDispose
    .family<LedgerMonthSummary, LedgerScope>((ref, scope) {
      return ref.watch(ledgerRepositoryProvider).fetchSummary(scope);
    });

/// 流水列表：跟随完整筛选条件，内部维护游标分页。
final ledgerRecordsProvider =
    NotifierProvider.autoDispose<LedgerRecordsNotifier, LedgerListState>(
      LedgerRecordsNotifier.new,
    );

class LedgerRecordsNotifier extends Notifier<LedgerListState> {
  int _generation = 0;

  @override
  LedgerListState build() {
    final query = ref.watch(ledgerFilterProvider);
    final generation = ++_generation;
    _loadFirstPage(query, generation);
    return const LedgerListState.loading();
  }

  Future<void> _loadFirstPage(LedgerQuery query, int generation) async {
    try {
      final page = await ref
          .read(ledgerRepositoryProvider)
          .fetchRecords(query);
      if (!ref.mounted || generation != _generation) {
        return;
      }
      state = LedgerListState(
        items: page.items,
        rows: buildLedgerRows(
          page.items,
          filteredCategory: query.category,
        ),
        cursor: page.nextCursor,
        hasMore: page.hasMore,
      );
    } catch (_) {
      if (!ref.mounted || generation != _generation) {
        return;
      }
      state = LedgerListState.empty().copyWith(errorMessage: '账单加载失败');
    }
  }

  Future<void> loadMore() async {
    final current = state;
    if (current.isLoading || current.isLoadingMore || !current.hasMore) {
      return;
    }
    final query = ref.read(ledgerFilterProvider);
    final generation = _generation;
    state = current.copyWith(isLoadingMore: true, isNextPageFailed: false);
    try {
      final page = await ref
          .read(ledgerRepositoryProvider)
          .fetchRecords(query, cursor: current.cursor);
      if (!ref.mounted || generation != _generation) {
        return;
      }
      final seen = current.items.map((record) => record.id).toSet();
      final appended = <LedgerRecord>[
        ...current.items,
        ...page.items.where((record) => !seen.contains(record.id)),
      ];
      state = LedgerListState(
        items: appended,
        rows: buildLedgerRows(appended, filteredCategory: query.category),
        cursor: page.nextCursor,
        hasMore: page.hasMore,
      );
    } catch (_) {
      if (!ref.mounted || generation != _generation) {
        return;
      }
      state = current.copyWith(isLoadingMore: false, isNextPageFailed: true);
    }
  }

  Future<void> refresh() async {
    final query = ref.read(ledgerFilterProvider);
    final generation = ++_generation;
    state = const LedgerListState.loading();
    await _loadFirstPage(query, generation);
  }

  Future<void> retry() async {
    final query = ref.read(ledgerFilterProvider);
    final generation = ++_generation;
    state = const LedgerListState.loading();
    await _loadFirstPage(query, generation);
  }

  Future<void> retryLoadMore() async {
    state = state.copyWith(isNextPageFailed: false);
    await loadMore();
  }
}
