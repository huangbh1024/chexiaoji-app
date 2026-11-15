import 'package:material_ui/material_ui.dart';

import 'vehicle_management_page.dart';

/// 打开车辆管理页。首页、我的页、统计车辆弹层与开销详情共用。
Future<void> openVehicleManagement(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const VehicleManagementPage()),
  );
}
