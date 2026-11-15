import 'package:chexiaoji_app/core/domain/enums.dart';
import 'package:chexiaoji_app/core/domain/vehicle.dart';
import 'package:chexiaoji_app/features/vehicles/data/vehicle_store.dart';
import 'package:flutter_test/flutter_test.dart';

VehicleRecord record(String id, int sortOrder) {
  return VehicleRecord(
    vehicle: Vehicle(
      id: id,
      name: '车辆 $id',
      plate: '粤B·$id',
      powertrain: PowertrainType.ev,
      powertrainLabel: '纯电',
      odometerKm: 1000,
    ),
    specLabel: '测试配置',
    sortOrder: sortOrder,
  );
}

void main() {
  group('VehicleStore', () {
    test('默认主驾置顶，其余按 sortOrder 排序', () {
      final store = VehicleStore(
        records: [record('a', 0), record('b', 1), record('c', 2)],
        primaryVehicleId: 'b',
      );
      expect(store.active.map((item) => item.id), ['b', 'a', 'c']);
    });

    test('切换主驾后置顶且全库唯一', () {
      final store = VehicleStore(
        records: [record('a', 0), record('b', 1), record('c', 2)],
        primaryVehicleId: 'a',
      );
      store.setPrimary('c');
      expect(store.primaryVehicleId, 'c');
      expect(store.active.first.id, 'c');
      expect(store.active.where((item) => item.id == 'c').length, 1);
    });

    test('归档默认主驾后由下一辆车继任', () {
      final store = VehicleStore(
        records: [record('a', 0), record('b', 1), record('c', 2)],
        primaryVehicleId: 'a',
      );
      store.archive('a', at: DateTime(2026, 11, 15));
      expect(store.primaryVehicleId, 'b');
      expect(store.archived.single.id, 'a');
      expect(store.active.map((item) => item.id), ['b', 'c']);
    });

    test('归档唯一车辆后默认主驾为空', () {
      final store = VehicleStore(
        records: [record('a', 0)],
        primaryVehicleId: 'a',
      );
      store.archive('a');
      expect(store.primaryVehicleId, isNull);
      expect(store.active, isEmpty);
    });

    test('恢复车辆追加到列表末尾；无主驾时自动成为主驾', () {
      final store = VehicleStore(
        records: [record('a', 0), record('b', 1)],
        primaryVehicleId: 'a',
      );
      store.archive('a');
      expect(store.primaryVehicleId, 'b');
      store.restore('a');
      expect(store.active.map((item) => item.id), ['b', 'a']);
      expect(store.active.last.sortOrder, 2);
      expect(store.primaryVehicleId, 'b');

      store.archive('b');
      expect(store.primaryVehicleId, 'a');
      store.archive('a');
      expect(store.primaryVehicleId, isNull);
      store.restore('b');
      expect(store.primaryVehicleId, 'b');
    });

    test('多车时不能直接删除默认主驾', () {
      final store = VehicleStore(
        records: [record('a', 0), record('b', 1)],
        primaryVehicleId: 'a',
      );
      expect(
        () => store.delete('a'),
        throwsA(
          isA<VehicleStoreException>().having(
            (error) => error.error,
            'error',
            VehicleStoreError.isPrimary,
          ),
        ),
      );
    });

    test('唯一车辆可删除并清空主驾', () {
      final store = VehicleStore(
        records: [record('a', 0)],
        primaryVehicleId: 'a',
      );
      store.delete('a');
      expect(store.active, isEmpty);
      expect(store.primaryVehicleId, isNull);
    });

    test('归档非主驾不影响默认主驾', () {
      final store = VehicleStore(
        records: [record('a', 0), record('b', 1)],
        primaryVehicleId: 'a',
      );
      store.archive('b');
      expect(store.primaryVehicleId, 'a');
      expect(store.active.single.id, 'a');
    });
  });
}
