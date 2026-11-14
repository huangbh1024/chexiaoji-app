import 'package:material_ui/material_ui.dart';

import '../domain/expense_entry_models.dart';
import 'expense_entry_page.dart';

/// 打开记账页；返回保存 / 放弃结果。
Future<ExpenseEntryResult?> openExpenseEntry(
  BuildContext context, {
  required ExpenseEntryArgs args,
}) {
  return Navigator.of(context, rootNavigator: true).push<ExpenseEntryResult>(
    MaterialPageRoute<ExpenseEntryResult>(
      fullscreenDialog: true,
      builder: (_) => ExpenseEntryPage(args: args),
    ),
  );
}
