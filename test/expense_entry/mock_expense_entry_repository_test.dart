import 'package:chexiaoji_app/core/domain/enums.dart';
import 'package:chexiaoji_app/features/expense_entry/data/mock_expense_entry_repository.dart';
import 'package:chexiaoji_app/features/expense_entry/domain/expense_entry_detail.dart';
import 'package:chexiaoji_app/features/expense_entry/domain/expense_entry_models.dart';
import 'package:chexiaoji_app/features/home/data/mock_home_repository.dart';
import 'package:chexiaoji_app/features/ledger/data/mock_ledger_repository.dart';
import 'package:chexiaoji_app/features/ledger/domain/ledger_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockLedgerRepository ledger;
  late MockHomeRepository home;
  late MockExpenseEntryRepository repository;

  setUp(() {
    ledger = MockLedgerRepository(delay: Duration.zero);
    home = MockHomeRepository(
      ledger: ledger,
      odometerResolver: ledger.latestOdometer,
    );
    repository = MockExpenseEntryRepository(ledger, home, delay: Duration.zero);
  });

  ExpenseEntryDraft buildDraft({
    int amountCents = 12345,
    int odometerKm = 60000,
  }) {
    return ExpenseEntryDraft(
      vehicleId: 'byd-han-ev',
      category: ExpenseCategory.charging,
      amountCents: amountCents,
      occurredAt: DateTime.now(),
      paymentChannel: PaymentChannel.wechat,
      paymentLabel: '微信支付',
      place: '特来电科技园快充站',
      odometerKm: odometerKm,
      lastOdometerKm: 59900,
      note: '夜间谷电',
      detail: const ChargingDetail(
        unitPriceCentsPerKwh: 120,
        socStart: 20,
        kwh: 102.9,
        socEnd: 100,
      ),
    );
  }

  test('默认值按动力类型给出分类与容量', () async {
    final defaults = await repository.fetchDefaults('byd-han-ev');
    expect(defaults.defaultCategory, ExpenseCategory.charging);
    expect(defaults.batteryCapacityKwh, 85.4);
    expect(defaults.unitPrices.chargingCentsPerKwh, 120);
    expect(defaults.fuelGrade, 95);
  });

  test('基线只返回发生时间之前的读数', () async {
    final before = DateTime(2000, 1, 2);
    final baseline = await repository.fetchOdometerBaseline(
      vehicleId: 'byd-han-ev',
      before: before,
    );
    expect(baseline.lastReadingKm, isNotNull);
    expect(baseline.recordedAt!.isBefore(before), isTrue);
    expect(baseline.currentOdometerKm, 18426);
  });

  test('创建记录后账单、车辆里程与详情一致', () async {
    final before = await ledger.fetchSummary(
      LedgerScope(month: monthStart(DateTime.now())),
    );
    final record = await repository.createExpense(buildDraft());
    final after = await ledger.fetchSummary(
      LedgerScope(month: monthStart(DateTime.now())),
    );

    expect(after.totalCents - before.totalCents, 12345);
    expect(ledger.recordById(record.id), isNotNull);
    expect(ledger.latestOdometer('byd-han-ev'), 60000);

    final vehicles = await home.fetchVehicles();
    final byd = vehicles.firstWhere((item) => item.id == 'byd-han-ev');
    expect(byd.odometerKm, 60000);

    final draft = await repository.fetchDraft(record.id);
    expect(draft.category, ExpenseCategory.charging);
    expect(draft.amountCents, 12345);
    expect(draft.place, '特来电科技园快充站');
    expect(draft.note, '夜间谷电');
    expect(draft.detail, isA<ChargingDetail>());
  });

  test('编辑记录更新金额且不新增记录', () async {
    final record = await repository.createExpense(buildDraft());
    final before = await ledger.fetchSummary(
      LedgerScope(month: monthStart(DateTime.now())),
    );
    final updated = await repository.updateExpense(
      record.id,
      buildDraft(amountCents: 20000),
    );

    final after = await ledger.fetchSummary(
      LedgerScope(month: monthStart(DateTime.now())),
    );
    expect(updated.id, record.id);
    expect(updated.amountCents, 20000);
    expect(after.count, before.count);
    expect(after.totalCents, before.totalCents + 7655);
  });

  test('上传凭证补齐 remoteId', () async {
    final uploaded = await repository.uploadReceipts([
      const ReceiptAttachment(localPath: '/tmp/a.jpg'),
    ]);
    expect(uploaded.single.remoteId, '/tmp/a.jpg');
  });

  test('查找不存在的记录抛出异常', () async {
    expect(() => repository.fetchDraft('missing'), throwsA(isA<Exception>()));
  });
}
