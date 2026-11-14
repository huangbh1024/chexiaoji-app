import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';

import '../../../core/domain/enums.dart';
import 'expense_entry_detail.dart';

enum ExpenseEntryMode { create, edit }

/// 打开记账页时的入口参数。family 需要值相等。
@immutable
class ExpenseEntryArgs {
  const ExpenseEntryArgs.create({
    this.initialVehicleId,
    this.initialCategory,
    this.initialOccurredAt,
    this.initialPlace,
  }) : mode = ExpenseEntryMode.create,
       recordId = null;

  const ExpenseEntryArgs.edit({required String this.recordId})
    : mode = ExpenseEntryMode.edit,
      initialVehicleId = null,
      initialCategory = null,
      initialOccurredAt = null,
      initialPlace = null;

  final ExpenseEntryMode mode;
  final String? recordId;
  final String? initialVehicleId;
  final ExpenseCategory? initialCategory;
  final DateTime? initialOccurredAt;
  final String? initialPlace;

  @override
  bool operator ==(Object other) =>
      other is ExpenseEntryArgs &&
      other.mode == mode &&
      other.recordId == recordId &&
      other.initialVehicleId == initialVehicleId &&
      other.initialCategory == initialCategory &&
      other.initialOccurredAt == initialOccurredAt &&
      other.initialPlace == initialPlace;

  @override
  int get hashCode => Object.hash(
    mode,
    recordId,
    initialVehicleId,
    initialCategory,
    initialOccurredAt,
    initialPlace,
  );
}

@immutable
class ReceiptAttachment {
  const ReceiptAttachment({
    required this.localPath,
    this.remoteId,
    this.isDeleted = false,
  });

  final String localPath;
  final String? remoteId;
  final bool isDeleted;

  ReceiptAttachment copyWith({
    String? localPath,
    String? remoteId,
    bool? isDeleted,
  }) {
    return ReceiptAttachment(
      localPath: localPath ?? this.localPath,
      remoteId: remoteId ?? this.remoteId,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReceiptAttachment &&
      other.localPath == localPath &&
      other.remoteId == remoteId &&
      other.isDeleted == isDeleted;

  @override
  int get hashCode => Object.hash(localPath, remoteId, isDeleted);
}

@immutable
class ExpenseEntryDraft {
  const ExpenseEntryDraft({
    required this.vehicleId,
    required this.category,
    required this.amountCents,
    required this.occurredAt,
    required this.paymentChannel,
    required this.paymentLabel,
    this.place,
    this.odometerKm,
    this.lastOdometerKm,
    this.note,
    this.receipts = const <ReceiptAttachment>[],
    this.detail = const EmptyEntryDetail(),
  });

  /// 占位草稿；默认值返回后由 controller 覆盖。
  factory ExpenseEntryDraft.empty(ExpenseEntryArgs args) {
    final time = args.initialOccurredAt ?? DateTime.now();
    return ExpenseEntryDraft(
      vehicleId: args.initialVehicleId,
      category: args.initialCategory ?? ExpenseCategory.charging,
      amountCents: 0,
      occurredAt: DateTime(
        time.year,
        time.month,
        time.day,
        time.hour,
        time.minute,
      ),
      paymentChannel: PaymentChannel.wechat,
      paymentLabel: '微信支付',
      place: args.initialPlace,
      detail: defaultDetailFor(
        args.initialCategory ?? ExpenseCategory.charging,
        place: args.initialPlace,
      ),
    );
  }

  final String? vehicleId;
  final ExpenseCategory category;

  /// 0 表示空输入；录入页只记支出正数。
  final int amountCents;
  final DateTime occurredAt;
  final PaymentChannel paymentChannel;
  final String paymentLabel;
  final String? place;

  /// 本次仪表里程；null = 用户清空。
  final int? odometerKm;

  /// 发生时间之前最近一条读数；null = 首次记录。
  final int? lastOdometerKm;
  final String? note;
  final List<ReceiptAttachment> receipts;
  final EntryCategoryDetail detail;

  int? get distanceKm {
    final current = odometerKm;
    final last = lastOdometerKm;
    if (current == null || last == null) {
      return null;
    }
    return current - last;
  }

  ExpenseEntryDraft copyWith({
    String? vehicleId,
    ExpenseCategory? category,
    int? amountCents,
    DateTime? occurredAt,
    PaymentChannel? paymentChannel,
    String? paymentLabel,
    String? place,
    bool clearPlace = false,
    int? odometerKm,
    bool clearOdometer = false,
    int? lastOdometerKm,
    bool clearLastOdometer = false,
    String? note,
    bool clearNote = false,
    List<ReceiptAttachment>? receipts,
    EntryCategoryDetail? detail,
  }) {
    return ExpenseEntryDraft(
      vehicleId: vehicleId ?? this.vehicleId,
      category: category ?? this.category,
      amountCents: amountCents ?? this.amountCents,
      occurredAt: occurredAt ?? this.occurredAt,
      paymentChannel: paymentChannel ?? this.paymentChannel,
      paymentLabel: paymentLabel ?? this.paymentLabel,
      place: clearPlace ? null : (place ?? this.place),
      odometerKm: clearOdometer ? null : (odometerKm ?? this.odometerKm),
      lastOdometerKm: clearLastOdometer
          ? null
          : (lastOdometerKm ?? this.lastOdometerKm),
      note: clearNote ? null : (note ?? this.note),
      receipts: receipts ?? this.receipts,
      detail: detail ?? this.detail,
    );
  }

  Map<String, Object?> toJson() => {
    'vehicleId': vehicleId,
    'category': category.name,
    'amountCents': amountCents,
    'occurredAt': occurredAt.toIso8601String(),
    'place': place,
    'payment': {'channel': paymentChannel.name, 'label': paymentLabel},
    'odometerKm': odometerKm,
    'lastOdometerKm': lastOdometerKm,
    'note': note,
    'receiptIds': [
      for (final receipt in receipts)
        if (!receipt.isDeleted && receipt.remoteId != null) receipt.remoteId,
    ],
    'detail': detail.toJson(),
  };

  @override
  bool operator ==(Object other) {
    if (other is! ExpenseEntryDraft) {
      return false;
    }
    if (other.vehicleId != vehicleId ||
        other.category != category ||
        other.amountCents != amountCents ||
        !other.occurredAt.isAtSameMomentAs(occurredAt) ||
        other.paymentChannel != paymentChannel ||
        other.paymentLabel != paymentLabel ||
        other.place != place ||
        other.odometerKm != odometerKm ||
        other.lastOdometerKm != lastOdometerKm ||
        other.note != note ||
        other.detail != detail ||
        other.receipts.length != receipts.length) {
      return false;
    }
    for (var i = 0; i < receipts.length; i++) {
      if (other.receipts[i] != receipts[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    vehicleId,
    category,
    amountCents,
    occurredAt.millisecondsSinceEpoch,
    paymentChannel,
    paymentLabel,
    place,
    odometerKm,
    lastOdometerKm,
    note,
    detail,
    Object.hashAll(receipts),
  );
}

@immutable
class ExpenseEntryDefaults {
  const ExpenseEntryDefaults({
    this.defaultCategory,
    this.paymentChannel = PaymentChannel.wechat,
    this.paymentLabel = '微信支付',
    this.lastPlace,
    this.recentPlaces = const <String>[],
    this.unitPrices = const EntryUnitPrices(),
    this.fuelGrade = 95,
    this.batteryCapacityKwh,
    this.tankCapacityL,
    this.lastSoc,
    this.lastOdometerKm,
    this.lastCategory,
  });

  final ExpenseCategory? defaultCategory;
  final PaymentChannel paymentChannel;
  final String paymentLabel;
  final String? lastPlace;
  final List<String> recentPlaces;
  final EntryUnitPrices unitPrices;
  final int fuelGrade;
  final double? batteryCapacityKwh;
  final double? tankCapacityL;
  final int? lastSoc;
  final int? lastOdometerKm;
  final ExpenseCategory? lastCategory;

  @override
  bool operator ==(Object other) =>
      other is ExpenseEntryDefaults &&
      other.defaultCategory == defaultCategory &&
      other.paymentChannel == paymentChannel &&
      other.paymentLabel == paymentLabel &&
      other.lastPlace == lastPlace &&
      listEquals(other.recentPlaces, recentPlaces) &&
      other.unitPrices == unitPrices &&
      other.fuelGrade == fuelGrade &&
      other.batteryCapacityKwh == batteryCapacityKwh &&
      other.tankCapacityL == tankCapacityL &&
      other.lastSoc == lastSoc &&
      other.lastOdometerKm == lastOdometerKm &&
      other.lastCategory == lastCategory;

  @override
  int get hashCode => Object.hash(
    defaultCategory,
    paymentChannel,
    paymentLabel,
    lastPlace,
    Object.hashAll(recentPlaces),
    unitPrices,
    fuelGrade,
    batteryCapacityKwh,
    tankCapacityL,
    lastSoc,
    lastOdometerKm,
    lastCategory,
  );
}

@immutable
class OdometerBaseline {
  const OdometerBaseline({
    this.lastReadingKm,
    this.recordedAt,
    this.recordId,
    this.currentOdometerKm,
  });

  final int? lastReadingKm;
  final DateTime? recordedAt;
  final String? recordId;
  final int? currentOdometerKm;

  bool get isFirstRecord => lastReadingKm == null;
}

enum EntryPresetKind { amount, full }

@immutable
class EntryPreset {
  const EntryPreset.amount(this.amountCents)
    : label = '',
      kind = EntryPresetKind.amount;

  const EntryPreset.full(this.label)
    : amountCents = 0,
      kind = EntryPresetKind.full;

  final int amountCents;
  final String label;
  final EntryPresetKind kind;

  String get displayLabel =>
      kind == EntryPresetKind.amount ? '¥${amountCents ~/ 100}' : label;
}

sealed class ExpenseEntryResult {
  const ExpenseEntryResult();
}

class ExpenseEntrySaved extends ExpenseEntryResult {
  const ExpenseEntrySaved({required this.recordId, required this.isNew});

  final String recordId;
  final bool isNew;
}

class ExpenseEntryCancelled extends ExpenseEntryResult {
  const ExpenseEntryCancelled();
}
