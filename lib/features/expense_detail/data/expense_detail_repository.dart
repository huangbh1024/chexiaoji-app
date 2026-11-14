import '../domain/expense_detail_models.dart';

/// 单笔开销详情仓库。接口接入时替换实现，页面与 provider 不改。
abstract class ExpenseDetailRepository {
  Future<ExpenseDetail> fetchDetail(String id);

  Future<ExpenseDetail> updateNote(String id, String? note);

  Future<ExpenseDetail> updateTags(String id, List<String> tags);

  Future<void> deleteExpense(String id);
}

sealed class ExpenseDetailException implements Exception {
  const ExpenseDetailException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'ExpenseDetailException: $message';
}

class ExpenseNotFoundException extends ExpenseDetailException {
  const ExpenseNotFoundException([String message = '记录不存在或已被删除'])
    : super(message);
}

class ExpenseDetailNetworkException extends ExpenseDetailException {
  const ExpenseDetailNetworkException([String message = '加载失败'])
    : super(message);
}

class ExpenseDetailConflictException extends ExpenseDetailException {
  const ExpenseDetailConflictException([String message = '记录已更新'])
    : super(message);
}
