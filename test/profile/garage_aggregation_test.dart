import 'package:chexiaoji_app/core/domain/enums.dart';
import 'package:chexiaoji_app/features/profile/domain/garage_aggregation.dart';
import 'package:chexiaoji_app/features/profile/domain/profile_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profile_test_helpers.dart';

void main() {
  group('computeAccountDays', () {
    test('首笔当天是第 1 天', () {
      expect(
        computeAccountDays(
          DateTime(2026, 11, 10, 23),
          DateTime(2026, 11, 10, 1),
        ),
        1,
      );
    });

    test('按自然日计算且包含首日', () {
      expect(
        computeAccountDays(DateTime(2026, 11, 10), DateTime(2026, 11, 14, 8)),
        5,
      );
    });

    test('跨闰年 2 月', () {
      expect(
        computeAccountDays(DateTime(2024, 2, 28), DateTime(2024, 3, 1)),
        3,
      );
    });

    test('无记录与未来记录归零', () {
      expect(computeAccountDays(null, DateTime(2026, 11, 14)), 0);
      expect(
        computeAccountDays(DateTime(2026, 12, 1), DateTime(2026, 11, 14)),
        0,
      );
    });
  });

  group('shortNameFor', () {
    test('去掉常见品牌前缀', () {
      expect(shortNameFor('比亚迪 汉 EV'), '汉 EV');
      expect(shortNameFor('丰田 凯美瑞 双擎'), '凯美瑞 双擎');
      expect(shortNameFor('宝马 3系 325Li'), '3系 325Li');
    });

    test('不误伤含空格的车型名', () {
      expect(shortNameFor('宋PLUS DM-i'), '宋PLUS DM-i');
    });

    test('未知品牌与空字符串保留原值', () {
      expect(shortNameFor('未知 车型'), '未知 车型');
      expect(shortNameFor(''), '');
    });
  });

  group('aggregateMonthEnergy', () {
    test('只统计本月充电与加油，退款计入金额', () {
      final records = [
        profileRecord(id: 'c1', amountCents: 1000, kwh: 10),
        profileRecord(
          id: 'f1',
          category: ExpenseCategory.fuel,
          powertrain: PowertrainType.ice,
          amountCents: 2000,
          liters: 5,
          occurredAt: DateTime(2026, 11, 3),
        ),
        profileRecord(
          id: 'p1',
          category: ExpenseCategory.parking,
          amountCents: 500,
          occurredAt: DateTime(2026, 11, 4),
        ),
        profileRecord(
          id: 'refund',
          amountCents: -500,
          kwh: 2,
          occurredAt: DateTime(2026, 11, 5),
        ),
        profileRecord(
          id: 'old',
          amountCents: 999,
          kwh: 9,
          occurredAt: DateTime(2026, 10, 31),
        ),
        profileRecord(
          id: 'future',
          amountCents: 999,
          kwh: 9,
          occurredAt: DateTime(2026, 11, 20),
        ),
      ];

      final energy = aggregateMonthEnergy(
        records,
        month: DateTime(2026, 11),
        now: DateTime(2026, 11, 14),
      );

      expect(energy.count, 3);
      expect(energy.amountCents, 2500);
      expect(energy.kwh, 12);
      expect(energy.liters, 5);
    });
  });

  group('buildGarageSnapshot', () {
    final now = DateTime(2026, 11, 14);

    test('单车快照展示能耗、里程与保养', () {
      final vehicle = garageVehicle();
      final snapshot = buildGarageSnapshot(
        vehicleId: vehicle.id,
        vehicles: [vehicle],
        monthRecords: [profileRecord(amountCents: 31240, kwh: 184)],
        maintenanceByVehicle: {vehicle.id: maintenance()},
        now: now,
      );

      expect(snapshot.badge, '纯电');
      expect(snapshot.plateText, '粤B·D82K6');
      expect(snapshot.title, '比亚迪 汉 EV');
      expect(snapshot.subtitle, '累计能耗 ¥0.18/km');
      expect(snapshot.odometerKm, 18426);
      expect(snapshot.monthEnergy.amountCents, 31240);
      expect(snapshot.monthEnergy.kwh, 184);
      expect(snapshot.maintenance.remainingKm, 1574);
      expect(snapshot.maintenance.status, MaintenanceStatus.normal);
      expect(snapshot.tip.text, contains('本月充电 1 次'));
    });

    test('全部资产汇总里程与金额，混合能源不合并数量', () {
      final ev = garageVehicle();
      final ice = garageVehicle(
        id: 'bmw-325li',
        name: '宝马 3系 325Li',
        shortName: '3系 325Li',
        plate: '粤B·88K32',
        powertrain: PowertrainType.ice,
        powertrainLabel: '纯燃油',
        odometerKm: 58940,
        energyCostPerKmCents: 75,
      );

      final snapshot = buildGarageSnapshot(
        vehicleId: null,
        vehicles: [ev, ice],
        monthRecords: [
          profileRecord(amountCents: 1000, kwh: 10),
          profileRecord(
            id: 'fuel',
            vehicleId: ice.id,
            category: ExpenseCategory.fuel,
            amountCents: 2000,
            liters: 5,
          ),
        ],
        maintenanceByVehicle: {
          ev.id: maintenance(remainingKm: 3000),
          ice.id: maintenance(remainingKm: 800, progressPercent: 85),
        },
        now: now,
      );

      expect(snapshot.title, '我的全部车辆');
      expect(snapshot.subtitle, '纯电 1 · 燃油 1');
      expect(snapshot.odometerKm, 77366);
      expect(snapshot.monthEnergy.amountCents, 3000);
      expect(snapshot.monthEnergy.count, 2);
      expect(snapshot.monthEnergy.kwh, isNull);
      expect(snapshot.monthEnergy.liters, isNull);
      expect(snapshot.maintenance.vehicleId, ice.id);
      expect(snapshot.maintenance.status, MaintenanceStatus.warning);
      expect(snapshot.tip.text, '本月共 2 笔能耗记录 · 合计 ¥30.0');
    });

    test('全部纯电车辆保留 kWh', () {
      final first = garageVehicle();
      final second = garageVehicle(
        id: 'tesla-model3',
        name: '特斯拉 Model 3',
        shortName: 'Model 3',
        odometerKm: 9000,
      );
      final snapshot = buildGarageSnapshot(
        vehicleId: null,
        vehicles: [first, second],
        monthRecords: [
          profileRecord(amountCents: 1000, kwh: 10),
          profileRecord(
            id: 'rec-2',
            vehicleId: second.id,
            amountCents: 500,
            kwh: 4,
          ),
        ],
        maintenanceByVehicle: const {},
        now: now,
      );

      expect(snapshot.monthEnergy.kwh, 14);
      expect(snapshot.monthEnergy.liters, isNull);
      expect(snapshot.maintenance.enabled, isFalse);
    });

    test('空车辆返回空态快照', () {
      final snapshot = buildGarageSnapshot(
        vehicleId: null,
        vehicles: const [],
        monthRecords: const [],
        maintenanceByVehicle: const {},
        now: now,
      );

      expect(snapshot.odometerKm, 0);
      expect(snapshot.maintenance.enabled, isFalse);
      expect(snapshot.tip.kind, GarageTipKind.empty);
      expect(snapshot.plateText, '0 辆在役');
    });
  });

  group('pickMostUrgent', () {
    final first = garageVehicle();
    final second = garageVehicle(id: 'second', name: '第二辆车', shortName: '第二辆');

    test('优先未超期车辆中剩余最少的', () {
      final result = pickMostUrgent(
        {
          first.id: maintenance(remainingKm: 3000),
          second.id: maintenance(remainingKm: 900),
        },
        [first, second],
      );
      expect(result.vehicleId, second.id);
      expect(result.remainingKm, 900);
    });

    test('全部超期时取超期最多的一辆', () {
      final result = pickMostUrgent(
        {
          first.id: maintenance(remainingKm: -100),
          second.id: maintenance(remainingKm: -500),
        },
        [first, second],
      );
      expect(result.vehicleId, second.id);
      expect(result.status, MaintenanceStatus.overdue);
    });

    test('未设置保养返回 disabled', () {
      final result = pickMostUrgent(const {}, [first]);
      expect(result.enabled, isFalse);
    });
  });

  group('buildGarageTip', () {
    final now = DateTime(2026, 11, 14);
    final energy = aggregateMonthEnergy(
      [profileRecord(amountCents: 1330, kwh: 10)],
      month: DateTime(2026, 11),
      now: now,
    );

    test('充电展示次数与平均单价', () {
      final tip = buildGarageTip(
        records: [profileRecord(amountCents: 1330, kwh: 10)],
        energy: energy,
        isAllAssets: false,
        month: DateTime(2026, 11),
        now: now,
      );
      expect(tip.kind, GarageTipKind.charging);
      expect(tip.text, '本月充电 1 次 · 平均 ¥1.33/kWh');
    });

    test('加油展示平均每升单价', () {
      final records = [
        profileRecord(
          category: ExpenseCategory.fuel,
          powertrain: PowertrainType.ice,
          amountCents: 1632,
          liters: 2,
        ),
      ];
      final tip = buildGarageTip(
        records: records,
        energy: aggregateMonthEnergy(
          records,
          month: DateTime(2026, 11),
          now: now,
        ),
        isAllAssets: false,
        month: DateTime(2026, 11),
        now: now,
      );
      expect(tip.kind, GarageTipKind.fuel);
      expect(tip.text, '本月加油 1 次 · 平均 ¥8.16/L');
    });

    test('油电同时存在时组合展示', () {
      final records = [
        profileRecord(amountCents: 1330, kwh: 10),
        profileRecord(
          id: 'fuel',
          category: ExpenseCategory.fuel,
          powertrain: PowertrainType.phev,
          amountCents: 1632,
          liters: 2,
        ),
      ];
      final tip = buildGarageTip(
        records: records,
        energy: aggregateMonthEnergy(
          records,
          month: DateTime(2026, 11),
          now: now,
        ),
        isAllAssets: false,
        month: DateTime(2026, 11),
        now: now,
      );
      expect(tip.kind, GarageTipKind.mixed);
      expect(tip.text, contains('本月充电 1 次'));
      expect(tip.text, contains('加油 1 次'));
    });

    test('无记录返回空提示', () {
      final tip = buildGarageTip(
        records: const [],
        energy: const MonthEnergy(amountCents: 0, count: 0),
        isAllAssets: true,
        month: DateTime(2026, 11),
        now: now,
      );
      expect(tip.kind, GarageTipKind.empty);
      expect(tip.text, '本月暂无能耗记录');
    });
  });
}
