import 'package:chexiaoji_app/core/domain/enums.dart';
import 'package:chexiaoji_app/core/format/formatters.dart';
import 'package:chexiaoji_app/features/expense_entry/domain/expense_entry_detail.dart';
import 'package:chexiaoji_app/features/expense_entry/domain/expense_entry_math.dart';
import 'package:chexiaoji_app/features/expense_entry/domain/expense_entry_models.dart';
import 'package:chexiaoji_app/features/expense_entry/domain/expense_entry_validation.dart';
import 'package:flutter_test/flutter_test.dart';

ExpenseEntryDraft draft({
  ExpenseCategory category = ExpenseCategory.charging,
  int amountCents = 10000,
  int? odometerKm = 18426,
  int? lastOdometerKm = 18375,
  EntryCategoryDetail? detail,
  String? note,
}) {
  return ExpenseEntryDraft(
    vehicleId: 'byd-han-ev',
    category: category,
    amountCents: amountCents,
    occurredAt: DateTime(2026, 11, 15, 8, 42),
    paymentChannel: PaymentChannel.wechat,
    paymentLabel: '微信支付',
    odometerKm: odometerKm,
    lastOdometerKm: lastOdometerKm,
    note: note,
    detail: detail ?? const ChargingDetail(kwh: 83.33, socEnd: 100),
  );
}

void main() {
  group('金额解析与格式化', () {
    test('parseYuanToCents 接受整数与两位小数', () {
      expect(parseYuanToCents('100'), 10000);
      expect(parseYuanToCents('100.5'), 10050);
      expect(parseYuanToCents('100.05'), 10005);
      expect(parseYuanToCents('.5'), 50);
      expect(parseYuanToCents(''), isNull);
      expect(parseYuanToCents('1.234'), isNull);
      expect(parseYuanToCents('1234567'), isNull);
    });

    test('formatYuanInput 不带千分位且补齐两位', () {
      expect(formatYuanInput(10000), '100.00');
      expect(formatYuanInput(5), '0.05');
    });

    test('formatOdometerDelta 带符号与一位小数', () {
      expect(formatOdometerDelta(51), '+51.0 km');
      expect(formatOdometerDelta(0), '+0.0 km');
      expect(formatOdometerDelta(-12), '-12.0 km');
    });
  });

  group('推导公式', () {
    test('电量与升数', () {
      expect(kwhFromAmount(10000, 120), closeTo(83.333, 0.001));
      expect(litersFromAmount(10000, 785), closeTo(12.738, 0.001));
      expect(kwhFromAmount(0, 120), isNull);
      expect(kwhFromAmount(100, 0), isNull);
    });

    test('SOC 与充满金额', () {
      expect(
        socEndFromKwh(socStart: 20, kwh: 83.3, batteryCapacityKwh: 85.4),
        100,
      );
      expect(
        fullChargeCents(
          batteryCapacityKwh: 85.4,
          socStart: 20,
          unitPriceCentsPerKwh: 120,
        ),
        8198,
      );
      expect(
        fullChargeCents(
          batteryCapacityKwh: null,
          socStart: 20,
          unitPriceCentsPerKwh: 120,
        ),
        isNull,
      );
    });

    test('停车时长与每公里成本', () {
      expect(parkingMinutes(10000, 800), 750);
      expect(parkingMinutes(100, 0), isNull);
      expect(costPerKm(10000, 51), closeTo(1.96, 0.001));
      expect(costPerKm(10000, 0), isNull);
      expect(costPerKm(10000, null), isNull);
    });

    test('里程与加满', () {
      expect(mileageDelta(18426, 18375), 51);
      expect(mileageDelta(null, 18375), isNull);
      expect(
        fullTankCents(tankCapacityL: 50, unitPriceCentsPerLiter: 785),
        39250,
      );
      expect(needsOdometerConfirmation(5000), isFalse);
      expect(needsOdometerConfirmation(5001), isTrue);
    });
  });

  group('校验', () {
    test('金额、时间和里程', () {
      expect(validateDraft(draft(), now: DateTime(2027)).isValid, isTrue);
      expect(
        validateDraft(draft(amountCents: 0), now: DateTime(2027)).field,
        EntryField.amount,
      );
      expect(
        validateDraft(draft(), now: DateTime(2026, 11, 15, 8, 40)).field,
        EntryField.occurredAt,
      );
      expect(
        validateDraft(draft(odometerKm: 18000), now: DateTime(2027)).field,
        EntryField.odometer,
      );
    });

    test('分类参数与备注', () {
      expect(
        validateDraft(
          draft(detail: const ChargingDetail(unitPriceCentsPerKwh: 1)),
          now: DateTime(2027),
        ).field,
        EntryField.chargingPrice,
      );
      expect(
        validateDraft(draft(note: 'x' * 201), now: DateTime(2027)).field,
        EntryField.note,
      );
      final warning = validateDraft(
        draft(odometerKm: 25000, lastOdometerKm: 18375),
        now: DateTime(2027),
      );
      expect(warning.needsOdometerConfirm, isTrue);
      expect(warning.isValid, isTrue);
    });
  });

  group('默认参数与分类', () {
    test('defaultDetailFor 按分类构造', () {
      expect(defaultDetailFor(ExpenseCategory.charging), isA<ChargingDetail>());
      expect(defaultDetailFor(ExpenseCategory.fuel), isA<FuelDetail>());
      expect(defaultDetailFor(ExpenseCategory.parking), isA<ParkingDetail>());
      expect(defaultDetailFor(ExpenseCategory.toll), isA<TollDetail>());
      expect(
        defaultDetailFor(ExpenseCategory.maintenance),
        isA<MaintenanceDetail>(),
      );
      expect(defaultDetailFor(ExpenseCategory.carWash), isA<CarWashDetail>());
      expect(defaultDetailFor(ExpenseCategory.other), isA<InsuranceDetail>());
    });

    test('里程分类判定', () {
      expect(categoryUsesOdometer(ExpenseCategory.charging), isTrue);
      expect(categoryUsesOdometer(ExpenseCategory.parking), isFalse);
      expect(categoryUsesOdometer(ExpenseCategory.other), isFalse);
    });

    test('Draft 值相等用于脏检查', () {
      expect(draft(), draft());
      expect(draft(amountCents: 1), isNot(draft()));
      expect(
        draft(detail: const ChargingDetail(unitPriceCentsPerKwh: 130)),
        isNot(draft()),
      );
    });
  });
}
