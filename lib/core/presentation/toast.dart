import 'package:material_ui/material_ui.dart';

/// 全局轻提示：统一浮动位置、圆角与时长，避免被底部导航遮挡。
void showAppToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        duration: const Duration(seconds: 2),
      ),
    );
}
