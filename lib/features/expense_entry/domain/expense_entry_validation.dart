import 'package:material_ui/material_ui.dart';

import 'expense_entry_detail.dart';
import 'expense_entry_math.dart';
import 'expense_entry_models.dart';

enum EntryField {
  amount,
  vehicle,
  occurredAt,
  odometer,
  chargingPrice,
  soc,
  fuelPrice,
  parkingRate,
  tollDistance,
  note,
  receipt,
  insurancePeriod,
}

@immutable
class EntryValidation {
  const EntryValidation({
    this.field,
    this.message,
    this.needsOdometerConfirm = false,
  });

  const EntryValidation.none()
    : field = null,
      message = null,
      needsOdometerConfirm = false;

  final EntryField? field;
  final String? message;

  /// 里程跨度较大，需要用户二次确认；不是错误。
  final bool needsOdometerConfirm;

  bool get isValid => message == null;
  bool isField(EntryField value) => field == value;
}

EntryValidation validateDraft(ExpenseEntryDraft draft, {DateTime? now}) {
  if (draft.vehicleId == null) {
    return const EntryValidation(field: EntryField.vehicle, message: '请选择车辆');
  }
  if (draft.amountCents <= 0) {
    return const EntryValidation(field: EntryField.amount, message: '请输入有效金额');
  }
  if (draft.amountCents > 99999999) {
    return const EntryValidation(
      field: EntryField.amount,
      message: '金额不能超过 999,999.99 元',
    );
  }
  final current = now ?? DateTime.now();
  if (draft.occurredAt.isAfter(current.add(const Duration(minutes: 1)))) {
    return const EntryValidation(
      field: EntryField.occurredAt,
      message: '发生时间不能晚于现在',
    );
  }
  if (draft.occurredAt.year < 2000) {
    return const EntryValidation(
      field: EntryField.occurredAt,
      message: '发生时间不能早于 2000 年',
    );
  }
  final odometer = draft.odometerKm;
  final last = draft.lastOdometerKm;
  if (odometer != null) {
    if (odometer < 0 || odometer > 9999999) {
      return const EntryValidation(
        field: EntryField.odometer,
        message: '请输入有效的仪表里程',
      );
    }
    if (last != null && odometer < last) {
      return EntryValidation(
        field: EntryField.odometer,
        message: '本次读数不能小于上次记录 ${_formatKm(last)} km',
      );
    }
  }

  switch (draft.detail) {
    case ChargingDetail d:
      if (d.unitPriceCentsPerKwh < 10 || d.unitPriceCentsPerKwh > 2000) {
        return const EntryValidation(
          field: EntryField.chargingPrice,
          message: '请输入 0.10–20.00 的单价',
        );
      }
      if (d.socStart < 0 || d.socStart > 100) {
        return const EntryValidation(
          field: EntryField.soc,
          message: '电量百分比需在 0–100 之间',
        );
      }
    case FuelDetail d:
      if (d.unitPriceCentsPerLiter < 300 || d.unitPriceCentsPerLiter > 1500) {
        return const EntryValidation(
          field: EntryField.fuelPrice,
          message: '请输入 3.00–15.00 的单价',
        );
      }
    case ParkingDetail d:
      if (d.rateCentsPerHour < 0 || d.rateCentsPerHour > 10000) {
        return const EntryValidation(
          field: EntryField.parkingRate,
          message: '请输入 0–100 的时租',
        );
      }
    case TollDetail d:
      final distance = d.distanceKm;
      if (distance != null && (distance < 0 || distance > 2000)) {
        return const EntryValidation(
          field: EntryField.tollDistance,
          message: '通行里程需在 0–2000 km 之间',
        );
      }
    case InsuranceDetail d:
      if (d.periodStart != null &&
          d.periodEnd != null &&
          d.periodEnd!.isBefore(d.periodStart!)) {
        return const EntryValidation(
          field: EntryField.insurancePeriod,
          message: '结束日期不能早于开始日期',
        );
      }
    case MaintenanceDetail _:
    case CarWashDetail _:
    case EmptyEntryDetail _:
      break;
  }

  final note = draft.note;
  if (note != null && note.length > 200) {
    return const EntryValidation(field: EntryField.note, message: '备注最多 200 字');
  }
  if (draft.receipts.where((item) => !item.isDeleted).length > 4) {
    return const EntryValidation(
      field: EntryField.receipt,
      message: '最多上传 4 张凭证',
    );
  }
  if (needsOdometerConfirmation(draft.distanceKm)) {
    return const EntryValidation(needsOdometerConfirm: true);
  }
  return const EntryValidation.none();
}

String _formatKm(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(text[i]);
  }
  return buffer.toString();
}
