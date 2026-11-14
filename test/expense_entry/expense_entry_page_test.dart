import 'package:chexiaoji_app/app/theme/app_theme.dart';
import 'package:chexiaoji_app/core/domain/enums.dart';
import 'package:chexiaoji_app/core/domain/vehicle.dart';
import 'package:chexiaoji_app/features/expense_entry/data/expense_entry_repository.dart';
import 'package:chexiaoji_app/features/expense_entry/data/receipt_picker.dart';
import 'package:chexiaoji_app/features/expense_entry/domain/expense_entry_detail.dart';
import 'package:chexiaoji_app/features/expense_entry/domain/expense_entry_models.dart';
import 'package:chexiaoji_app/features/expense_entry/domain/providers.dart';
import 'package:chexiaoji_app/features/expense_entry/presentation/expense_entry_page.dart';
import 'package:chexiaoji_app/features/expense_entry/presentation/expense_entry_routes.dart';
import 'package:chexiaoji_app/features/home/domain/providers.dart';
import 'package:chexiaoji_app/features/ledger/domain/ledger_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _vehicles = [
  Vehicle(
    id: 'byd-han-ev',
    name: '比亚迪 汉 EV',
    plate: '粤B·D82K6',
    powertrain: PowertrainType.ev,
    powertrainLabel: '纯电',
    odometerKm: 18426,
    batteryCapacityKwh: 85.4,
  ),
  Vehicle(
    id: 'toyota-camry-hev',
    name: '丰田 凯美瑞 双擎',
    plate: '粤B·7Q315',
    powertrain: PowertrainType.hev,
    powertrainLabel: '油电混动',
    odometerKm: 46210,
    tankCapacityL: 50,
    defaultFuelGrade: 95,
  ),
];

class _FakePicker implements ReceiptPicker {
  @override
  Future<PickedReceipt?> pick(ReceiptSource source) async {
    return const PickedReceipt(path: '/tmp/fake-receipt.jpg', sizeBytes: 100);
  }
}

class _FakeRepository implements ExpenseEntryRepository {
  bool created = false;
  bool updated = false;
  ExpenseEntryDraft? lastDraft;

  @override
  Future<ExpenseEntryDefaults> fetchDefaults(String vehicleId) async {
    return const ExpenseEntryDefaults(
      defaultCategory: ExpenseCategory.charging,
      batteryCapacityKwh: 85.4,
      tankCapacityL: 50,
      lastPlace: '特来电科技园快充站',
      recentPlaces: ['万象城地下停车场'],
    );
  }

  @override
  Future<OdometerBaseline> fetchOdometerBaseline({
    required String vehicleId,
    required DateTime before,
    String? excludeRecordId,
  }) async {
    return const OdometerBaseline(
      lastReadingKm: 18375,
      currentOdometerKm: 18426,
      recordId: 'rec_prev',
    );
  }

  @override
  Future<ExpenseEntryDraft> fetchDraft(String recordId) async {
    return ExpenseEntryDraft(
      vehicleId: 'byd-han-ev',
      category: ExpenseCategory.charging,
      amountCents: 5110,
      occurredAt: DateTime(2026, 11, 14, 13, 28),
      paymentChannel: PaymentChannel.wechat,
      paymentLabel: '微信支付',
      place: '特来电科技园快充站',
      odometerKm: 18375,
      note: '夜间补电',
      detail: const ChargingDetail(kwh: 42.5, socEnd: 78),
    );
  }

  @override
  Future<LedgerRecord> createExpense(ExpenseEntryDraft draft) async {
    created = true;
    lastDraft = draft;
    return _record(draft);
  }

  @override
  Future<LedgerRecord> updateExpense(
    String recordId,
    ExpenseEntryDraft draft,
  ) async {
    updated = true;
    lastDraft = draft;
    return _record(draft, id: recordId);
  }

  @override
  Future<List<ReceiptAttachment>> uploadReceipts(
    List<ReceiptAttachment> receipts, {
    void Function(String localPath, double progress)? onProgress,
  }) async {
    return [
      for (final receipt in receipts)
        receipt.remoteId == null
            ? receipt.copyWith(remoteId: receipt.localPath)
            : receipt,
    ];
  }

  LedgerRecord _record(ExpenseEntryDraft draft, {String id = 'rec_new'}) {
    return LedgerRecord(
      id: id,
      vehicleId: draft.vehicleId ?? 'byd-han-ev',
      vehicleShortName: '汉 EV',
      vehicleName: '比亚迪 汉 EV',
      powertrain: PowertrainType.ev,
      category: draft.category,
      title: draft.place ?? '充电',
      amountCents: draft.amountCents,
      occurredAt: draft.occurredAt,
      metrics: LedgerMetrics(odometerKm: draft.odometerKm),
      statusText: draft.paymentLabel,
      note: draft.note,
    );
  }
}

Future<_FakeRepository> _pumpPage(
  WidgetTester tester, {
  bool viaLauncher = false,
  double height = 1600,
}) async {
  tester.view.physicalSize = Size(390, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final repository = _FakeRepository();
  final overrides = [
    vehiclesProvider.overrideWith((ref) async => _vehicles),
    expenseEntryRepositoryProvider.overrideWithValue(repository),
    receiptPickerProvider.overrideWithValue(_FakePicker()),
  ];
  final args = ExpenseEntryArgs.create(initialVehicleId: 'byd-han-ev');
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: viaLauncher
            ? Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => openExpenseEntry(context, args: args),
                      child: const Text('打开记账'),
                    ),
                  ),
                ),
              )
            : ExpenseEntryPage(args: args),
      ),
    ),
  );
  if (viaLauncher) {
    await tester.tap(find.text('打开记账'));
  }
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('渲染车辆、分类、金额、参数、里程与备注', (tester) async {
    await _pumpPage(tester);

    expect(find.text('记一笔开销'), findsOneWidget);
    expect(find.text('比亚迪 汉 EV'), findsOneWidget);
    expect(find.text('纯电'), findsOneWidget);
    expect(find.text('充电'), findsOneWidget);
    expect(find.text('加油'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('保养维修'), findsOneWidget);
    expect(find.text('车险车税'), findsOneWidget);
    expect(find.text('实付金额 (元)'), findsOneWidget);
    expect(find.text('补能明细参数'), findsOneWidget);
    expect(find.text('里程仪表读数'), findsOneWidget);
    expect(find.text('18,375 km'), findsOneWidget);
    expect(find.text('+51.0 km'), findsOneWidget);
    expect(find.text('备注与凭证'), findsOneWidget);
    expect(find.text('保存并记入账本'), findsOneWidget);
  });

  testWidgets('输入金额联动能耗预估，切换分类替换参数卡', (tester) async {
    await _pumpPage(tester);

    await tester.enterText(find.byKey(const Key('entry-amount')), '100');
    await tester.pumpAndSettle();

    expect(find.textContaining('充入约 83.3', findRichText: true), findsOneWidget);
    expect(find.textContaining('¥1.96', findRichText: true), findsOneWidget);

    await tester.tap(find.text('加油'));
    await tester.pumpAndSettle();

    expect(find.text('加油明细参数'), findsOneWidget);
    expect(find.text('加注油量 (L)'), findsOneWidget);
    expect(find.text('12.74'), findsOneWidget);
    expect(find.text('95#'), findsOneWidget);
  });

  testWidgets('里程倒挂时保存被拦截并展示错误', (tester) async {
    final repository = await _pumpPage(tester);
    await tester.enterText(find.byKey(const Key('entry-amount')), '100');
    await tester.enterText(find.byKey(const Key('entry-odometer')), '18000');
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存并记入账本'));
    await tester.pumpAndSettle();

    expect(repository.created, isFalse);
    expect(find.text('本次读数不能小于上次记录 18,375 km'), findsAtLeastNWidgets(1));
  });

  testWidgets('有内容时关闭会确认放弃', (tester) async {
    await _pumpPage(tester);
    await tester.enterText(find.byKey(const Key('entry-amount')), '100');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('放弃这笔记录？'), findsOneWidget);
    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    expect(find.text('记一笔开销'), findsOneWidget);
  });

  testWidgets('保存成功后返回来源页', (tester) async {
    final repository = await _pumpPage(tester, viaLauncher: true);
    await tester.enterText(find.byKey(const Key('entry-amount')), '100');
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存并记入账本'));
    await tester.pumpAndSettle();

    expect(repository.created, isTrue);
    expect(repository.lastDraft?.amountCents, 10000);
    expect(find.text('打开记账'), findsOneWidget);
  });

  testWidgets('发生时间浮层可打开并选择现在', (tester) async {
    await _pumpPage(tester);

    await tester.tap(find.text('发生时间'));
    await tester.pumpAndSettle();

    expect(find.text('现在'), findsOneWidget);
    expect(find.text('今天早些时候'), findsOneWidget);
    expect(find.text('昨天'), findsOneWidget);
    expect(find.text('选择日期与时间'), findsOneWidget);

    await tester.tap(find.text('现在'));
    await tester.pumpAndSettle();
    expect(find.text('选择日期与时间'), findsNothing);
  });

  testWidgets('可以添加凭证照片，最多四张', (tester) async {
    await _pumpPage(tester);

    await tester.tap(find.text('凭证照片'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从相册选择'));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('凭证照片'), findsOneWidget);
  });

  testWidgets('编辑模式预填金额与备注', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vehiclesProvider.overrideWith((ref) async => _vehicles),
          expenseEntryRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ExpenseEntryPage(
            args: ExpenseEntryArgs.edit(recordId: 'rec_prev'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('编辑这笔开销'), findsOneWidget);
    expect(find.text('51.10'), findsOneWidget);
    expect(find.text('18375'), findsOneWidget);
    expect(find.text('夜间补电'), findsOneWidget);
    expect(find.text('保存修改'), findsOneWidget);
  });
}
