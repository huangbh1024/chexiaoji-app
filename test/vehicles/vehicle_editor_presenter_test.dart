import 'package:chexiaoji_app/core/domain/enums.dart';
import 'package:chexiaoji_app/core/domain/vehicle.dart';
import 'package:chexiaoji_app/features/vehicles/data/vehicle_store.dart';
import 'package:chexiaoji_app/features/vehicles/domain/vehicle_editor_models.dart';
import 'package:chexiaoji_app/features/vehicles/domain/vehicle_editor_presenter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('车牌', () {
    test('规范化、补点与拆分', () {
      expect(
        VehicleEditorPresenter.normalizePlateBody(' b·df-8932 '),
        'BDF8932',
      );
      expect(VehicleEditorPresenter.formatPlateBody('BDF8932'), 'B·DF8932');
      expect(VehicleEditorPresenter.fullPlate('粤', 'BD82K6'), '粤B·D82K6');
      final split = VehicleEditorPresenter.splitPlate('粤B·D82K6');
      expect(split.province, '粤');
      expect(split.body, 'BD82K6');
      expect(VehicleEditorPresenter.samePlate('粤B·D82K6', '粤BD82K6'), isTrue);
    });

    test('燃油 6 位、新能源 7 位', () {
      expect(VehicleEditorPresenter.plateBodyMaxLength(false), 6);
      expect(VehicleEditorPresenter.plateBodyMaxLength(true), 7);
    });
  });

  group('校验', () {
    final now = DateTime(2026, 11, 15);

    test('必填与格式错误', () {
      final errors = VehicleEditorPresenter.validate(
        const VehicleEditorDraft(),
        now: now,
      );
      expect(errors[VehicleEditorField.name], isNotNull);
      expect(errors[VehicleEditorField.plate], isNotNull);
      expect(errors[VehicleEditorField.odometer], isNotNull);
    });

    test('合法燃油车通过', () {
      final errors = VehicleEditorPresenter.validate(
        const VehicleEditorDraft(
          name: '测试车',
          plateBody: 'BD82K6',
          isGreenPlate: false,
          odometerKm: 1000,
          powertrain: PowertrainType.ice,
        ),
        now: now,
      );
      expect(errors, isEmpty);
    });

    test('车牌重复（含在库车辆）', () {
      final errors = VehicleEditorPresenter.validate(
        const VehicleEditorDraft(
          name: '测试车',
          plateBody: 'BD82K6',
          isGreenPlate: false,
          odometerKm: 1000,
        ),
        now: now,
        knownVehicles: const [PlateOwner(plate: '粤B·D82K6', name: '比亚迪 汉 EV')],
      );
      expect(errors[VehicleEditorField.plate], contains('比亚迪 汉 EV'));
    });

    test('里程不能低于最近记账里程', () {
      final errors = VehicleEditorPresenter.validate(
        const VehicleEditorDraft(
          name: '测试车',
          plateBody: 'BD82K6',
          isGreenPlate: false,
          odometerKm: 900,
        ),
        now: now,
        latestOdometerKm: 1000,
      );
      expect(errors[VehicleEditorField.odometer], contains('1,000'));
    });

    test('购车时间不能晚于今天、价格上限', () {
      final errors = VehicleEditorPresenter.validate(
        VehicleEditorDraft(
          name: '测试车',
          plateBody: 'BD82K6',
          isGreenPlate: false,
          odometerKm: 1000,
          purchaseDate: DateTime(2026, 11, 16),
          purchasePriceCents: 1000000001,
        ),
        now: now,
      );
      expect(errors[VehicleEditorField.purchaseDate], isNotNull);
      expect(errors[VehicleEditorField.purchasePrice], isNotNull);
    });

    test('按动力类型校验字段', () {
      final evErrors = VehicleEditorPresenter.validate(
        const VehicleEditorDraft(
          name: '测试车',
          plateBody: 'BDF8932',
          odometerKm: 1000,
          powertrain: PowertrainType.ev,
          batteryCapacityKwh: 500,
        ),
        now: now,
      );
      expect(evErrors[VehicleEditorField.battery], isNotNull);
      expect(evErrors[VehicleEditorField.tank], isNull);

      final iceErrors = VehicleEditorPresenter.validate(
        const VehicleEditorDraft(
          name: '测试车',
          plateBody: 'BD82K6',
          isGreenPlate: false,
          odometerKm: 1000,
          powertrain: PowertrainType.ice,
          tankCapacityL: 500,
        ),
        now: now,
      );
      expect(iceErrors[VehicleEditorField.tank], isNotNull);
      expect(iceErrors[VehicleEditorField.battery], isNull);
    });
  });

  group('映射', () {
    test('draftOf 拆分车牌并取最近里程', () {
      final record = VehicleRecord(
        vehicle: const Vehicle(
          id: 'ev-1',
          name: '测试车',
          plate: '粤B·DF8932',
          powertrain: PowertrainType.ev,
          powertrainLabel: '纯电',
          odometerKm: 1000,
          batteryCapacityKwh: 60,
        ),
        specLabel: '旗舰版',
        sortOrder: 0,
        insuranceExpiry: DateTime(2026, 12, 1),
        nextMaintenanceKm: 5000,
      );
      final draft = VehicleEditorPresenter.draftOf(
        record,
        latestOdometerKm: 1200,
        isPrimary: true,
      );
      expect(draft.province, '粤');
      expect(draft.plateBody, 'BDF8932');
      expect(draft.isGreenPlate, isTrue);
      expect(draft.odometerKm, 1200);
      expect(draft.makePrimary, isTrue);
      expect(draft.nextMaintenanceKm, 5000);
    });

    test('buildRecord 保留 SOH / 年检并清空空昵称', () {
      final existing = VehicleRecord(
        vehicle: const Vehicle(
          id: 'ev-1',
          name: '旧车',
          plate: '粤B·D82K6',
          powertrain: PowertrainType.ev,
          powertrainLabel: '纯电',
          odometerKm: 1000,
        ),
        specLabel: '旧配置',
        sortOrder: 3,
        batteryHealthPercent: 96,
        inspectionExpiry: DateTime(2027, 1, 1),
      );
      final draft = VehicleEditorPresenter.draftOf(existing);
      final vehicle = VehicleEditorPresenter.buildVehicle(
        draft: draft.copyWith(name: '新车'),
        id: 'ev-1',
      );
      final record = VehicleEditorPresenter.buildRecord(
        vehicle: vehicle,
        draft: draft.copyWith(name: '新车', nickname: '  '),
        sortOrder: 0,
        existing: existing,
      );
      expect(record.sortOrder, 3);
      expect(record.batteryHealthPercent, 96);
      expect(record.inspectionExpiry, DateTime(2027, 1, 1));
      expect(record.nickname, isNull);
      expect(record.vehicle.name, '新车');
    });
  });

  group('金额与文案', () {
    test('万元解析与回显', () {
      expect(VehicleEditorPresenter.parseWanToCents('26.8'), 26800000);
      expect(VehicleEditorPresenter.formatWanInput(26800000), '26.8');
      expect(VehicleEditorPresenter.formatWanInput(null), '');
    });

    test('保存成功文案区分新增 / 编辑 / 主驾 / 归档', () {
      expect(
        VehicleEditorPresenter.successMessageOf(
          name: '测试车',
          created: true,
          primary: true,
          archived: false,
        ),
        contains('设为默认主驾'),
      );
      expect(
        VehicleEditorPresenter.successMessageOf(
          name: '测试车',
          created: false,
          primary: false,
          archived: true,
        ),
        '已将「测试车」归档',
      );
    });
  });
}
