import 'package:chexiaoji_app/features/ledger/data/mock_ledger_repository.dart';
import 'package:chexiaoji_app/features/ledger/domain/ledger_models.dart';
import 'package:flutter_test/flutter_test.dart';

LedgerRecord _movedTo(LedgerRecord record, DateTime time) {
  return LedgerRecord(
    id: record.id,
    vehicleId: record.vehicleId,
    vehicleShortName: record.vehicleShortName,
    vehicleName: record.vehicleName,
    powertrain: record.powertrain,
    category: record.category,
    title: record.title,
    amountCents: record.amountCents,
    occurredAt: time,
    badgeText: record.badgeText,
    badgeKind: record.badgeKind,
    description: record.description,
    metrics: record.metrics,
    statusText: record.statusText,
    note: record.note,
  );
}

void main() {
  late MockLedgerRepository ledger;
  late DateTime now;
  late DateTime currentMonth;
  late DateTime previousMonth;
  late LedgerRecord source;
  late DateTime movedAt;

  setUp(() async {
    ledger = MockLedgerRepository(delay: Duration.zero);
    now = DateTime.now();
    currentMonth = monthStart(now);
    previousMonth = DateTime(now.year, now.month - 1);
    final page = await ledger.fetchRecords(LedgerQuery(month: currentMonth));
    source = page.items.firstWhere((record) => record.id.startsWith('ledger-'));
    movedAt = DateTime(previousMonth.year, previousMonth.month, 10, 12);
    ledger.updateRecord(_movedTo(source, movedAt));
  });

  test('编辑后跨月：记录从原月份迁移到新月份', () async {
    final currentPage = await ledger.fetchRecords(
      LedgerQuery(month: currentMonth),
    );
    expect(currentPage.items.where((r) => r.id == source.id), isEmpty);

    final previousPage = await ledger.fetchRecords(
      LedgerQuery(month: previousMonth),
    );
    final moved = previousPage.items.where((r) => r.id == source.id);
    expect(moved, hasLength(1));
    expect(moved.single.occurredAt, movedAt);
    expect(ledger.recordById(source.id), isNotNull);
  });

  test('编辑后跨月：月总额等于日柱之和', () async {
    final currentSummary = await ledger.fetchSummary(
      LedgerScope(month: currentMonth),
    );
    expect(
      currentSummary.totalCents,
      currentSummary.daily.fold(0, (sum, point) => sum + point.amountCents),
    );

    final previousSummary = await ledger.fetchSummary(
      LedgerScope(month: previousMonth),
    );
    expect(
      previousSummary.totalCents,
      previousSummary.daily.fold(0, (sum, point) => sum + point.amountCents),
    );
  });

  test('编辑后跨月：统计窗口能找到记录', () async {
    final records = ledger.recordsBetween(
      previousMonth,
      DateTime(previousMonth.year, previousMonth.month, 28, 23, 59, 59),
    );
    expect(records.where((r) => r.id == source.id), hasLength(1));
  });
}
