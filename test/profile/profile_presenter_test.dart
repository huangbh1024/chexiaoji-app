import 'package:chexiaoji_app/core/domain/enums.dart';
import 'package:chexiaoji_app/core/format/formatters.dart';
import 'package:chexiaoji_app/features/profile/domain/profile_models.dart';
import 'package:chexiaoji_app/features/profile/domain/profile_presenter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profile_test_helpers.dart';

void main() {
  group('资料卡展示', () {
    test('统计数字与单位格式化', () {
      final view = buildProfileSummaryView(
        overview: profileOverview(),
        vehicleCount: 3,
      );

      expect(view.initial, '林');
      expect(view.nickname, '林漪');
      expect(view.verifiedOwner, isTrue);
      expect(view.accountDaysText, '328 天');
      expect(view.recordCountText, '142 笔');
      expect(view.vehicleCountText, '3 辆');
      expect(view.phoneText, '138 **** 9208');
    });

    test('无记录、车辆未知与空手机号', () {
      final view = buildProfileSummaryView(
        overview: profileOverview(
          accountDays: 0,
          recordCount: 0,
          phoneMasked: null,
        ),
        vehicleCount: null,
      );

      expect(view.accountDaysText, '— 天');
      expect(view.recordCountText, '0 笔');
      expect(view.vehicleCountText, '— 辆');
      expect(view.phoneText, isNull);
    });
  });

  group('车库卡展示', () {
    test('全部资产：里程、金额、笔数与最紧迫保养', () {
      const snapshot = GarageSnapshot(
        badge: '全部资产',
        plateText: '4 辆在役',
        title: '我的全部车辆',
        subtitle: '纯电 1 · 混动 2 · 燃油 1',
        odometerKm: 155096,
        monthEnergy: MonthEnergy(amountCents: 114820, count: 23),
        maintenance: GarageMaintenance(
          enabled: true,
          status: MaintenanceStatus.warning,
          vehicleId: 'byd-han-ev',
          vehicleName: '汉 EV',
          remainingKm: 1574,
          remainingDays: 22,
        ),
        tip: GarageTip(
          kind: GarageTipKind.energySummary,
          text: '本月共 23 笔能耗记录 · 合计 ¥1,148.2',
        ),
      );

      final view = buildGarageCardView(snapshot);

      expect(view.odometerText, '155,096');
      expect(view.energyAmountText, '¥1,148.2');
      expect(view.energySubText, '共 23 笔');
      expect(view.maintenanceValue, '1,574');
      expect(view.maintenanceUnit, '汉 EV · km 后 · 即将保养');
      expect(view.maintenanceStatus, MaintenanceStatus.warning);
      expect(view.tipText, '本月共 23 笔能耗记录 · 合计 ¥1,148.2');
    });

    test('单车：kWh 副文与超期保养', () {
      const snapshot = GarageSnapshot(
        vehicleId: 'byd-han-ev',
        badge: '纯电',
        plateText: '粤B·D82K6',
        title: '比亚迪 汉 EV',
        subtitle: '累计能耗 ¥0.18/km',
        powertrain: PowertrainType.ev,
        odometerKm: 18426,
        monthEnergy: MonthEnergy(amountCents: 31240, count: 6, kwh: 184),
        maintenance: GarageMaintenance(
          enabled: true,
          status: MaintenanceStatus.overdue,
          vehicleId: 'byd-han-ev',
          vehicleName: '汉 EV',
          remainingKm: -120,
        ),
        tip: GarageTip(kind: GarageTipKind.charging, text: '本月充电 6 次'),
      );

      final view = buildGarageCardView(snapshot);

      expect(view.energySubText, '184 kWh · 6 笔');
      expect(view.maintenanceValue, '已超期 120');
      expect(view.maintenanceUnit, 'km');
    });

    test('插混：电与油同时展示', () {
      const snapshot = GarageSnapshot(
        vehicleId: 'byd-song-plus-dmi',
        badge: '插电混动',
        plateText: '粤B·9X521',
        title: '宋PLUS DM-i',
        subtitle: '累计能耗 ¥0.26/km',
        powertrain: PowertrainType.phev,
        odometerKm: 31520,
        monthEnergy: MonthEnergy(
          amountCents: 22800,
          count: 9,
          kwh: 12,
          liters: 5,
        ),
        maintenance: GarageMaintenance(
          enabled: false,
          status: MaintenanceStatus.normal,
        ),
        tip: GarageTip(kind: GarageTipKind.empty, text: '本月暂无能耗记录'),
      );

      final view = buildGarageCardView(snapshot);

      expect(view.energySubText, '电 12 kWh · 油 5 L');
      expect(view.maintenanceValue, '—');
      expect(view.maintenanceUnit, '未设置保养周期');
    });

    test('无能耗记录展示空提示', () {
      const snapshot = GarageSnapshot(
        vehicleId: 'byd-han-ev',
        badge: '纯电',
        plateText: '粤B·D82K6',
        title: '比亚迪 汉 EV',
        subtitle: '本月已记 0 笔',
        powertrain: PowertrainType.ev,
        odometerKm: 18426,
        monthEnergy: MonthEnergy(amountCents: 0, count: 0),
        maintenance: GarageMaintenance(
          enabled: false,
          status: MaintenanceStatus.normal,
        ),
        tip: GarageTip(kind: GarageTipKind.empty, text: '本月暂无能耗记录'),
      );

      final view = buildGarageCardView(snapshot);

      expect(view.energyAmountText, '¥0.0');
      expect(view.energySubText, '本月暂无能耗记录');
    });
  });

  group('格式化', () {
    test('金额一位小数与千分位', () {
      expect(formatYuanOneDecimal(31240), '¥312.4');
      expect(formatYuanOneDecimal(114820), '¥1,148.2');
      expect(formatYuanOneDecimal(0), '¥0.0');
    });

    test('计数千分位', () {
      expect(formatCount(0), '0');
      expect(formatCount(142), '142');
      expect(formatCount(1248), '1,248');
    });

    test('能耗量去掉无意义尾零', () {
      expect(formatEnergyQuantity(184, unit: 'kWh'), '184 kWh');
      expect(formatEnergyQuantity(184.5, unit: 'kWh'), '184.5 kWh');
      expect(formatEnergyQuantity(5.2, unit: 'L'), '5.2 L');
      expect(formatEnergyQuantity(5.25, unit: 'L'), '5.25 L');
    });
  });
}
