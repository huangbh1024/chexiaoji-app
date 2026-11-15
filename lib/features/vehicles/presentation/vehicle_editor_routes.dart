import 'package:material_ui/material_ui.dart';

import '../domain/vehicle_editor_models.dart';
import 'vehicle_editor_page.dart';

/// 打开添加 / 编辑爱车档案页。返回 null 表示取消。
Future<VehicleEditorResult?> openVehicleEditor(
  BuildContext context, {
  String? vehicleId,
}) {
  return Navigator.of(context).push<VehicleEditorResult>(
    MaterialPageRoute<VehicleEditorResult>(
      builder: (_) => VehicleEditorPage(vehicleId: vehicleId),
    ),
  );
}
