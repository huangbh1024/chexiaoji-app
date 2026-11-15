import 'package:material_ui/material_ui.dart';

import 'archived_vehicles_page.dart';

/// 打开已归档车辆页；车辆管理页底部入口与后续设置页共用。
Future<void> openArchivedVehicles(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const ArchivedVehiclesPage()),
  );
}
