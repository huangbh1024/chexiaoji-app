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
  group('VehicleStore.purge', () {
    test('仅归档车辆可彻底删除', () {
      final store = VehicleStore(
        records: [record('a', 0), record('b', 1)],
        primaryVehicleId: 'a',
      );

      expect(
        () => store.purge('a'),
        throwsA(
          isA<VehicleStoreException>().having(
            (error) => error.error,
            'error',
            VehicleStoreError.notArchived,
          ),
        ),
      );

      store.archive('a');
      store.purge('a');
      expect(store.byId('a'), isNull);
      expect(store.archived, isEmpty);
      expect(store.primaryVehicleId, 'b');
    });

    test('彻底删除不存在的车辆抛出 notFound', () {
      final store = VehicleStore(records: [record('a', 0)]);
      expect(
        () => store.purge('missing'),
        throwsA(
          isA<VehicleStoreException>().having(
            (error) => error.error,
            'error',
            VehicleStoreError.notFound,
          ),
        ),
      );
    });
  });

  _editorStoreTests();
}

void _editorStoreTests() {
  group('VehicleStore 编辑器写入口', () {
    test('新增分配排序；空车库自动成为主驾', () {
      final store = VehicleStore(records: const []);
      final created = store.add(record('new', 0), makePrimary: false);
      expect(created.sortOrder, 0);
      expect(store.primaryVehicleId, 'new');
    });

    test('新增尊重 makePrimary；非首辆不抢占主驾', () {
      final store = VehicleStore(
        records: [record('a', 0)],
        primaryVehicleId: 'a',
      );
      store.add(record('b', 1));
      expect(store.primaryVehicleId, 'a');
      store.add(record('c', 2), makePrimary: true);
      expect(store.primaryVehicleId, 'c');
    });

    test('车牌重复（含归档车辆）抛 duplicatePlate', () {
      final store = VehicleStore(
        records: [record('a', 0)],
        primaryVehicleId: 'a',
      );
      expect(
        () => store.add(record('a', 1)),
        throwsA(
          isA<VehicleStoreException>().having(
            (error) => error.error,
            'error',
            VehicleStoreError.duplicatePlate,
          ),
        ),
      );
      store.archive('a');
      expect(
        () => store.add(record('a', 2)),
        throwsA(isA<VehicleStoreException>()),
      );
    });

    test('在库车辆上限为 10', () {
      final records = [
        for (var index = 0; index < VehicleStore.maxActiveVehicles; index++)
          record('v$index', index),
      ];
      final store = VehicleStore(records: records, primaryVehicleId: 'v0');
      expect(
        () => store.add(record('overflow', 99)),
        throwsA(
          isA<VehicleStoreException>().having(
            (error) => error.error,
            'error',
            VehicleStoreError.limitReached,
          ),
        ),
      );
    });

    test('更新保留排序 / SOH / 年检，并可接管主驾', () {
      final store = VehicleStore(
        records: [
          VehicleRecord(
            vehicle: record('a', 0).vehicle,
            specLabel: '旧配置',
            sortOrder: 4,
            batteryHealthPercent: 95,
            inspectionExpiry: DateTime(2027, 1, 1),
          ),
          record('b', 1),
        ],
        primaryVehicleId: 'a',
      );
      final updated = VehicleRecord(
        vehicle: const Vehicle(
          id: 'a',
          name: '新名称',
          plate: '粤B·A0001',
          powertrain: PowertrainType.ice,
          powertrainLabel: '纯燃油',
          odometerKm: 2000,
        ),
        specLabel: '新配置',
        sortOrder: 0,
        nickname: '小白',
        nextMaintenanceKm: 5000,
        insuranceExpiry: DateTime(2026, 12, 1),
      );
      final result = store.update('a', updated, makePrimary: true);
      expect(result.sortOrder, 4);
      expect(result.batteryHealthPercent, 95);
      expect(result.inspectionExpiry, DateTime(2027, 1, 1));
      expect(result.nickname, '小白');
      expect(result.nextMaintenanceKm, 5000);
      expect(store.primaryVehicleId, 'a');
    });

    test('更新车牌与他人冲突时拒绝', () {
      final store = VehicleStore(
        records: [record('a', 0), record('b', 1)],
        primaryVehicleId: 'a',
      );
      final updated = VehicleRecord(
        vehicle: const Vehicle(
          id: 'a',
          name: 'A',
          plate: '粤B·b',
          powertrain: PowertrainType.ev,
          powertrainLabel: '纯电',
          odometerKm: 1000,
        ),
        specLabel: '',
        sortOrder: 0,
      );
      expect(
        () => store.update('a', updated),
        throwsA(
          isA<VehicleStoreException>().having(
            (error) => error.error,
            'error',
            VehicleStoreError.duplicatePlate,
          ),
        ),
      );
    });
  });
}
