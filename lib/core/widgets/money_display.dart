import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../format/formatters.dart';

/// 金额三段式排版：`¥` + 整数大字 + 小数小字，基线对齐。
///
/// 用于账单页汇总卡的月度总额；首页 Hero 的每公里成本结构相似，
/// 后续可逐步替换。
class MoneyDisplay extends StatelessWidget {
  const MoneyDisplay({
    super.key,
    required this.cents,
    this.currencyStyle,
    this.integerStyle,
    this.decimalStyle,
  });

  final int cents;
  final TextStyle? currencyStyle;
  final TextStyle? integerStyle;
  final TextStyle? decimalStyle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final parts = splitYuanParts(cents);
    final currency = currencyStyle ??
        AppTypography.headlineMd.copyWith(
          color: palette.primaryText,
          fontWeight: FontWeight.w700,
        );
    final integer = integerStyle ??
        AppTypography.displayHero.copyWith(color: palette.onSurface);
    final decimal = decimalStyle ??
        AppTypography.bodySm.copyWith(color: palette.outline);
    final sign = currencyStyle ??
        AppTypography.headlineMd.copyWith(color: palette.onSurface);

    return Text.rich(
      TextSpan(
        children: [
          if (cents < 0) TextSpan(text: '-', style: sign),
          TextSpan(text: '¥', style: currency),
          TextSpan(text: parts.integer, style: integer),
          TextSpan(text: parts.decimal, style: decimal),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
