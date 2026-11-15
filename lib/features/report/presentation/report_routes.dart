import 'package:material_ui/material_ui.dart';

import '../domain/report_models.dart';
import 'monthly_report_page.dart';

/// 打开月度报表：账单页、我的页与已归档车辆页共用。
///
/// [archivedVehicle] 用于归档车辆：报表范围栏继续保留该车 chip，
/// 即使它已不在在库车辆列表中。
Future<void> openMonthlyReport(
  BuildContext context,
  ReportScope scope, {
  ReportVehicleBrief? archivedVehicle,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => MonthlyReportPage(
        initialScope: scope,
        archivedVehicle: archivedVehicle,
      ),
    ),
  );
}
