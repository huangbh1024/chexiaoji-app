import 'package:intl/intl.dart';

final NumberFormat _thousands = NumberFormat('#,##0');
final NumberFormat _twoDecimals = NumberFormat('#,##0.00');

/// 聚合金额：千分位、四舍五入取整，例如 `¥1,286`。
String formatYuanCompact(int cents) => '¥${_thousands.format(cents / 100)}';

/// 明细金额：千分位、保留两位，例如 `¥51.10`。
String formatYuanDetail(int cents) => '¥${_twoDecimals.format(cents / 100)}';

/// 支出金额：带负号，例如 `-¥51.10`。
String formatExpense(int cents) => '-${formatYuanDetail(cents)}';

/// 里程：千分位整数，例如 `18,426 km`。
String formatKm(int km) => '${_thousands.format(km)} km';

/// 里程数值：千分位、无单位，例如 `18,426`。
String formatKmValue(int km) => _thousands.format(km);

/// 一位小数，例如 `14.8`。
String formatOneDecimal(double value) => value.toStringAsFixed(1);

/// 两位小数，例如 `0.60`。
String formatTwoDecimals(double value) => value.toStringAsFixed(2);

/// 带符号的百分比，例如 `-8.2%`、`+4.2%`。
String formatSignedPercent(double value) {
  final sign = value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(1)}%';
}

/// 整数百分比，例如 `30%`。
String formatPercentInt(int value) => '$value%';
