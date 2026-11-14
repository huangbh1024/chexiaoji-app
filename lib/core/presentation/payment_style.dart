import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../domain/enums.dart';

/// 支付渠道的展示文案与圆点色，详情页与记账页共用。
extension PaymentChannelVisual on PaymentChannel {
  String get label => switch (this) {
    PaymentChannel.wechat => '微信支付',
    PaymentChannel.alipay => '支付宝',
    PaymentChannel.unionpay => '云闪付',
    PaymentChannel.etc => 'ETC',
    PaymentChannel.cash => '现金',
    PaymentChannel.card => '银行卡',
    PaymentChannel.other => '其他',
  };

  Color color(AppPalette palette) => switch (this) {
    PaymentChannel.wechat => palette.primary,
    PaymentChannel.alipay => palette.tertiary,
    PaymentChannel.unionpay => palette.secondary,
    PaymentChannel.etc => palette.violet,
    PaymentChannel.cash => palette.outline,
    PaymentChannel.card => palette.tertiary,
    PaymentChannel.other => palette.outline,
  };
}
