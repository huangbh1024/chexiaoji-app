import 'package:material_ui/material_ui.dart';

import '../../ledger/domain/ledger_models.dart';

/// 单笔开销的状态。
enum ExpenseStatus { completed, refunded }

/// 支付渠道。颜色映射放在 presenter，避免模型依赖 UI。
enum PaymentChannel { wechat, alipay, unionpay, etc, cash, card, other }

/// 详情页关闭时回传给账单页的结果。
enum ExpenseDetailOutcome { updated, deleted }

@immutable
class ExpensePayment {
  const ExpensePayment({required this.channel, required this.label});

  final PaymentChannel channel;

  /// 后端展示名，如「微信支付」。P0 不展示尾号 / 卡号。
  final String label;
}

@immutable
class ExpenseDetail {
  const ExpenseDetail({
    required this.record,
    required this.status,
    this.payment,
    this.tags = const <String>[],
    this.note,
    this.vehicleBound = true,
    this.updatedAt,
  });

  /// 列表同源记录：金额、分类、时间、车辆快照、里程。
  final LedgerRecord record;
  final ExpenseStatus status;
  final ExpensePayment? payment;
  final List<String> tags;
  final String? note;
  final bool vehicleBound;
  final DateTime? updatedAt;

  ExpenseDetail copyWith({
    ExpenseStatus? status,
    ExpensePayment? payment,
    List<String>? tags,
    String? note,
    bool clearNote = false,
    bool? vehicleBound,
    DateTime? updatedAt,
  }) {
    return ExpenseDetail(
      record: record,
      status: status ?? this.status,
      payment: payment ?? this.payment,
      tags: tags ?? this.tags,
      note: clearNote ? null : (note ?? this.note),
      vehicleBound: vehicleBound ?? this.vehicleBound,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 无详情时的轻量快照，供首帧与骨架使用。
  factory ExpenseDetail.fromRecord(LedgerRecord record) {
    return ExpenseDetail(
      record: record,
      status: record.amountCents < 0
          ? ExpenseStatus.refunded
          : ExpenseStatus.completed,
      note: record.note,
    );
  }
}

/// 标签与备注的输入规则。
abstract final class ExpenseDetailRules {
  static const maxTags = 8;
  static const maxTagLength = 10;
  static const maxNoteLength = 200;
}

/// trim、去 `#`、去空、去重、限长、限数量。保留输入顺序。
List<String> sanitizeTags(Iterable<String> input) {
  final result = <String>[];
  for (final raw in input) {
    var value = raw.trim();
    while (value.startsWith('#')) {
      value = value.substring(1).trimLeft();
    }
    if (value.isEmpty) {
      continue;
    }
    value = _takeRunes(value, ExpenseDetailRules.maxTagLength);
    if (result.contains(value)) {
      continue;
    }
    result.add(value);
    if (result.length >= ExpenseDetailRules.maxTags) {
      break;
    }
  }
  return List<String>.unmodifiable(result);
}

/// trim；空串转 null；超长截断到 200 字。
String? normalizeNote(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    return null;
  }
  return _takeRunes(value, ExpenseDetailRules.maxNoteLength);
}

String _takeRunes(String value, int max) {
  final runes = value.runes.toList(growable: false);
  if (runes.length <= max) {
    return value;
  }
  return String.fromCharCodes(runes.take(max));
}
