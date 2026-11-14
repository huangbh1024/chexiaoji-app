import '../../../core/domain/enums.dart';
import '../../ledger/domain/ledger_models.dart';
import '../domain/report_aggregation.dart';
import '../domain/report_models.dart';

/// 生成报表明细 CSV（UTF-8 BOM + RFC 4180）。
///
/// 金额、电量、升数、里程、时长等数值列原样输出，避免负数被加上
/// 公式注入防护前缀后失去计算能力；只有文本列做转义与前缀防护。
String buildReportCsv({
  required MonthlyReport report,
  required List<LedgerRecord> records,
  required ReportOptions options,
}) {
  final buffer = StringBuffer('﻿');
  const header = [
    '日期',
    '时间',
    '分类',
    '车辆',
    '车牌',
    '标题',
    '金额(元)',
    '电量(kWh)',
    '加油量(L)',
    '里程(km)',
    '时长(分钟)',
    '支付方式',
    '备注',
  ];
  buffer
    ..write(header.join(','))
    ..write('\r\n');

  final vehiclePlates = {
    for (final vehicle in report.vehicles) vehicle.id: vehicle.plate,
  };
  final seen = <String>{};
  final sorted =
      records.where((record) => seen.add(record.id)).toList(growable: false)
        ..sort((a, b) {
          final byTime = a.occurredAt.compareTo(b.occurredAt);
          return byTime != 0 ? byTime : a.id.compareTo(b.id);
        });

  for (final record in sorted) {
    final plate = vehiclePlates[record.vehicleId] ?? record.metrics.plate ?? '';
    final row = <String>[
      _date(record.occurredAt),
      _time(record.occurredAt),
      record.category.filterLabel,
      record.vehicleName ?? record.vehicleShortName,
      options.maskPlate ? maskPlate(plate) : plate,
      record.title,
      _amount(record.amountCents),
      _double(record.metrics.kwh, 1),
      _double(record.metrics.liters, 2),
      _int(record.metrics.odometerKm),
      _int(record.metrics.durationMinutes),
      record.metrics.paymentMethod ?? '',
      record.note ?? '',
    ];
    buffer
      ..write(
        [
          for (var index = 0; index < row.length; index++)
            index == 6 || index == 7 || index == 8 || index == 9 || index == 10
                ? row[index]
                : _escapeText(row[index]),
        ].join(','),
      )
      ..write('\r\n');
  }
  return buffer.toString();
}

String _date(DateTime date) =>
    '${date.year}-${_two(date.month)}-${_two(date.day)}';

String _time(DateTime date) => '${_two(date.hour)}:${_two(date.minute)}';

String _two(int value) => value.toString().padLeft(2, '0');

String _amount(int cents) => (cents / 100).toStringAsFixed(2);

String _double(double? value, int digits) =>
    value == null ? '' : value.toStringAsFixed(digits);

String _int(int? value) => value?.toString() ?? '';

String _escapeText(String value) {
  var text = value;
  if (RegExp(r'^[=+\-@]').hasMatch(text)) {
    text = "'$text";
  }
  if (text.contains(RegExp(r'[",\r\n]'))) {
    text = '"${text.replaceAll('"', '""')}"';
  }
  return text;
}
