# 车辆管理技术方案 · 爱车车库

| 项目 | 内容 |
| --- | --- |
| 关联需求 | [车辆管理需求文档 v0.1](../requirements/vehicle-management.md) |
| 关联方案 | [我的页技术方案](profile.md)、[首页技术方案](home-dashboard.md)、[记账页技术方案](expense-entry.md)、[已归档车辆技术方案](archived-vehicles.md) |
| 设计稿（对应页面） | [Stitch · 车辆管理与爱车车库页（支持归档与删除）](https://stitch.google.com/projects/9615374848161425677?node-id=20559c50d1d3475ea35ffb9e14cd8099) |
| 客户端 | Flutter 3.50.0 stable / Dart 3.14 |
| 平台 | Android（arm64 优先）、iOS |
| 文档版本 | v0.3（归档页拆分） |
| 状态 | P0 已实现（Mock）；接口未确认 |

> 本文档基于**仓库当前已有实现**（首页、账单、统计、我的页、记账页、单笔详情、月度报表已落地；依赖为 `material_ui`、`flutter_riverpod 3.5`、`fl_chart`、`intl`、`pdf`、`printing`、`share_plus`、`path_provider`）编写。新增目录与文件均为拟实施内容，按 `feat/vehicle-management-*` 分支推进。
> 需求口径以[需求文档 v0.1](../requirements/vehicle-management.md) 的「口径建议（Q1–Q14）」为准。接口契约见需求文档 §8，本文档 §6 只描述客户端映射与容错。
> **本页是车库的唯一写入口**。首页、我的页、账单、统计、记账、报表都只读车辆列表；因此本方案的核心不是页面本身，而是把车辆状态的**单一数据源**和**跨页失效**做正确。

---

## 1. 目标与约束

### 1.1 技术目标

- 从任意入口进入本页，首屏 ≤ 1s（Mock，含 140ms 模拟延迟）；下拉刷新 ≤ 800ms；主驾切换 / 归档 / 恢复 / 删除在 Mock 下 ≤ 300ms。
- **单一数据源**：车辆列表、默认主驾、归档状态只由 `VehicleStore` 持有；`vehiclesProvider`、我的页车库、统计筛选、记账预填读取同一份数据，禁止各页各维护一份车辆数组。
- **写入串行**：页面同一时刻只允许一个写操作；确认弹窗内部维护 loading 与失败态，避免重复提交与状态竞争。
- **失效可证明**：每次写操作后按 §7.3 的矩阵失效相关 provider，确保首页、账单、统计、报表、我的页在下一帧读到新数据。
- **空车库是一等状态**：允许 `selectedVehicleIdProvider == null`；首页、记账、统计、账单有各自的空态，不因删除最后一辆车崩溃。
- **不伪造能力**：SOH、保险、年检、车联网字段缺失时返回 `null`，由展示层输出「— / 未录入」；不生成假值。
- 不新增依赖、不新增图片资源；深色模式复用 `AppPalette.dark` / `AppTokens.dark`。

### 1.2 约束

- 不引入 `go_router`：继续用 `Navigator.push(MaterialPageRoute)` + `showModalBottomSheet`，返回即 `pop`。
- 金额全链路整数分（`int cents`），展示统一走 `formatters.dart`；里程整数 km。
- 本页只负责车辆管理与轻量跳转；添加 / 编辑爱车页为 P1 独立页面，本文档只定义路由契约。
- 归档是软移除，删除是硬删除；删除有流水车辆在 P0 直接拒绝（服务端与客户端双重校验）。
- 排序 P1 才支持拖拽；P0 默认主驾置顶 + `sortOrder` 升序，不渲染长按提示。
- 不实现车联网授权、真实同步、车辆图片上传。
- Mock 数据只存在内存，重启 App 恢复种子状态；接口接入后由服务端持久化。
- 不修改 `core/domain/vehicle.dart` 的既有字段语义；管理字段放在新模型，避免污染其他页面。

---

## 2. 现状与复用清单

| 现有能力 | 位置 | 本页用法 |
| --- | --- | --- |
| 色彩 token | `lib/app/theme/app_colors.dart` → `AppPalette` / `AppColors` | 页面、卡片、徽标、归档 / 删除色 |
| 间距 / 圆角 / 阴影 | `lib/app/theme/app_tokens.dart` → `AppTokens` | 页面边距、卡片阴影、顶部栏高度；32 圆角本页局部定义 |
| 字体 | `lib/app/theme/app_typography.dart` | `headlineMd`、`headlineSm`、`bodySm`、`bodyMd`、`labelLg`、`labelMd`、`labelSm`、`displayHero` |
| 车辆基础模型 | `lib/core/domain/vehicle.dart` → `Vehicle` | 车辆 id、名称、车牌、动力、里程、电池 / 油箱容量 |
| 动力色与图标 | `lib/core/presentation/category_style.dart` → `PowertrainVisual` | 车辆图标、徽标、动力构成点 |
| 金额 / 里程 / 日期格式化 | `lib/core/format/formatters.dart` | `formatYuanCompact`、`formatYuanDetail`、`formatKmValue`、`formatCount` |
| 车辆列表 | `lib/features/home/domain/providers.dart` → `vehiclesProvider` | 全 App 车辆选择器；本页写操作后失效 |
| 当前选中车辆 | 同上 → `selectedVehicleIdProvider` | 首页 / 记账 / 统计的默认车辆；本页设主驾后更新 |
| 首页车辆数据 | `lib/features/home/data/mock_home_repository.dart` → `_cars` | `HomeDashboard` 提供能耗、保养、本月支出 |
| 能耗 / 保养模型 | `lib/features/home/domain/home_models.dart` → `Consumption`、`Maintenance` | 卡片三指标与提醒 |
| 账单仓库 | `lib/features/ledger/data/ledger_repository.dart` | 统计每辆车流水数（删除拦截）、当前月支出校验 |
| 我的页车库聚合 | `lib/features/profile/domain/garage_aggregation.dart` | 口径参考（本月能耗、保养紧迫度、动力构成）；本页汇总取全部类别，不复用能耗专用函数 |
| 页面骨架 / 吸顶栏 | `lib/core/widgets/blurred_header_delegate.dart`、各页 `CustomScrollView` | 顶部栏吸顶 |
| 卡片容器 | `lib/core/widgets/app_card.dart` | 提示卡、弹层内卡片；车辆卡 32 圆角自定义 |
| 空 / 错 / 骨架 | `lib/core/widgets/empty_state.dart`、`section_error.dart`、`skeleton_box.dart` | 空车库、模块错误、加载 |
| Toast | `lib/core/presentation/toast.dart` → `showAppToast` | 成功 / 失败轻提示 |
| 路由写法 | `lib/features/expense_entry/presentation/expense_entry_routes.dart`、`report_routes.dart` | 新增 `vehicle_management_routes.dart` |
| 记账入口 | `openExpenseEntry(context, args: ExpenseEntryArgs.create(...))` | 「记一笔」预填车辆 |
| Tab 跳转 | `lib/app/tab.dart` → `appTabProvider`；`lib/app/tab_shell.dart` | 「能耗统计」回壳切 Tab |
| 统计筛选 | `lib/features/stats/domain/providers.dart` → `statsFilterProvider` | 「能耗统计」定位到该车 |
| 我的页车库范围 | `lib/features/profile/domain/providers.dart` → `profileGarageVehicleIdProvider` | 归档 / 删除后纠正选中范围 |
| 弹层模式 | `lib/features/expense_detail/presentation/widgets/delete_expense_sheet.dart` | 确认弹层的 loading / 失败 / 关闭写法 |

### 2.1 现有实现与本页的差异

| 项 | 现状 | 本页处理 |
| --- | --- | --- |
| 车辆列表归属 | `MockHomeRepository` 私有 `_cars`，只读 | 抽出 `VehicleStore` 作为可变数据源；首页仓库改为读 store |
| 默认主驾 | `MockHomeRepository.defaultVehicleId => _cars.first` 写死 | `VehicleStore.primaryVehicleId`，可切换、可持久化（Mock 内存） |
| 当前选中车辆 | `selectedVehicleIdProvider` 为 `String`，车库为空时无法表达 | 改为 `String?`；新增 `effectiveVehicleIdProvider` 兜底 |
| 车辆管理入口 | 首页 / 我的 / 统计 / 详情均为 Toast 占位 | 统一改为推入本页；P0 添加 / 编辑仍 Toast |
| 归档 / 删除 | 无模型、无接口 | 新增 `archivedAt`、`recordCount`、`primaryVehicleId` 规则 |
| 管理字段 | 无 SOH、保险、年检、配置名 | 新增 `VehicleRecord` / `ManagedVehicle` 可选字段；Mock 提供演示值 |
| 车库汇总 | 我的页「车库资产与车辆」按单车 / 全部资产聚合，只含能耗 | 本页汇总全部类别支出 + 动力构成 + 健康项，口径单独定义 |
| 长按排序 | 无 | P1；P0 不显示提示 |
| 车联网卡 | 无 | P0 不展示 |

---

## 3. 结构调整（M0）

### 3.1 新增目录

```
lib/features/vehicles/
├── data/
│   ├── vehicle_repository.dart          # 接口 + 错误码 + 异常
│   ├── mock_vehicle_repository.dart     # 组装 store / home / ledger
│   ├── vehicle_store.dart               # 内存车辆状态：在库 / 归档 / 主驾 / 顺序
│   └── vehicle_seed_data.dart           # 4 辆现有车辆 + 管理字段种子
├── domain/
│   ├── vehicle_models.dart              # ManagedVehicle / GarageOverview / FleetSummary
│   ├── vehicle_presenter.dart           # 三指标、提醒、健康、动力构成、按钮模型
│   └── providers.dart                   # store / repository / garage / command
└── presentation/
    ├── vehicle_management_page.dart      # 页面骨架 + 状态分发
    ├── vehicle_management_routes.dart    # openVehicleManagement / openVehicleEditor(P1)
    ├── vehicle_management_style.dart     # 32 圆角、20 内边距等局部常量
    └── widgets/
        ├── vehicle_management_header.dart
        ├── fleet_summary_card.dart
        ├── vehicle_member_card.dart
        ├── vehicle_metric_row.dart
        ├── vehicle_action_row.dart
        ├── add_vehicle_card.dart
        ├── archived_entry_card.dart
        ├── vehicle_more_sheet.dart
        ├── set_primary_sheet.dart
        ├── archive_vehicle_sheet.dart
        ├── delete_vehicle_sheet.dart
        ├── archived_vehicles_page.dart       # v0.3：归档独立页
        ├── archived_vehicles_routes.dart
        ├── vehicle_empty_state.dart
        └── vehicle_management_skeleton.dart
```

设计稿卡片圆角 32、内边距 20，与现有 `AppTokens.radiusCard = 16` 不同。为避免影响首页 / 账单 / 我的页，本页定义局部常量：

```dart
// lib/features/vehicles/presentation/vehicle_management_style.dart
abstract final class VehicleManagementStyle {
  static const cardRadius = 32.0;
  static const cardPadding = 20.0;
  static const cardGap = 12.0;
  static const innerRadius = 16.0;
  static const actionHeight = 36.0;
  static const iconBox = 44.0;
  static const contentBottomPadding = 32.0;
}
```

若评审确认 32 圆角将用于更多页面，再提升为 `AppTokens.radiusPanel`；本期不扩大公共 token 面。

### 3.2 修改现有文件

| 文件 | 改动 | 影响 |
| --- | --- | --- |
| `lib/features/home/domain/providers.dart` | `homeRepositoryProvider` 注入 `vehicleStoreProvider`；`selectedVehicleIdProvider` 改为 `String?`；新增 `effectiveVehicleIdProvider` | 首页、记账、统计、Tab 壳统一走兜底 id |
| `lib/features/home/data/home_repository.dart` | `defaultVehicleId` 改为 `String?`；`fetchVehicles` 语义改为「在库车辆」 | 接口实现需过滤归档 |
| `lib/features/home/data/mock_home_repository.dart` | 移除私有车辆基础信息，改为读 `VehicleStore`；`_CarMock` 仅保留 dashboard 数据 | 车辆可见性、默认车辆与 store 一致 |
| `lib/app/tab_shell.dart` | FAB 读取 `effectiveVehicleIdProvider`（可空） | 空车库时 FAB 打开记账页并显示「先添加车辆」 |
| `lib/features/expense_entry/domain/providers.dart` | `initialVehicleId ?? effectiveVehicleIdProvider` | 空车库下 `hasNoVehicles` 分支已存在 |
| `lib/features/stats/domain/providers.dart` | `StatsFilter` 初始车辆改用 `effectiveVehicleIdProvider`；`selectVehicle` 同步首页选中 | 空车库时 `vehicleId = null` |
| `lib/features/home/presentation/home_page.dart` 及其 6 个 section widget | 改为 watch `effectiveVehicleIdProvider`；为 null 时渲染空占位，不请求 family | 支持空车库 |
| `lib/features/home/presentation/widgets/vehicle_switcher.dart` | 「管理车辆」「添加车辆」改为 `openVehicleManagement` / `openVehicleEditor`（P1 前 Toast） | 移除「车辆管理页待接入」 |
| `lib/features/profile/presentation/widgets/garage_section.dart` | 「管理爱车」「添加新车」入口改为路由；空态按钮同 | 我的页入口落地 |
| `lib/features/stats/presentation/stats_vehicle_sheet.dart` | 空态「添加爱车」改为路由 | 统计页入口落地 |
| `lib/features/expense_detail/presentation/widgets/detail_vehicle_card.dart` | 车辆箭头改为 `openVehicleManagement` | 详情页入口落地 |
| `lib/features/ledger/data/ledger_repository.dart` | 新增 `Future<int> countRecords({String? vehicleId})` | 删除拦截需要流水数 |
| `lib/features/ledger/data/mock_ledger_repository.dart` | 实现 `countRecords`，复用 24 个月记录窗口与 `_deletedIds` 过滤 | Mock 口径；生产由服务端返回 |
| `lib/features/profile/domain/providers.dart` | `profileGarageVehicleIdProvider` 不新增能力；归档后由命令层纠正范围 | 无接口变化 |
| `test/widget_test.dart` | 适配 `selectedVehicleIdProvider` 可空与 store 注入；4 辆车仍应可见 | 防止首页回归 |

> 不修改 `Vehicle` 既有字段；`specLabel`、SOH、保险、年检属于管理域，放在 `VehicleRecord` / `ManagedVehicle`，避免每个消费方都被迫理解管理字段。

### 3.3 前置改造：选中车辆可空（M0-A）

空车库是需求明确支持的状态。当前 `selectedVehicleIdProvider` 为 `String`，无法表达「没有车」。改造分三步：

1. `SelectedVehicleIdNotifier extends Notifier<String?>`；`build()` 返回 `vehicleRepositoryProvider.primaryVehicleId`。
2. 新增派生 provider：

```dart
/// 当前可用的车辆 id：优先用户选择，其次第一辆在库车，空车库为 null。
final effectiveVehicleIdProvider = Provider<String?>((ref) {
  final vehicles = ref.watch(vehiclesProvider).value ?? const <Vehicle>[];
  if (vehicles.isEmpty) {
    return null;
  }
  final selected = ref.watch(selectedVehicleIdProvider);
  return vehicles.any((vehicle) => vehicle.id == selected)
      ? selected
      : vehicles.first.id;
});
```

3. 所有原来 `ref.watch(selectedVehicleIdProvider)` 的消费方改为 `effectiveVehicleIdProvider`，并在 null 时走各自空态：

| 消费方 | null 时行为 |
| --- | --- |
| 首页 Hero / 能耗 / 趋势 / 构成 / 保养 / 最近记录 | 各模块显示「添加车辆后查看数据」空占位，不请求 family |
| 首页车辆切换条 | 只显示「添加车辆」卡 |
| `AppTabShell` FAB | 传 `initialVehicleId: null`，记账页显示「还没有添加车辆」 |
| 记账页 bootstrap | `vehicles.isEmpty` 分支已有，保持 |
| 统计页 | 车辆筛选为 null（全部车辆无数据），整页空态 |
| 账单页 | 车辆筛选保持 null（全部），流水仍可显示；车辆 chip 只显示「全部车辆」 |

> 这是本页的前置改造，独立提交（`feat/vehicle-management-m0-nullable-vehicle`），先保证现有页面在 4 辆车时行为不变，再接入本页。

---

## 4. 数据流

```
┌──────────────────────────────────────────────────────────────┐
│ VehicleManagementPage                                       │
│                                                              │
│  watch garageProvider ──► VehicleRepository.fetchGarage()    │
│                                 │                            │
│                                 ├─ VehicleStore（在库/归档/主驾/顺序）│
│                                 ├─ HomeRepository.fetchDashboard │
│                                 │    （能耗 / 保养 / 本月支出）  │
│                                 └─ LedgerRepository.countRecords │
│                                      （删除拦截用流水数）        │
│                                                              │
│  watch vehicleCommandProvider ──► setPrimary / archive /     │
│                                   restore / delete           │
│                                        │                     │
│                                        ▼                     │
│                                 VehicleStore 写入            │
│                                        │                     │
│                                        ▼                     │
│                           invalidate 车库 / 车辆列表 / 首页 /  │
│                           账单 / 统计 / 报表 / 我的页          │
└──────────────────────────────────────────────────────────────┘
```

- 读：页面只 watch `garageProvider` 与 `vehicleCommandProvider`；不直接读 store。
- 写：页面调用 `ref.read(vehicleCommandProvider.notifier).setPrimary(...)`，await 结果；成功后关闭弹窗并 Toast。
- 失效：由命令 notifier 统一执行，页面不做散落的 `invalidate`。
- 跨页：`selectedVehicleIdProvider`、账单 / 统计 / 我的页车辆范围由命令层归一化（§7.4）。

---

## 5. 数据模型

### 5.1 车辆记录（store 层）

```dart
// lib/features/vehicles/data/vehicle_store.dart
@immutable
class VehicleRecord {
  const VehicleRecord({
    required this.vehicle,
    required this.specLabel,
    required this.sortOrder,
    required this.isArchived,
    this.archivedAt,
    this.batteryHealthPercent,
    this.insuranceExpiry,
    this.inspectionExpiry,
  });

  final Vehicle vehicle;
  final String specLabel;
  final int sortOrder;
  final bool isArchived;
  final DateTime? archivedAt;
  final int? batteryHealthPercent;
  final DateTime? insuranceExpiry;
  final DateTime? inspectionExpiry;

  String get id => vehicle.id;

  VehicleRecord copyWith({
    bool? isArchived,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
    int? sortOrder,
    int? batteryHealthPercent,
    DateTime? insuranceExpiry,
    DateTime? inspectionExpiry,
  }) { /* ... */ }
}
```

- `Vehicle` 仍是共享基础模型（`core/domain/vehicle.dart`）。
- `specLabel` 为设计稿的「2023款 创世旗舰型 · 纯电」；添加 / 编辑页 P1 负责维护。
- `insuranceExpiry` / `inspectionExpiry` 生产环境为 ISO 日期；Mock 种子用「相对今天的天数」生成，避免演示值过期。
- `batteryHealthPercent` 为 0–100 整数；缺失为 `null`。

### 5.2 展示模型

```dart
// lib/features/vehicles/domain/vehicle_models.dart
@immutable
class ManagedVehicle {
  const ManagedVehicle({
    required this.vehicle,
    required this.specLabel,
    required this.sortOrder,
    required this.isPrimary,
    required this.monthSpendCents,
    required this.recordCount,
    required this.consumption,
    required this.maintenance,
    this.batteryHealthPercent,
    this.insuranceExpiry,
    this.inspectionExpiry,
    this.archivedAt,
  });

  final Vehicle vehicle;
  final String specLabel;
  final int sortOrder;
  final bool isPrimary;
  final int monthSpendCents;
  final int recordCount;
  final Consumption consumption;
  final Maintenance maintenance;
  final int? batteryHealthPercent;
  final DateTime? insuranceExpiry;
  final DateTime? inspectionExpiry;
  final DateTime? archivedAt;

  String get id => vehicle.id;
  bool get isArchived => archivedAt != null;
}
```

```dart
@immutable
class FleetSummary {
  const FleetSummary({
    required this.vehicleCount,
    required this.totalOdometerKm,
    required this.monthSpendCents,
    required this.powertrainCounts,
    required this.pendingIssueCount,
    required this.hasReminderData,
  });

  final int vehicleCount;
  final int totalOdometerKm;
  final int monthSpendCents;

  /// 只包含数量 > 0 的动力类型。
  final Map<PowertrainType, int> powertrainCounts;
  final int pendingIssueCount;
  final bool hasReminderData;
}

@immutable
class ArchivedVehicle {
  const ArchivedVehicle({
    required this.vehicle,
    required this.specLabel,
    required this.sortOrder,
    required this.archivedAt,
  });

  final Vehicle vehicle;
  final String specLabel;
  final int sortOrder;
  final DateTime archivedAt;
}

@immutable
class GarageOverview {
  const GarageOverview({
    required this.vehicles,
    required this.archivedVehicles,
    required this.primaryVehicleId,
    required this.summary,
    required this.fetchedAt,
  });

  final List<ManagedVehicle> vehicles;        // 在库，默认主驾置顶
  final List<ArchivedVehicle> archivedVehicles;
  final String? primaryVehicleId;
  final FleetSummary summary;
  final DateTime fetchedAt;
}
```

`GarageOverview` 不由页面自行拼装；Mock / HTTP 仓库返回完整快照，避免 UI 多源读取。

### 5.3 指标与提醒模型

```dart
enum VehicleMetricTone { normal, accent, warning, danger, muted }

@immutable
class VehicleMetric {
  const VehicleMetric({
    required this.label,
    required this.value,
    required this.unit,
    this.tone = VehicleMetricTone.normal,
    this.missing = false,
  });

  final String label;
  final String value;
  final String unit;
  final VehicleMetricTone tone;
  final bool missing;
}

enum VehicleReminderKind { maintenance, insurance, inspection }

@immutable
class VehicleReminder {
  const VehicleReminder({
    required this.kind,
    required this.text,
    required this.tone,
  });

  final VehicleReminderKind kind;
  final String text;
  final VehicleMetricTone tone;
}
```

展示层只认 `VehicleMetricTone`，颜色映射集中在一个 `_toneColor` 函数，避免 domain 依赖 `Color`。

### 5.4 展示推导（presenter）

```dart
// lib/features/vehicles/domain/vehicle_presenter.dart
abstract final class VehiclePresenter {
  static List<VehicleMetric> metricsOf(ManagedVehicle vehicle, {DateTime? now});
  static VehicleReminder? reminderOf(ManagedVehicle vehicle, {DateTime? now});
  static String healthLabel(FleetSummary summary);
  static String powertrainComposition(Map<PowertrainType, int> counts);
  static String specLine(ManagedVehicle vehicle);
  static bool canSetPrimary(ManagedVehicle vehicle);
  static bool canDelete(ManagedVehicle vehicle, GarageOverview garage);
  static DeleteBlockReason? deleteBlockReason(ManagedVehicle vehicle, GarageOverview garage);
}

enum DeleteBlockReason { isPrimary, hasRecords }
```

**三指标**

| 槽位 | 规则 |
| --- | --- |
| 1 当前里程 | `formatKmValue(odometerKm)` + `km`，`normal` |
| 2 能耗 | ev / phev：`consumption.primary`，标签「动力电耗」，`accent`；hev / ice：`consumption.primary`，标签「综合油耗」，`accent` |
| 3 健康 / 归属 | ev：`batteryHealthPercent` →「电池健康 (SOH)」`%`；< 80 `danger`，否则 `normal`。phev：`consumption.secondary` →「亏电油耗」；缺失 → `missing('亏电油耗')`。hev / ice：`insuranceExpiry` →「车险剩余」`n 天到期`；≤ 30 `danger`，否则 `normal`；缺失 → `missing('车险剩余')` |

缺失指标统一生成：

```dart
VehicleMetric _missing(String label) => VehicleMetric(
  label: label,
  value: '—',
  unit: '未录入',
  tone: VehicleMetricTone.muted,
  missing: true,
);
```

**提醒优先级**（只展示一条）：

1. 保养超期：`maintenance.enabled && (status == overdue || remainingKm < 0)` →「保养已超期 {abs(km)} km」，`danger`。
2. 保险 / 年检 30 天内到期：取剩余天数更少者 →「交强险+商业险 {n} 天后到期」/「年检 {n} 天后到期」，`danger`。
3. 保养预警：`status == warning || progressPercent > 80` →「下次小保养：约 {km} km 后」，`warning`。
4. 保养正常：`enabled` →「下次小保养：约 {km} km 后」，`normal`。
5. 否则 `null`，不显示提醒行左侧。

**健康项计数**

```dart
int pendingIssueCount(List<ManagedVehicle> vehicles, DateTime now) {
  var count = 0;
  for (final vehicle in vehicles) {
    final m = vehicle.maintenance;
    if (m.enabled && m.status != MaintenanceStatus.normal) count++;
    if (_daysUntil(vehicle.insuranceExpiry, now) case final days? when days <= 30) count++;
    if (_daysUntil(vehicle.inspectionExpiry, now) case final days? when days <= 30) count++;
  }
  return count;
}
```

- `hasReminderData = 任一车 maintenance.enabled || insuranceExpiry != null || inspectionExpiry != null`。
- `healthLabel`：`!hasReminderData` → `''`（UI 不渲染徽标）；`pendingIssueCount == 0` → 「全部在库良好」；否则「{n} 项待处理」。

**动力构成**

```dart
String powertrainComposition(Map<PowertrainType, int> counts) {
  const order = [
    PowertrainType.ev,
    PowertrainType.phev,
    PowertrainType.hev,
    PowertrainType.ice,
  ];
  const label = {
    PowertrainType.ev: '纯电',
    PowertrainType.phev: '插混',
    PowertrainType.hev: '油混',
    PowertrainType.ice: '燃油',
  };
  return [
    for (final type in order)
      if ((counts[type] ?? 0) > 0) '${label[type]} ${counts[type]} 辆',
  ].join('  |  ');
}
```

**删除判断**

```dart
DeleteBlockReason? deleteBlockReason(ManagedVehicle v, GarageOverview g) {
  if (v.isPrimary && g.vehicles.length > 1) {
    return DeleteBlockReason.isPrimary;
  }
  if (v.recordCount > 0) {
    return DeleteBlockReason.hasRecords;
  }
  return null;
}
```

> 顺序很重要：默认主驾优先提示「先切换主驾」，即使它同时有流水，也先解决主驾问题；切换后再次删除才会进入「先归档」提示。

### 5.5 格式化与文案

| 内容 | 实现 |
| --- | --- |
| 总览里程 | `formatKmValue(totalOdometerKm)` + 单位 `km` |
| 总览金额 | `formatYuanCompact(monthSpendCents)`（`¥` + 千分位，无小数） |
| 卡片金额 | `formatYuanDetail(monthSpendCents)` |
| 电耗 / 油耗 | `formatOneDecimal(value)`；单位取 `EnergyValue.unit` |
| 百分比 | `formatPercentInt(value)` |
| 天数 | `'$days 天到期'` / `'$days 天后到期'` |
| 车牌 | `vehicle.plate.isEmpty ? '未填写车牌' : vehicle.plate.toUpperCase()` |
| 归档日期 | `DateFormat('yyyy-MM-dd')` + 「 归档」 |
| 副标题 | `specLabel` 为空时只显示车牌，不留空分隔符 |

不新增货币符号硬编码；`¥` 统一从 formatter 输出或单独小号渲染（总览卡需要数字与符号分号）。

---

## 6. 数据层

### 6.1 仓库接口

```dart
// lib/features/vehicles/data/vehicle_repository.dart
abstract class VehicleRepository {
  String? get primaryVehicleId;

  Future<GarageOverview> fetchGarage();

  Future<void> setPrimary(String vehicleId);

  Future<void> archive(String vehicleId);

  Future<void> restore(String vehicleId);

  Future<void> delete(String vehicleId);
}

enum VehicleErrorCode {
  isPrimary,
  hasRecords,
  notFound,
  conflict,
  limitReached,
  unknown,
}

class VehicleOperationException implements Exception {
  const VehicleOperationException(this.code, [this.message]);

  final VehicleErrorCode code;
  final String? message;
}
```

添加 / 编辑接口 P1 再由 `VehicleEditorRepository` 或本接口扩展，避免本期空实现污染 UI。

### 6.2 内存状态

```dart
// lib/features/vehicles/data/vehicle_store.dart
class VehicleStore {
  VehicleStore({required List<VehicleRecord> records, String? primaryVehicleId})
    : _records = [...records],
      _primaryVehicleId = primaryVehicleId;

  final List<VehicleRecord> _records;
  String? _primaryVehicleId;

  String? get primaryVehicleId => _primaryVehicleId;

  /// 演示种子：4 辆现有 Mock 车辆，汉 EV 为主驾。
  factory VehicleStore.seeded() => VehicleStore(
    records: seedVehicleRecords(),
    primaryVehicleId: 'byd-han-ev',
  );

  List<VehicleRecord> get active {
    final list = _records.where((r) => !r.isArchived).toList()
      ..sort(_compare);
    return list;
  }

  List<VehicleRecord> get archived {
    final list = _records.where((r) => r.isArchived).toList()
      ..sort((a, b) => (b.archivedAt ?? DateTime(0)).compareTo(a.archivedAt ?? DateTime(0)));
    return list;
  }

  int _compare(VehicleRecord a, VehicleRecord b) {
    if (a.id == _primaryVehicleId) return -1;
    if (b.id == _primaryVehicleId) return 1;
    return a.sortOrder.compareTo(b.sortOrder);
  }

  VehicleRecord require(String id) { /* 找不到抛 notFound */ }

  String? successorOf(String id) {
    final remaining = active.where((r) => r.id != id).toList();
    return remaining.isEmpty ? null : remaining.first.id;
  }

  void setPrimary(String id) {
    require(id).isArchived ? throw ... : _primaryVehicleId = id;
  }

  void archive(String id) {
    final record = require(id);
    if (record.isArchived) return;
    final wasPrimary = _primaryVehicleId == id;
    final successor = wasPrimary ? successorOf(id) : null;
    _replace(record.copyWith(isArchived: true, archivedAt: DateTime.now()));
    if (wasPrimary) _primaryVehicleId = successor;
  }

  void restore(String id) {
    final record = require(id);
    if (!record.isArchived) return;
    _replace(
      record.copyWith(
        isArchived: false,
        clearArchivedAt: true,
        sortOrder: nextSortOrder, // 恢复到列表末尾，符合需求 §6.11
      ),
    );
    _primaryVehicleId ??= id;
  }

  int get nextSortOrder =>
      _records.fold(-1, (max, record) => record.sortOrder > max ? record.sortOrder : max) + 1;

  void delete(String id) {
    final record = require(id);
    if (_primaryVehicleId == id && active.length > 1) {
      throw const VehicleOperationException(VehicleErrorCode.isPrimary);
    }
    _records.removeWhere((r) => r.id == id);
    if (_primaryVehicleId == id) _primaryVehicleId = null;
  }
}
```

约束由 store 保证，仓库与 UI 只做提示；服务端仍需返回同样的 409。

### 6.3 Mock 仓库

```dart
class MockVehicleRepository implements VehicleRepository {
  MockVehicleRepository({
    required this.store,
    required this.home,
    required this.ledger,
    this.now = DateTime.now,
    this.delay = const Duration(milliseconds: 140),
  });

  final VehicleStore store;
  final HomeRepository home;
  final LedgerRepository ledger;
  final DateTime Function() now;
  final Duration delay;

  @override
  String? get primaryVehicleId => store.primaryVehicleId;

  @override
  Future<GarageOverview> fetchGarage() async {
    await Future<void>.delayed(delay);
    final records = store.active;
    final dashboards = await Future.wait(
      records.map((record) => home.fetchDashboard(record.id)),
    );
    final counts = await Future.wait(
      [for (final record in records) ledger.countRecords(vehicleId: record.id)],
    );
    final vehicles = <ManagedVehicle>[
      for (var i = 0; i < records.length; i++)
        ManagedVehicle(
          vehicle: records[i].vehicle,
          specLabel: records[i].specLabel,
          sortOrder: records[i].sortOrder,
          isPrimary: records[i].id == store.primaryVehicleId,
          monthSpendCents: dashboards[i].summary.monthSpendCents,
          recordCount: counts[i],
          consumption: dashboards[i].consumption,
          maintenance: dashboards[i].maintenance,
          batteryHealthPercent: records[i].batteryHealthPercent,
          insuranceExpiry: records[i].insuranceExpiry,
          inspectionExpiry: records[i].inspectionExpiry,
        ),
    ];
    final archived = [
      for (final record in store.archived)
        ArchivedVehicle(
          vehicle: record.vehicle,
          specLabel: record.specLabel,
          sortOrder: record.sortOrder,
          archivedAt: record.archivedAt!,
        ),
    ];
    return GarageOverview(
      vehicles: vehicles,
      archivedVehicles: archived,
      primaryVehicleId: store.primaryVehicleId,
      summary: _summaryOf(vehicles),
      fetchedAt: now(),
    );
  }

  // 写操作：先做 store 级校验，再统一抛出 VehicleOperationException。
}
```

- `Future.wait` 保证 4 辆车只等待一轮；生产接口由 `/garage` 一次返回，客户端不做 N+1。
- 归档车辆用独立 `ArchivedVehicle`，不带 `consumption` / `maintenance` / `recordCount`，避免为归档列表伪造指标；P1 若支持「彻底清理归档」，再补真实计数。
- 删除前 `MockVehicleRepository` 先调用 `ledger.countRecords(vehicleId: id)`，`> 0` 直接抛 `VehicleErrorCode.hasRecords`，不进入 store 删除。

### 6.4 流水数

`LedgerRepository` 新增：

```dart
/// 账号生命周期内、未删除的记录数；传入 vehicleId 时只统计该车。
Future<int> countRecords({String? vehicleId});
```

Mock 实现：

```dart
@override
Future<int> countRecords({String? vehicleId}) async {
  final now = DateTime.now();
  final records = recordsBetween(DateTime(now.year - 2, now.month), now)
      .where((record) => !_deletedIds.contains(record.id))
      .where((record) => vehicleId == null || record.vehicleId == vehicleId);
  return records.length;
}
```

- Mock 的账本只生成近 24 个月记录，`countRecords` 与 `fetchLifetimeStats` 使用同一窗口，保证「有流水」判断与用户可见历史一致。
- 生产接口在 `/garage` 的每个车辆上返回 `recordCount`，客户端不再逐车请求。

### 6.5 Provider

```dart
// lib/features/vehicles/domain/providers.dart
final vehicleStoreProvider = Provider<VehicleStore>((ref) => VehicleStore.seeded());

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  return MockVehicleRepository(
    store: ref.watch(vehicleStoreProvider),
    home: ref.watch(homeRepositoryProvider),
    ledger: ref.watch(ledgerRepositoryProvider),
  );
});

final garageProvider = FutureProvider<GarageOverview>((ref) {
  return ref.watch(vehicleRepositoryProvider).fetchGarage();
});
```

- `homeRepositoryProvider` 需要 `vehicleStoreProvider`，而 `vehicleRepositoryProvider` 需要 `homeRepositoryProvider`；依赖方向为 `home → store`、`vehicles → home + store`，无环。
- `garageProvider` 不使用 `autoDispose`：页面短时返回再进入不应重新拉取；写操作后显式失效。
- 测试通过 `vehicleStoreProvider.overrideWithValue(...)` 注入固定状态。

### 6.6 错误映射

| 仓库异常 / HTTP | 页面文案 |
| --- | --- |
| `isPrimary` | 「请先将其他座驾设为主驾后再删除。」 |
| `hasRecords` | 「该车辆有历史流水，请先归档。」 |
| `notFound` | 「车辆已不存在，已为你刷新车库。」并关闭弹窗 + 刷新 |
| `conflict` | 「车辆信息已更新，请重试。」并刷新车库 |
| `limitReached` | 「车库车辆已达上限。」 |
| `unknown` / 网络 | 「操作失败，请重试。」 |

错误文案显示在确认弹窗内（`bodySm`、`error`），不关闭弹窗；`notFound` / `conflict` 例外，关闭并刷新。

---

## 7. 状态管理

### 7.1 车库读取

```dart
class VehicleManagementPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final garage = ref.watch(garageProvider);
    final command = ref.watch(vehicleCommandProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448),
          child: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: BlurredHeaderDelegate(
                      height: context.tokens.headerHeight,
                      child: VehicleManagementHeader(
                        summary: garage.value?.summary,
                        isBusy: command.isBusy,
                      ),
                    ),
                  ),
                  ..._buildBody(context, ref, garage, command),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- 顶部栏副标题需要汇总数量；`garage` 加载中显示「加载中」，失败显示「数据待刷新」。
- 内容按 `garage.when(loading/error/data)` 分发；总览与列表同属一个快照，避免一个显示新数据、一个显示旧数据。
- 错误态整页显示 `SectionError('车库加载失败')` + 重试，顶部栏与添加卡仍可用（添加页 P1 前为 Toast）。

### 7.2 写命令

```dart
enum VehicleCommandKind { setPrimary, archive, restore, delete }

@immutable
class VehicleCommandState {
  const VehicleCommandState({this.pending, this.errorCode, this.errorMessage});

  final VehicleCommandKind? pending;
  final VehicleErrorCode? errorCode;
  final String? errorMessage;

  bool get isBusy => pending != null;
}

final vehicleCommandProvider =
    NotifierProvider<VehicleCommandNotifier, VehicleCommandState>(
      VehicleCommandNotifier.new,
    );

class VehicleCommandNotifier extends Notifier<VehicleCommandState> {
  @override
  VehicleCommandState build() => const VehicleCommandState();

  Future<bool> setPrimary(String id) => _run(
    VehicleCommandKind.setPrimary,
    () => ref.read(vehicleRepositoryProvider).setPrimary(id),
    affectedVehicleId: id,
  );

  Future<bool> archive(String id) => _run(
    VehicleCommandKind.archive,
    () => ref.read(vehicleRepositoryProvider).archive(id),
    affectedVehicleId: id,
  );

  Future<bool> restore(String id) => _run(
    VehicleCommandKind.restore,
    () => ref.read(vehicleRepositoryProvider).restore(id),
  );

  Future<bool> delete(String id) => _run(
    VehicleCommandKind.delete,
    () => ref.read(vehicleRepositoryProvider).delete(id),
    affectedVehicleId: id,
  );

  Future<bool> _run(
    VehicleCommandKind kind,
    Future<void> Function() action, {
    String? affectedVehicleId,
  }) async {
    if (state.isBusy) {
      return false;
    }
    state = VehicleCommandState(pending: kind);
    try {
      await action();
      if (kind == VehicleCommandKind.setPrimary && affectedVehicleId != null) {
        // 需求 Q11：首页立即切到新主驾
        ref.read(selectedVehicleIdProvider.notifier).select(affectedVehicleId);
      }
      _normalizeScopes(affectedVehicleId);
      _invalidateAll();
      state = const VehicleCommandState();
      return true;
    } on VehicleOperationException catch (error) {
      state = VehicleCommandState(
        errorCode: error.code,
        errorMessage: error.message,
      );
      return false;
    } catch (_) {
      state = const VehicleCommandState(
        errorCode: VehicleErrorCode.unknown,
        errorMessage: '操作失败，请重试',
      );
      return false;
    }
  }
}
```

- 弹窗内部等待 `Future<bool>`；`true` 关闭并 Toast，`false` 保持弹窗、显示 `state.errorMessage`。
- 命令 notifier 不持有弹窗；弹窗自行管理本地 `_submitting` 与错误展示，命令层只提供结果。
- 成功后重置 state，避免错误文案残留到下个弹窗。

### 7.3 失效矩阵

| 操作 | 失效 / 更新 |
| --- | --- |
| 设为默认主驾 | `garageProvider`、`vehiclesProvider`、`selectedVehicleIdProvider → select(id)`、`homeDashboardProvider`（family 全部）、`breakdownProvider`、`recordsProvider`、`trendProvider` |
| 归档 | 同上；另 `profileGarageProvider`、`ledgerSummaryProvider`、`ledgerRecordsProvider`、`statsOverviewProvider`、`statsBreakdownProvider`、`statsRecentProvider`、`statsTrendProvider`、`monthlyReportProvider` |
| 恢复 | 同归档 |
| 删除 | 同归档 |
| 添加 / 编辑（P1） | 同归档；新增时把新 id 设为首页选中 |

实现：

```dart
void _invalidateAll() {
  ref.invalidate(garageProvider);
  ref.invalidate(vehiclesProvider);
  ref.invalidate(homeDashboardProvider);
  ref.invalidate(breakdownProvider);
  ref.invalidate(recordsProvider);
  ref.invalidate(trendProvider);
  ref.invalidate(profileGarageProvider);
  ref.invalidate(ledgerSummaryProvider);
  ref.invalidate(ledgerRecordsProvider);
  ref.invalidate(statsOverviewProvider);
  ref.invalidate(statsBreakdownProvider);
  ref.invalidate(statsRecentProvider);
  ref.invalidate(statsTrendProvider);
  ref.invalidate(monthlyReportProvider);
}
```

- Riverpod 3 中对 family provider 整体 `invalidate` 会失效全部实例；无需逐个 key。
- `ledgerRecordsProvider` 是 `NotifierProvider.autoDispose`，invalidate 后自动重拉当前筛选第一页。
- 报表页若未打开，`monthlyReportProvider` 无实例，invalidate 无成本。

### 7.4 作用域归一化

归档 / 删除 / 设主驾后，纠正所有持有车辆 id 的筛选：

```dart
void _normalizeScopes(String? affectedVehicleId) {
  final primary = ref.read(vehicleRepositoryProvider).primaryVehicleId;

  if (affectedVehicleId == null) {
    ref.read(selectedVehicleIdProvider.notifier).select(primary);
    return;
  }

  if (ref.read(selectedVehicleIdProvider) == affectedVehicleId) {
    ref.read(selectedVehicleIdProvider.notifier).select(primary);
  }

  if (ref.read(ledgerFilterProvider).vehicleId == affectedVehicleId) {
    ref.read(ledgerFilterProvider.notifier).selectVehicle(null);
  }

  if (ref.read(statsFilterProvider).vehicleId == affectedVehicleId) {
    ref.read(statsFilterProvider.notifier).selectVehicle(primary);
  }

  if (ref.read(profileGarageVehicleIdProvider) == affectedVehicleId) {
    ref.read(profileGarageVehicleIdProvider.notifier).select(null);
  }
}
```

- 设主驾时 `affectedVehicleId` 为新主驾 id，但 `selectedVehicleIdProvider` 未必等于旧主驾；需求 Q11 要求首页立即切到新主驾，因此 `_run` 在调用 `_normalizeScopes` 前先执行一次 `select(affectedVehicleId)`（见 §7.2）。
- 归档 / 删除后若首页选中的正是该车，切到新主驾；若车库为空，切到 `null`。
- 账单页选择「全部车辆」；统计页选择新主驾（没有则全部）；我的页车库回到「全部资产」。
- 归一化必须发生在 `invalidate` 之前或之后均可，但要在同一微任务内完成，避免中间帧请求已删除车辆。

### 7.5 竞态与生命周期

- 同一时刻只允许一个写操作；命令层 `state.isBusy` 拦截，UI 同时禁用按钮。
- 页面在写操作期间被返回：命令仍会完成并失效 provider；不允许中途取消，避免「界面关闭但服务端已写」的不一致。
- 连续快速点击「确认」：弹窗本地 `_submitting` + 命令层双保险。
- 页面 `autoDispose` 不用于 `garageProvider`；`VehicleCommandNotifier` 页面级存活即可，离开页面时未完成操作不影响数据一致性。
- 下拉刷新与写操作并发：刷新先读取 store 当前状态；若写操作在刷新途中完成，随后的 invalidate 会触发第二次读取，最终一致。

### 7.6 乐观更新取舍

- **不做乐观更新**：归档 / 删除 / 主驾切换都等待仓库返回后再关闭弹窗、移出卡片。Mock 延迟 140ms，用户感知可控；避免失败回滚导致卡片「消失又出现」。
- 成功后立即 invalidate，页面可能在下一帧短暂显示骨架；为减少闪烁，`garageProvider` 使用上一份数据 + `AsyncValue.isRefreshing`，列表项按 id 做 `ValueKey`，未变化卡片不重建。
- 若后续接入网络后延迟明显，再引入「本地先移出 + 失败回滚」；本期不提前复杂化。

---

## 8. UI 实现

### 8.1 页面骨架

- `Scaffold` + `Center` + `ConstrainedBox(maxWidth: 448)`，与 `AppTabShell` 一致。
- `CustomScrollView`：
  1. `SliverPersistentHeader(pinned: true)` → `VehicleManagementHeader`。
  2. `SliverPadding` + `SliverList`：总览卡、区块标题、车辆卡、添加卡、已归档入口。
  3. 底部 `SliverToBoxAdapter` 留白 `contentBottomPadding + MediaQuery.padding.bottom`。
- 不渲染底部导航与 FAB；`SafeArea(bottom: false)`，底部留白自行处理。
- 加载态：顶部栏真实；内容为 `VehicleManagementSkeleton`（总览卡骨架 + 3 张卡骨架 + 添加卡）。
- 空态：总览显示 0；区块标题「共 0 辆」；`EmptyState(icon: directions_car, title: '车库还是空的', actionLabel: '添加第一辆爱车')`；添加卡仍显示；已归档入口按数据决定。
- 错误态：`SectionError(message: '车库加载失败', onRetry: () => ref.invalidate(garageProvider))`；添加卡保留。

### 8.2 顶部栏

```dart
class VehicleManagementHeader extends StatelessWidget {
  const VehicleManagementHeader({super.key, required this.summary, required this.isBusy});

  final FleetSummary? summary;
  final bool isBusy;
  // 40 返回 + 标题 / 副标题 + 添加胶囊
}
```

- 返回：`IconButton` 44 × 44，`Navigator.maybePop`；`isBusy` 时禁用。
- 副标题：`summary == null` → 「车库数据加载中」；否则「名下在库 {n} 辆座驾 · {healthLabel}」。
- 添加按钮：P0 `showAppToast(context, '添加爱车页待接入')`；P1 `openVehicleEditor(context)`。
- 高度固定 64，文字 `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.2)` 防止溢出。

### 8.3 总览卡 `FleetSummaryCard`

- `Container` + `BoxDecoration` 线性渐变（`palette.heroStart → heroMid → heroEnd`）+ 32 圆角 + `tokens.heroShadow`。
- 背景装饰：右下 192 圆白色 10% 模糊光斑、左上 144 圆 `tertiary` 20% 光斑、12px 点阵（`CustomPainter` 或遮罩），全部 `IgnorePointer` 且裁切在卡片内。
- 内容：
  - 顶部行：28 圆白色 20% 底 + `garage` 图标；「车库资产总览」；右侧健康徽标。
  - 两列指标：`Expanded` 两个半透明深色盒（黑 10% + 白 15% 描边 + 16 圆角 + 12 内边距），金额 / 里程为 `displayHero.copyWith(fontSize: 28)`。
  - 构成行：`Wrap` 或 `Row` + `|` 分隔；动力点 8 × 8。
- 数字使用 `FittedBox(fit: BoxFit.scaleDown, alignment: centerLeft)`，最多占满半宽。
- 点击整卡滚动到列表顶部：`ScrollController.animateTo(headerHeight, ...)`；P0 若不需要可不加点击（避免误触）。

### 8.4 车辆卡 `VehicleMemberCard`

```dart
class VehicleMemberCard extends StatelessWidget {
  const VehicleMemberCard({
    super.key,
    required this.vehicle,
    required this.isBusy,
    required this.onRecord,
    required this.onStats,
    required this.onSetPrimary,
    required this.onEdit,
    required this.onMore,
  });
```

- 外层 `Container`：白底、32 圆角、20 内边距、1px 描边；默认主驾用 `primary.withValues(alpha: 0.25)` + `tokens.selectedShadow`；普通用 `outlineVariant` 60% + `tokens.cardShadow`。
- 头部 `Row`：44 × 44 动力图标容器（动力色 15% 底 + 图标 24）→ 名称列 → 更多按钮 32 × 32。
  - 名称行：`Flexible(Text(name, maxLines: 1, overflow: ellipsis))` + 主驾徽标 / 动力徽标。
  - 第二行：车牌胶囊（`surfaceContainer`、等宽、6 圆角）+ 副标题（`specLabel`，`bodySm`，`Expanded`）。
- 指标区：`Padding(vertical: 16)` + 上下 `Border`（`outlineVariant`）+ `Row` 三个 `Expanded`，每列间无需竖线（设计稿无竖线）。
- 提醒行：`Row` + `Expanded` 左提醒 + 右侧本月支出；窄屏用 `Wrap`。
- 操作行：`Row` 三个 `Expanded` 按钮，高 36、间距 8；「记一笔」默认主驾为主色浅底 + 主色文字，其余中性底。
- 更多按钮与操作按钮 `onTap` 不冒泡到卡片；卡片本体 P0 不响应点击。

### 8.5 操作行 `VehicleActionRow`

| 状态 | 按钮模型 |
| --- | --- |
| 默认主驾 | `record`（primary soft）、`stats`、`edit` |
| 普通 | `record`（neutral）、`setPrimary`、`edit` |

- `isBusy`：整组 `IgnorePointer` + `AnimatedOpacity(0.6)`。
- 按钮内 `Icon(size: 16) + SizedBox(4) + Text(label)`，超出宽度用 `FittedBox`。
- 「设为主驾」打开 `SetPrimarySheet`；「编辑档案」P0 Toast。

### 8.6 弹层与确认弹窗

统一使用 `showModalBottomSheet`：

```dart
Future<T?> showVehicleSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: builder(context),
    ),
  );
}
```

- 弹层外壳：白底、顶部 32 圆角、拖拽把手、最大高度 70% 屏高、`SafeArea(top: false)`。
- `VehicleMoreSheet`：4 个菜单项 + 分隔线；当前主驾项禁用并显示「当前主驾」胶囊；点击返回枚举 `VehicleMoreAction?`，由页面打开下一个弹窗。
- `SetPrimarySheet`：图标 + 标题 + 正文 + 双按钮；内部 `_submitting`，成功后 `pop(true)`。
- `ArchiveVehicleSheet`：动态正文（继任 / 空车库）；确认按钮 `secondaryContainer`。
- `DeleteVehicleSheet`：三种形态（主驾拦截 / 有流水拦截 / 可删除）；拦截形态只返回 `DeleteBlockReason` 或触发「去归档」回调。
- `ArchivedVehiclesSheet`：列表 + 恢复按钮；恢复成功后 `pop` 并 Toast；列表为空时自动关闭。

弹窗都通过返回结果驱动页面，不在弹窗内部直接 `ref.invalidate`（除恢复外），保证逻辑集中。

### 8.7 已归档入口与恢复

- `ArchivedEntryCard`：仅 `archivedVehicles.isNotEmpty` 时插入；`AppCard` 样式（16 圆角、16 内边距）+ 图标 + 文案 + 箭头。
- 点击改为 `openArchivedVehicles(context)`，推入独立页面「已归档车辆」；页面内的恢复、查看历史报表与彻底删除见[已归档车辆技术方案](archived-vehicles.md)。
- 原 `ArchivedVehiclesSheet`（底部恢复弹层）在 v0.3 移除，避免两套归档写入口并存。
- 从归档页返回后，本页依赖 `garageProvider` 失效刷新入口计数；归档页恢复的车辆出现在车库末尾，车库原本为空时自动成为默认主驾。

### 8.8 加载 / 空 / 错误

- `VehicleManagementSkeleton`：`SkeletonBox` 组合；总览卡 140 高、车辆卡 220 高、添加卡 120 高；不显示可点击按钮。
- 空车库：总览 + 空态 + 添加卡；已归档入口若有归档仍显示（用户可以恢复）。
- 模块错误：整页 `SectionError`；若之前有缓存数据（`garage.hasValue`），保留旧内容并在顶部显示「刷新失败」细条，点击重试。
- 下拉刷新：`RefreshIndicator`；`onRefresh` 执行 `ref.invalidate(garageProvider); await ref.read(garageProvider.future);` 并吞掉异常（错误态由页面展示）。

### 8.9 深色模式

- 所有颜色走 `context.palette` / `context.tokens`，不写死浅色值。
- Hero 渐变在深色下使用 `palette.heroStart/heroMid/heroEnd`（当前深色值仍为绿色系）；若对比不足，在 `VehicleManagementStyle.heroGradientFor(palette)` 中降低亮度 10%。
- 白色内描边在深色用 `palette.cardBorder`（`#14FFFFFF`）。
- 归档 / 删除 / 主驾徽标的浅底使用 `withValues(alpha:)`，确保深色下可见。
- 无独立深色设计稿，验收以对比度 ≥ 4.5:1 与现有页面一致性为准。

### 8.10 无障碍

- 返回、更多、添加按钮 ≥ 44 × 44；操作按钮高 36 但外扩点击区到 44（`InkWell` + `Padding`）。
- 语义：
  - 更多：「管理{车名}」；
  - 记一笔：「为{车名}记一笔」；
  - 设为主驾：「将{车名}设为默认主驾」；
  - 主驾徽标：「默认主驾」；
  - 健康徽标：「{n} 项待处理」或「全部在库良好」。
- 不依赖颜色传达信息：提醒同时有图标与文案；危险操作有「删除」字样。
- 支持 1.3 倍字号；车辆卡可自然增高，指标数值 `FittedBox`，按钮文字不截断。

### 8.11 动效

- 卡片移出：`AnimatedSize` + `AnimatedOpacity` 250ms；列表 `ValueKey(vehicle.id)` 保持其他卡片状态。
- 主驾切换：徽标与描边用 `AnimatedContainer` 200ms；列表重排不播放位移动画，避免「跳跃」。
- 弹层：`showModalBottomSheet` 默认动画 + `isScrollControlled`；不自定义曲线，保持系统一致。
- 打开更多菜单后 180ms 再打开确认弹窗，避免遮罩叠加；`await Future<void>.delayed(...)` 前先检查 `context.mounted`。
- 减少动效：读取 `MediaQuery.disableAnimationsOf(context)`，关闭卡片收起与淡入。

---

## 9. 交互与跳转

### 9.1 入口路由

```dart
// lib/features/vehicles/presentation/vehicle_management_routes.dart
Future<void> openVehicleManagement(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const VehicleManagementPage()),
  );
}
```

- 我的页、首页、统计弹层、详情页统一调用该函数。
- 从 `AppTabShell` 的 Tab 页进入时，二级页覆盖底部导航；返回恢复原 Tab 与滚动位置（`IndexedStack` 保留状态）。
- 统计车辆弹层：先 `pop` 弹层，再推入本页；避免弹层留在路由栈。

### 9.2 记一笔

```dart
await openExpenseEntry(
  context,
  args: ExpenseEntryArgs.create(initialVehicleId: vehicle.id),
);
if (context.mounted) {
  ref.invalidate(garageProvider);
  ref.invalidate(vehiclesProvider);
}
```

- 记账页为 `fullscreenDialog`，保存成功后已自行失效 `vehiclesProvider`；本页再失效 `garageProvider` 以更新本月支出与里程。
- 用户取消返回：不刷新（返回值为 null）。
- 车辆在记账期间被其他端删除：记账页保存会抛「车辆不存在」，保持现有错误处理。

### 9.3 能耗统计

```dart
void _openStats(BuildContext context, WidgetRef ref, String vehicleId) {
  ref.read(statsFilterProvider.notifier).selectVehicle(vehicleId);
  ref.read(appTabProvider.notifier).select(AppTab.stats);
  Navigator.of(context).popUntil((route) => route.isFirst);
}
```

- 先设置筛选再回壳，保证统计页构建时已是该车。
- `statsFilterProvider.selectVehicle` 会同步 `selectedVehicleIdProvider`（现有实现），本页无需重复设置。
- 从本页进入时，统计页的周期 / 锚点保持上次状态；只改变车辆范围。

### 9.4 添加 / 编辑（P1 契约）

```dart
class VehicleEditorResult {
  const VehicleEditorResult({required this.vehicleId, required this.created});

  final String vehicleId;
  final bool created;
}

Future<VehicleEditorResult?> openVehicleEditor(
  BuildContext context, {
  String? vehicleId,
});
```

- `vehicleId == null` 为新增，否则编辑。
- 返回 `null` 表示取消；返回结果后本页失效车库并滚动到该车（新增时滚动到底部）。
- P0 两者均为 Toast；路由常量可以提前定义但页面未实现时不引用，避免悬空路由。

### 9.5 系统返回

- 顶部返回与系统返回一致：`Navigator.maybePop`。
- 写操作进行中：返回按钮禁用，`PopScope(canPop: !command.isBusy)`；弹窗打开时由弹窗自身消费返回（关闭弹窗）。
- 从统计 Tab 进入时，返回统计页；不重置统计筛选（已切到该车）。

---

## 10. 性能

- Mock 车库一次请求返回全部车辆；`Future.wait` 并发获取 dashboard，4 辆车约 140ms。
- 生产 `/garage` 单接口返回，避免 N+1；服务端聚合本月支出与流水数。
- 列表最多 10 辆（建议上限），无需虚拟滚动；仍使用 `SliverList`，为未来增长留余地。
- 卡片 `RepaintBoundary` 包裹，主驾切换只重绘受影响卡片。
- 不在 `build` 中排序 / 聚合：`GarageOverview` 在仓库返回前完成排序与汇总。
- 图片 / 图标全部使用 Material Icons，无网络图片。
- 页面进入不阻塞首帧：顶部栏先渲染，内容骨架随后替换。
- 写操作后 `invalidate` 面较大，但只重拉当前可见页面；账单 / 统计未挂载时无请求。

---

## 11. 错误与边界

| 场景 | 处理 |
| --- | --- |
| 车库为空 | 总览 0 / ¥0；空态 + 添加卡；已归档入口按需；首页 / 记账 / 统计各自的空态 |
| 删除唯一车辆 | 允许（无流水时）；删除后 `primaryVehicleId = null`；首页切到空态 |
| 归档唯一车辆 | 允许；确认文案说明车库清空；归档后空车库；可从已归档恢复 |
| 归档默认主驾 | 继任 = 剩余排序最前；确认弹窗写明；无继任则主驾置空 |
| 删除默认主驾（多车） | 拦截；引导切换主驾；不调用接口 |
| 删除有流水车辆 | 拦截；引导归档；不调用接口 |
| 其他端删除车辆 | 写操作返回 404 → 关闭弹窗、刷新车库、Toast「车辆已不存在」 |
| 并发写冲突 | 409 → 关闭弹窗、刷新、Toast「车辆信息已更新，请重试」 |
| 归档车辆仍在筛选中 | `_normalizeScopes` 清空账单 / 切统计 / 我的页回全部 |
| 归档车辆出现在旧列表缓存 | `vehiclesProvider` 失效；选择器按 id 找不到时回退到第一辆 |
| 空车库 + FAB 记账 | 记账页显示 `hasNoVehicles` 提示与「去添加」；本页添加页 P1 前 Toast |
| 记录数接口失败 | garage 仍展示，`recordCount = 0`；删除时服务端 409 兜底并展示「先归档」 |
| 主驾切换后首页请求失败 | 首页显示模块错误；不阻塞本页 |
| 快速连续点击确认 | 弹窗 `_submitting` + 命令 `isBusy` 双拦截 |
| 页面在写操作中关闭 | 写操作继续完成，provider 失效；不弹 Toast（`context.mounted` 判断） |
| 深色 / 大字号 | 布局可滚动；按钮文字 `FittedBox`；无溢出警告 |

---

## 12. 测试方案

### 12.1 单元测试

| 文件 | 覆盖 |
| --- | --- |
| `test/vehicles/vehicle_store_test.dart` | 主驾唯一；排序（主驾置顶 + sortOrder）；归档继任；归档唯一车清空主驾；恢复自动成为主驾；删除唯一车；删除主驾（多车）抛 `isPrimary` |
| `test/vehicles/vehicle_presenter_test.dart` | 三类动力三指标；PHEV 亏电油耗；SOH < 80 危险色；车险 ≤ 30 天；缺失指标「— / 未录入」；提醒优先级；健康计数；动力构成文案；删除判断顺序 |
| `test/vehicles/mock_vehicle_repository_test.dart` | `fetchGarage` 在库 / 归档分离；本月支出取 dashboard；`recordCount` 过滤删除记录；写操作错误码；`primaryVehicleId` 同步 |
| `test/vehicles/garage_aggregation_test.dart` | 汇总里程、总开销、构成、健康项；空车库；负金额；大数缩放 |

### 12.2 Widget 测试

| 文件 | 覆盖 |
| --- | --- |
| `test/vehicles/vehicle_management_page_test.dart` | 4 辆车渲染；默认主驾徽标与置顶；普通卡按钮；更多菜单打开；设主驾确认 → 列表重排 + Toast；归档确认继任文案；删除主驾拦截；删除有流水拦截；空车库空态；已归档恢复；加载 / 错误态 |
| `test/vehicles/vehicle_management_sheets_test.dart` | 四种弹层的按钮状态、loading、错误文案、返回结果 |
| `test/home/home_empty_garage_test.dart` | `effectiveVehicleIdProvider == null` 时首页各模块空占位、FAB 打开记账页显示无车辆 |
| `test/widget_test.dart` | 现有首页回归：4 辆车仍显示，BMW 可切换 |

Widget 测试使用：

```dart
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      vehicleStoreProvider.overrideWithValue(testStore),
      vehicleRepositoryProvider.overrideWithValue(
        MockVehicleRepository(
          store: testStore,
          home: testHomeRepository,
          ledger: testLedgerRepository,
          now: () => DateTime(2026, 11, 15),
          delay: Duration.zero,
        ),
      ),
    ],
    child: MaterialApp(theme: AppTheme.light(), home: const VehicleManagementPage()),
  ),
);
```

`testStore` 提供 1 辆主驾 + 1 辆普通 + 1 辆归档，确保四种边界都能覆盖。

### 12.3 手工验收

1. 我的页 / 首页 / 统计弹层 / 详情页四个入口均进入本页，返回位置正确。
2. 设为默认主驾后，首页立即切车；记账页预填正确；统计页保持原筛选。
3. 归档默认主驾 → 继任车辆成为主驾；账单仍能筛选到归档车（若账单页允许）。
4. 删除默认主驾（多车）被拦截；切换后可继续删除或进入归档。
5. 删除有流水车辆被拦截，点「去归档」流程顺畅。
6. 归档唯一车辆 → 空车库 → 恢复 → 自动主驾。
7. 空车库下首页、记账、统计、账单无崩溃。
8. 深色模式、1.3 倍字号、320 宽屏、横屏检查。
9. 快速连点确认按钮不重复提交。
10. 下拉刷新与写操作并发无错乱。

### 12.4 CI

- `flutter analyze` 零警告。
- `flutter test` 全绿；新增测试与现有 `test/widget_test.dart` 不冲突。
- PR 阶段不构建 APK；合并 main 后由 `flutter-android.yml` 构建。

---

## 13. 实施拆分

| 里程碑 | 内容 | 交付 |
| --- | --- | --- |
| M0-A | 选中车辆可空：`selectedVehicleIdProvider` → `String?`、`effectiveVehicleIdProvider`、首页 / 记账 / 统计 / Tab 壳适配、现有测试修复 | `feat/vehicle-management-m0-nullable-vehicle` |
| M0-B | `VehicleStore` + 种子数据 + `MockHomeRepository` 读 store + `LedgerRepository.countRecords` | `feat/vehicle-management-m0-store` |
| M1 | `ManagedVehicle` / `GarageOverview` / presenter + `MockVehicleRepository` + 单测 | `feat/vehicle-management-m1-data` |
| M2 | 页面只读部分：顶部栏、总览卡、车辆卡、添加卡、已归档入口、加载 / 空 / 错态 | `feat/vehicle-management-m2-ui` |
| M3 | 写操作：命令 notifier、四个弹层、失效矩阵、作用域归一化、Widget 测试 | `feat/vehicle-management-m3-actions` |
| M4 | 入口接线（首页 / 我的 / 统计 / 详情）、深色 / 无障碍 / 动效、手工验收、文档实施记录 | `feat/vehicle-management-m4-integration` |

每个里程碑独立 PR，便于评审与回滚；M0-A 必须先合入，避免后续 base 冲突。

---

## 14. 风险与待确认

| 风险 | 影响 | 应对 |
| --- | --- | --- |
| `selectedVehicleIdProvider` 改为可空波及 10+ 文件 | 首页 / 记账 / 统计回归 | M0-A 独立 PR，先保证 4 辆车行为不变；补空车库 Widget 测试 |
| Mock store 与 `_cars` 重复定义车辆 | 数据不一致 | store 成为唯一基础信息源；`_CarMock` 只保留 dashboard；启动时断言 id 对齐 |
| 「删除有流水车辆」产品口径未定 | 交互与数据完整性 | P0 按本文档禁止并引导归档；若产品改为级联删除，需补充强确认与批量失效 |
| 归档默认主驾的继任不透明 | 用户误改主驾 | 确认弹窗强制写出继任车名；不允许静默 |
| 添加 / 编辑页 P1 | 本页添加入口 P0 不可用 | 明确 Toast 文案；P1 前置交付后再移除占位 |
| 32 圆角与现有 16 圆角体系并存 | 视觉不统一 | 本页局部常量；评审后再决定是否提升 token |
| Mock 记录数只覆盖 24 个月 | 删除拦截可能漏判 | 生产由服务端 `recordCount` 兜底；Mock 与生命周期统计同窗口 |
| 页面失效面大 | 刷新抖动 | 不做乐观更新；`ValueKey` + `isRefreshing` 保留旧数据；只失效可见页面 |
| 无深色设计稿 | 视觉验收争议 | 按现有 dark token 推导；先过对比度与一致性 checklist |
| 车联网 / SOH / 保险数据源未定 | 展示空值 | 字段可空；缺失显示未录入；不编造 |

---

## 15. 附录：需求 → 实现映射

| 需求 | 实现 |
| --- | --- |
| §6.1 顶部栏 | `VehicleManagementHeader` + `BlurredHeaderDelegate` |
| §6.2 车库资产总览 | `FleetSummaryCard` + `FleetSummary` + `healthLabel` |
| §6.3 车队成员排序 | `VehicleStore.active` 排序 + `GarageOverview.vehicles` |
| §6.4 车辆卡 | `VehicleMemberCard` + `VehicleMetricRow` + `VehicleActionRow` + `VehiclePresenter.metricsOf/reminderOf` |
| §6.5 添加卡 | `AddVehicleCard` → `openVehicleEditor`（P1） |
| §6.6 车联网 | 不实现；无对应组件 |
| §6.7 更多菜单 | `VehicleMoreSheet` + `showVehicleSheet` |
| §6.8 设为主驾 | `SetPrimarySheet` + `vehicleCommandProvider.setPrimary` + `_normalizeScopes` |
| §6.9 归档 | `ArchiveVehicleSheet` + `vehicleCommandProvider.archive` + store 继任 |
| §6.10 删除 | `DeleteVehicleSheet` + `deleteBlockReason` + 仓库 / store 双校验 |
| §6.11 已归档与恢复 | `ArchivedEntryCard` + `ArchivedVehiclesSheet` + `restore` |
| §6.12 状态与反馈 | `garageProvider.when` + `SectionError` + `EmptyState` + `Skeleton` + `showAppToast` |
| §6.13 跳转 | `vehicle_management_routes.dart` + `openExpenseEntry` + `statsFilterProvider` + `appTabProvider` |
| §7 数据口径 | `MockVehicleRepository.fetchGarage` + `VehiclePresenter` + `formatters.dart` |
| §8 接口契约 | `VehicleRepository` / `VehicleOperationException` / `_invalidateAll` |

---

## 16. 实施记录（v0.2）

### 16.1 已落地文件

| 层 | 文件 |
| --- | --- |
| 状态 / 数据 | `lib/features/vehicles/data/vehicle_store.dart`、`vehicle_seed_data.dart`、`vehicle_store_provider.dart`、`vehicle_repository.dart`、`mock_vehicle_repository.dart` |
| 领域 | `lib/features/vehicles/domain/vehicle_models.dart`、`vehicle_presenter.dart`、`providers.dart` |
| 页面 | `lib/features/vehicles/presentation/vehicle_management_page.dart`、`vehicle_management_routes.dart`、`vehicle_management_style.dart` |
| 组件 | `widgets/vehicle_management_header.dart`、`fleet_summary_card.dart`、`vehicle_member_card.dart`、`add_vehicle_card.dart`、`archived_entry_card.dart`、`vehicle_management_skeleton.dart`、`vehicle_sheet_shell.dart`、`vehicle_more_sheet.dart`、`vehicle_confirm_sheets.dart`、`archived_vehicles_sheet.dart`（v0.3 移除） |
| 测试 | `test/vehicles/vehicle_store_test.dart`、`vehicle_presenter_test.dart`、`mock_vehicle_repository_test.dart`、`vehicle_management_page_test.dart`、`home_empty_garage_test.dart` |

### 16.2 前置改造

- `selectedVehicleIdProvider` 改为 `Notifier<String?>`；新增 `effectiveVehicleIdProvider` 作为首页 / 记账 / 统计 / Tab 壳的统一兜底。
- 首页 6 个 section 在无可用车辆时返回空占位；`HomePage` 为空车库展示 `EmptyState`；下拉刷新做空判断。
- `MockHomeRepository` 注入 `VehicleStore`，`fetchVehicles()` 只返回在库车辆，`defaultVehicleId` 改为可空。
- `LedgerRepository` 新增 `countRecords({String? vehicleId})`，Mock 使用近 24 个月窗口，与生命周期统计一致。
- 首页「管理车辆」、我的「管理爱车」、单笔详情车辆箭头改为 `openVehicleManagement`；添加 / 编辑爱车仍为 Toast。

### 16.3 与方案的差异

| 项 | 方案 | 实施 |
| --- | --- | --- |
| 归档模型 | `ManagedVehicle.archivedAt` | 独立 `ArchivedVehicle`，不伪造能耗 / 保养指标 |
| 主驾继任 | store 内计算并写入 | 同方案；归档确认弹窗动态展示继任车名 |
| 删除拦截 | 客户端 + 服务端双校验 | Mock 仓库先查主驾、再查 `countRecords`；无网络冲突 / 上限路径 |
| 恢复文案 | 可带车名 | 统一 Toast「已恢复到车库」，车名在归档列表可见 |
| 上限 | 建议 10 辆 | 未在 Mock 强制执行；`AddVehicleCard` 预留 `enabled` 参数 |
| 添加 / 编辑 | P1 路由契约 | 仅 Toast，未创建编辑页与 `openVehicleEditor` 实现 |
| 排序 | P1 拖拽 | 未实现；页面不展示「长按可调换顺序」 |
| 车联网 | P1 | 不展示 |

### 16.4 验证

- `flutter analyze`：0 issue。
- `flutter test`：247 个测试全部通过；新增 35 个（store 8、presenter 12、repository 8、页面 6、空车库首页 1）。
- 页面 Widget 测试覆盖：渲染、设主驾确认与重排、删除流水拦截、归档与已归档入口、空车库、恢复。
- 未做真机手工验收与深色模式截图复核；PR 合并前由 CI 执行 analyze / test。

### 16.5 后续

- 添加 / 编辑爱车页（行驶证 OCR、车型库、能耗基准、保险 / 年检字段编辑）。
- 拖拽排序与顺序持久化。
- 车联网授权与自动里程同步。
- HTTP `VehicleRepository` 实现、409 冲突 / 上限处理、离线队列。
- 已归档车辆迁入设置页。
- 归档车辆的独立页面、恢复确认与彻底删除：见[已归档车辆技术方案](archived-vehicles.md)。

---

## 17. 变更记录

| 版本 | 日期 | 说明 |
| --- | --- | --- |
| v0.1 | 2026-11-15 | 首版：现状与复用、store / 仓库 / provider 设计、失效矩阵、三种删除形态、可空选中车辆改造、实施拆分与测试方案 |
| v0.2 | 2026-11-15 | P0 实施：补充落地文件、前置改造、方案差异、测试与后续事项 |
| v0.3 | 2026-11-15 | 归档车辆拆分独立页：入口改为路由，移除 `ArchivedVehiclesSheet`，恢复 / 历史报表 / 彻底删除迁入[已归档车辆技术方案](archived-vehicles.md) |
