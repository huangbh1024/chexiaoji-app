import 'enums.dart';

/// 支付渠道的领域规则：账单记录里保存的是展示文案，客户端据此反查渠道。
///
/// 记账页、详情页与 Mock 仓库共用，避免各处各写一套 `contains` 判断。
PaymentChannel paymentChannelForLabel(String? label) {
  final text = (label ?? '').trim();
  if (text.isEmpty) {
    return PaymentChannel.wechat;
  }
  if (text.contains('支付宝')) {
    return PaymentChannel.alipay;
  }
  if (text.contains('云闪付') || text.contains('银联')) {
    return PaymentChannel.unionpay;
  }
  if (text.contains('现金')) {
    return PaymentChannel.cash;
  }
  if (text.contains('银行卡') || text.contains('信用卡')) {
    return PaymentChannel.card;
  }
  if (text.contains('ETC') || text.contains('粤通卡')) {
    return PaymentChannel.etc;
  }
  if (text.contains('无感')) {
    return PaymentChannel.other;
  }
  return PaymentChannel.wechat;
}

/// 分类的默认支付文案；记录里没有支付方式时使用。
String defaultPaymentLabelFor(ExpenseCategory category) => switch (category) {
  ExpenseCategory.charging || ExpenseCategory.carWash => '微信支付',
  ExpenseCategory.fuel => '云闪付',
  ExpenseCategory.maintenance || ExpenseCategory.other => '支付宝',
  ExpenseCategory.parking => '无感支付',
  ExpenseCategory.toll => 'ETC',
};
