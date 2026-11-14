import 'package:material_ui/material_ui.dart';

import '../domain/report_models.dart';
import 'monthly_report_page.dart';

/// 打开月度报表：账单页与我的页共用，避免各写一份路由。
Future<void> openMonthlyReport(BuildContext context, ReportScope scope) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => MonthlyReportPage(initialScope: scope),
    ),
  );
}
