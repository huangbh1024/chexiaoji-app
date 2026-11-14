import 'package:chexiaoji_app/core/domain/enums.dart';
import 'package:chexiaoji_app/core/domain/vehicle.dart';
import 'package:chexiaoji_app/features/ledger/domain/ledger_models.dart';
import 'package:chexiaoji_app/features/report/domain/report_aggregation.dart';
import 'package:chexiaoji_app/features/report/domain/report_models.dart';
import 'package:flutter_test/flutter_test.dart';

LedgerRecord _record({
  required String id,
  required ExpenseCategory category,
  required DateTime occurredAt,
  int amountCents = 1000,
  String vehicleId = 'byd-han-ev',
  String vehicleName = '比亚迪 汉 EV',
  int? odometerKm,
  int? distanceKm,
  double? kwh,
  double? liters,
}) {
  return LedgerRecord(
    id: id,
    vehicleId: vehicleId,
    vehicleShortName: vehicleName,
    vehicleName: vehicleName,
    powertrain: PowertrainType.ev,
    category: category,
    title: '记录 $id',
    amountCents: amountCents,
    occurredAt: occurredAt,
    metrics: LedgerMetrics(
      odometerKm: odometerKm,
      distanceKm: distanceKm,
      kwh: kwh,
      liters: liters,
    ),
  );
}

const _vehicles = <Vehicle>[
  Vehicle(
    id: 'byd-han-ev',
    name: '比亚迪 汉 EV',
    plate: '粤B·D82K6',
    powertrain: PowertrainType.ev,
    powertrainLabel: '纯电驱动',
    odometerKm: 18426,
  ),
  Vehicle(
    id: 'toyota-camry-hev',
    name: '丰田 凯美瑞 双擎',
    plate: '粤B·7Q315',
    powertrain: PowertrainType.hev,
    powertrainLabel: '油电混动',
    odometerKm: 46210,
  ),
];

void main() {
  final now = DateTime(2026, 11, 14, 10);

  group('buildMonthlyReport', () {
    test('当前月为记录中，日点只到今天，金额与笔数正确', () {
      final report = buildMonthlyReport(
        scope: ReportScope(month: DateTime(2026, 11)),
        records: [
          _record(
            id: 'a',
            category: ExpenseCategory.charging,
            occurredAt: DateTime(2026, 11, 14, 8, 42),
            amountCents: 5110,
            odometerKm: 17000,
            kwh: 38.5,
          ),
          _record(
            id: 'b',
            category: ExpenseCategory.parking,
            occurredAt: DateTime(2026, 11, 13, 16, 45),
            amountCents: 2400,
            odometerKm: 17400,
          ),
        ],
        vehicles: _vehicles,
        now: now,
        previousTotalCents: 7000,
      );

      expect(report.status, ReportStatus.recording);
      expect(report.settledAt, isNull);
      expect(report.totalCents, 7510);
      expect(report.recordCount, 2);
      expect(report.days, 30);
      expect(report.daily, hasLength(14));
      expect(report.distanceKm, 400);
      expect(report.distanceSource, ReportDistanceSource.odometer);
      expect(report.costPerKmCents, 19);
      expect(report.momPercent, closeTo(7.2857, 0.001));
      expect(report.momTrend, TrendDirection.up);
    });

    test('历史月为已出账，日点覆盖整月并带结算时间', () {
      final report = buildMonthlyReport(
        scope: ReportScope(month: DateTime(2026, 9)),
        records: const [],
        vehicles: _vehicles,
        now: now,
      );

      expect(report.status, ReportStatus.issued);
      expect(report.settledAt, DateTime(2026, 9, 30, 23, 59, 59));
      expect(report.days, 30);
      expect(report.daily, hasLength(30));
      expect(report.totalCents, 0);
      expect(report.recordCount, 0);
      expect(report.costPerKmCents, isNull);
      expect(report.kwhPer100km, isNull);
      expect(report.momPercent, isNull);
      expect(report.momTrend, TrendDirection.none);
      expect(report.isEmpty, isTrue);
    });

    test('全部车辆时按车分组计算里程，不串车', () {
      final report = buildMonthlyReport(
        scope: ReportScope(month: DateTime(2026, 11)),
        records: [
          _record(
            id: 'a1',
            category: ExpenseCategory.charging,
            occurredAt: DateTime(2026, 11, 2),
            odometerKm: 1000,
          ),
          _record(
            id: 'a2',
            category: ExpenseCategory.charging,
            occurredAt: DateTime(2026, 11, 10),
            odometerKm: 2000,
          ),
          _record(
            id: 'b1',
            category: ExpenseCategory.fuel,
            occurredAt: DateTime(2026, 11, 3),
            odometerKm: 5000,
            vehicleId: 'toyota-camry-hev',
            vehicleName: '丰田 凯美瑞 双擎',
          ),
          _record(
            id: 'b2',
            category: ExpenseCategory.fuel,
            occurredAt: DateTime(2026, 11, 12),
            odometerKm: 5500,
            vehicleId: 'toyota-camry-hev',
            vehicleName: '丰田 凯美瑞 双擎',
          ),
        ],
        vehicles: _vehicles,
        now: now,
      );

      expect(report.distanceKm, 1500);
      expect(report.vehicles, hasLength(2));
      expect(report.vehicles.first.recordCount, 2);
      expect(report.vehicles.last.recordCount, 2);
    });

    test('里程读数不足时使用单笔距离兜底', () {
      final report = buildMonthlyReport(
        scope: ReportScope(month: DateTime(2026, 11)),
        records: [
          _record(
            id: 'a',
            category: ExpenseCategory.charging,
            occurredAt: DateTime(2026, 11, 4),
            amountCents: 3000,
            odometerKm: 1000,
            distanceKm: 300,
            kwh: 20,
          ),
        ],
        vehicles: _vehicles,
        now: now,
      );

      expect(report.distanceKm, 300);
      expect(report.distanceSource, ReportDistanceSource.records);
      expect(report.costPerKmCents, 10);
      expect(report.kwhPer100km, closeTo(6.67, 0.01));
    });

    test('无里程数据时每公里与百公里能耗为空', () {
      final report = buildMonthlyReport(
        scope: ReportScope(month: DateTime(2026, 11)),
        records: [
          _record(
            id: 'a',
            category: ExpenseCategory.maintenance,
            occurredAt: DateTime(2026, 11, 4),
            amountCents: 48000,
          ),
        ],
        vehicles: _vehicles,
        now: now,
      );

      expect(report.distanceKm, 0);
      expect(report.distanceSource, ReportDistanceSource.none);
      expect(report.costPerKmCents, isNull);
      expect(report.kwhPer100km, isNull);
      expect(report.litersPer100km, isNull);
    });

    test('充电量、加油量与百公里能耗分别计算', () {
      final report = buildMonthlyReport(
        scope: ReportScope(month: DateTime(2026, 11)),
        records: [
          _record(
            id: 'a1',
            category: ExpenseCategory.charging,
            occurredAt: DateTime(2026, 11, 2),
            kwh: 20,
            odometerKm: 1000,
          ),
          _record(
            id: 'a2',
            category: ExpenseCategory.charging,
            occurredAt: DateTime(2026, 11, 8),
            kwh: 10,
            odometerKm: 1200,
          ),
          _record(
            id: 'b1',
            category: ExpenseCategory.fuel,
            occurredAt: DateTime(2026, 11, 3),
            liters: 5,
            vehicleId: 'toyota-camry-hev',
            vehicleName: '丰田 凯美瑞 双擎',
            odometerKm: 5000,
          ),
          _record(
            id: 'b2',
            category: ExpenseCategory.fuel,
            occurredAt: DateTime(2026, 11, 9),
            liters: 5,
            vehicleId: 'toyota-camry-hev',
            vehicleName: '丰田 凯美瑞 双擎',
            odometerKm: 5200,
          ),
        ],
        vehicles: _vehicles,
        now: now,
      );

      expect(report.energyKwh, 30);
      expect(report.fuelLiters, 10);
      expect(report.distanceKm, 400);
      expect(report.kwhPer100km, 7.5);
      expect(report.litersPer100km, 2.5);
    });
  });

  group('分类分组', () {
    test('洗车与其他合并，6 组顺序固定，百分比合计 100', () {
      final report = buildMonthlyReport(
        scope: ReportScope(month: DateTime(2026, 11)),
        records: [
          _record(
            id: 'a',
            category: ExpenseCategory.charging,
            occurredAt: DateTime(2026, 11, 1),
            amountCents: 1000,
          ),
          _record(
            id: 'b',
            category: ExpenseCategory.fuel,
            occurredAt: DateTime(2026, 11, 2),
            amountCents: 2000,
          ),
          _record(
            id: 'c',
            category: ExpenseCategory.carWash,
            occurredAt: DateTime(2026, 11, 3),
            amountCents: 500,
          ),
          _record(
            id: 'd',
            category: ExpenseCategory.other,
            occurredAt: DateTime(2026, 11, 4),
            amountCents: 1500,
          ),
        ],
        vehicles: _vehicles,
        now: now,
      );

      expect(report.categories.map((group) => group.key), [
        ReportCategoryKey.charging,
        ReportCategoryKey.fuel,
        ReportCategoryKey.maintenance,
        ReportCategoryKey.parking,
        ReportCategoryKey.toll,
        ReportCategoryKey.carWashOther,
      ]);
      expect(report.categories[5].amountCents, 2000);
      expect(report.categories[5].count, 2);
      expect(
        report.categories.fold(0, (sum, group) => sum + (group.percent ?? 0)),
        100,
      );
    });

    test('负金额分组时全部百分比为空', () {
      final report = buildMonthlyReport(
        scope: ReportScope(month: DateTime(2026, 11)),
        records: [
          _record(
            id: 'a',
            category: ExpenseCategory.charging,
            occurredAt: DateTime(2026, 11, 1),
            amountCents: -500,
          ),
          _record(
            id: 'b',
            category: ExpenseCategory.parking,
            occurredAt: DateTime(2026, 11, 2),
            amountCents: 2000,
          ),
        ],
        vehicles: _vehicles,
        now: now,
      );

      expect(report.totalCents, 1500);
      expect(report.categories.every((group) => group.percent == null), isTrue);
    });

    test('最大余数法保证整数之和为 100', () {
      expect(largestRemainderPercents([1, 1, 1]), [34, 33, 33]);
      expect(largestRemainderPercents([50, 50]), [50, 50]);
      expect(largestRemainderPercents([0, 0]), [0, 0]);
      expect(largestRemainderPercents([]), <int>[]);
    });
  });

  group('逐日开支', () {
    test('充电与其他两条序列、主导分类与笔数正确', () {
      final points = buildDailyPoints(
        [
          _record(
            id: 'a',
            category: ExpenseCategory.charging,
            occurredAt: DateTime(2026, 11, 3, 8),
            amountCents: 3000,
          ),
          _record(
            id: 'b',
            category: ExpenseCategory.maintenance,
            occurredAt: DateTime(2026, 11, 3, 14),
            amountCents: 48000,
          ),
          _record(
            id: 'c',
            category: ExpenseCategory.parking,
            occurredAt: DateTime(2026, 11, 4, 16),
            amountCents: 2400,
          ),
        ],
        DateTime(2026, 11),
        5,
      );

      expect(points, hasLength(5));
      expect(points[2].chargingCents, 3000);
      expect(points[2].otherCents, 48000);
      expect(points[2].totalCents, 51000);
      expect(points[2].recordCount, 2);
      expect(points[2].dominantCategory, ExpenseCategory.maintenance);
      expect(points[3].otherCents, 2400);
      expect(points[0].totalCents, 0);
      expect(points[0].dominantCategory, isNull);
    });
  });

  group('单号与脱敏', () {
    test('同一范围单号稳定，不同范围不同，格式正确', () {
      final scope = ReportScope(month: _FixedMonth.november);

      final first = reportNoFor(scope);
      final second = reportNoFor(scope);
      final otherVehicle = reportNoFor(
        ReportScope(month: _FixedMonth.november, vehicleId: 'byd-han-ev'),
      );

      expect(first, second);
      expect(first, isNot(otherVehicle));
      expect(first, matches(RegExp(r'^RP-202611-\d{4}$')));
    });

    test('车牌脱敏保留省市与首位', () {
      expect(maskPlate('粤B·D82K6'), '粤B·D****');
      expect(maskPlate('粤B·88K32'), '粤B·8****');
      expect(maskPlate('ABC'), '***');
      expect(maskPlate('D12345'), 'D1****');
    });
  });
}

/// `const` 构造里不能调用 `DateTime`，用一个固定月份常量代替。
abstract final class _FixedMonth {
  static final november = DateTime(2026, 11);
}
