import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../domain/home_models.dart';

extension PowertrainVisual on PowertrainType {
  Color get color => switch (this) {
    PowertrainType.ev => AppColors.ev,
    PowertrainType.hev => AppColors.hev,
    PowertrainType.phev => AppColors.phev,
    PowertrainType.ice => AppColors.ice,
  };

  IconData get icon => switch (this) {
    PowertrainType.ev => Icons.bolt_rounded,
    PowertrainType.hev => Icons.local_gas_station_rounded,
    PowertrainType.phev => Icons.ev_station_rounded,
    PowertrainType.ice => Icons.local_gas_station_rounded,
  };
}

extension ExpenseCategoryVisual on ExpenseCategory {
  Color get color => switch (this) {
    ExpenseCategory.charging => AppColors.charging,
    ExpenseCategory.fuel => AppColors.fuel,
    ExpenseCategory.maintenance => AppColors.maintenance,
    ExpenseCategory.parking => AppColors.parking,
    ExpenseCategory.toll => AppColors.toll,
    ExpenseCategory.carWash => AppColors.carWash,
    ExpenseCategory.other => AppColors.other,
  };

  IconData get icon => switch (this) {
    ExpenseCategory.charging => Icons.bolt_rounded,
    ExpenseCategory.fuel => Icons.local_gas_station_rounded,
    ExpenseCategory.maintenance => Icons.build_rounded,
    ExpenseCategory.parking => Icons.local_parking_rounded,
    ExpenseCategory.toll => Icons.toll_rounded,
    ExpenseCategory.carWash => Icons.local_car_wash_rounded,
    ExpenseCategory.other => Icons.receipt_long_rounded,
  };
}
