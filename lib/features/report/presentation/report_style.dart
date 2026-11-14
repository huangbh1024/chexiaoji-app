import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/domain/enums.dart';
import '../domain/report_models.dart';

/// A4 预览的设计画布（逻辑像素），外层用 FittedBox 缩放到实际宽度。
const double reportPaperWidth = 358;
const double reportPaperHeight = 506;
const double reportPaperRadius = 24;
const double reportPaperPadding = 16;

/// 纸张阴影：比页面卡片更柔、更深，形成「一张纸」的层次。
const List<BoxShadow> reportPaperShadow = [
  BoxShadow(
    color: Color(0x140B1C30),
    blurRadius: 36,
    offset: Offset(0, 16),
    spreadRadius: -8,
  ),
  BoxShadow(
    color: Color(0x0A0B1C30),
    blurRadius: 12,
    offset: Offset(0, 4),
    spreadRadius: -2,
  ),
];

Color reportCategoryColor(ReportCategoryKey key) => switch (key) {
  ReportCategoryKey.charging => AppColors.charging,
  ReportCategoryKey.fuel => AppColors.fuel,
  ReportCategoryKey.maintenance => AppColors.maintenance,
  ReportCategoryKey.parking => AppColors.parking,
  ReportCategoryKey.toll => AppColors.toll,
  ReportCategoryKey.carWashOther => AppColors.carWash,
};

Color reportCategorySoftColor(ReportCategoryKey key) =>
    reportCategoryColor(key).withValues(alpha: 0.16);

Color reportPowertrainColor(PowertrainType powertrain) => switch (powertrain) {
  PowertrainType.ev => AppColors.ev,
  PowertrainType.hev => AppColors.hev,
  PowertrainType.phev => AppColors.phev,
  PowertrainType.ice => AppColors.ice,
};

/// 报表内固定使用浅色纸张，不随 App 深色模式变化。
ThemeData reportPaperTheme() => _paperTheme;

final ThemeData _paperTheme = AppTheme.light();
