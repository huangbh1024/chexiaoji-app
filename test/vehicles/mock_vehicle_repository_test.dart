import 'package:chexiaoji_app/core/domain/enums.dart';
import 'package:chexiaoji_app/core/domain/vehicle.dart';
import 'package:chexiaoji_app/features/home/data/mock_home_repository.dart';
import 'package:chexiaoji_app/features/ledger/data/mock_ledger_repository.dart';
import 'package:chexiaoji_app/features/ledger/domain/ledger_analytics.dart';
import 'package:chexiaoji_app/features/ledger/domain/ledger_models.dart';
import 'package:chexiaoji_app/features/vehicles/data/mock_vehicle_repository.dart';
import 'package:chexiaoji_app/features/vehicles/data/vehicle_repository.dart';
import 'package:chexiaoji_app/features/vehicles/data/vehicle_seed_data.dart';
import 'package:chexiaoji_app/features/vehicles/data/vehicle_store.dart';
import 'package:chexiaoji_app/features/vehicles/domain/vehicle_editor_models.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 15);

void main() {
  _editorRepositoryTests();
  late VehicleStore store;
  late MockLedgerRepository ledger;
  late MockHomeRepository home;
  late MockVehicleRepository repository;

  setUp(() {
    store = seededVehicleStore(now: _now);
    ledger = MockLedgerRepository(delay: Duration.zero);
    home = MockHomeRepository(ledger: ledger, store: store);
    repository = MockVehicleRepository(
      store: store,
      home: home,
      ledger: ledger,
      now: () => _now,
      delay: Duration.zero,
    );
  });

  test('车库快照包含 4 辆车、主驾置顶与汇总', () async {
    final garage = await repository.fetchGarage();
    final month = DateTime.now();
    final monthTotal = totalCentsOf(
      ledger.recordsBetween(
        monthStart(month),
        DateTime(
          month.year,
          month.month + 1,
        ).subtract(const Duration(milliseconds: 1)),
      ),
    );

    expect(garage.vehicles.length, 4);
    expect(garage.vehicles.first.id, 'byd-han-ev');
    expect(garage.vehicles.first.isPrimary, isTrue);
    expect(garage.archivedVehicles, isEmpty);
    expect(garage.primaryVehicleId, 'byd-han-ev');
    expect(garage.summary.vehicleCount, 4);
    expect(garage.summary.totalOdometerKm, 18426 + 46210 + 31520 + 58940);
    expect(garage.summary.monthSpendCents, monthTotal);
    expect(garage.vehicles.first.recordCount, greaterThan(0));
  });

  test('设为主驾后快照与排序同步', () async {
    await repository.setPrimary('toyota-camry-hev');
    final garage = await repository.fetchGarage();

    expect(repository.primaryVehicleId, 'toyota-camry-hev');
    expect(garage.vehicles.first.id, 'toyota-camry-hev');
    expect(garage.vehicles.first.isPrimary, isTrue);
    expect(garage.vehicles.where((item) => item.isPrimary).length, 1);
  });

  test('归档默认主驾后继任并保留归档列表', () async {
    await repository.archive('byd-han-ev');
    final garage = await repository.fetchGarage();

    expect(repository.primaryVehicleId, 'toyota-camry-hev');
    expect(garage.vehicles.length, 3);
    expect(garage.archivedVehicles.single.id, 'byd-han-ev');
    expect(garage.summary.vehicleCount, 3);
    expect(garage.summary.totalOdometerKm, 46210 + 31520 + 58940);
  });

  test('恢复归档车辆后回到列表末尾', () async {
    await repository.archive('toyota-camry-hev');
    await repository.restore('toyota-camry-hev');
    final garage = await repository.fetchGarage();

    expect(garage.archivedVehicles, isEmpty);
    expect(garage.vehicles.length, 4);
    expect(garage.vehicles.last.id, 'toyota-camry-hev');
    expect(repository.primaryVehicleId, 'byd-han-ev');
  });

  test('删除默认主驾（多车）返回 isPrimary', () async {
    await expectLater(
      repository.delete('byd-han-ev'),
      throwsA(
        isA<VehicleOperationException>().having(
          (error) => error.code,
          'code',
          VehicleErrorCode.isPrimary,
        ),
      ),
    );
  });

  test('删除有流水车辆返回 hasRecords', () async {
    await expectLater(
      repository.delete('toyota-camry-hev'),
      throwsA(
        isA<VehicleOperationException>().having(
          (error) => error.code,
          'code',
          VehicleErrorCode.hasRecords,
        ),
      ),
    );
  });

  test('归档车辆无能耗读数时显示未录入而不是 0', () async {
    final emptyStore = VehicleStore(
      records: [
        VehicleRecord(
          vehicle: const Vehicle(
            id: 'archived-ev',
            name: '归档测试车',
            plate: '粤B·00001',
            powertrain: PowertrainType.ev,
            powertrainLabel: '纯电',
            odometerKm: 1000,
          ),
          specLabel: '',
          sortOrder: 0,
          isArchived: true,
          archivedAt: _now,
        ),
      ],
    );
    final emptyHome = MockHomeRepository(ledger: ledger, store: emptyStore);
    final emptyRepository = MockVehicleRepository(
      store: emptyStore,
      home: emptyHome,
      ledger: ledger,
      now: () => _now,
      delay: Duration.zero,
    );

    final garage = await emptyRepository.fetchArchivedGarage();
    expect(garage.vehicles.single.averageConsumption, isNull);
  });

  test('无流水车辆可删除，唯一车辆删除后主驾为空', () async {
    final emptyStore = VehicleStore(
      records: [
        VehicleRecord(
          vehicle: const Vehicle(
            id: 'empty-vehicle',
            name: '临时车辆',
            plate: '粤B·00000',
            powertrain: PowertrainType.ice,
            powertrainLabel: '纯燃油',
            odometerKm: 0,
          ),
          specLabel: '',
          sortOrder: 0,
        ),
      ],
      primaryVehicleId: 'empty-vehicle',
    );
    final emptyRepository = MockVehicleRepository(
      store: emptyStore,
      home: home,
      ledger: ledger,
      now: () => _now,
      delay: Duration.zero,
    );

    await emptyRepository.delete('empty-vehicle');
    expect(emptyStore.active, isEmpty);
    expect(emptyStore.primaryVehicleId, isNull);
  });

  test('归档唯一车辆后主驾为空，恢复后自动成为主驾', () async {
    final emptyStore = VehicleStore(
      records: [
        VehicleRecord(
          vehicle: const Vehicle(
            id: 'only-vehicle',
            name: '唯一车辆',
            plate: '粤B·00001',
            powertrain: PowertrainType.ev,
            powertrainLabel: '纯电',
            odometerKm: 0,
          ),
          specLabel: '',
          sortOrder: 0,
        ),
      ],
      primaryVehicleId: 'only-vehicle',
    );
    final onlyRepository = MockVehicleRepository(
      store: emptyStore,
      home: home,
      ledger: ledger,
      now: () => _now,
      delay: Duration.zero,
    );

    await onlyRepository.archive('only-vehicle');
    expect(emptyStore.primaryVehicleId, isNull);
    await onlyRepository.restore('only-vehicle');
    expect(emptyStore.primaryVehicleId, 'only-vehicle');
  });
  test('归档快照包含累计花费、能耗与最近流水时间', () async {
    await repository.archive('toyota-camry-hev');
    final archived = await repository.fetchArchivedGarage();

    expect(archived.vehicles, hasLength(1));
    final summary = archived.vehicles.single;
    expect(summary.id, 'toyota-camry-hev');
    expect(summary.recordCount, greaterThan(0));
    expect(summary.lifetimeSpendCents, greaterThan(0));
    expect(summary.energyRecordCount, greaterThan(0));
    expect(summary.averageConsumption, isNotNull);
    expect(summary.latestRecordAt, isNotNull);
  });

  test('彻底删除校验车牌尾号并移除归档档案', () async {
    await repository.archive('toyota-camry-hev');

    await expectLater(
      repository.purgeArchivedVehicle('toyota-camry-hev', plateTail: '00000'),
      throwsA(
        isA<VehicleOperationException>().having(
          (error) => error.code,
          'code',
          VehicleErrorCode.plateTailMismatch,
        ),
      ),
    );

    await repository.purgeArchivedVehicle(
      'toyota-camry-hev',
      plateTail: '7q315',
    );
    expect(store.byId('toyota-camry-hev'), isNull);
    final archived = await repository.fetchArchivedGarage();
    expect(archived.vehicles, isEmpty);
  });

  test('在库车辆不能走彻底删除', () async {
    await expectLater(
      repository.purgeArchivedVehicle('byd-han-ev', plateTail: 'D82K6'),
      throwsA(
        isA<VehicleOperationException>().having(
          (error) => error.code,
          'code',
          VehicleErrorCode.notArchived,
        ),
      ),
    );
  });

  test('彻底删除不存在的车辆返回 notFound', () async {
    await expectLater(
      repository.purgeArchivedVehicle('missing', plateTail: '00000'),
      throwsA(
        isA<VehicleOperationException>().having(
          (error) => error.code,
          'code',
          VehicleErrorCode.notFound,
        ),
      ),
    );
  });
}

void _editorRepositoryTests() {
  group('MockVehicleRepository 编辑器', () {
    late VehicleStore store;
    late MockVehicleRepository repository;

    setUp(() {
      store = seededVehicleStore(now: _now);
      final ledger = MockLedgerRepository(delay: Duration.zero);
      repository = MockVehicleRepository(
        store: store,
        home: MockHomeRepository(ledger: ledger, store: store),
        ledger: ledger,
        now: () => _now,
        delay: Duration.zero,
      );
    });

    test('编辑快照包含草稿、主驾、继任与最近里程', () async {
      final snapshot = await repository.fetchVehicleEditor('byd-han-ev');
      expect(snapshot.vehicleId, 'byd-han-ev');
      expect(snapshot.draft.name, '比亚迪 汉 EV');
      expect(snapshot.draft.province, '粤');
      expect(snapshot.draft.plateBody, 'BD82K6');
      expect(snapshot.draft.isGreenPlate, isFalse);
      expect(snapshot.isPrimary, isTrue);
      expect(snapshot.successorName, '丰田 凯美瑞 双擎');
      expect(snapshot.isOnlyActiveVehicle, isFalse);
      expect(snapshot.activeVehicleCount, 4);
    });

    test('新增车辆写回车库并成为主驾', () async {
      final result = await repository.createVehicle(
        const VehicleEditorDraft(
          name: '测试新车',
          province: '粤',
          plateBody: 'BDF8932',
          odometerKm: 1000,
          powertrain: PowertrainType.ev,
          batteryCapacityKwh: 60,
          officialConsumption: 13.5,
          makePrimary: true,
        ),
      );
      expect(result.created, isTrue);
      expect(store.active.length, 5);
      expect(store.primaryVehicleId, result.vehicleId);
      final record = store.byId(result.vehicleId)!;
      expect(record.vehicle.name, '测试新车');
      expect(record.vehicle.plate, '粤B·DF8932');
      expect(record.vehicle.batteryCapacityKwh, 60);
    });

    test('新增重复车牌抛 duplicatePlate', () async {
      await expectLater(
        repository.createVehicle(
          const VehicleEditorDraft(
            name: '重复车',
            province: '粤',
            plateBody: 'BD82K6',
            isGreenPlate: false,
            odometerKm: 1000,
          ),
        ),
        throwsA(
          isA<VehicleOperationException>().having(
            (error) => error.code,
            'code',
            VehicleErrorCode.duplicatePlate,
          ),
        ),
      );
    });

    test('更新档案保留 SOH 并写入主驾', () async {
      final snapshot = await repository.fetchVehicleEditor('toyota-camry-hev');
      await repository.updateVehicle(
        'toyota-camry-hev',
        snapshot.draft.copyWith(
          name: '丰田 凯美瑞 双擎 改',
          odometerKm: 47000,
          nickname: '小凯',
          makePrimary: true,
        ),
      );
      final record = store.byId('toyota-camry-hev')!;
      expect(record.vehicle.name, '丰田 凯美瑞 双擎 改');
      expect(record.vehicle.odometerKm, 47000);
      expect(record.nickname, '小凯');
      expect(store.primaryVehicleId, 'toyota-camry-hev');
    });
  });
}
