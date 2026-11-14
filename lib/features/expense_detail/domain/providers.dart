import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/domain/providers.dart';
import '../../ledger/domain/providers.dart';
import '../../report/domain/providers.dart';
import '../data/expense_detail_repository.dart';
import '../data/mock_expense_detail_repository.dart';
import 'expense_detail_models.dart';

/// 详情仓库：复用账单 Mock 的同一批记录，保证列表与详情一致。
final expenseDetailRepositoryProvider = Provider<ExpenseDetailRepository>((ref) {
  return MockExpenseDetailRepository(ref.watch(mockLedgerRepositoryProvider));
});

final expenseDetailProvider = AsyncNotifierProvider.autoDispose
    .family<ExpenseDetailController, ExpenseDetail, String>(
      ExpenseDetailController.new,
    );

class ExpenseDetailController extends AsyncNotifier<ExpenseDetail> {
  ExpenseDetailController(this.recordId);

  final String recordId;
  bool _isMutating = false;

  @override
  Future<ExpenseDetail> build() {
    return ref.watch(expenseDetailRepositoryProvider).fetchDetail(recordId);
  }

  Future<void> saveNote(String? note) async {
    final current = state.valueOrNull;
    if (current == null || _isMutating) {
      return;
    }
    _isMutating = true;
    final normalized = normalizeNote(note ?? '');
    state = AsyncData(
      current.copyWith(note: normalized, clearNote: normalized == null),
    );
    try {
      final updated = await ref
          .read(expenseDetailRepositoryProvider)
          .updateNote(recordId, normalized);
      if (!ref.mounted) {
        return;
      }
      state = AsyncData(updated);
      // 列表副标题在部分分类下使用备注，保存后需要刷新。
      ref.invalidate(ledgerRecordsProvider);
    } catch (_) {
      if (ref.mounted) {
        state = AsyncData(current);
      }
      rethrow;
    } finally {
      _isMutating = false;
    }
  }

  Future<void> saveTags(List<String> tags) async {
    final current = state.valueOrNull;
    if (current == null || _isMutating) {
      return;
    }
    _isMutating = true;
    final sanitized = sanitizeTags(tags);
    state = AsyncData(current.copyWith(tags: sanitized));
    try {
      final updated = await ref
          .read(expenseDetailRepositoryProvider)
          .updateTags(recordId, sanitized);
      if (!ref.mounted) {
        return;
      }
      state = AsyncData(updated);
    } catch (_) {
      if (ref.mounted) {
        state = AsyncData(current);
      }
      rethrow;
    } finally {
      _isMutating = false;
    }
  }

  Future<void> delete() async {
    if (_isMutating) {
      return;
    }
    _isMutating = true;
    try {
      await ref.read(expenseDetailRepositoryProvider).deleteExpense(recordId);
      _invalidateDependents();
    } finally {
      _isMutating = false;
    }
  }

  void _invalidateDependents() {
    ref.invalidate(ledgerRecordsProvider);
    ref.invalidate(ledgerSummaryProvider);
    ref.invalidate(homeDashboardProvider);
    ref.invalidate(recordsProvider);
    ref.invalidate(monthlyReportProvider);
  }
}
