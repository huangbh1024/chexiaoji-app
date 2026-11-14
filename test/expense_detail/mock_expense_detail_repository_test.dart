import 'package:chexiaoji_app/features/expense_detail/data/expense_detail_repository.dart';
import 'package:chexiaoji_app/features/expense_detail/data/mock_expense_detail_repository.dart';
import 'package:chexiaoji_app/features/expense_detail/domain/expense_detail_models.dart';
import 'package:chexiaoji_app/features/ledger/data/mock_ledger_repository.dart';
import 'package:chexiaoji_app/features/ledger/domain/ledger_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockLedgerRepository ledger;
  late MockExpenseDetailRepository repository;

  setUp(() {
    ledger = MockLedgerRepository(delay: Duration.zero);
    repository = MockExpenseDetailRepository(
      ledger,
      delay: Duration.zero,
    );
  });

  Future<LedgerRecord> firstRecord() async {
    final page = await ledger.fetchRecords(
      LedgerQuery(month: monthStart(DateTime.now())),
    );
    return page.items.first;
  }

  test('按 id 取详情，支付 / 标签 / 备注有默认值', () async {
    final record = await firstRecord();
    final detail = await repository.fetchDetail(record.id);

    expect(detail.record.id, record.id);
    expect(detail.payment, isNotNull);
    expect(detail.tags, isNotEmpty);
    expect(detail.note, isNotNull);
    expect(detail.vehicleBound, isTrue);
  });

  test('未知 id 抛 ExpenseNotFoundException', () async {
    await expectLater(
      repository.fetchDetail('missing-id'),
      throwsA(isA<ExpenseNotFoundException>()),
    );
  });

  test('更新备注与标签后返回最新详情', () async {
    final record = await firstRecord();

    final withNote = await repository.updateNote(record.id, '新的备注');
    expect(withNote.note, '新的备注');

    final withTags = await repository.updateTags(record.id, ['  #甲 ', '乙', '甲']);
    expect(withTags.tags, ['甲', '乙']);
  });

  test('清空备注后返回 null', () async {
    final record = await firstRecord();

    final detail = await repository.updateNote(record.id, '   ');

    expect(detail.note, isNull);
  });

  test('删除后详情 404，列表不再包含该记录', () async {
    final record = await firstRecord();
    final before = await repository.fetchDetail(record.id);
    expect(before.record.id, record.id);

    await repository.deleteExpense(record.id);

    await expectLater(
      repository.fetchDetail(record.id),
      throwsA(isA<ExpenseNotFoundException>()),
    );
    final page = await ledger.fetchRecords(
      LedgerQuery(month: monthStart(DateTime.now())),
    );
    expect(page.items.where((item) => item.id == record.id), isEmpty);
  });

  test('重复删除按 404 处理', () async {
    final record = await firstRecord();
    await repository.deleteExpense(record.id);

    await expectLater(
      repository.deleteExpense(record.id),
      throwsA(isA<ExpenseNotFoundException>()),
    );
  });

  test('sanitize 后的标签数量不超过上限', () async {
    final record = await firstRecord();
    final tags = List<String>.generate(12, (index) => '标签$index');

    final detail = await repository.updateTags(record.id, tags);

    expect(detail.tags.length, ExpenseDetailRules.maxTags);
  });
}
