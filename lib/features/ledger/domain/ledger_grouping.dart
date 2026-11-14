import '../../../core/domain/enums.dart';
import 'ledger_models.dart';

/// 把记录按本地日期分组并拍平成「组头 + 记录」行。
///
/// - 日期倒序；组内按发生时间倒序（无时刻的记录自然排在当日末尾）；
/// - 组头带当日笔数、合计与金额最大分类；
/// - 分类筛选生效时，首行插入结果提示条。
List<LedgerRow> buildLedgerRows(
  List<LedgerRecord> records, {
  ExpenseCategory? filteredCategory,
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final groups = <DateTime, List<LedgerRecord>>{};

  for (final record in records) {
    final day = DateTime(
      record.occurredAt.year,
      record.occurredAt.month,
      record.occurredAt.day,
    );
    groups.putIfAbsent(day, () => <LedgerRecord>[]).add(record);
  }

  final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));
  final rows = <LedgerRow>[];

  if (filteredCategory != null) {
    rows.add(
      LedgerResultBarRow(
        category: filteredCategory,
        count: records.length,
        totalCents: _sum(records),
      ),
    );
  }

  for (final day in days) {
    final items = groups[day]!;
    items.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    rows.add(
      LedgerDayHeaderRow(
        day: day,
        count: items.length,
        totalCents: _sum(items),
        dominantCategory: _dominantCategory(items),
        isToday: isSameDay(day, reference),
      ),
    );
    for (final record in items) {
      rows.add(LedgerRecordRow(record));
    }
  }

  return rows;
}

int _sum(List<LedgerRecord> records) =>
    records.fold(0, (total, record) => total + record.amountCents);

ExpenseCategory? _dominantCategory(List<LedgerRecord> records) {
  final totals = <ExpenseCategory, int>{};
  for (final record in records) {
    totals.update(
      record.category,
      (value) => value + record.amountCents,
      ifAbsent: () => record.amountCents,
    );
  }
  if (totals.isEmpty) {
    return null;
  }
  var best = totals.entries.first;
  for (final entry in totals.entries) {
    if (entry.value > best.value) {
      best = entry;
    }
  }
  return best.value > 0 ? best.key : null;
}
