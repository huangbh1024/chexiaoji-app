import 'package:chexiaoji_app/core/domain/enums.dart';
import 'package:chexiaoji_app/features/expense_detail/domain/expense_detail_models.dart';
import 'package:chexiaoji_app/features/expense_detail/domain/expense_detail_presenter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'expense_detail_test_helpers.dart';

void main() {
  test('支出记录展示负号、状态、时间与记录里程', () {
    final detail = ExpenseDetail.fromRecord(buildRecord());

    expect(detail.heroAmountText, '-¥51.10');
    expect(detail.settledAmountText, '¥51.10');
    expect(detail.settledLabel, '实付金额');
    expect(detail.statusLabel, '已完成');
    expect(detail.timeText, '2025-05-16 13:28');
    expect(detail.odometerText, '记录里程 18,426 km');
    expect(detail.categoryLabel, '充电');
    expect(detail.categoryCaption, '新能源补能');
    expect(detail.titleText, '特来电充电站');
  });

  test('退款记录展示正号与退款金额', () {
    final detail = ExpenseDetail.fromRecord(buildRecord(amountCents: -5110));

    expect(detail.heroAmountText, '+¥51.10');
    expect(detail.settledAmountText, '+¥51.10');
    expect(detail.settledLabel, '退款金额');
    expect(detail.statusLabel, '已退款');
  });

  test('零金额不带符号', () {
    final detail = ExpenseDetail.fromRecord(buildRecord(amountCents: 0));

    expect(detail.heroAmountText, '¥0.00');
    expect(detail.settledAmountText, '¥0.00');
  });

  test('缺少里程时兜底', () {
    final detail = ExpenseDetail.fromRecord(buildRecord(odometerKm: null));

    expect(detail.odometerText, '里程未记录');
  });

  test('分享文本隐藏车牌并包含状态', () {
    final detail = ExpenseDetail.fromRecord(buildRecord(note: '周末补电'));

    expect(detail.shareText, contains('充电 · 特来电充电站'));
    expect(detail.shareText, contains('-¥51.10'));
    expect(detail.shareText, contains('2025-05-16 13:28 · 已完成'));
    expect(detail.shareText, contains('车牌已隐藏'));
    expect(detail.shareText, contains('备注：周末补电'));
    expect(detail.shareText, isNot(contains('粤B·D82K6')));
  });

  test('支付渠道有 / 无标签', () {
    final withPayment = ExpenseDetail.fromRecord(buildRecord()).copyWith(
      payment: const ExpensePayment(
        channel: PaymentChannel.wechat,
        label: '微信支付',
      ),
    );
    final withoutPayment = ExpenseDetail.fromRecord(buildRecord());

    expect(withPayment.paymentLabel, '微信支付');
    expect(withoutPayment.paymentLabel, isNull);
  });

  test('未知分类用分类名兜底标题', () {
    final detail = ExpenseDetail.fromRecord(
      buildRecord(category: ExpenseCategory.other, title: '  '),
    );

    expect(detail.titleText, '其他');
    expect(detail.categoryCaption, '其他开销');
  });
}
