import 'package:intl/intl.dart';

final NumberFormat _thousands = NumberFormat('#,##0');
final NumberFormat _twoDecimals = NumberFormat('#,##0.00');

/// 聚合金额：千分位、四舍五入取整，例如 `¥1,286`。
String formatYuanCompact(int cents) => '¥${_thousands.format(cents / 100)}';

/// 明细金额：千分位、保留两位，例如 `¥51.10`。
String formatYuanDetail(int cents) => '¥${_twoDecimals.format(cents / 100)}';

/// 支出金额：带负号，例如 `-¥51.10`。
String formatExpense(int cents) => '-${formatYuanDetail(cents)}';

/// 带符号金额：支出 `-¥51.10`，退款 `+¥51.10`，零金额 `¥0.00`。
String formatSignedYuan(int cents) {
  if (cents == 0) {
    return formatYuanDetail(0);
  }
  return cents < 0
      ? '+${formatYuanDetail(cents.abs())}'
      : '-${formatYuanDetail(cents)}';
}

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

const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/// 把金额拆成「整数部分」与「小数部分」，用于汇总卡的大字 + 小字排版。
/// 返回的整数部分已带千分位且不含符号，小数部分带小数点（如 `.50`）。
({String integer, String decimal}) splitYuanParts(int cents) {
  final text = _twoDecimals.format(cents.abs() / 100);
  final index = text.lastIndexOf('.');
  return (integer: text.substring(0, index), decimal: text.substring(index));
}

/// 交易时间到分钟，例如 `2025-05-16 13:28`。
String formatDateTimeMinute(DateTime time) {
  final t = time.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} '
      '${two(t.hour)}:${two(t.minute)}';
}

/// 月份标签，例如 `2026年11月`。
String formatMonthLabel(DateTime month) =>
    DateFormat('yyyy年M月').format(month);

/// 账单分组的日期标题：
/// `今天 · 6月28日` / `6月20日 · 周四` / 跨年 `2025年12月31日 · 周三`。
String formatDayTitle(DateTime day, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final diff = DateTime(n.year, n.month, n.day)
      .difference(DateTime(day.year, day.month, day.day))
      .inDays;
  final base = day.year == n.year
      ? '${day.month}月${day.day}日'
      : '${day.year}年${day.month}月${day.day}日';
  return switch (diff) {
    0 => '今天 · $base',
    1 => '昨天 · $base',
    2 => '前天 · $base',
    _ => '$base · ${_weekdays[day.weekday - 1]}',
  };
}

/// 电量，例如 `38.5 kWh`。
String formatKwh(double value) => '${value.toStringAsFixed(1)} kWh';

/// 加油升数，例如 `24.51 L`。
String formatLiters(double value) => '${value.toStringAsFixed(2)} L';

/// 单价，例如 `¥1.33/kWh`、`¥8.16/L`。
String formatUnitPrice(int cents, String unit) =>
    '${formatYuanDetail(cents)}/$unit';

/// 停车时长：`45 分钟` / `3.5 小时` / `2 小时`。
String formatDuration(int minutes) {
  if (minutes < 60) {
    return '$minutes 分钟';
  }
  final hours = minutes / 60;
  final text = hours == hours.roundToDouble()
      ? hours.toStringAsFixed(0)
      : hours.toStringAsFixed(1);
  return '$text 小时';
}
