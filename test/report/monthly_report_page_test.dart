import 'package:chexiaoji_app/app/app.dart';
import 'package:chexiaoji_app/app/theme/app_theme.dart';
import 'package:chexiaoji_app/features/report/domain/report_models.dart';
import 'package:chexiaoji_app/features/report/presentation/monthly_report_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pumpReportPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final now = DateTime.now();
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        home: MonthlyReportPage(
          initialScope: ReportScope(month: DateTime(now.year, now.month)),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pumpAndSettle();
}

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(const ProviderScope(child: CheXiaoJiApp()));
  await tester.pumpAndSettle();
}

Future<void> _scrollControlsIntoView(WidgetTester tester) async {
  await tester.drag(find.byType(CustomScrollView), const Offset(0, -520));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('月度报表页展示范围、A4 预览、格式与配置', (tester) async {
    await _pumpReportPage(tester);

    expect(find.text('月度报表与导出'), findsOneWidget);
    expect(find.text('报表实时预览 (A4标准)'), findsOneWidget);
    expect(find.text('本月总开销'), findsOneWidget);
    expect(find.text('综合每公里'), findsOneWidget);
    expect(find.text('本月行驶'), findsOneWidget);
    expect(find.text('每日开销走势'), findsOneWidget);
    expect(find.text('分类支出核算明细'), findsOneWidget);
    expect(find.text('导出选项与格式'), findsOneWidget);
    expect(find.text('立即导出 PDF 报表'), findsOneWidget);
    expect(find.textContaining('全部车辆'), findsWidgets);
  });

  testWidgets('切换导出格式后 CTA 文案同步', (tester) async {
    await _pumpReportPage(tester);
    await _scrollControlsIntoView(tester);

    await tester.tap(find.text('Excel / CSV'));
    await tester.pumpAndSettle();

    expect(find.text('导出 Excel / CSV'), findsOneWidget);
    expect(find.text('立即导出 PDF 报表'), findsNothing);
  });

  testWidgets('关闭能耗分析后隐藏每公里与走势图', (tester) async {
    await _pumpReportPage(tester);
    await _scrollControlsIntoView(tester);

    await tester.tap(find.text('包含能耗与每公里成本分析'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 520));
    await tester.pumpAndSettle();

    expect(find.text('综合每公里'), findsNothing);
    expect(find.text('每日开销走势'), findsNothing);
    expect(find.text('本月总开销'), findsOneWidget);
    expect(find.text('分类支出核算明细'), findsOneWidget);
  });

  testWidgets('隐私开关在预览中脱敏车牌', (tester) async {
    await _pumpReportPage(tester);

    await tester.tap(find.text('比亚迪 汉 EV'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(find.textContaining('粤B·D82K6'), findsOneWidget);

    await _scrollControlsIntoView(tester);

    await tester.tap(find.text('隐藏车牌及个人敏感隐私'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 520));
    await tester.pumpAndSettle();

    expect(find.text('粤B·D****'), findsOneWidget);
    expect(find.text('粤B·D82K6'), findsNothing);
  });

  testWidgets('长图海报禁用并给出提示', (tester) async {
    await _pumpReportPage(tester);
    await _scrollControlsIntoView(tester);

    await tester.tap(find.text('长图海报'));
    await tester.pump();

    expect(find.text('长图海报即将支持'), findsOneWidget);
  });

  testWidgets('从账单页导出按钮进入月度报表页', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('账单'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.ios_share_rounded));
    await tester.pumpAndSettle();

    expect(find.text('月度报表与导出'), findsOneWidget);
    expect(find.text('报表实时预览 (A4标准)'), findsOneWidget);
  });
}
