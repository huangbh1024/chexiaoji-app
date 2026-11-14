import '../../../core/domain/enums.dart';
import '../../ledger/data/mock_ledger_repository.dart';
import '../../ledger/domain/ledger_models.dart';
import '../domain/expense_detail_models.dart';
import 'expense_detail_repository.dart';

/// 由账单 Mock 派生详情：同一 id 的记录、金额、车辆与列表一致。
class MockExpenseDetailRepository implements ExpenseDetailRepository {
  MockExpenseDetailRepository(
    this.ledger, {
    this.delay = const Duration(milliseconds: 120),
  });

  final MockLedgerRepository ledger;
  final Duration delay;

  final Map<String, String?> _noteOverrides = {};
  final Map<String, List<String>> _tagOverrides = {};
  final Map<String, DateTime> _updatedAt = {};

  @override
  Future<ExpenseDetail> fetchDetail(String id) async {
    await Future<void>.delayed(delay);
    final record = ledger.recordById(id);
    if (record == null) {
      throw const ExpenseNotFoundException();
    }
    return _build(record);
  }

  @override
  Future<ExpenseDetail> updateNote(String id, String? note) async {
    await Future<void>.delayed(delay);
    final record = ledger.recordById(id);
    if (record == null) {
      throw const ExpenseNotFoundException();
    }
    _noteOverrides[id] = normalizeNote(note ?? '');
    _updatedAt[id] = DateTime.now();
    return _build(record);
  }

  @override
  Future<ExpenseDetail> updateTags(String id, List<String> tags) async {
    await Future<void>.delayed(delay);
    final record = ledger.recordById(id);
    if (record == null) {
      throw const ExpenseNotFoundException();
    }
    _tagOverrides[id] = sanitizeTags(tags);
    _updatedAt[id] = DateTime.now();
    return _build(record);
  }

  @override
  Future<void> deleteExpense(String id) async {
    await Future<void>.delayed(delay);
    if (ledger.recordById(id) == null) {
      throw const ExpenseNotFoundException();
    }
    ledger.markDeleted(id);
    _noteOverrides.remove(id);
    _tagOverrides.remove(id);
    _updatedAt.remove(id);
  }

  ExpenseDetail _build(LedgerRecord record) {
    final payment = _paymentFor(record.category);
    final tags = _tagOverrides[record.id] ?? _defaultTags(record.category);
    final note = _noteOverrides.containsKey(record.id)
        ? _noteOverrides[record.id]
        : (record.note ?? _defaultNote(record.category));
    return ExpenseDetail(
      record: record,
      status: record.amountCents < 0
          ? ExpenseStatus.refunded
          : ExpenseStatus.completed,
      payment: payment,
      tags: List<String>.unmodifiable(sanitizeTags(tags)),
      note: normalizeNote(note ?? ''),
      vehicleBound: true,
      updatedAt: _updatedAt[record.id] ?? record.occurredAt.add(
        const Duration(minutes: 2),
      ),
    );
  }

  ExpensePayment _paymentFor(ExpenseCategory category) {
    return switch (category) {
      ExpenseCategory.charging => const ExpensePayment(
        channel: PaymentChannel.wechat,
        label: '微信支付',
      ),
      ExpenseCategory.fuel => const ExpensePayment(
        channel: PaymentChannel.unionpay,
        label: '云闪付加油卡代扣',
      ),
      ExpenseCategory.maintenance => const ExpensePayment(
        channel: PaymentChannel.alipay,
        label: '支付宝',
      ),
      ExpenseCategory.parking => const ExpensePayment(
        channel: PaymentChannel.other,
        label: '无感免密支付',
      ),
      ExpenseCategory.toll => const ExpensePayment(
        channel: PaymentChannel.etc,
        label: '粤通卡 ETC 自动划扣',
      ),
      ExpenseCategory.carWash => const ExpensePayment(
        channel: PaymentChannel.wechat,
        label: '微信支付（次卡划扣）',
      ),
      ExpenseCategory.other => const ExpensePayment(
        channel: PaymentChannel.alipay,
        label: '支付宝',
      ),
    };
  }

  List<String> _defaultTags(ExpenseCategory category) {
    return switch (category) {
      ExpenseCategory.charging => const ['日常补能', '谷电错峰'],
      ExpenseCategory.fuel => const ['满箱加注', '跨城自驾'],
      ExpenseCategory.maintenance => const ['官方授权', '基础保养'],
      ExpenseCategory.parking => const ['商场购物', '无感支付'],
      ExpenseCategory.toll => const ['ETC 通行', '高速出行'],
      ExpenseCategory.carWash => const ['精洗内饰', '轮胎养护'],
      ExpenseCategory.other => const ['临时开销'],
    };
  }

  String _defaultNote(ExpenseCategory category) {
    return switch (category) {
      ExpenseCategory.charging =>
        '周五午休顺道补电，车机空调开启休息模式，体验顺畅。',
      ExpenseCategory.fuel =>
        '周末出省自驾前加满一箱 95# 汽油，使用加油优惠券减免 20 元，油枪跳枪准。',
      ExpenseCategory.maintenance =>
        '完成基础保养，更换空调滤芯、刹车油以及底盘螺栓紧固，服务专业。',
      ExpenseCategory.parking => '晚餐消费积分抵扣了 1 小时停车券，出场自动抬杆。',
      ExpenseCategory.toll => '早高峰前往前海自贸区会议，走沿江高速全程畅通。',
      ExpenseCategory.carWash => '下班前顺路洗了外观和内饰，轮毂泥沙都冲洗干净。',
      ExpenseCategory.other => '临时开销，先记一笔，稍后补充备注。',
    };
  }
}
