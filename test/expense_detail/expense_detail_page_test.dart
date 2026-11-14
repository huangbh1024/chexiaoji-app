import 'package:chexiaoji_app/app/theme/app_theme.dart';
import 'package:chexiaoji_app/features/expense_detail/data/expense_detail_repository.dart';
import 'package:chexiaoji_app/features/expense_detail/domain/expense_detail_models.dart';
import 'package:chexiaoji_app/features/expense_detail/domain/providers.dart';
import 'package:chexiaoji_app/features/expense_detail/presentation/expense_detail_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'expense_detail_test_helpers.dart';

class _FakeRepository implements ExpenseDetailRepository {
  _FakeRepository(this.detail);

  ExpenseDetail detail;
  bool deleted = false;

  @override
  Future<ExpenseDetail> fetchDetail(String id) async => detail;

  @override
  Future<ExpenseDetail> updateNote(String id, String? note) async {
    detail = detail.copyWith(note: note, clearNote: note == null);
    return detail;
  }

  @override
  Future<ExpenseDetail> updateTags(String id, List<String> tags) async {
    detail = detail.copyWith(tags: tags);
    return detail;
  }

  @override
  Future<void> deleteExpense(String id) async {
    deleted = true;
  }
}

ExpenseDetail _detail() {
  return ExpenseDetail.fromRecord(buildRecord()).copyWith(
    payment: const ExpensePayment(
      channel: PaymentChannel.wechat,
      label: '微信支付',
    ),
    tags: const ['日常补能', '谷电错峰'],
    note: '周五午休顺道补电',
  );
}

Future<_FakeRepository> _pumpPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final repository = _FakeRepository(_detail());
  final record = buildRecord();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        expenseDetailRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: ExpenseDetailPage(recordId: record.id, initialRecord: record),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('渲染摘要、车辆、结算、标签与底栏', (tester) async {
    await _pumpPage(tester);

    expect(find.text('开销详情'), findsOneWidget);
    expect(find.text('全品类通用账单'), findsOneWidget);
    expect(find.text('特来电充电站'), findsOneWidget);
    expect(find.text('新能源补能'), findsOneWidget);
    expect(find.text('-¥'), findsOneWidget);
    expect(find.text('51.10'), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);
    expect(find.text('关联爱车资产'), findsOneWidget);
    expect(find.text('已绑定'), findsOneWidget);
    expect(find.text('记录里程 18,426 km'), findsOneWidget);
    expect(find.text('结算明细'), findsOneWidget);
    expect(find.text('微信支付'), findsOneWidget);
    expect(find.text('编辑此笔账单'), findsOneWidget);
    expect(find.text('#日常补能'), findsOneWidget);
    expect(find.textContaining('周五午休顺道补电'), findsOneWidget);
  });

  testWidgets('编辑备注并保存后原地更新', (tester) async {
    await _pumpPage(tester);

    await tester.tap(find.text('编辑备注'));
    await tester.pumpAndSettle();
    expect(find.text('保存'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '新的备注内容');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.textContaining('新的备注内容'), findsOneWidget);
    expect(find.text('备注已保存'), findsOneWidget);
  });

  testWidgets('点击更多打开菜单并进入删除确认', (tester) async {
    final repository = await _pumpPage(tester);

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    expect(find.text('删除此笔账单'), findsOneWidget);

    await tester.tap(find.text('删除此笔账单'));
    await tester.pumpAndSettle();
    expect(find.text('删除这笔开销？'), findsOneWidget);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(repository.deleted, isTrue);
  });
}
