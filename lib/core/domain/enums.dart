/// 跨页面共用的基础枚举。
///
/// 从 `features/home/domain/home_models.dart` 迁出，供首页、账单页、
/// 记账页与统计页共同引用；`home_models.dart` 仍会 re-export，历史
/// import 不受影响。
library;

/// 车辆动力类型。UI 的颜色 / 图标映射放在各 feature 的 presentation 层。
enum PowertrainType { ev, hev, phev, ice }

enum TrendDirection { up, down, flat, none }

enum ExpenseCategory {
  charging('充电'),
  fuel('加油'),
  maintenance('保养'),
  parking('停车'),
  toll('过路费'),
  carWash('洗车'),
  other('其他');

  const ExpenseCategory(this.label);

  final String label;
}

/// 支出分类的展示名，用于分类筛选 chip 与「保险 / 其他」等合并文案。
extension ExpenseCategoryLabel on ExpenseCategory {
  /// 账单页「其他」分类含保险，文案沿用设计稿的「保险/其他」。
  String get filterLabel => this == ExpenseCategory.other ? '保险/其他' : label;
}
