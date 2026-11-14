import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/domain/enums.dart';
import '../../../core/format/formatters.dart';
import '../../../core/presentation/category_style.dart';
import 'expense_detail_models.dart';

extension ExpenseDetailPresentation on ExpenseDetail {
  String get heroAmountText => formatSignedYuan(record.amountCents);

  String get settledAmountText => record.amountCents < 0
      ? '+${formatYuanDetail(record.amountCents.abs())}'
      : formatYuanDetail(record.amountCents);

  String get settledLabel =>
      status == ExpenseStatus.refunded ? '退款金额' : '实付金额';

  String get statusLabel =>
      status == ExpenseStatus.refunded ? '已退款' : '已完成';

  String get timeText => formatDateTimeMinute(record.occurredAt);

  String get titleText =>
      record.title.trim().isEmpty ? record.category.label : record.title;

  String get categoryLabel => record.category.label;

  String get categoryCaption => record.category.captionLabel;

  String get odometerText {
    final km = record.metrics.odometerKm;
    return km == null ? '里程未记录' : '记录里程 ${formatKm(km)}';
  }

  String? get paymentLabel => payment?.label;

  String get vehicleName => record.vehicleName ?? record.vehicleShortName;

  String? get plate => record.metrics.plate;

  String get noteText => (note ?? '').trim();

  bool get hasNote => noteText.isNotEmpty;

  String get shareText => buildExpenseShareText(this);
}

extension ExpenseStatusVisual on ExpenseStatus {
  IconData get icon => switch (this) {
    ExpenseStatus.completed => Icons.check_circle_rounded,
    ExpenseStatus.refunded => Icons.undo_rounded,
  };

  Color color(AppPalette palette) => switch (this) {
    ExpenseStatus.completed => palette.primary,
    ExpenseStatus.refunded => palette.pink,
  };
}

extension PaymentChannelVisual on PaymentChannel {
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

/// 分享 / 复制文本：不包含车牌、支付账号等敏感信息。
String buildExpenseShareText(ExpenseDetail detail) {
  final buffer = StringBuffer()
    ..writeln('车小记 · 开销详情')
    ..writeln('${detail.categoryLabel} · ${detail.titleText}')
    ..writeln(detail.heroAmountText)
    ..writeln('${detail.timeText} · ${detail.statusLabel}')
    ..write('车辆：${detail.vehicleName}（车牌已隐藏）');
  if (detail.hasNote) {
    final note = detail.noteText;
    buffer
      ..writeln()
      ..write('备注：${note.length > 80 ? '${note.substring(0, 80)}……' : note}');
  }
  return buffer.toString();
}
