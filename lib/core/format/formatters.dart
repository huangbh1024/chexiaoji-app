import 'package:intl/intl.dart';

final NumberFormat _thousands = NumberFormat('#,##0');
final NumberFormat _twoDecimals = NumberFormat('#,##0.00');
final NumberFormat _oneDecimal = NumberFormat('#,##0.0');

/// 聚合金额：千分位、四舍五入取整，例如 `¥1,286`。
String formatYuanCompact(int cents) => '¥${_thousands.format(cents / 100)}';

/// 明细金额：千分位、保留两位，例如 `¥51.10`。
String formatYuanDetail(int cents) => '¥${_twoDecimals.format(cents / 100)}';

/// 概览金额：千分位、保留一位，例如 `¥312.4`、`¥1,148.2`。
String formatYuanOneDecimal(int cents) => '¥${_oneDecimal.format(cents / 100)}';

/// 千分位计数，例如 `1,248`。
String formatCount(int value) => _thousands.format(value);

/// 能耗量：kWh 保留一位、L 保留两位，并去掉无意义的尾零。
String formatEnergyQuantity(double value, {required String unit}) {
  final text = unit == 'L'
      ? value.toStringAsFixed(2)
      : value.toStringAsFixed(1);
  return '${_trimTrailingZeros(text)} $unit';
}

String _trimTrailingZeros(String text) {
  if (!text.contains('.')) {
    return text;
  }
  return text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

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
String formatMonthLabel(DateTime month) => DateFormat('yyyy年M月').format(month);

/// 归档日期，例如 `2024年8月15日`。
String formatArchiveDate(DateTime date) => DateFormat('yyyy年M月d日').format(date);

/// 账单分组的日期标题：
/// `今天 · 6月28日` / `6月20日 · 周四` / 跨年 `2025年12月31日 · 周三`。
String formatDayTitle(DateTime day, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final diff = DateTime(
    n.year,
    n.month,
    n.day,
  ).difference(DateTime(day.year, day.month, day.day)).inDays;
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

/// 解析用户输入的元金额为整数分。
///
/// 仅接受 `123`、`123.4`、`123.45`；整数最多 6 位。空串或非法返回 null。
int? parseYuanToCents(String raw) {
  final text = raw.trim();
  if (text.isEmpty) {
    return null;
  }
  final match = RegExp(r'^(\d{0,6})(?:\.(\d{0,2}))?$').firstMatch(text);
  if (match == null) {
    return null;
  }
  final yuanText = match.group(1) ?? '';
  final fractionText = (match.group(2) ?? '').padRight(2, '0');
  final yuan = int.tryParse(yuanText.isEmpty ? '0' : yuanText) ?? 0;
  return yuan * 100 + int.parse(fractionText);
}

/// 金额输入框文本：不带千分位、固定两位小数，例如 `1234.56`。
String formatYuanInput(int cents) => (cents / 100).toStringAsFixed(2);

/// 带符号的里程增量，例如 `+51.0 km`、`-12.0 km`。
String formatOdometerDelta(int deltaKm) {
  final sign = deltaKm >= 0 ? '+' : '-';
  return '$sign${deltaKm.abs().toStringAsFixed(1)} km';
}

/// 发生时间的行内文案：
/// `今天 08:42` / `昨天 08:42` / `6月20日 08:42` / `2025年12月31日 08:42`。
String formatOccurredAtLabel(DateTime time, {DateTime? now}) {
  final n = (now ?? DateTime.now()).toLocal();
  final t = time.toLocal();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  final hm = '${_two(t.hour)}:${_two(t.minute)}';
  if (diff == 0) {
    return '今天 $hm';
  }
  if (diff == 1) {
    return '昨天 $hm';
  }
  if (t.year == n.year) {
    return '${t.month}月${t.day}日 $hm';
  }
  return '${t.year}年${t.month}月${t.day}日 $hm';
}

/// 电量百分比，例如 `22%`。
String formatSoc(int value) => '$value%';

String _two(int value) => value.toString().padLeft(2, '0');
