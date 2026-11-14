import '../../ledger/domain/ledger_models.dart';
import '../domain/expense_entry_models.dart';

/// 记账页数据仓库。接口接入时替换实现，页面与 provider 不改。
abstract class ExpenseEntryRepository {
  Future<ExpenseEntryDefaults> fetchDefaults(String vehicleId);

  Future<OdometerBaseline> fetchOdometerBaseline({
    required String vehicleId,
    required DateTime before,
    String? excludeRecordId,
  });

  Future<ExpenseEntryDraft> fetchDraft(String recordId);

  Future<LedgerRecord> createExpense(ExpenseEntryDraft draft);

  Future<LedgerRecord> updateExpense(String recordId, ExpenseEntryDraft draft);

  Future<List<ReceiptAttachment>> uploadReceipts(
    List<ReceiptAttachment> receipts, {
    void Function(String localPath, double progress)? onProgress,
  });
}

sealed class ExpenseEntryException implements Exception {
  const ExpenseEntryException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'ExpenseEntryException: $message';
}

class ExpenseEntryNetworkException extends ExpenseEntryException {
  const ExpenseEntryNetworkException([super.message = '网络不可用，请稍后重试']);
}

class ExpenseEntryValidationException extends ExpenseEntryException {
  const ExpenseEntryValidationException([super.message = '保存失败，请检查输入']);
}

class ExpenseEntryVehicleMissingException extends ExpenseEntryException {
  const ExpenseEntryVehicleMissingException([super.message = '车辆已不存在']);
}

class ExpenseEntryConflictException extends ExpenseEntryException {
  const ExpenseEntryConflictException(this.latest, [super.message = '记录已更新']);

  final LedgerRecord latest;
}

class ExpenseEntryOdometerConflictException extends ExpenseEntryException {
  const ExpenseEntryOdometerConflictException(
    this.baseline, [
    super.message = '里程读数已更新',
  ]);

  final OdometerBaseline baseline;
}
