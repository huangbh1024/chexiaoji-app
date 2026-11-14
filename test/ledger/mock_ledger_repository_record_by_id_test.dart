import 'package:chexiaoji_app/features/ledger/data/mock_ledger_repository.dart';
import 'package:chexiaoji_app/features/ledger/domain/ledger_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recordById 命中当前月记录并缓存', () async {
    final repository = MockLedgerRepository(delay: Duration.zero);
    final page = await repository.fetchRecords(
      LedgerQuery(month: monthStart(DateTime.now())),
    );
    final record = page.items.first;

    final found = repository.recordById(record.id);

    expect(found, isNotNull);
    expect(found!.id, record.id);
    expect(repository.recordById(record.id), same(found));
  });

  test('markDeleted 后 recordById 返回 null，列表过滤该记录', () async {
    final repository = MockLedgerRepository(delay: Duration.zero);
    final scope = LedgerQuery(month: monthStart(DateTime.now()));
    final page = await repository.fetchRecords(scope);
    final record = page.items.first;

    repository.markDeleted(record.id);

    expect(repository.recordById(record.id), isNull);
    final next = await repository.fetchRecords(scope);
    expect(next.items.where((item) => item.id == record.id), isEmpty);
  });

  test('未知 id 返回 null', () {
    final repository = MockLedgerRepository(delay: Duration.zero);

    expect(repository.recordById('missing-id'), isNull);
  });
}
