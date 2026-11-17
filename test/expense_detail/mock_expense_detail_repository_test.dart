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
    repository = MockExpenseDetailRepository(ledger, delay: Duration.zero);
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

  test('支付方式与记账时写入的 paymentMethod 一致', () async {
    final record = await firstRecord();
    final detail = await repository.fetchDetail(record.id);

    expect(detail.payment, isNotNull);
    expect(detail.payment!.label, record.metrics.paymentMethod);
  });

  test('用户手动记账不补演示备注与标签', () async {
    final now = DateTime.now();
    ledger.insertRecord(
      LedgerRecord(
        id: 'rec_manual_test',
        vehicleId: 'byd-han-ev',
        vehicleShortName: '汉 EV',
        vehicleName: '比亚迪 汉 EV',
        powertrain: PowertrainType.ev,
        category: ExpenseCategory.charging,
        title: '测试充电站',
        amountCents: 3000,
        occurredAt: now,
        metrics: const LedgerMetrics(paymentMethod: '微信支付'),
      ),
    );

    final detail = await repository.fetchDetail('rec_manual_test');

    expect(detail.note, isNull);
    expect(detail.tags, isEmpty);
    expect(detail.payment!.label, '微信支付');
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

    final withTags = await repository.updateTags(record.id, [
      '  #甲 ',
      '乙',
      '甲',
    ]);
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
  test('车辆档案不存在时详情标记为未绑定', () async {
    final record = await firstRecord();
    final unboundRepository = MockExpenseDetailRepository(
      ledger,
      delay: Duration.zero,
      vehicleExists: (_) => false,
    );

    final detail = await unboundRepository.fetchDetail(record.id);

    expect(detail.vehicleBound, isFalse);
  });
}
