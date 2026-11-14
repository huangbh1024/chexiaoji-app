import 'package:chexiaoji_app/app/app.dart';
import 'package:chexiaoji_app/app/theme/app_theme.dart';
import 'package:chexiaoji_app/features/stats/presentation/stats_page.dart';
import 'package:chexiaoji_app/features/home/data/mock_home_repository.dart';
import 'package:chexiaoji_app/features/ledger/data/mock_ledger_repository.dart';
import 'package:chexiaoji_app/features/stats/data/mock_stats_repository.dart';
import 'package:chexiaoji_app/features/stats/domain/providers.dart';
import 'package:chexiaoji_app/features/stats/presentation/stats_breakdown_card.dart';
import 'package:chexiaoji_app/features/stats/presentation/stats_recent_records.dart';
import 'package:chexiaoji_app/features/stats/presentation/stats_trend_chart.dart';
import 'package:chexiaoji_app/features/stats/presentation/stats_vehicle_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pumpStats(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(const ProviderScope(child: CheXiaoJiApp()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('统计'));
  await tester.pumpAndSettle();
}

Future<void> _pumpFailingStats(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final ledger = MockLedgerRepository(delay: Duration.zero);
  final repository = MockStatsRepository(
    ledger: ledger,
    home: MockHomeRepository(ledger: ledger),
    delay: Duration.zero,
    failures: const {StatsMockFailure.overview},
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [statsRepositoryProvider.overrideWithValue(repository)],
      child: const CheXiaoJiApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('统计'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('统计页展示周期、Hero、走势、构成与最近记录', (tester) async {
    await _pumpStats(tester);

    expect(find.text('数据统计'), findsOneWidget);
    expect(find.textContaining('综合每公里成本'), findsOneWidget);
    expect(find.text('花费趋势与开销走势'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('stats-scroll')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();

    expect(find.text('开销构成分析'), findsOneWidget);
    expect(find.text('最近开销记录'), findsOneWidget);
  });

  testWidgets('切换周期后 Hero 与趋势粒度联动', (tester) async {
    await _pumpStats(tester);

    await tester.tap(find.text('周'));
    await tester.pumpAndSettle();

    expect(find.textContaining('本周总开销'), findsOneWidget);
    expect(find.textContaining('本周行驶'), findsOneWidget);
    expect(find.text('近 7 天'), findsOneWidget);
  });

  testWidgets('切换车辆后能耗标题联动', (tester) async {
    await _pumpStats(tester);

    await tester.tap(find.byKey(const Key('stats-vehicle-pill')));
    await tester.pumpAndSettle();
    expect(find.text('选择爱车'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(StatsVehicleSheet),
        matching: find.text('丰田 凯美瑞 双擎'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('平均百公里油耗'), findsOneWidget);
    expect(find.text('全部车辆'), findsNothing);
  });

  testWidgets('概览失败时显示模块级错误，其他卡片正常', (tester) async {
    await _pumpFailingStats(tester);

    expect(find.text('汇总加载失败'), findsOneWidget);
    expect(find.text('重试'), findsWidgets);
    expect(find.text('花费趋势与开销走势'), findsOneWidget);
  });

  testWidgets('趋势图可点按且不抛异常', (tester) async {
    await _pumpStats(tester);

    await tester.drag(
      find.byKey(const Key('stats-scroll')),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(StatsTrendChart));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('点击构成图例跳转账单并带分类', (tester) async {
    await _pumpStats(tester);

    await tester.drag(
      find.byKey(const Key('stats-scroll')),
      const Offset(0, -800),
    );
    await tester.pumpAndSettle();

    final card = find.byType(StatsBreakdownCard);
    final firstLegend = find.descendant(
      of: card,
      matching: find.byType(InkWell),
    );
    expect(firstLegend, findsWidgets);
    await tester.tap(firstLegend.first);
    await tester.pumpAndSettle();

    expect(find.text('账单明细'), findsOneWidget);
  });

  testWidgets('最近记录查看全部跳转账单', (tester) async {
    await _pumpStats(tester);

    await tester.drag(
      find.byKey(const Key('stats-scroll')),
      const Offset(0, -1400),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(StatsRecentRecords),
        matching: find.text('查看全部'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('账单明细'), findsOneWidget);
  });

  testWidgets('字号放大 1.3 倍不溢出', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final ledger = MockLedgerRepository(delay: Duration.zero);
    final repository = MockStatsRepository(
      ledger: ledger,
      home: MockHomeRepository(ledger: ledger),
      delay: Duration.zero,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [statsRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: StatsPage(scrollController: ScrollController())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('数据统计'), findsOneWidget);
  });
}
