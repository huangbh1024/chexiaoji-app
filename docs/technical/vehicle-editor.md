# 添加 / 编辑爱车档案技术方案 · 车辆档案编辑器

| 项目 | 内容 |
| --- | --- |
| 关联需求 | [添加 / 编辑爱车档案需求文档 v0.1](../requirements/vehicle-editor.md) |
| 关联方案 | [车辆管理技术方案](vehicle-management.md)、[已归档车辆技术方案](archived-vehicles.md)、[首页技术方案](home-dashboard.md)、[记账页技术方案](expense-entry.md)、[我的页技术方案](profile.md) |
| 设计稿 | [Stitch · 车辆新增与编辑档案页](https://stitch.google.com/projects/9615374848161425677?node-id=ab4c2e04ed0d44e7bf5941c9ba700e86) |
| 客户端 | Flutter 3.50.0 stable / Dart 3.14 |
| 平台 | Android（arm64 优先）、iOS |
| 文档版本 | v0.2（P1 已实现） |
| 状态 | P1 已实现（Mock）；接口未确认 |

> 本文档基于**仓库当前已有实现**编写：车辆管理、已归档车辆、车辆档案编辑器、首页、账单、统计、我的页、记账页、单笔详情、月度报表均已落地；依赖为 `material_ui`、`flutter_riverpod 3.5`、`fl_chart`、`intl`、`pdf`、`printing`、`share_plus`、`path_provider`、`image_picker`。
> 本页是车辆**档案字段的唯一写入口**；默认主驾、归档、删除仍复用车辆管理的命令与确认弹层，避免出现两套规则。
> 技术难点不在表单本身，而在三处跨页影响：
> 1. **新建车辆没有流水 / 能耗 / 保养数据**，首页、统计、我的页、报表不能崩溃或伪造数值；
> 2. **编辑容量 / 油品 / 里程**会改变记账页预填与首页指标，必须统一失效；
> 3. **主驾开关、归档、未保存离开**涉及全局状态与导航拦截，需要串行和明确结果契约。

---

## 1. 目标与约束

### 1.1 技术目标

- 新增页首帧 ≤ 300ms；编辑详情 ≤ 800ms（Mock，含 140ms 模拟延迟）；保存 ≤ 500ms；滚动 60fps。
- **单一数据源**：车辆档案、默认主驾、归档状态只由 `VehicleStore` 持有；本页不维护第二份车辆数组。
- **表单可预测**：`VehicleEditorDraft` 是纯不可变值对象；所有校验是纯函数，可单测；切换动力类型不丢已输入的其他类型字段。
- **保存串行**：同一时刻只允许一个保存；`isSaving` 期间禁用字段、按钮与返回，避免重复提交。
- **跨页可证明**：保存 / 归档后按 §7.4 的矩阵失效；新建车辆在所有页面有确定空态；编辑容量后记账页立即使用新值。
- **不伪造能力**：OCR、车型检索、云同步在 P0 不实现；新增车辆无数据时显示「暂无能耗记录 / 未录入」，不写 0 能耗、不写假流水。
- **导航契约明确**：返回 `VehicleEditorResult?`；`null` 表示取消；新增 / 编辑 / 归档三种结果可区分，供来源页刷新与滚动。
- 不新增依赖、不新增图片资源；深色模式复用 `AppPalette.dark` / `AppTokens.dark`。

### 1.2 约束

- 不引入 `go_router`：继续 `Navigator.push(MaterialPageRoute)` + `showModalBottomSheet`。
- 金额全链路整数分（`int cents`）；里程整数 km；日期只存本地日期（`DateTime` 的 y/m/d，时分秒置零）。
- 不修改 `core/domain/vehicle.dart` 的既有字段语义；编辑页新增字段放在 `VehicleRecord`，避免污染首页 / 账单 / 统计的 `Vehicle`。
- 车牌唯一性由客户端即时校验 + 服务端再次校验；客户端校验不是唯一安全边界。
- 在库车辆上限 10 辆；归档车辆不计入上限（恢复后可能超过上限的问题放 Q/R）。
- 编辑归属字段不改变历史流水的归属与金额；不级联修改账单。
- Mock 数据只存在内存，重启恢复种子；接口接入后由服务端持久化。
- 不新增公共 token；本页局部圆角 / 间距常量放在 `vehicle_editor_style.dart`。
- 不实现 OCR、车型库、车辆图片、VIN、保养周期配置。

---

## 2. 现状与复用清单

| 现有能力 | 位置 | 本页用法 |
| --- | --- | --- |
| 色彩 token | `lib/app/theme/app_colors.dart` → `AppPalette` / `AppColors` | 页面、卡片、动力色、错误色 |
| 间距 / 圆角 / 阴影 | `lib/app/theme/app_tokens.dart` → `AppTokens` | 页面边距、输入框、底部栏、卡片 |
| 字体 | `lib/app/theme/app_typography.dart` | `headlineMd`、`headlineSm`、`bodyLg`、`bodyMd`、`bodySm`、`labelLg`、`labelMd`、`labelSm` |
| 车辆基础模型 | `lib/core/domain/vehicle.dart` → `Vehicle` | id、名称、车牌、动力、里程、电池 / 油箱、油品 |
| 动力枚举 | `lib/core/domain/enums.dart` → `PowertrainType` / `PowertrainLabel` | 四类动力与标准文案 |
| 动力色与图标 | `lib/core/presentation/category_style.dart` → `PowertrainVisual` | 动力段、图标、车牌状态 |
| 车库状态 | `lib/features/vehicles/data/vehicle_store.dart` → `VehicleStore` | 新增 / 更新 / 主驾 / 归档 / 车牌唯一 |
| 车库仓库 | `.../data/vehicle_repository.dart` → `VehicleRepository` | 新增编辑器快照 / 创建 / 更新 |
| 车库模型 | `.../domain/vehicle_models.dart` → `ManagedVehicle` | 归档确认、车辆卡昵称 |
| 车辆展示推导 | `.../domain/vehicle_presenter.dart` | 指标、提醒、删除拦截 |
| 写命令 | `.../domain/providers.dart` → `VehicleCommandNotifier` | 主驾 / 归档复用；抽出失效与作用域归一化 |
| 车辆确认弹层 | `.../presentation/widgets/vehicle_confirm_sheets.dart` | 归档确认；改为接收 `Vehicle` 轻量模型 |
| 车辆更多菜单 | `.../presentation/widgets/vehicle_more_sheet.dart` | 「编辑车辆档案」入口 |
| 车辆管理页 | `.../presentation/vehicle_management_page.dart` | 添加入口 / 编辑入口 / 保存后滚动 |
| 首页车辆切换器 | `lib/features/home/presentation/widgets/vehicle_switcher.dart` | 「添加车辆」入口 |
| 我的页车库 | `lib/features/profile/presentation/widgets/garage_section.dart` | 「添加车辆」入口 |
| 首页 dashboard | `lib/features/home/domain/home_models.dart` | `Consumption` / `Maintenance` 增加「无数据 / 无进度」标记 |
| 首页 Mock | `lib/features/home/data/mock_home_repository.dart` | 新车辆空看板、保养提醒覆盖 |
| 记账预填 | `lib/features/expense_entry/...` | 容量 / 油品来自 `Vehicle`，保存后自动生效 |
| 金额 / 里程 / 日期格式化 | `lib/core/format/formatters.dart` | 里程、金额、日期；新增万元 / 日期输入辅助 |
| 空 / 错 / 骨架 | `lib/core/widgets/empty_state.dart`、`section_error.dart`、`skeleton_box.dart` | 车辆不存在、加载失败、加载中 |
| Toast | `lib/core/presentation/toast.dart` → `showAppToast` | 成功 / 失败轻提示 |
| 弹层外壳 | `.../presentation/widgets/vehicle_sheet_shell.dart` | 省份弹层、放弃修改、归档确认 |
| 路由写法 | `.../presentation/vehicle_management_routes.dart` | 新增 `openVehicleEditor` |

### 2.1 现有实现与本页的差异

| 项 | 现状 | 本页处理 |
| --- | --- | --- |
| 添加车辆 | 车辆管理 / 首页 / 我的页均为 Toast | 统一推入 `VehicleEditorPage` 新增态 |
| 编辑档案 | 车辆管理「更多」为 Toast | 推入 `VehicleEditorPage` 编辑态 |
| 车辆字段 | `Vehicle` 只有基础字段；`VehicleRecord` 有 SOH / 保险 / 年检 | 扩展 `VehicleRecord`：昵称、官方电耗、纯电续航、购车日期 / 价格、下次保养里程 |
| 动力类型 | 仓库有 4 类，设计稿 3 段 | 4 段选择器；HEV 与 ICE 共用油箱 + 油耗字段 |
| 车牌 | 只存完整字符串 | 拆分省份 / 字符，规范化、自动补「·」、唯一性校验 |
| 默认主驾 | 车辆管理「设为主驾」；本页无入口 | 保存时开关接管；首辆车强制主驾；编辑主驾不可关闭 |
| 归档 | 车辆管理「更多」 | 编辑页底部入口；复用归档确认与命令 |
| 新增车辆数据 | `MockHomeRepository._cars` 只认识 4 辆种子车，未知 id 直接抛错 | 新增未知车辆的空 dashboard / 空趋势 / 空分类 / 空记录 |
| 保养提醒 | 来自 Mock dashboard 的固定值 | 有 `nextMaintenanceKm` 时按「下次里程 − 当前里程」覆盖；无保养流水不显示进度环 |
| 首页能耗卡 | 总是显示一个数值与 sparkline | `Consumption.hasData == false` 时显示「暂无能耗记录」，不画 sparkline |
| 车辆昵称 | 无字段、无展示 | `VehicleRecord.nickname`；车辆管理卡显示胶囊，不替换车名 |
| 车牌重复 | 无校验 | 客户端即时 + 服务端再次校验 |
| 未保存离开 | 无 | `PopScope` + 放弃修改弹层 |
| 车型搜索 / OCR | 无 | P0 不实现；OCR 胶囊 Toast 占位 |

---

## 3. 结构调整

### 3.1 新增 / 调整文件

```
lib/features/vehicles/
├── data/
│   ├── vehicle_repository.dart              # + fetchVehicleEditor / createVehicle / updateVehicle / 新错误码
│   ├── mock_vehicle_repository.dart         # + 编辑器快照 / 创建 / 更新 / 车牌冲突 / 最近里程
│   ├── vehicle_store.dart                   # + add / update / 车牌唯一 / 10 辆上限 / duplicatePlate
│   ├── vehicle_editor_catalog.dart          # 新增：省份、快捷车型、油品常量
│   └── vehicle_seed_data.dart               # 可选：补 nickname / nextMaintenanceKm 演示值
├── domain/
│   ├── vehicle_editor_models.dart           # 新增：Draft / Args / Result / Snapshot / State / Field
│   ├── vehicle_editor_presenter.dart        # 新增：校验 / 车牌 / 标题 / 映射 / 错误文案
│   ├── vehicle_editor_providers.dart        # 新增：编辑器 Controller
│   ├── vehicle_models.dart                  # + ManagedVehicle.nickname
│   └── providers.dart                       # + 失效 / 作用域归一化抽离；归档接收 Vehicle
└── presentation/
    ├── vehicle_editor_page.dart             # 新增：页面骨架与结果分发
    ├── vehicle_editor_routes.dart           # 新增：openVehicleEditor
    ├── vehicle_editor_style.dart            # 新增：局部圆角 / 间距 / 高度
    └── widgets/
        ├── vehicle_editor_header.dart       # 顶部栏
        ├── powertrain_selector.dart         # 四段动力选择器
        ├── vehicle_identity_card.dart       # 身份信息卡
        ├── vehicle_plate_input.dart         # 省份 + 车牌字符 + 绿牌开关
        ├── province_picker_sheet.dart       # 省份选择弹层
        ├── vehicle_specs_card.dart          # 动力 / 能耗 / 购车信息
        ├── vehicle_preferences_card.dart    # 昵称 / 主驾 / 保养 / 保险
        ├── vehicle_editor_bottom_bar.dart   # 保存 / 归档 / 错误
        ├── vehicle_editor_skeleton.dart     # 编辑加载骨架
        └── discard_changes_sheet.dart       # 放弃修改确认
```

其他模块：

```
lib/features/home/domain/home_models.dart          # + Consumption.hasData / Maintenance.hasProgress
lib/features/home/data/mock_home_repository.dart   # + 未知车辆空看板 / 保养覆盖 / 空趋势
lib/features/home/presentation/widgets/consumption_card.dart
lib/features/home/presentation/widgets/maintenance_card.dart
lib/features/home/presentation/widgets/vehicle_switcher.dart   # 添加入口
lib/features/profile/presentation/widgets/garage_section.dart  # 添加入口
lib/features/profile/presentation/widgets/garage_vehicle_card.dart
lib/features/vehicles/presentation/vehicle_management_page.dart
lib/features/vehicles/presentation/widgets/vehicle_member_card.dart
lib/features/vehicles/presentation/widgets/vehicle_confirm_sheets.dart
lib/core/format/formatters.dart                    # + 万元 / 日期输入辅助
```

### 3.2 修改现有文件

| 文件 | 改动 | 影响 |
| --- | --- | --- |
| `core/domain/vehicle.dart` | 不改字段；如需昵称等新字段，放 `VehicleRecord` | 避免污染其他页面 |
| `vehicles/data/vehicle_store.dart` | 新增 `add` / `update`；车牌规范化唯一；10 辆上限；`duplicatePlate` / `limitReached` | 车库写入口 |
| `vehicles/data/vehicle_repository.dart` | 新增 `fetchVehicleEditor`、`createVehicle`、`updateVehicle`；错误码 `duplicatePlate` / `invalidField` | Mock / HTTP 两套实现 |
| `vehicles/data/mock_vehicle_repository.dart` | 编辑器快照、创建 / 更新、最近记账里程、车牌冲突、空看板依赖 | Mock 行为 |
| `vehicles/domain/vehicle_models.dart` | `ManagedVehicle.nickname`；`VehicleRecord` 新字段；`VehicleEditorSnapshot` | 卡片、归档、编辑 |
| `vehicles/domain/providers.dart` | 抽出 `VehicleScopeInvalidator` / `normalizeVehicleScopes`；归档命令复用 | 编辑保存后失效 |
| `vehicles/presentation/vehicle_management_page.dart` | 添加入口 / 编辑入口改为 `openVehicleEditor`；保存后刷新并滚动到该车 | 入口接线 |
| `vehicles/presentation/widgets/vehicle_member_card.dart` | 昵称胶囊（非空时） | 展示 |
| `vehicles/presentation/widgets/archived_vehicle_card.dart` | 配置为空时显示「车辆档案待完善」 | 归档卡 |
| `vehicles/presentation/widgets/vehicle_confirm_sheets.dart` | `showArchiveVehicleSheet` 接收 `Vehicle`（而非 `ManagedVehicle`） | 编辑页 / 管理页共用 |
| `home/domain/home_models.dart` | `Consumption.hasData`、`Maintenance.hasProgress`（默认 true） | 新车辆空态 |
| `home/data/mock_home_repository.dart` | 未知 id 返回空看板；`nextMaintenanceKm` 覆盖保养；空趋势 / 分类 / 记录 | 新车辆全链路 |
| `home/presentation/widgets/consumption_card.dart` | `hasData == false` 显示「暂无能耗记录」 | 首页 |
| `home/presentation/widgets/maintenance_card.dart` | `hasProgress == false` 隐藏进度环 | 首页 |
| `home/presentation/widgets/vehicle_switcher.dart` | 添加卡改为 `openVehicleEditor` | 首页入口 |
| `profile/presentation/widgets/garage_section.dart` | 空态 / 添加卡改为 `openVehicleEditor` | 我的页入口 |
| `core/format/formatters.dart` | 新增 `formatWan` / `formatEditorDate`；万元输入解析在 `vehicle_editor_presenter.dart` | 购车信息 |
| `vehicles/domain/vehicle_presenter.dart` | 三指标对 `consumption.hasData == false` 显示「—」 | 车辆管理卡 |
| `vehicles/data/vehicle_seed_data.dart` | 可选补昵称 / 下次保养里程演示值 | 演示一致性 |

### 3.3 页面局部常量

```dart
// lib/features/vehicles/presentation/vehicle_editor_style.dart
abstract final class VehicleEditorStyle {
  static const cardRadius = 28.0;
  static const cardPadding = 20.0;
  static const cardGap = 20.0;
  static const innerRadius = 16.0;
  static const inputHeight = 48.0;
  static const fieldGap = 12.0;
  static const iconBox = 32.0;
  static const saveButtonHeight = 52.0;
  static const bottomBarPadding = 8.0;
  static const sheetMaxHeight = 0.85;
  static const plateStripHeight = 3.0;
}
```

局部常量避免污染 `AppTokens`；若后续「表单输入 48 高 / 卡片 28 圆角」成为跨页规范，再提升为公共 token。

---

## 4. 数据流

```
┌──────────────────────────────────────────────────────────────┐
│ VehicleEditorPage                                            │
│                                                              │
│  watch vehicleEditorControllerProvider(args)                 │
│        │                                                     │
│        ├─ create: vehiclesProvider / garageProvider          │
│        │      （在库数量、车牌、首辆车判定）                    │
│        │                                                     │
│        └─ edit: VehicleRepository.fetchVehicleEditor(id)      │
│               │                                             │
│               ├─ VehicleStore.byId(id)                       │
│               ├─ LedgerRepository.latestOdometerForVehicle(id)│
│               └─ 归档 / 主驾 / 上限约束                       │
│                                                              │
│  表单编辑 ──► VehicleEditorDraft（不可变）                     │
│        │                                                     │
│        ├─ 纯函数校验 → fieldErrors                           │
│        └─ save()                                             │
│               │                                             │
│               ├─ createVehicle(draft)                        │
│               └─ updateVehicle(id, draft)                    │
│                        │                                     │
│                        ▼                                     │
│                 VehicleStore.add / update                    │
│                 （车牌唯一 / 上限 / 主驾）                     │
│                        │                                     │
│                        ▼                                     │
│        VehicleScopeInvalidator.invalidateAll()               │
│        + normalizeScopes(vehicleId, select: created/primary) │
│                        │                                     │
│                        ▼                                     │
│        Navigator.pop(VehicleEditorResult)                    │
│                        │                                     │
│        来源页（车辆管理 / 首页 / 我的页）刷新并定位            │
└──────────────────────────────────────────────────────────────┘
```

- 读：新增态不请求详情；编辑态一次请求快照；页面不直接读 store。
- 写：新增 / 更新走 `VehicleRepository`；归档复用 `vehicleCommandProvider.archive`；两者都会走同一套失效与作用域归一化。
- 空数据：`VehicleStore` 只保存档案；流水、能耗、保养由各仓库聚合；新建车辆没有聚合数据时，首页 / 统计 / 我的页 / 报表使用各自空态。

---

## 5. 数据模型

### 5.1 `VehicleRecord` 扩展

```dart
// lib/features/vehicles/data/vehicle_store.dart
@immutable
class VehicleRecord {
  const VehicleRecord({
    required this.vehicle,
    required this.specLabel,
    required this.sortOrder,
    this.isArchived = false,
    this.archivedAt,
    this.nickname,
    this.officialConsumption,
    this.electricRangeKm,
    this.purchaseDate,
    this.purchasePriceCents,
    this.nextMaintenanceKm,
    this.batteryHealthPercent,
    this.insuranceExpiry,
    this.inspectionExpiry,
  });

  final Vehicle vehicle;
  final String specLabel;
  final int sortOrder;
  final bool isArchived;
  final DateTime? archivedAt;

  /// 档案别名；不替换 vehicle.name。
  final String? nickname;

  /// 官方标称电耗 / 亏电油耗 / 综合油耗 / 标称油耗。
  /// 统一存一个字段，单位与标签由 [Vehicle.powertrain] 决定。
  final double? officialConsumption;

  /// 纯电续航（PHEV），km。
  final int? electricRangeKm;

  /// 首次上牌 / 购车日期，只取 y/m/d。
  final DateTime? purchaseDate;

  /// 购车落地价，整数分；26.8 万元 = 26800000。
  final int? purchasePriceCents;

  /// 下次保养的绝对表显里程。
  final int? nextMaintenanceKm;

  final int? batteryHealthPercent;
  final DateTime? insuranceExpiry;
  final DateTime? inspectionExpiry;

  String get id => vehicle.id;

  VehicleRecord copyWith({
    Vehicle? vehicle,
    String? specLabel,
    bool? isArchived,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
    String? nickname,
    bool clearNickname = false,
    int? sortOrder,
    int? batteryHealthPercent,
    DateTime? insuranceExpiry,
    DateTime? inspectionExpiry,
  }) {
    return VehicleRecord(
      vehicle: vehicle ?? this.vehicle,
      specLabel: specLabel ?? this.specLabel,
      sortOrder: sortOrder ?? this.sortOrder,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
      nickname: clearNickname ? null : (nickname ?? this.nickname),
      officialConsumption: officialConsumption,
      electricRangeKm: electricRangeKm,
      purchaseDate: purchaseDate,
      purchasePriceCents: purchasePriceCents,
      nextMaintenanceKm: nextMaintenanceKm,
      batteryHealthPercent: batteryHealthPercent ?? this.batteryHealthPercent,
      insuranceExpiry: insuranceExpiry ?? this.insuranceExpiry,
      inspectionExpiry: inspectionExpiry ?? this.inspectionExpiry,
    );
  }
}
```

- `copyWith` 只用于归档 / 恢复 / 排序等局部变更；编辑页保存时**整体构造新记录**，避免「清空字段」需要大量 `clearXxx` 标记。
- `Vehicle` 仍不增加新字段；昵称、购车信息、官方能耗留在 `VehicleRecord`，只在本页与车辆管理卡使用。
- `ManagedVehicle` 增加 `final String? nickname;`，由 Mock 仓库从记录带入；`VehicleMemberCard` 在昵称为非空时显示胶囊。
- `ArchivedVehicleSummary` 不展示昵称 / 购车信息；归档页保持现状。

### 5.2 `VehicleEditorDraft`

```dart
// lib/features/vehicles/domain/vehicle_editor_models.dart
@immutable
class VehicleEditorDraft {
  const VehicleEditorDraft({
    this.name = '',
    this.specLabel = '',
    this.nickname = '',
    this.province = '粤',
    this.plateBody = '',
    this.isGreenPlate = true,
    this.odometerKm,
    this.powertrain = PowertrainType.ev,
    this.batteryCapacityKwh,
    this.officialConsumption,
    this.electricRangeKm,
    this.tankCapacityL,
    this.defaultFuelGrade,
    this.purchaseDate,
    this.purchasePriceCents,
    this.nextMaintenanceKm,
    this.insuranceExpiry,
    this.makePrimary = false,
  });

  final String name;
  final String specLabel;
  final String nickname;
  final String province;

  /// 已规范化：大写、去分隔符、不含「·」。
  final String plateBody;
  final bool isGreenPlate;
  final int? odometerKm;
  final PowertrainType powertrain;

  final double? batteryCapacityKwh;

  /// EV 为官方电耗；PHEV 为亏电油耗；HEV / ICE 为综合 / 标称油耗。
  /// 单位与字段标签由 [powertrain] 决定，存储只保留一个数值。
  final double? officialConsumption;
  final int? electricRangeKm;
  final double? tankCapacityL;
  final int? defaultFuelGrade;

  final DateTime? purchaseDate;
  final int? purchasePriceCents;
  final int? nextMaintenanceKm;
  final DateTime? insuranceExpiry;
  final bool makePrimary;

  String get plate => fullPlate(province, plateBody);
  bool get hasPlate => plateBody.isNotEmpty;

  VehicleEditorDraft copyWith({
    String? name,
    String? specLabel,
    String? nickname,
    String? province,
    String? plateBody,
    bool? isGreenPlate,
    int? odometerKm,
    bool clearOdometer = false,
    PowertrainType? powertrain,
    double? batteryCapacityKwh,
    bool clearBattery = false,
    double? officialConsumption,
    bool clearOfficialConsumption = false,
    int? electricRangeKm,
    bool clearElectricRange = false,
    double? tankCapacityL,
    bool clearTank = false,
    int? defaultFuelGrade,
    bool clearFuelGrade = false,
    DateTime? purchaseDate,
    bool clearPurchaseDate = false,
    int? purchasePriceCents,
    bool clearPurchasePrice = false,
    int? nextMaintenanceKm,
    bool clearNextMaintenance = false,
    DateTime? insuranceExpiry,
    bool clearInsurance = false,
    bool? makePrimary,
  });

  /// 用于脏检查与调试；不直接持久化。
  Map<String, Object?> toMap() => {
    'name': name,
    'specLabel': specLabel,
    'nickname': nickname,
    'province': province,
    'plateBody': plateBody,
    'isGreenPlate': isGreenPlate,
    'odometerKm': odometerKm,
    'powertrain': powertrain.name,
    'batteryCapacityKwh': batteryCapacityKwh,
    'officialConsumption': officialConsumption,
    'electricRangeKm': electricRangeKm,
    'tankCapacityL': tankCapacityL,
    'defaultFuelGrade': defaultFuelGrade,
    'purchaseDate': purchaseDate?.toIso8601String(),
    'purchasePriceCents': purchasePriceCents,
    'nextMaintenanceKm': nextMaintenanceKm,
    'insuranceExpiry': insuranceExpiry?.toIso8601String(),
    'makePrimary': makePrimary,
  };

  @override
  bool operator ==(Object other) =>
      other is VehicleEditorDraft && mapEquals(toMap(), other.toMap());

  @override
  int get hashCode => Object.hashAll(toMap().values);
}
```

- `copyWith` 使用 `clearXxx` 标记处理「把选填字段清空」，避免 `null` 歧义。
- `plateBody` 始终保存**规范化后的字符**（不含「·」），展示时由 presenter 补点；避免存储两套格式。
- 日期字段只保留 y/m/d；构造时统一 `DateTime(y, m, d)`。

### 5.3 Args / Result / Snapshot / State

```dart
@immutable
class VehicleEditorArgs {
  const VehicleEditorArgs.create() : vehicleId = null;
  const VehicleEditorArgs.edit(this.vehicleId);

  final String? vehicleId;
  bool get isCreate => vehicleId == null;

  @override
  bool operator ==(Object other) =>
      other is VehicleEditorArgs && other.vehicleId == vehicleId;

  @override
  int get hashCode => vehicleId.hashCode;
}

@immutable
class VehicleEditorResult {
  const VehicleEditorResult({
    required this.vehicleId,
    required this.created,
    this.archived = false,
  });

  final String vehicleId;
  final bool created;
  final bool archived;
}

@immutable
class VehicleEditorSnapshot {
  const VehicleEditorSnapshot({
    required this.vehicleId,
    required this.draft,
    required this.isPrimary,
    required this.activeVehicleCount,
    required this.maxActiveVehicles,
    required this.version,
    this.latestOdometerKm,
    this.successorName,
    this.isOnlyActiveVehicle = false,
  });

  final String vehicleId;
  final VehicleEditorDraft draft;
  final bool isPrimary;
  final int activeVehicleCount;
  final int maxActiveVehicles;
  final int version;

  /// 该车最近一次记账里程；高于档案里程时作为显示值。
  final int? latestOdometerKm;

  /// 当前是主驾时，归档后的继任车名；没有继任为 null。
  final String? successorName;

  /// 是否为唯一在库车辆；用于归档确认文案。
  final bool isOnlyActiveVehicle;
}

enum VehicleEditorMode { create, edit }

enum VehicleEditorStatus { loading, ready, notFound, archived, error }

enum VehicleEditorField {
  name,
  specLabel,
  nickname,
  plate,
  odometer,
  battery,
  officialConsumption,
  electricRange,
  tank,
  fuelGrade,
  purchaseDate,
  purchasePrice,
  nextMaintenance,
  insuranceExpiry,
}

@immutable
class VehicleEditorState {
  const VehicleEditorState({
    required this.args,
    required this.draft,
    this.status = VehicleEditorStatus.loading,
    this.initialDraft,
    this.fieldErrors = const {},
    this.formError,
    this.isSaving = false,
    this.isPrimaryLocked = false,
    this.activeVehicleCount = 0,
    this.maxActiveVehicles = 10,
    this.latestOdometerKm,
    this.version,
  });

  final VehicleEditorArgs args;
  final VehicleEditorDraft draft;
  final VehicleEditorStatus status;
  final VehicleEditorDraft? initialDraft;
  final Map<VehicleEditorField, String> fieldErrors;
  final String? formError;
  final bool isSaving;
  final bool isPrimaryLocked;
  final int activeVehicleCount;
  final int maxActiveVehicles;
  final int? latestOdometerKm;
  final int? version;

  VehicleEditorMode get mode =>
      args.isCreate ? VehicleEditorMode.create : VehicleEditorMode.edit;

  bool get isDirty => initialDraft != null && draft != initialDraft;
  bool get isReady => status == VehicleEditorStatus.ready;
  bool get canSubmit => isReady && !isSaving;

  VehicleEditorState copyWith({
    VehicleEditorDraft? draft,
    VehicleEditorStatus? status,
    VehicleEditorDraft? initialDraft,
    Map<VehicleEditorField, String>? fieldErrors,
    String? formError,
    bool clearFormError = false,
    bool? isSaving,
    bool? isPrimaryLocked,
    int? activeVehicleCount,
    int? maxActiveVehicles,
    int? latestOdometerKm,
    int? version,
  }) {
    return VehicleEditorState(
      args: args,
      draft: draft ?? this.draft,
      status: status ?? this.status,
      initialDraft: initialDraft ?? this.initialDraft,
      fieldErrors: fieldErrors ?? this.fieldErrors,
      formError: clearFormError ? null : (formError ?? this.formError),
      isSaving: isSaving ?? this.isSaving,
      isPrimaryLocked: isPrimaryLocked ?? this.isPrimaryLocked,
      activeVehicleCount: activeVehicleCount ?? this.activeVehicleCount,
      maxActiveVehicles: maxActiveVehicles ?? this.maxActiveVehicles,
      latestOdometerKm: latestOdometerKm ?? this.latestOdometerKm,
      version: version ?? this.version,
    );
  }
}
```

### 5.4 校验

```dart
// lib/features/vehicles/domain/vehicle_editor_presenter.dart
class PlateOwner {
  const PlateOwner({required this.plate, required this.name});
  final String plate;
  final String name;
}

/// 按字段返回错误；空 map 表示通过。
/// 调用方按 [VehicleEditorField] 的顺序滚动到第一个错误。
Map<VehicleEditorField, String> validateVehicleEditorDraft(
  VehicleEditorDraft draft, {
  required DateTime now,
  int? latestOdometerKm,
  List<PlateOwner> knownVehicles = const [],
}) {
  final errors = <VehicleEditorField, String>{};

  final name = draft.name.trim();
  if (name.isEmpty) {
    errors[VehicleEditorField.name] = '请填写品牌与车型';
  } else if (name.length < 2 || name.length > 40) {
    errors[VehicleEditorField.name] = '品牌与车型需为 2–40 个字符';
  }

  if (draft.specLabel.trim().length > 30) {
    errors[VehicleEditorField.specLabel] = '配置版本不能超过 30 个字符';
  }
  if (draft.nickname.trim().length > 12) {
    errors[VehicleEditorField.nickname] = '昵称不能超过 12 个字符';
  }

  final body = normalizePlateBody(draft.plateBody);
  final expected = draft.isGreenPlate ? 7 : 6;
  if (body.isEmpty) {
    errors[VehicleEditorField.plate] = '请填写车牌号码';
  } else if (body.length != expected ||
      !RegExp(
        draft.isGreenPlate
            ? r'^[A-Z][A-Z0-9]{6}$'
            : r'^[A-Z][A-Z0-9]{5}$',
      ).hasMatch(body)) {
    errors[VehicleEditorField.plate] = draft.isGreenPlate
        ? '新能源车牌需为城市字母 + 6 位字母数字'
        : '燃油车牌需为城市字母 + 5 位字母数字';
  } else {
    final full = fullPlate(draft.province, body);
    for (final owner in knownVehicles) {
      if (samePlate(owner.plate, full)) {
        errors[VehicleEditorField.plate] = '该车牌已在车库中（${owner.name}）';
        break;
      }
    }
  }

  final odometer = draft.odometerKm;
  if (odometer == null) {
    errors[VehicleEditorField.odometer] = '请填写当前总里程';
  } else if (odometer < 0 || odometer > 9999999) {
    errors[VehicleEditorField.odometer] = '请输入 0–9,999,999 之间的里程';
  } else if (latestOdometerKm != null && odometer < latestOdometerKm) {
    errors[VehicleEditorField.odometer] =
        '当前总里程不能小于最近记账里程 ${formatKmValue(latestOdometerKm)} km';
  }

  _validateRange(errors, VehicleEditorField.battery,
      draft.batteryCapacityKwh, 1, 300, '电池容量需在 1–300 kWh 之间');
  _validateRange(errors, VehicleEditorField.officialConsumption,
      draft.officialConsumption, 0.1, 100, '官方能耗需在 0.1–100 之间');
  _validateRange(errors, VehicleEditorField.electricRange,
      draft.electricRangeKm?.toDouble(), 1, 2000, '纯电续航需在 1–2,000 km 之间');
  _validateRange(errors, VehicleEditorField.tank,
      draft.tankCapacityL, 1, 300, '油箱容积需在 1–300 L 之间');
  _validateRange(errors, VehicleEditorField.officialConsumption,
      draft.officialConsumption, 0.1, 100, '能耗 / 油耗需在 0.1–100 之间');

  if (draft.purchaseDate != null) {
    final date = _dateOnly(draft.purchaseDate!);
    if (date.isAfter(_dateOnly(now))) {
      errors[VehicleEditorField.purchaseDate] = '购车时间不能晚于今天';
    } else if (date.isBefore(DateTime(1980))) {
      errors[VehicleEditorField.purchaseDate] = '购车时间不能早于 1980 年';
    }
  }
  final price = draft.purchasePriceCents;
  // 1,000 万元 = 1,000,000,000 分
  if (price != null && (price < 0 || price > 1000000000)) {
    errors[VehicleEditorField.purchasePrice] = '购车价格需在 0–1,000 万元之间';
  }
  final next = draft.nextMaintenanceKm;
  if (next != null && (next < 0 || next > 9999999)) {
    errors[VehicleEditorField.nextMaintenance] = '请输入有效里程';
  }

  return errors;
}
```

- `_validateRange` 只在该字段适用于当前动力类型时调用；不适用字段不校验。
- `nextMaintenanceKm <= odometer` 不是错误，只在 UI 显示警示（需求 §6.5.3）。
- 保险日期已过不是错误，只在 UI 显示「已过期」。
- 车牌唯一性客户端只对当前已知车辆做即时提示；服务端对在库 + 归档全量校验。

### 5.5 展示推导与映射

```dart
abstract final class VehicleEditorPresenter {
  static const commonProvinces = [
    '粤', '京', '沪', '浙', '苏', '川', '鲁', '豫', '鄂', '湘', '闽', '皖',
  ];

  static const allProvinces = [
    '京', '津', '冀', '晋', '蒙', '辽', '吉', '黑', '沪', '苏', '浙',
    '皖', '闽', '赣', '鲁', '豫', '鄂', '湘', '粤', '桂', '琼', '渝',
    '川', '贵', '云', '藏', '陕', '甘', '青', '宁', '新',
  ];

  static String normalizePlateBody(String raw) =>
      raw.toUpperCase().replaceAll(RegExp(r'[\s·•\-]'), '');

  static String formatPlateBody(String body) {
    final normalized = normalizePlateBody(body);
    if (normalized.length <= 1) {
      return normalized;
    }
    return '${normalized[0]}·${normalized.substring(1)}';
  }

  static String fullPlate(String province, String body) =>
      '$province${formatPlateBody(body)}';

  static ({String province, String body}) splitPlate(String plate) {
    final trimmed = plate.trim();
    if (trimmed.isEmpty) {
      return (province: '粤', body: '');
    }
    final province = trimmed.substring(0, 1);
    final rest = normalizePlateBody(trimmed.substring(1));
    return (province: province, body: rest);
  }

  static bool samePlate(String a, String b) =>
      _normalizeFullPlate(a) == _normalizeFullPlate(b);

  static String _normalizeFullPlate(String plate) =>
      normalizePlateBody(plate);

  static String titleOf(VehicleEditorMode mode) =>
      mode == VehicleEditorMode.create ? '添加爱车档案' : '编辑爱车档案';

  static String subtitleOf(VehicleEditorState state) {
    if (state.isSaving) {
      return '正在保存…';
    }
    if (state.formError != null) {
      return '保存失败，请重试';
    }
    if (state.status == VehicleEditorStatus.loading) {
      return '正在读取档案…';
    }
    if (state.isDirty) {
      return '有未保存的修改';
    }
    if (state.mode == VehicleEditorMode.create) {
      return '新建车辆档案 · 保存至本地';
    }
    return '档案编号 #${shortCodeOf(state.args.vehicleId)} · 本地档案';
  }

  static String shortCodeOf(String? id) {
    final normalized = (id ?? '').replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (normalized.isEmpty) {
      return '';
    }
    final tail = normalized.length <= 5
        ? normalized
        : normalized.substring(normalized.length - 5);
    return tail.toUpperCase();
  }

  static String successMessageOf({
    required String name,
    required bool created,
    required bool primary,
    required bool archived,
  }) {
    if (archived) {
      return '已将「$name」归档';
    }
    if (created) {
      return primary
          ? '「$name」已添加到车库，并设为默认主驾'
          : '「$name」已添加到车库';
    }
    return primary
        ? '「$name」档案已更新，并设为默认主驾'
        : '「$name」档案已更新';
  }

  static String errorMessageFor(VehicleErrorCode code) => switch (code) {
    VehicleErrorCode.duplicatePlate => '该车牌已在车库中',
    VehicleErrorCode.limitReached => '车库车辆已达上限（10 辆），请先归档不再使用的车辆',
    VehicleErrorCode.notFound => '车辆已不存在，请返回车库刷新',
    VehicleErrorCode.notArchived => '该车辆已归档，请在已归档车辆中恢复后再修改',
    VehicleErrorCode.conflict => '车辆信息已更新，请刷新后重试',
    VehicleErrorCode.isPrimary => '默认主驾需在车辆管理中切换',
    VehicleErrorCode.invalidField => '请检查填写内容',
    _ => '保存失败，请重试',
  };

  static String powertrainSublabel(PowertrainType type) => switch (type) {
    PowertrainType.ev => '电耗核算',
    PowertrainType.phev => '双模计量',
    PowertrainType.hev => '油混计量',
    PowertrainType.ice => '标称油耗',
  };

  static String? consumptionUnitOf(PowertrainType type) => switch (type) {
    PowertrainType.ev => 'kWh/100km',
    PowertrainType.phev || PowertrainType.hev || PowertrainType.ice =>
      'L/100km',
  };

  static int? parseWanToCents(String text) {
    final value = double.tryParse(text.trim());
    if (value == null) {
      return null;
    }
    return (value * 10000 * 100).round();
  }

  static String formatWanInput(int? cents) {
    if (cents == null) {
      return '';
    }
    return (cents / 1000000).toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  static Vehicle buildVehicle({
    required VehicleEditorDraft draft,
    required String id,
    String? badge,
  }) {
    return Vehicle(
      id: id,
      name: draft.name.trim(),
      plate: draft.plate,
      powertrain: draft.powertrain,
      powertrainLabel: draft.powertrain.label,
      odometerKm: draft.odometerKm!,
      badge: badge,
      batteryCapacityKwh: draft.batteryCapacityKwh,
      tankCapacityL: draft.tankCapacityL,
      defaultFuelGrade: draft.defaultFuelGrade,
    );
  }

  static VehicleRecord buildRecord({
    required Vehicle vehicle,
    required VehicleEditorDraft draft,
    required int sortOrder,
    VehicleRecord? existing,
  }) {
    return VehicleRecord(
      vehicle: vehicle,
      specLabel: draft.specLabel.trim(),
      sortOrder: existing?.sortOrder ?? sortOrder,
      isArchived: existing?.isArchived ?? false,
      archivedAt: existing?.archivedAt,
      nickname: _nullIfBlank(draft.nickname),
      officialConsumption: draft.officialConsumption,
      electricRangeKm: draft.electricRangeKm,
      purchaseDate: draft.purchaseDate,
      purchasePriceCents: draft.purchasePriceCents,
      nextMaintenanceKm: draft.nextMaintenanceKm,
      batteryHealthPercent: existing?.batteryHealthPercent,
      insuranceExpiry: draft.insuranceExpiry,
      inspectionExpiry: existing?.inspectionExpiry,
    );
  }
}
```

- 省份 / 快捷车型 / 油品常量统一定义在 `data/vehicle_editor_catalog.dart`；上面的 `commonProvinces` / `allProvinces` 仅示意，不在 presenter 里重复维护。

### 5.6 映射方向

| 方向 | 函数 | 说明 |
| --- | --- | --- |
| 记录 → 草稿 | `VehicleEditorPresenter.draftOf(record, latestOdometerKm)` | 拆分车牌、油箱 / 电池字段、日期、购车价、主驾 |
| 草稿 → 车辆 | `buildVehicle(draft, id, badge)` | `Vehicle` 只保留基础字段 |
| 草稿 → 记录 | `buildRecord(vehicle, draft, sortOrder, existing)` | `VehicleRecord` 保留 SOH / 年检 / 归档等既有字段 |
| 记录 → 车辆卡 | `ManagedVehicle` | 增加 `nickname` |
| 记录 → 归档卡 | `ArchivedVehicleSummary` | 不使用昵称 / 购车信息 |

`draftOf` 的规则：

```dart
static VehicleEditorDraft draftOf(
  VehicleRecord record, {
  int? latestOdometerKm,
  bool isPrimary = false,
}) {
  final split = splitPlate(record.vehicle.plate);
  return VehicleEditorDraft(
    name: record.vehicle.name,
    specLabel: record.specLabel,
    nickname: record.nickname ?? '',
    province: split.province,
    plateBody: split.body,
    isGreenPlate: split.body.length >= 7,
    odometerKm: max(record.vehicle.odometerKm, latestOdometerKm ?? 0),
    powertrain: record.vehicle.powertrain,
    batteryCapacityKwh: record.vehicle.batteryCapacityKwh,
    officialConsumption: record.officialConsumption,
    electricRangeKm: record.electricRangeKm,
    tankCapacityL: record.vehicle.tankCapacityL,
    defaultFuelGrade: record.vehicle.defaultFuelGrade,
    purchaseDate: record.purchaseDate,
    purchasePriceCents: record.purchasePriceCents,
    nextMaintenanceKm: record.nextMaintenanceKm,
    insuranceExpiry: record.insuranceExpiry,
    makePrimary: isPrimary,
  );
}
```

### 5.7 脏检查

- `VehicleEditorDraft` 实现值相等（`toMap` + `mapEquals`），`initialDraft` 在加载完成 / 新增初始化后保存。
- `isDirty = initialDraft != null && draft != initialDraft`。
- 文本字段以 `trim()` 后的值参与比较，避免「只多了空格」被判断为修改。
- 数字字段以**草稿中的解析值**比较；输入框中的临时文本（如 `12.`）不改变草稿。
- 保存成功前不重置 `initialDraft`；保存成功后先更新 `initialDraft = draft`，再 pop，避免返回拦截误触发。

---

## 6. 数据层

### 6.1 仓库接口

```dart
// lib/features/vehicles/data/vehicle_repository.dart
abstract class VehicleRepository {
  String? get primaryVehicleId;

  Future<GarageOverview> fetchGarage();
  Future<ArchivedGarage> fetchArchivedGarage();

  Future<void> setPrimary(String vehicleId);
  Future<void> archive(String vehicleId);
  Future<void> restore(String vehicleId);
  Future<void> delete(String vehicleId);
  Future<void> purgeArchivedVehicle(
    String vehicleId, {
    required String plateTail,
  });

  /// 编辑态档案快照；不存在 / 已归档抛对应错误。
  Future<VehicleEditorSnapshot> fetchVehicleEditor(String vehicleId);

  /// 新增车辆；返回新 id 与是否成为主驾。
  Future<VehicleEditorResult> createVehicle(VehicleEditorDraft draft);

  /// 更新档案；[version] 用于生产环境的乐观并发校验。
  Future<VehicleEditorResult> updateVehicle(
    String vehicleId,
    VehicleEditorDraft draft, {
    int? version,
  });
}

enum VehicleErrorCode {
  isPrimary,
  hasRecords,
  notFound,
  notArchived,
  plateTailMismatch,
  conflict,
  limitReached,
  duplicatePlate,
  invalidField,
  unknown,
}
```

- `createVehicle` / `updateVehicle` 接收 domain 层草稿，不接收 UI 模型；Mock 与 HTTP 实现共享同一套字段语义。
- `VehicleOperationException` 继续携带 `code` 与可选 `message`；`duplicatePlate` 用 `message` 带冲突车名，`invalidField` 用 `message` 带字段级错误（生产可由服务端返回 `details`，Mock 主要走客户端校验）。
- 生产 `PATCH` 建议携带 `version`；Mock 阶段 `version` 固定为 1，不做冲突检测（R5）。

### 6.2 `VehicleStore.add` / `update`

```dart
// lib/features/vehicles/data/vehicle_store.dart
enum VehicleStoreError {
  notFound,
  archived,
  notArchived,
  isPrimary,
  duplicatePlate,
  limitReached,
}

class VehicleStore {
  static const maxActiveVehicles = 10;

  VehicleRecord add(VehicleRecord record, {bool makePrimary = false}) {
    if (record.isArchived) {
      throw const VehicleStoreException(VehicleStoreError.archived);
    }
    if (active.length >= maxActiveVehicles) {
      throw const VehicleStoreException(VehicleStoreError.limitReached);
    }
    if (_plateOwner(record.vehicle.plate) != null) {
      throw const VehicleStoreException(VehicleStoreError.duplicatePlate);
    }
    final created = VehicleRecord(
      vehicle: record.vehicle,
      specLabel: record.specLabel,
      sortOrder: nextSortOrder,
      nickname: record.nickname,
      officialConsumption: record.officialConsumption,
      electricRangeKm: record.electricRangeKm,
      purchaseDate: record.purchaseDate,
      purchasePriceCents: record.purchasePriceCents,
      nextMaintenanceKm: record.nextMaintenanceKm,
      insuranceExpiry: record.insuranceExpiry,
      inspectionExpiry: record.inspectionExpiry,
    );
    _records.add(created);
    if (makePrimary || _primaryVehicleId == null) {
      _primaryVehicleId = created.id;
    }
    return created;
  }

  VehicleRecord update(
    String id,
    VehicleRecord updated, {
    bool makePrimary = false,
  }) {
    final current = require(id);
    if (current.isArchived) {
      throw const VehicleStoreException(VehicleStoreError.archived);
    }
    final owner = _plateOwner(updated.vehicle.plate);
    if (owner != null && owner.id != id) {
      throw const VehicleStoreException(VehicleStoreError.duplicatePlate);
    }
    final next = VehicleRecord(
      vehicle: updated.vehicle,
      specLabel: updated.specLabel,
      sortOrder: current.sortOrder,
      isArchived: current.isArchived,
      archivedAt: current.archivedAt,
      nickname: updated.nickname,
      officialConsumption: updated.officialConsumption,
      electricRangeKm: updated.electricRangeKm,
      purchaseDate: updated.purchaseDate,
      purchasePriceCents: updated.purchasePriceCents,
      nextMaintenanceKm: updated.nextMaintenanceKm,
      batteryHealthPercent: current.batteryHealthPercent,
      insuranceExpiry: updated.insuranceExpiry,
      inspectionExpiry: current.inspectionExpiry,
    );
    _replace(next);
    if (makePrimary) {
      _primaryVehicleId = id;
    }
    return next;
  }

  VehicleRecord? byPlate(String plate) => _plateOwner(plate);

  VehicleRecord? _plateOwner(String plate) {
    final normalized = _normalizePlate(plate);
    for (final record in _records) {
      if (_normalizePlate(record.vehicle.plate) == normalized) {
        return record;
      }
    }
    return null;
  }

  String _normalizePlate(String plate) =>
      plate.toUpperCase().replaceAll(RegExp(r'[\s·•\-]'), '');
}
```

- `add` 只接受在库记录；`sortOrder` 由 store 分配；`primaryVehicleId` 为空时首辆车自动成为主驾。
- `update` 保留 `sortOrder` / `isArchived` / `archivedAt` / SOH / 年检；不通过本方法修改归档状态。
- `_plateOwner` 检查**全部记录**（含归档），与需求 §7.2 一致；冲突时仓库层再查出车名用于错误文案。
- `update` 对当前主驾传 `makePrimary: false` 时保持主驾不变；UI 已禁用关闭开关，store 只做兜底。
- `add` / `update` 抛出 `duplicatePlate` / `limitReached` 后由 Mock 仓库映射为 `VehicleOperationException`。

### 6.3 Mock 仓库

```dart
// lib/features/vehicles/data/mock_vehicle_repository.dart
class MockVehicleRepository implements VehicleRepository {
  MockVehicleRepository({
    required this.store,
    required this.home,
    required this.ledger,
    DateTime Function()? now,
    String Function()? idGenerator,
    this.delay = const Duration(milliseconds: 140),
  }) : _now = now ?? DateTime.now,
       _idGenerator = idGenerator ?? _defaultId;

  final VehicleStore store;
  final HomeRepository home;
  final LedgerRepository ledger;
  final DateTime Function() _now;
  final String Function() _idGenerator;
  final Duration delay;

  @override
  Future<VehicleEditorSnapshot> fetchVehicleEditor(String vehicleId) async {
    await Future<void>.delayed(delay);
    final record = store.byId(vehicleId);
    if (record == null) {
      throw const VehicleOperationException(VehicleErrorCode.notFound);
    }
    if (record.isArchived) {
      throw const VehicleOperationException(VehicleErrorCode.notArchived);
    }
    final latest = await ledger.latestOdometer(vehicleId);
    final isPrimary = store.primaryVehicleId == vehicleId;
    final successor = isPrimary ? store.successorOf(vehicleId) : null;
    return VehicleEditorSnapshot(
      vehicleId: vehicleId,
      draft: VehicleEditorPresenter.draftOf(
        record,
        latestOdometerKm: latest,
        isPrimary: isPrimary,
      ),
      isPrimary: isPrimary,
      activeVehicleCount: store.active.length,
      maxActiveVehicles: VehicleStore.maxActiveVehicles,
      latestOdometerKm: latest,
      version: 1,
      successorName: successor == null
          ? null
          : store.byId(successor)?.vehicle.name,
      isOnlyActiveVehicle: store.active.length == 1,
    );
  }

  @override
  Future<VehicleEditorResult> createVehicle(VehicleEditorDraft draft) async {
    await Future<void>.delayed(delay);
    if (store.active.length >= VehicleStore.maxActiveVehicles) {
      throw const VehicleOperationException(VehicleErrorCode.limitReached);
    }
    final conflict = store.byPlate(draft.plate);
    if (conflict != null) {
      throw VehicleOperationException(
        VehicleErrorCode.duplicatePlate,
        conflict.vehicle.name,
      );
    }
    final id = _idGenerator();
    final vehicle = VehicleEditorPresenter.buildVehicle(
      draft: draft,
      id: id,
      badge: _badgeOf(draft),
    );
    final record = VehicleEditorPresenter.buildRecord(
      vehicle: vehicle,
      draft: draft,
      sortOrder: store.nextSortOrder,
    );
    final created = store.add(
      record,
      makePrimary: draft.makePrimary || store.active.isEmpty,
    );
    return VehicleEditorResult(vehicleId: created.id, created: true);
  }

  @override
  Future<VehicleEditorResult> updateVehicle(
    String vehicleId,
    VehicleEditorDraft draft, {
    int? version,
  }) async {
    await Future<void>.delayed(delay);
    final existing = store.byId(vehicleId);
    if (existing == null) {
      throw const VehicleOperationException(VehicleErrorCode.notFound);
    }
    if (existing.isArchived) {
      throw const VehicleOperationException(VehicleErrorCode.notArchived);
    }
    final conflict = store.byPlate(draft.plate);
    if (conflict != null && conflict.id != vehicleId) {
      throw VehicleOperationException(
        VehicleErrorCode.duplicatePlate,
        conflict.vehicle.name,
      );
    }
    final vehicle = VehicleEditorPresenter.buildVehicle(
      draft: draft,
      id: vehicleId,
      badge: _badgeOf(draft, fallback: existing.vehicle.badge),
    );
    final record = VehicleEditorPresenter.buildRecord(
      vehicle: vehicle,
      draft: draft,
      sortOrder: existing.sortOrder,
      existing: existing,
    );
    store.update(vehicleId, record, makePrimary: draft.makePrimary);
    return VehicleEditorResult(vehicleId: vehicleId, created: false);
  }

  String? _badgeOf(VehicleEditorDraft draft, {String? fallback}) {
    if (draft.defaultFuelGrade != null) {
      return '${draft.defaultFuelGrade}号汽油';
    }
    if (fallback == null || fallback.contains('号汽油')) {
      return null;
    }
    return fallback;
  }

  static String _defaultId() =>
      'veh-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
}
```

- `fetchGarage` 构造 `ManagedVehicle` 时传入 `nickname: record.nickname`；`VehicleMemberCard` 在非空时显示昵称胶囊。
- Mock 的 `version` 固定为 1；生产 `PATCH` 携带快照 `version`，服务端冲突返回 `VEHICLE_CONFLICT`。
- `badge` 只做展示：有默认油品时显示「{grade}号汽油」，否则保留原徽标；不生成「绿牌插混」等无数据依据的文案。
- 新增车辆的 id 为本地时间戳 base36；生产由服务端返回。Mock 重启后种子恢复，新增车辆丢失（已知限制，R5）。
- `store.byPlate` 为新增方法，返回冲突记录；实现复用 `_normalizePlate`。

### 6.4 新车辆空看板与保养覆盖

新建车辆没有 `MockHomeRepository._cars` 中的静态演示数据，必须让所有读取 dashboard 的页面拿到结构化空数据，而不是抛异常。

```dart
// lib/features/home/data/mock_home_repository.dart
@override
Future<HomeDashboard> fetchDashboard(String vehicleId) async {
  final base = _carByIdOrNull(vehicleId);
  final record = store?.byId(vehicleId);
  if (base == null) {
    if (record == null) {
      throw StateError('Unknown vehicle: $vehicleId');
    }
    return _withMaintenanceOverride(_emptyDashboard(record), record);
  }
  final dashboard = HomeDashboard(
    vehicle: record?.vehicle ?? base.vehicle,
    summary: base.summary,
    consumption: base.consumption,
    maintenance: base.maintenance,
  );
  return _withMaintenanceOverride(dashboard, record);
}

HomeDashboard _emptyDashboard(VehicleRecord record) {
  final electric = record.vehicle.powertrain == PowertrainType.ev ||
      record.vehicle.powertrain == PowertrainType.phev;
  return HomeDashboard(
    vehicle: record.vehicle,
    summary: const HomeSummary(
      costPerKm: 0,
      monthSpendCents: 0,
      monthMileageKm: 0,
      energyCostPerKm: 0,
      momTrend: TrendDirection.none,
    ),
    consumption: Consumption(
      label: electric ? '动力电耗' : '综合油耗',
      typeLabel: record.vehicle.powertrainLabel,
      primary: EnergyValue(
        value: 0,
        unit: electric ? 'kWh/百公里' : 'L/百公里',
      ),
      primarySparkline: const [],
      hasData: false,
    ),
    maintenance: const Maintenance(
      enabled: false,
      remainingKm: 0,
      progressPercent: 0,
      status: MaintenanceStatus.normal,
      hasProgress: false,
    ),
  );
}

HomeDashboard _withMaintenanceOverride(
  HomeDashboard dashboard,
  VehicleRecord? record,
) {
  final next = record?.nextMaintenanceKm;
  if (next == null) {
    return dashboard;
  }
  final current = odometerResolver?.call(record!.id) ??
      record.vehicle.odometerKm;
  final remaining = next - current;
  final last = ledger?.latestMaintenanceOdometer(record.id);
  final hasProgress = last != null && next > last;
  final progress = hasProgress
      ? (((current - last!) / (next - last)) * 100).clamp(0, 100).round()
      : 0;
  return HomeDashboard(
    vehicle: dashboard.vehicle,
    summary: dashboard.summary,
    consumption: dashboard.consumption,
    maintenance: Maintenance(
      enabled: true,
      remainingKm: remaining,
      progressPercent: progress,
      status: remaining < 0
          ? MaintenanceStatus.overdue
          : (remaining <= 1000
                ? MaintenanceStatus.warning
                : MaintenanceStatus.normal),
      hasProgress: hasProgress,
    ),
  );
}
```

- `Consumption` 增加 `bool hasData`（默认 `true`）；`Maintenance` 增加 `bool hasProgress`（默认 `true`）。既有 Mock 构造不传，行为不变。
- `fetchBreakdown` / `fetchTrend` / `fetchRecords` 对未知车辆返回空结构：
  - `Breakdown(totalCents: 0, count: 0, categories: const [])`
  - `TrendData(range: range, points: const [], totalCents: 0, ...)`
  - 记录列表为空。
- `MockProfileRepository`、`MockStatsRepository`、`MockVehicleRepository` 都通过 `home.fetchDashboard` 取数，因此空看板会自动覆盖这些页面。
- `VehiclePresenter.metricsOf` 在 `consumption.hasData == false` 时显示「— / 未录入」，不输出 0.0；首页能耗卡显示「暂无能耗记录」。我的页车库聚合不读 `consumption`，零支出 / 未设置保养按既有空态显示。
- 月度报表只依赖账单记录；新车辆无流水时按既有空态处理。

`LedgerRepository` 新增：

```dart
/// 最近一次「保养」类别流水的表显里程；无记录返回 null。
int? latestMaintenanceOdometer(String vehicleId);
```

Mock 实现从 `_records` 中筛 `ExpenseCategory.maintenance`、按 `occurredAt` 倒序取第一条的 `metrics.odometerKm`；没有里程字段则返回 null。

### 6.5 车牌规范化与唯一

- 规范化函数只保留一份：`VehicleEditorPresenter.normalizePlateBody`。
- `VehicleStore` 内部使用同一规则（不依赖 presentation 层）；建议把纯函数下沉到 `core/format/plate_format.dart`，由 store 与 presenter 共用，避免循环依赖。
- 唯一性比较：`province + plateBody` 去掉分隔符后大写；包含归档车辆。
- 客户端即时校验使用 `vehiclesProvider`（在库）与可选的 `fetchArchivedGarage`（归档）；保存时服务端为最终裁判。
- 车牌输入格式器：

```dart
// lib/features/vehicles/presentation/widgets/vehicle_plate_input.dart
class PlateInputFormatter extends TextInputFormatter {
  PlateInputFormatter({required this.green});

  final bool green;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final body = VehicleEditorPresenter.normalizePlateBody(newValue.text);
    final maxBody = green ? 7 : 6;
    final limited = body.length > maxBody ? body.substring(0, maxBody) : body;
    final formatted = VehicleEditorPresenter.formatPlateBody(limited);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
```

- 输入框始终把光标放在末尾；用户从中间编辑时会跳到末尾，属于可接受的 P0 取舍（车牌通常一次输入）。
- 粘贴完整车牌时，页面在格式化前去掉与当前省份相同的首字；避免用户把「粤B·D82K6」整段粘进字符框后校验失败。
- 切换绿牌开关时重建 formatter；若已有字符长度不匹配，保留文本并显示错误，不自动截断。
- 省份选择通过 `showProvincePicker` 返回 `String?`；取消返回 null，不改变当前值。

### 6.6 Provider

```dart
// lib/features/vehicles/domain/vehicle_editor_providers.dart
final vehicleEditorControllerProvider = NotifierProvider.autoDispose
    .family<VehicleEditorController, VehicleEditorState, VehicleEditorArgs>(
      VehicleEditorController.new,
    );

final vehicleEditorRepositoryProvider = Provider<VehicleRepository>((ref) {
  return ref.watch(vehicleRepositoryProvider);
});
```

- `autoDispose`：离开页面即释放；编辑态重新进入会重新拉快照，避免拿到旧档案。
- 新增态不调用仓库；只读 `vehiclesProvider` / `garageProvider` 获取在库数量与车牌。
- 页面只 watch `vehicleEditorControllerProvider(args)`，不直接读 store。

### 6.7 错误映射

| 错误码 | 页面处理 | 文案 |
| --- | --- | --- |
| `invalidField` | 字段级错误（生产 `details.field`） | 使用服务端文案；缺省「请检查该字段」 |
| `duplicatePlate` | 车牌字段错误 | 「该车牌已在车库中（{车名}）」 |
| `limitReached` | 表单级错误 | 「车库车辆已达上限（10 辆），请先归档不再使用的车辆」 |
| `notFound` | 错误态 / 保存失败 | 「车辆已不存在，请返回车库刷新」 |
| `notArchived` | 错误态 / 保存失败 | 「该车辆已归档，请在已归档车辆中恢复后再修改」 |
| `conflict` | 表单级错误 | 「车辆信息已更新，请刷新后重试」；保留输入 |
| `isPrimary` | 主驾开关提示 | 「默认主驾需在车辆管理中切换」 |
| `unknown` | 表单级错误 | 「保存失败，请重试」 |

- 编辑加载阶段 `notFound` / `notArchived` 进入整页错误态；保存阶段进入表单级错误，不切换整页状态，避免用户输入丢失。
- 归档复用 `VehicleCommandNotifier._messageFor`，新增 `duplicatePlate` / `invalidField` 分支不影响归档错误。

### 6.8 格式化辅助

```dart
// lib/core/format/formatters.dart
String formatWan(int cents) => '${(cents / 1000000).toStringAsFixed(2)} 万元';
String formatEditorDate(DateTime date) => DateFormat('yyyy/MM/dd').format(date);
int? parseWanToCents(String text) { /* 见 presenter */ }
```

- 金额内部仍为整数分；`formatWan` 只用于编辑页 / 详情展示。
- 日期输入使用 `yyyy/MM/dd`；卡片与提醒沿用 `formatArchiveDate` 的 `yyyy年M月d日` 或既有相对文案。

---

## 7. 状态管理

### 7.1 Controller 生命周期

```dart
// lib/features/vehicles/domain/vehicle_editor_providers.dart
class VehicleEditorController extends Notifier<VehicleEditorState> {
  VehicleEditorController(this.args);

  final VehicleEditorArgs args;
  bool _submitting = false;
  bool _plateManuallyToggled = false;
  final Map<PowertrainType, _SpecValues> _specCache = {};

  @override
  VehicleEditorState build() {
    final initial = VehicleEditorDraft(
      province: '粤',
      powertrain: PowertrainType.ev,
      isGreenPlate: true,
    );
    _bootstrap();
    return VehicleEditorState(
      args: args,
      draft: initial,
      initialDraft: args.isCreate ? initial : null,
      status: args.isCreate
          ? VehicleEditorStatus.ready
          : VehicleEditorStatus.loading,
    );
  }

  Future<void> _bootstrap() async {
    if (args.isCreate) {
      try {
        final garage = await ref.read(garageProvider.future);
        if (!ref.mounted) return;
        final empty = garage.vehicles.isEmpty;
        final full = garage.vehicles.length >= VehicleStore.maxActiveVehicles;
        // 约束回填不覆盖用户已经输入的内容。
        if (state.draft != state.initialDraft) {
          state = state.copyWith(
            isPrimaryLocked: empty,
            activeVehicleCount: garage.vehicles.length,
            maxActiveVehicles: VehicleStore.maxActiveVehicles,
          );
          return;
        }
        final draft = state.draft.copyWith(makePrimary: empty);
        state = state.copyWith(
          draft: draft,
          initialDraft: draft,
          isPrimaryLocked: empty,
          activeVehicleCount: garage.vehicles.length,
          maxActiveVehicles: VehicleStore.maxActiveVehicles,
          formError: full
              ? '车库车辆已达上限（10 辆），请先归档不再使用的车辆'
              : null,
        );
      } catch (_) {
        if (!ref.mounted) return;
        // 新增不因车库约束读取失败而阻断；保存时由接口兜底。
        state = state.copyWith(
          formError: '未能读取车库状态，保存时将由服务端校验。',
        );
      }
      return;
    }

    try {
      final snapshot = await ref
          .read(vehicleEditorRepositoryProvider)
          .fetchVehicleEditor(args.vehicleId!);
      if (!ref.mounted) return;
      state = state.copyWith(
        status: VehicleEditorStatus.ready,
        draft: snapshot.draft,
        initialDraft: snapshot.draft,
        isPrimaryLocked: snapshot.isPrimary,
        activeVehicleCount: snapshot.activeVehicleCount,
        maxActiveVehicles: snapshot.maxActiveVehicles,
        latestOdometerKm: snapshot.latestOdometerKm,
        version: snapshot.version,
      );
    } on VehicleOperationException catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        status: error.code == VehicleErrorCode.notArchived
            ? VehicleEditorStatus.archived
            : VehicleEditorStatus.notFound,
        formError: error.message,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(status: VehicleEditorStatus.error);
    }
  }
}
```

- 新增态 `build()` 即返回 `ready` 与默认草稿，用户可立即输入；`_bootstrap` 只回填在库数量 / 首辆车锁定，不覆盖已输入内容。
- 新增态在 `_bootstrap` 中读取一次 `garageProvider`；之后的主驾锁定、上限提示都基于这份快照。
- 新增态若 `activeVehicleCount >= maxActiveVehicles`，`status` 仍为 ready，但预置 `formError`「车库车辆已达上限（10 辆），请先归档不再使用的车辆」；页面可据此禁用主按钮，保存接口仍兜底 `limitReached`。
- 编辑态只请求一次快照；页面停留期间不重拉，避免用户输入被覆盖。
- `ref.mounted` 在每个 `await` 后检查；页面退出后不再 setState。

### 7.2 字段更新与动力缓存

```dart
void update(VehicleEditorDraft Function(VehicleEditorDraft draft) transform) {
  if (state.isSaving || !state.isReady) return;
  final next = transform(state.draft);
  if (next == state.draft) return;
  state = state.copyWith(
    draft: next,
    fieldErrors: _withoutErrorFor(transform, next),
    formError: null,
  );
}

void setPowertrain(PowertrainType type) {
  if (state.isSaving || state.draft.powertrain == type) return;
  _specCache[state.draft.powertrain] = _SpecValues.fromDraft(state.draft);
  final cached = _specCache[type] ?? const _SpecValues();
  _plateManuallyToggled = false;
  final draft = state.draft.copyWith(
    powertrain: type,
    isGreenPlate: _defaultGreenPlate(type),
    batteryCapacityKwh: cached.battery,
    clearBattery: cached.battery == null,
    officialConsumption: cached.officialConsumption,
    clearOfficialConsumption: cached.officialConsumption == null,
    electricRangeKm: cached.electricRange,
    clearElectricRange: cached.electricRange == null,
    tankCapacityL: cached.tank,
    clearTank: cached.tank == null,
    defaultFuelGrade: cached.fuelGrade,
    clearFuelGrade: cached.fuelGrade == null,
  );
  state = state.copyWith(draft: draft, fieldErrors: const {});
}

void toggleGreenPlate() {
  _plateManuallyToggled = true;
  state = state.copyWith(
    draft: state.draft.copyWith(isGreenPlate: !state.draft.isGreenPlate),
    fieldErrors: _withoutField(VehicleEditorField.plate),
  );
}

void togglePrimary() {
  if (state.isPrimaryLocked) return;
  state = state.copyWith(
    draft: state.draft.copyWith(makePrimary: !state.draft.makePrimary),
  );
}
```

- `_SpecValues` 保存当前动力类型下的电池 / 官方能耗 / 续航 / 油箱 / 默认油品；切换时先存后取。EV 缓存中的油品固定为 null，切换到 EV 会清空油品，避免给纯电车型写入 `defaultFuelGrade`。
- 车牌手动切换只改 `isGreenPlate`，不截断已输入字符；字符长度不匹配由校验提示。
- 主驾锁定时 `togglePrimary` 直接返回；UI 同时禁用开关。
- 字段更新只清除**该字段**的错误，不整表清空，避免用户改一个字段后其他错误消失。

`VehicleEditorState.copyWith` 需支持清除 `formError` / `fieldErrors`，实现时使用 `clearFormError` 标记，避免 `null` 歧义。

### 7.3 保存流程

```dart
Future<VehicleEditorResult?> save() async {
  if (_submitting || !state.isReady) return null;

  final errors = validateVehicleEditorDraft(
    state.draft,
    now: DateTime.now(),
    latestOdometerKm: state.latestOdometerKm,
    knownVehicles: _knownPlateOwners(),
  );
  if (errors.isNotEmpty) {
    state = state.copyWith(fieldErrors: errors, formError: null);
    return null;
  }

  _submitting = true;
  state = state.copyWith(
    isSaving: true,
    fieldErrors: const {},
    formError: null,
  );

  try {
    final repository = ref.read(vehicleEditorRepositoryProvider);
    final result = args.isCreate
        ? await repository.createVehicle(state.draft)
        : await repository.updateVehicle(
            args.vehicleId!,
            state.draft,
            version: state.version,
          );
    if (!ref.mounted) return result;

    final scopes = ref.read(vehicleScopeInvalidatorProvider);
    scopes.invalidateAll();
    scopes.normalizeScopes(
      result.vehicleId,
      select: args.isCreate || state.draft.makePrimary,
    );
    state = state.copyWith(
      isSaving: false,
      initialDraft: state.draft,
    );
    return result;
  } on VehicleOperationException catch (error) {
    if (!ref.mounted) return null;
    if (error.code == VehicleErrorCode.duplicatePlate) {
      state = state.copyWith(
        isSaving: false,
        fieldErrors: {
          VehicleEditorField.plate: '该车牌已在车库中（${error.message ?? '已有车辆'}）',
        },
      );
    } else {
      state = state.copyWith(
        isSaving: false,
        formError: VehicleEditorPresenter.errorMessageFor(error.code),
      );
    }
    return null;
  } catch (_) {
    if (!ref.mounted) return null;
    state = state.copyWith(
      isSaving: false,
      formError: '保存失败，请重试',
    );
    return null;
  } finally {
    _submitting = false;
  }
}
```

`_knownPlateOwners()` 从 `vehiclesProvider` 的当前快照构造在库车辆车牌；归档车辆不在其中，由服务端在保存时做全量唯一校验。客户端即时提示只覆盖在库冲突，避免为了一个提示额外拉取归档列表。

- 先校验、后提交；校验失败不改变 `isSaving`，也不调用接口。
- 成功后先刷新全局状态，再返回结果；页面拿到结果后用 `VehicleEditorPresenter.successMessageOf(...)` 调 `showAppToast`，再 `pop`。`ScaffoldMessenger` 由 `MaterialApp` 根持有，Toast 在 pop 后仍可见。
- 新增成功后**总是选中新车**（`select: true`），无论是否设为主驾；这样从首页添加后能立即看到新车。主驾仍由 `makePrimary` 决定。
- 编辑成功且接管主驾时选中该车；否则保持当前选中。
- 失败时保留 `fieldErrors` / `formError` 与全部输入；不重试、不乐观更新。

### 7.4 失效矩阵

| 操作 | 车库 | 车辆列表 | 首页看板 / 记录 | 账单 | 统计 | 我的页 | 报表 | 归档列表 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 新增车辆 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 更新名称 / 车牌 / 里程 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 更新容量 / 油品 | ✅ | ✅ | ✅ | — | — | ✅ | — | — |
| 更新保险 / 保养 | ✅ | — | ✅ | — | ✅ | ✅ | — | — |
| 设为默认主驾 | ✅ | — | ✅ | — | — | ✅ | — | — |
| 归档 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

- 本页保存统一调用 `VehicleScopeInvalidator.invalidateAll()`，沿用车辆管理现有的全量失效列表，避免漏项。
- 容量 / 油品虽不改变账单金额，但会改变记账页预填；仍走全量失效，逻辑简单且数据量小。
- 归档复用 `vehicleCommandProvider`，其 `_invalidateAll` 已包含归档列表。

### 7.5 作用域归一化

把现有 `VehicleCommandNotifier._normalizeScopes` / `_invalidateAll` 抽成可复用对象：

```dart
// lib/features/vehicles/domain/providers.dart
final vehicleScopeInvalidatorProvider = Provider<VehicleScopeInvalidator>(
  (ref) => VehicleScopeInvalidator(ref),
);

class VehicleScopeInvalidator {
  VehicleScopeInvalidator(this.ref);

  final Ref ref;

  void invalidateAll() {
    ref.invalidate(garageProvider);
    ref.invalidate(archivedGarageProvider);
    ref.invalidate(vehiclesProvider);
    ref.invalidate(homeDashboardProvider);
    // ... 与现有 VehicleCommandNotifier._invalidateAll 相同
  }

  void normalizeScopes(
    String? affectedVehicleId, {
    bool select = false,
    bool fallbackIfAffected = false,
  }) {
    if (affectedVehicleId == null) return;
    final primary = ref.read(vehicleRepositoryProvider).primaryVehicleId;
    final selected = ref.read(selectedVehicleIdProvider);

    if (select && selected != affectedVehicleId) {
      ref.read(selectedVehicleIdProvider.notifier).select(affectedVehicleId);
    } else if (fallbackIfAffected && selected == affectedVehicleId) {
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
}
```

- 新增：`select` 为 true，首页 / 统计默认看新车；账单 / 统计筛选不可能指向新 id，相关分支为兜底。
- 编辑：若接管主驾，`select` 为 true；否则 `select: false, fallbackIfAffected: false`，保持当前选中，不把正在编辑的非主驾车重置为主驾。
- 归档 / 删除：沿用 `VehicleCommandNotifier.archive` / `delete`，`select: false, fallbackIfAffected: true`；选中被移除车辆时回退到继任主驾或 `null`。
- 编辑名称 / 车牌不改变任何 scope 的 id，只靠失效刷新抬头。

### 7.6 竞态与生命周期

- **重复提交**：`_submitting` + `state.isSaving` 双重保护；按钮 loading 期间禁用。
- **快速返回**：保存中 `PopScope(canPop: false)` + 主按钮 / 归档禁用；保存完成后页面已 `pop`，不再 Toast。
- **并发编辑**：生产 `PATCH` 携带 `version`；冲突返回 `VEHICLE_CONFLICT`，保留用户输入并提示刷新；Mock 不模拟。
- **车辆被归档 / 删除**：保存返回 `notArchived` / `notFound`；表单级错误提示，用户可返回车库。
- **页面销毁**：`autoDispose` 释放 controller；每个 `await` 后检查 `ref.mounted`。
- **主驾竞态**：保存时 `makePrimary` 由服务端原子处理；客户端只以保存结果为准，不先本地改主驾。
- **归档竞态**：归档命令串行；编辑页在归档成功后直接 `pop`，不再触发保存。

### 7.7 乐观更新取舍

**不做乐观更新**：保存 / 归档均等待服务端（Mock 延迟）返回后再刷新与退出。理由：

1. 车辆档案影响首页、账单、统计、我的页、报表，乐观失败回滚面太大；
2. 车牌唯一、车库上限、主驾唯一性都只能由服务端最终判定；
3. 表单保留输入比「先退出再报错」体验更好。

---

## 8. UI 实现

### 8.1 页面骨架

```dart
class VehicleEditorPage extends ConsumerStatefulWidget {
  const VehicleEditorPage({super.key, this.vehicleId});

  final String? vehicleId;

  @override
  ConsumerState<VehicleEditorPage> createState() => _VehicleEditorPageState();
}

class _VehicleEditorPageState extends ConsumerState<VehicleEditorPage> {
  @override
  Widget build(BuildContext context) {
    final args = widget.vehicleId == null
        ? const VehicleEditorArgs.create()
        : VehicleEditorArgs.edit(widget.vehicleId!);
    final state = ref.watch(vehicleEditorControllerProvider(args));

    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: context.palette.background,
      resizeToAvoidBottomInset: false,
      body: Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 448),
            child: PopScope(
              canPop: !state.isSaving && !state.isDirty,
              onPopInvokedWithResult: (didPop, _) => _handlePop(didPop, state),
              child: SafeArea(
                top: true,
                bottom: false,
                child: Column(
                  children: [
                    VehicleEditorHeader(
                      state: state,
                      onBack: () => _handleBack(state),
                    ),
                    Expanded(
                      child: _VehicleEditorForm(args: args, state: state),
                    ),
                    VehicleEditorBottomBar(state: state),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- 顶部栏固定，不随表单滚动；`SafeArea(top: true)` 避开状态栏，与设计稿的吸顶 + 毛玻璃一致。
- 表单使用 `SingleChildScrollView` / `ListView`，底部留出操作栏高度 + 安全区。
- 不把操作栏放进 `bottomNavigationBar`：使用 `resizeToAvoidBottomInset: false` + `Padding(bottom: viewInsets.bottom)`，键盘弹出时整页上移、操作栏贴在键盘上方，表单可用高度缩小，行为比 `bottomNavigationBar` 更可控。
- 操作栏自身使用 `SafeArea(top: false)`；键盘弹出时 `viewInsets` 已覆盖底部安全区。
- 加载 / 错误态仍渲染顶部栏；表单区替换为骨架 / 空态 / 错误。
- 不渲染底部导航与 FAB。

### 8.2 顶部栏 `VehicleEditorHeader`

- 40 × 40 圆形返回按钮；`Navigator.maybePop` 或脏检查回调。
- 标题 / 副标题由 `VehicleEditorPresenter.titleOf` / `subtitleOf` 生成。
- OCR 胶囊：`photo_camera` 16 + 「证件识别」10/12；点击 `showAppToast(context, '证件识别将在下一版开放')`；`state.isSaving` 时禁用。
- 背景 `surface` 85% + 毛玻璃；底部 1px 半透明描边；用 `BackdropFilter` 或现有 `BlurredHeaderDelegate` 的样式。

### 8.3 动力选择器 `PowertrainSelector`

```dart
class PowertrainSelector extends StatelessWidget {
  const PowertrainSelector({
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final PowertrainType value;
  final ValueChanged<PowertrainType> onChanged;
  final bool enabled;
}
```

- `Row` + 4 个 `Expanded`；每段 `InkWell` + `AnimatedContainer` 200ms。
- 4 段在 320 宽下仍可显示：主标签 11 号、副标签 10 号；文案用「纯电 EV / 插混·增程 / 油电混动 / 燃油 ICE」。
- 选中态使用 `PowertrainVisual.color`；未选中 `outline`。
- 用 `Semantics(selected: true, button: true, label: '纯电 EV，电耗核算')`。
- 切换时表单字段用 `AnimatedSwitcher` + `AnimatedSize`；不重建整个页面，避免滚动位置跳变。

### 8.4 身份信息卡 `VehicleIdentityCard`

- 卡片 `AppCard` / `Container`：白底、28 圆角、20 内边距、1px 白描边、`AppTokens.cardShadow`。
- 卡片头部：32 圆形主色 10% 底 + `directions_car`；标题「车辆身份信息」；副标题「品牌、车系与车牌基础档案」。
- 字段：
  - 品牌车型：`TextField` + `TextEditingController`；`textInputAction: next`；
  - 快捷胶囊：`SingleChildScrollView(horizontal)` + 4 个 `ActionChip` 样式按钮；
  - 配置版本：选填；
  - 车牌：`VehiclePlateInput`（§8.5）；
  - 当前总里程：`TextField(keyboardType: number)` + 右侧 `km`；`FilteringTextInputFormatter.digitsOnly`。
- 每个字段下方保留 16–20 的垂直间距；错误文案占位高度固定，避免布局跳动。
- 文本控制器由 `_VehicleEditorForm` 持有；`ref.listen` 在编辑加载完成后写入初值。
- `_syncControllers` 只在 `controller.text != value` 且字段未聚焦时更新，避免光标跳动。

### 8.5 车牌输入 `VehiclePlateInput` 与省份弹层

```dart
class VehiclePlateInput extends StatelessWidget {
  const VehiclePlateInput({
    required this.province,
    required this.plateBody,
    required this.green,
    required this.error,
    required this.onProvinceTap,
    required this.onChanged,
    required this.onGreenChanged,
    this.enabled = true,
  });
}
```

- 行标题左侧「车牌号码」，右侧文案 + `Switch`（44 × 26）。
- 输入行：省份按钮（64 × 48）+ 字符框（`Expanded`）。
- 字符框使用 `PlateInputFormatter`；`textAlign: center`、`letterSpacing: 0.12em`、`headlineSm`。
- 下方 3px `Container` 渐变条：绿色 / 蓝色；用 `AnimatedContainer` 200ms。
- 省份按钮点击：

```dart
Future<String?> showProvincePicker(
  BuildContext context, {
  required String selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ProvincePickerSheet(selected: selected),
  );
}
```

- 弹层内容：拖拽把手、标题 / 副标题、关闭按钮、常用 12 格（6 列）、全览 31 格（7 列）、取消。
- 选中态：主色底 + `onPrimaryContainer` 字 + 2px 主色 30% 外环；用 `AnimatedContainer` 150ms。
- 点击省份立即 `Navigator.pop(province)`；页面收到后更新草稿并 Toast。
- 保存中不允许打开弹层；`enabled: false`。

### 8.6 规格卡 `VehicleSpecsCard`

- 卡片头部：32 圆形 `secondary` 15% 底 + `tune`；标题「动力与能耗基准」；副标题「官方标称数据，用于能耗核算参考」。
- 动态字段用 `AnimatedSwitcher(duration: 200ms)`，按动力类型渲染：
  - EV：电池容量 / 官方电耗；
  - PHEV：纯电续航 / 电池容量 / 油箱 / 亏电油耗；
  - HEV：油箱 / 综合油耗；
  - ICE：油箱 / 标称油耗。
- 双列 `Row` + `Expanded` + 12 间距；窄屏 / 1.3 倍字号用 `LayoutBuilder` 切单列。
- 数字输入统一使用 `_NumberField`：
  - `keyboardType: TextInputType.numberWithOptions(decimal: true/false)`；
  - `inputFormatters`：`FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}'))`；
  - 右侧单位 `Positioned` 或 `suffixText`；不遮挡输入。
- 默认油品：`Wrap` + 3 个 `ChoiceChip` 样式按钮（92 / 95 / 98）；单选，再次点击取消。与记账页 `FuelDetail.fuelGrade` 的取值范围一致，不引入柴油选项。
- 购车日期 / 车险日期：`_DateField`，点击 `showDatePicker`；显示 `yyyy/MM/dd` + 日历图标。
- 购车价格：小数输入 + 右侧「万元」；`parseWanToCents` 存储。

### 8.7 偏好卡 `VehiclePreferencesCard`

- 卡片头部：32 圆形 `tertiary` 10% 底 + `verified_user`；标题「周期提醒与偏好」；副标题「保养计划与专属驾驶标识」。
- 昵称：普通文本输入，`maxLength: 12`，不显示计数器（避免视觉噪音）；超出截断。
- 主驾行：`star` 图标底盘 + 标题 + 副标题 + `Switch`；锁定态开关禁用，副标题替换为「默认主驾需在车辆管理中切换」。
- 保养 / 保险：双列 `Row`；保养为整数输入 + `km`；保险为日期输入。
- 保养输入 ≤ 当前里程时，在字段下方显示警示文案（`secondaryText`），不阻断。
- 保险日期早于今天时，显示「已过期」警示。
- 所有字段错误使用危险色 `bodySm`；警示使用 `secondaryText`，与错误区分。

### 8.8 底部操作栏 `VehicleEditorBottomBar`

```dart
class VehicleEditorBottomBar extends ConsumerWidget {
  const VehicleEditorBottomBar({super.key, required this.state});

  final VehicleEditorState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = state.mode;
    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface.withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(color: context.palette.outlineVariant, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.formError != null) ...,
              _SaveButton(mode: mode, state: state),
              if (mode == VehicleEditorMode.edit) _ArchiveButton(state: state),
            ],
          ),
        ),
      ),
    );
  }
}
```

- 保存按钮：`FilledButton` 样式、52 高、圆角 999、主色；内容 `check_circle` + 文案；`state.isSaving` 时显示 16 圆形进度。
- 归档按钮：`TextButton`、危险色、`inventory_2` 16；高 44。
- 表单级错误放在按钮上方，`liveRegion: true`。
- 点击保存：`controller.save()`；成功则 `Navigator.pop(result)`；失败留在本页。
- 主按钮在 `!state.canSubmit` 时禁用（加载中 / 保存中）；新增 / 编辑的必填未填时**不禁用**，点击后展示字段错误（避免用户不知道为什么点不动）。

### 8.9 放弃修改弹层

- 复用 `showVehicleSheet<bool>` 外壳（32 顶部圆角、拖拽把手、安全区）。
- 图标 48 圆形、警示色 14% 底、`edit_note`。
- 标题「放弃未保存的修改？」；正文「当前填写的内容尚未保存，离开后将丢失。」
- 按钮「继续编辑」（中性）/「放弃修改」（危险实心）。
- 返回 `true` 表示放弃；页面据此执行 pop 或继续归档。
- 弹层不自动关闭；由按钮显式关闭；点击遮罩 / 下滑等同于「继续编辑」（不丢数据）。

### 8.10 状态分发

```dart
Widget _body(VehicleEditorState state) {
  return switch (state.status) {
    VehicleEditorStatus.loading => const VehicleEditorSkeleton(),
    VehicleEditorStatus.ready => VehicleEditorForm(state: state),
    VehicleEditorStatus.notFound => _EditorErrorState(
      icon: Icons.car_crash_rounded,
      title: '车辆档案不存在',
      message: '该车辆可能已被删除，请返回车库刷新。',
      actionLabel: '返回车库',
      onAction: () => Navigator.of(context).pop(),
    ),
    VehicleEditorStatus.archived => _EditorErrorState(
      icon: Icons.inventory_2_rounded,
      title: '该车辆已归档',
      message: '归档车辆不可编辑，请在「已归档车辆」中恢复后再修改。',
      actionLabel: '返回车库',
      onAction: () => Navigator.of(context).pop(),
    ),
    VehicleEditorStatus.error => SectionError(
      message: '车辆档案加载失败',
      onRetry: () => ref.invalidate(
        vehicleEditorControllerProvider(args),
      ),
    ),
  };
}
```

- `_EditorErrorState` 为页面局部空态组件（现有 `EmptyState` 只有标题，没有正文参数），包含图标、标题、正文与「返回车库」按钮；视觉沿用 `AppCard`。
- 编辑加载中底部栏仍显示但主按钮禁用；返回可用（无脏数据）。
- 错误态不渲染表单与底部栏，避免用户误以为可以保存。
- 保存失败不改变 `status`，只显示 `formError` / `fieldErrors`。

### 8.11 深色模式

- 全部颜色来自 `context.palette` / `context.tokens`；不使用设计稿的硬编码 hex。
- 输入框底色 `surfaceContainer` 70%；深色下改为 50%–60%，保持与卡片对比。
- 车牌渐变在深色下降低亮度：绿牌 `#00C48C → #0A8C66`，蓝牌 `#2563EB → #4F46E5` 降低 10% 透明度。
- 危险 / 错误色使用 `palette.error`（深色为 `#FFB4AB`），对比 ≥ 4.5:1。
- 省选中态在深色下使用主色 18% 底 + 主色文字，避免纯白底刺眼。

### 8.12 无障碍

- 每个输入框有 `labelText` / `hintText` 或外部 `Semantics(label:)`；不要只靠占位符。
- 动力段：`Semantics(button: true, selected: ..., label: '纯电 EV，电耗核算')`。
- 开关：`Semantics(toggled: value, label: '新能源渐变绿牌' / '设为默认主座驾')`。
- 错误文案：`Semantics(liveRegion: true)`，保存失败时播报。
- 触控区：返回 40 + 外层 padding ≥ 44；保存 52；归档 44；省份胶囊 ≥ 40；快捷胶囊 ≥ 32（可点区域外扩）。
- 键盘导航：`textInputAction` 依次 next / done；保存按钮可从键盘 `done` 触发。
- 颜色不是唯一信息载体：动力段有图标 + 文字；错误有图标或文案；绿牌 / 蓝牌有文字标签。

### 8.13 动效

- 页面路由 250ms；动力切换 200ms；省份弹层 280ms；放弃修改 260ms。
- 保存中只做进度旋转，不做按钮缩放；防止误触。
- 表单错误淡入 150ms，不抖动。
- 系统开启「减少动态效果」：取消位移 / 缩放，保留淡入淡出与进度。
- 不做成功 confetti、不做危险脉冲。

---

## 9. 交互与跳转

### 9.1 入口接线

| 入口 | 文件 | 改动 |
| --- | --- | --- |
| 车辆管理顶部「添加爱车」 | `vehicle_management_page.dart` | `_addPlaceholder` → `openVehicleEditor(context)` |
| 车辆管理虚线卡「添加新座驾到车库」 | 同上 | `onTap` → `openVehicleEditor(context)`；达到上限时置灰并 Toast |
| 车辆管理「更多 → 编辑车辆档案」 | 同上 | `_editPlaceholder` → `openVehicleEditor(context, vehicleId: id)` |
| 首页车辆切换器「添加车辆」 | `vehicle_switcher.dart` | `_toast` → `openVehicleEditor(context)` |
| 我的页车库空态「添加车辆」 | `garage_section.dart` | `_toast` → `openVehicleEditor(context)` |
| 我的页车库「添加新车」卡 | `garage_section.dart` / `garage_vehicle_card.dart` | 同上 |

路由：

```dart
// lib/features/vehicles/presentation/vehicle_editor_routes.dart
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
```

- 返回 `null` 表示取消；`created` 区分新增 / 编辑；`archived` 表示从编辑页归档。
- 调用方只依赖结果与 provider 失效，不直接改车辆数组。
- 车辆上限：车辆管理虚线卡已有 `enabled` 参数；首页车辆切换器的添加卡与我的页添加卡在在库数量 ≥ 10 时同样置灰（或点击 Toast「车库车辆已达上限」），编辑页 `limitReached` 兜底。

### 9.2 保存结果与车辆管理滚动

车辆管理页当前是 `ConsumerWidget` 且没有 `ScrollController`；为实现「保存后滚动到该车卡片」，需要改为 `ConsumerStatefulWidget`：

```dart
class VehicleManagementPage extends ConsumerStatefulWidget {
  const VehicleManagementPage({super.key});
  @override
  ConsumerState<VehicleManagementPage> createState() =>
      _VehicleManagementPageState();
}

class _VehicleManagementPageState
    extends ConsumerState<VehicleManagementPage> {
  final _scrollController = ScrollController();
  final _cardKeys = <String, GlobalKey>{};

  Future<void> _openEditor({String? vehicleId}) async {
    final result = await openVehicleEditor(context, vehicleId: vehicleId);
    if (!mounted || result == null) return;
    ref.invalidate(garageProvider);
    await ref.read(garageProvider.future);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _cardKeys[result.vehicleId];
      final target = key?.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 250),
          alignment: 0.2,
        );
      }
    });
  }

  // 车辆卡使用 key: _cardKeys.putIfAbsent(id, GlobalKey.new)
}
```

- 新增 / 编辑成功后刷新车库并滚动到该车；归档成功后刷新，不滚动。
- 卡片 `Key` 用 `GlobalKey`；不要用 `ValueKey` 直接 `ensureVisible`。
- 若卡片因筛选 / 空态不存在（归档后），跳过滚动。
- 首页 / 我的页只需 `await openVehicleEditor`；provider 已失效，页面重新可见时自动刷新。
- 新增成功后 controller 已把 `selectedVehicleIdProvider` 指向新车，因此首页 / 记账 / 统计默认展示新车；主驾仍由 `makePrimary` 决定。

### 9.3 归档

归档确认弹层改为接收轻量 `Vehicle`：

```dart
// lib/features/vehicles/presentation/widgets/vehicle_confirm_sheets.dart
Future<bool?> showArchiveVehicleSheet(
  BuildContext context,
  Vehicle vehicle, {
  required String body,
  required String confirmLabel,
  required Future<String?> Function() onConfirm,
}) { ... }
```

- 内部只用 `vehicle.name` / `vehicle.powertrain` 的图标与颜色；不再要求 `ManagedVehicle` 的月度支出 / 流水数。
- 车辆管理页调用改为 `showArchiveVehicleSheet(context, vehicle.vehicle, ...)`；测试同步调整。
- 编辑页：

```dart
Future<void> _archive(VehicleEditorState state) async {
  final snapshot = await ref
      .read(vehicleEditorRepositoryProvider)
      .fetchVehicleEditor(state.args.vehicleId!);
  if (!mounted) return;

  final body = snapshot.isOnlyActiveVehicle
      ? '归档后车库将为空，首页仪表盘与快捷记账将显示空状态；历史流水、报表与凭证完整保留。'
      : snapshot.successorName != null
          ? '归档后，默认主驾将由「${snapshot.successorName}」接任；历史流水、报表与凭证完整保留。'
          : '归档后该车辆将移出常用车库，首页仪表盘与快捷记账不再展示；历史流水、报表与凭证完整保留，可随时在「已归档车辆」恢复。';

  final confirmed = await showArchiveVehicleSheet(
    context,
    vehicle,
    body: body,
    confirmLabel: '确认归档',
    onConfirm: () async {
      final ok = await ref
          .read(vehicleCommandProvider.notifier)
          .archive(vehicleId);
      return ok ? null : ref.read(vehicleCommandProvider).errorMessage;
    },
  );
  if (confirmed == true && mounted) {
    Navigator.of(context).pop(
      VehicleEditorResult(vehicleId: vehicleId, created: false, archived: true),
    );
  }
}
```

- 归档前若 `state.isDirty`，先走放弃修改弹层；选择放弃后再打开归档确认。
- 归档命令成功后会失效车库 / 首页 / 账单 / 统计 / 我的页 / 报表 / 归档列表；页面在 `pop` 前 Toast「已将「{车名}」归档」，来源页刷新。
- 若归档失败，弹层内显示错误，页面不退出。
- 归档当前主驾时，`VehicleStore.archive` 已计算继任；`successorName` 由快照提供，只用于文案。

### 9.4 系统返回

- `PopScope(canPop: !isSaving && !isDirty)`：
  - 无修改且非保存中：直接 pop；
  - 有修改：拦截，弹出放弃修改弹层；
  - 保存中：不响应返回；
- 顶部返回按钮调用同一处理函数，避免系统返回与按钮行为不一致。
- 保存成功后先 `initialDraft = draft`，再 `pop`，避免 `isDirty` 仍为 true 触发拦截。
- 编辑加载失败 / 不存在时无表单，返回直接 pop。

### 9.5 OCR 与日期选择

- OCR 胶囊只做占位：`showAppToast(context, '证件识别将在下一版开放')`；不请求相机 / 相册权限，不引入新的识别依赖。
- 日期字段使用 `showDatePicker`：
  - 购车日期：`firstDate: DateTime(1980)`, `lastDate: today`；
  - 保险到期：`firstDate: DateTime(1980)`, `lastDate: DateTime(2100, 12, 31)`；
  - `locale` 沿用 App 配置；主题通过 `datePickerTheme` 与主色统一。
- 日期选择返回后只更新草稿，不立即保存；用户仍需点主按钮。

---

## 10. 性能

- 表单约 15 个字段，无长列表；单页 `SingleChildScrollView` 足够，不需要虚拟滚动。
- 编辑详情一次请求；Mock 140ms；生产单接口返回，避免 N+1。
- 保存一次写入；成功后全量失效，但只重拉当前可见页面；未挂载页面无请求。
- 表单重建范围：页面级 `ref.watch` 会在每次输入时重建表单；15 个字段可接受，但要求：
  - 每个字段 widget `const` 化或 `RepaintBoundary` 包裹；
  - 不在 `build` 中做正则 / 解析 / 排序等重活；
  - 文本输入只更新草稿与对应字段，不触发仓库请求；
  - 动力切换才重建动态规格区。
- 若性能不达标，可把文本控制器下沉到各字段并用 `ValueListenableBuilder`；P0 不做过度优化。
- 车牌输入格式器只做字符串操作，O(n)，n ≤ 8。
- 页面无图片、无网络资源；图标全部 Material Icons。
- 保存中进度动画只重绘按钮，不重建整页。
- 车辆管理滚动使用 `Scrollable.ensureVisible` 250ms，避免长列表跳变。

---

## 11. 错误与边界

| 场景 | 预期表现 |
| --- | --- |
| 品牌车型为空 / 过短 / 过长 | 字段错误；不保存 |
| 配置版本 / 昵称超长 | 字段错误；输入可继续编辑 |
| 车牌为空 | 字段错误「请填写车牌号码」 |
| 车牌长度 / 字符不合法 | 字段错误，提示当前牌型规则 |
| 车牌重复（在库 / 归档） | 字段错误，包含冲突车名；不保存 |
| 省份未选 | 默认「粤」；不出现空省份 |
| 里程为空 / 非数字 / 超范围 | 字段错误；不保存 |
| 里程低于最近记账里程 | 字段错误，显示最近里程；不保存 |
| 电池 / 油箱 / 能耗超范围 | 字段错误；不保存 |
| 购车日期晚于今天 | 字段错误；不保存 |
| 购车价格超 1,000 万元 | 字段错误；不保存 |
| 保养里程 ≤ 当前里程 | 警示「将显示为已超期」；允许保存 |
| 保险日期已过 | 警示「已过期」；允许保存 |
| 保存中再次点击 | 按钮 loading；`_submitting` 兜底 |
| 保存中返回 | 被拦截；不退出 |
| 保存失败（网络） | 表单级错误；保留输入；按钮恢复 |
| 保存失败（车牌冲突） | 车牌字段错误；保留输入 |
| 保存失败（车辆已归档 / 删除） | 表单级错误；提示返回车库刷新 |
| 并发版本冲突 | 表单级「车辆信息已更新，请刷新后重试」；保留输入 |
| 车库达到 10 辆 | 入口置灰；保存兜底错误 |
| 编辑加载慢 | 骨架；底部按钮禁用；不显示空表单 |
| 编辑车辆不存在 / 已归档 | 整页错误态；返回车库 |
| 新增首辆车 | 主驾强制开；保存后成为默认主驾 |
| 编辑当前主驾 | 主驾开关锁定；不能关闭 |
| 归档唯一在库车 | 文案提示车库将为空；确认后归档 |
| 归档失败 | 弹层内错误；页面不退出 |
| 有未保存修改时归档 | 先放弃确认；确认后归档旧档案 |
| 快速连点保存 | 只提交一次 |
| 1.3 倍字号 | 双列字段变单列；按钮文案不截断 |
| 320 宽 | 动力 4 段仍可读；省份 7 列可点 |
| 键盘弹出 | 操作栏上移；字段可滚动到可视区 |
| 深色模式 | 对比度 ≥ 4.5:1；车牌渐变不刺眼 |
| 编辑名称后历史流水 | 流水金额 / 归属不变；抬头使用新名称 |
| 新增车辆无流水 | 首页 / 统计 / 账单 / 报表空态；不崩溃、不伪造 |

---

## 12. 测试方案

### 12.1 单元测试

| 文件 | 覆盖 |
| --- | --- |
| `test/vehicles/vehicle_editor_presenter_test.dart` | 车牌规范化 / 补点 / 拆分 / 燃油与新能源校验 / 大小写与分隔符 / 重复；里程回退；数值范围；购车日期 / 价格；动力副标签；短码；万元解析与格式化；`draftOf` 映射；脏检查相等 |
| `test/vehicles/vehicle_store_test.dart` | `add` 分配排序 / 首辆车主驾 / 上限 / 车牌重复（含归档）；`update` 保留 SOH / 年检 / 排序 / 归档态 / 车牌排除自身；`makePrimary` |
| `test/vehicles/mock_vehicle_repository_test.dart` | `fetchVehicleEditor` 快照（最近里程 / 主驾 / 继任 / 仅一车）；`createVehicle` 成功 / 冲突 / 上限；`updateVehicle` 成功 / 不存在 / 已归档 / 冲突 |
| `test/home/mock_home_repository_test.dart` | 未知车辆空看板；`hasData == false`；`nextMaintenanceKm` 覆盖剩余 / 超期 / 进度；无保养流水 `hasProgress == false`；空趋势 / 分类 / 记录 |
| `test/ledger/mock_ledger_repository_test.dart` | `latestMaintenanceOdometer` 取最近保养记录；无记录 / 无里程返回 null |
| `test/vehicles/vehicle_editor_controller_test.dart` | 新增初始化（空车库主驾锁定 / 上限）；编辑加载成功 / 失败；动力切换缓存；保存校验失败；保存成功失效与选中；错误映射 |
| `test/expense_entry/...` | 编辑电池 / 油箱 / 油品后，记账默认值使用新值 |

### 12.2 Widget 测试

| 场景 | 断言 |
| --- | --- |
| 新增态渲染 | 标题、四段动力、三个卡片、保存按钮、无归档入口 |
| 编辑态加载 | 骨架 → 字段回显；主驾锁定；归档入口存在 |
| 动力切换 | EV / PHEV / HEV / ICE 字段与单位正确；切回保留输入 |
| 车牌输入 | 自动大写 / 补点；绿牌 7 位 / 蓝牌 6 位；省份弹层选择回填 |
| 校验 | 必填错误、里程回退、重复车牌、购车未来日期；错误定位 |
| 保存成功 | 返回结果、Toast 文案、车库刷新 |
| 保存失败 | 错误可见、表单保留、按钮恢复 |
| 未保存返回 | 弹出放弃确认；继续编辑 / 放弃修改两条路径 |
| 编辑页归档 | 脏表单先确认；归档弹层文案；成功后返回 |
| 车辆不存在 / 已归档 | 整页错误态 + 返回按钮 |
| 新增首辆车 | 主驾开关锁开；保存后成为默认主驾 |
| 新增无流水车辆 | 首页显示零支出 + 「暂无能耗记录」；统计 / 账单不崩溃 |

Widget 测试通过 `ProviderScope` override `vehicleStoreProvider` / `vehicleRepositoryProvider` / `homeRepositoryProvider`，使用带固定 clock 的种子车库；不改全局 Mock 种子。

### 12.3 手工验收

- 真机（Android arm64）走完：新增首辆车 → 首页空看板 → 记账页容量预填；新增第二辆车并设主驾 → 首页切换；编辑车牌 / 里程 → 车辆管理 / 账单 / 统计同步；归档 → 已归档车辆恢复。
- 车牌：蓝牌 / 绿牌、大小写、分隔符、重复、超长、省份切换各走一遍。
- 未保存：返回、系统返回、归档三条路径；保存中返回。
- 键盘：车牌、里程、价格字段在键盘弹出时可滚动；操作栏不被遮挡。
- 深色模式、1.3 倍字号、320 宽屏、横屏滚动各走一遍。
- 检查无「已同步」「云端」「自动识别」等未实现文案。

### 12.4 CI

- PR：`flutter analyze` + `flutter test`（不打包）。
- 合并 `main`：检查 + arm64 release APK。
- 本次改动不涉及 CI 配置。

---

## 13. 实施拆分

| 阶段 | 分支 | 内容 |
| --- | --- | --- |
| M1 | `feat/vehicle-editor-model` | `VehicleRecord` 扩展、Draft / Snapshot / State、presenter 校验与映射、store `add` / `update`、仓库接口与 Mock、单测 |
| M2 | `feat/vehicle-editor-create` | 新增页骨架、顶部栏、身份 / 规格 / 偏好卡、底部栏、车牌输入、省份弹层、保存新增、入口接线 |
| M3 | `feat/vehicle-editor-edit` | 编辑快照加载、字段回显、动力缓存、更新保存、未保存离开、归档入口、错误态 |
| M4 | `feat/vehicle-editor-cleanup` | 默认油品 / 配置版本 / 购车信息、深色 / 1.3 倍 / 320 适配、动效与无障碍 |
| M5 | `feat/vehicle-editor-empty-data` | 未知车辆空看板、`Consumption.hasData`、`Maintenance.hasProgress`、保养覆盖、首页 / 统计 / 我的页空态 |
| M6 | `test/vehicle-editor` | Widget 测试、跨页测试、手工验收、文档实施记录 |

依赖顺序：M1 → M2 → M3；M5 可与 M3 并行，但合并前必须完成，否则新增车辆会打不开首页。M4 依赖 M2 / M3。M6 最后。

---

## 14. 风险与待确认

| # | 风险 | 影响 | 处置 |
| --- | --- | --- | --- |
| R1 | 设计稿 3 段动力，实现 4 段 | 视觉验收 / 产品预期 | 需求 Q1；若坚持 3 段，需把 HEV 归入燃油并保留只读标记 |
| R2 | 新车辆空看板涉及首页 / 统计 / 我的页 / 报表多个页面 | 崩溃或伪造数据 | M5 独立实施；空数据用 `hasData` / `hasProgress` 标记，逐页验证 |
| R3 | `MockHomeRepository._cars` 仍是 4 辆种子车的静态数据 | 编辑种子车的名称 / 能耗后，dashboard 的能耗仍是旧演示值 | 读 dashboard 时用 `store.record.vehicle` 覆盖抬头；能耗保持演示值，明确 Mock 限制；生产由接口返回真实聚合 |
| R4 | 车牌特殊号段 / 临时牌 | 校验误拒 | P0 只校验通用规则；特殊号段放 Q6；服务端最终校验 |
| R5 | Mock 的 id / version / 内存态 | 重启丢失新增车辆；无法模拟并发冲突 | 已知限制；生产由服务端 id / version；测试注入 `idGenerator` |
| R6 | 保养提醒覆盖优先级 | 与既有 Mock 保养冲突 | 有 `nextMaintenanceKm` 时覆盖；无则保留 Mock；进度环仅在存在保养流水时显示 |
| R7 | 购车日期 / 价格暂无消费方 | 字段价值感低 | 需求 D12：只落库；P1 做折旧 / 持有成本；文案不承诺分析 |
| R8 | 主驾保存与车辆管理切换并发 | 主驾不一致 | 服务端原子处理；客户端以保存结果为准；命令串行 |
| R9 | 昵称展示范围有限 | 用户预期 | 需求 D6：不替换车名；P1 再扩展到首页问候 / 报表 |
| R10 | OCR / 车型库无实现 | 录入效率 / 设计还原 | P0 明确占位 / 隐藏；P1 排期 |
| R11 | 深色稿未提供 | 视觉验收 | 按 `AppPalette.dark` 推导，待设计复核 |
| R12 | 归档车辆恢复后可能超过 10 辆上限 | 上限规则不自洽 | P0 沿用现有 restore 行为；Q12 待产品确认，必要时恢复时校验上限 |
| R13 | 归档弹层签名从 `ManagedVehicle` 改为 `Vehicle` | 现有测试 / 调用方改动 | 同步改车辆管理页与测试；行为不变 |
| R14 | 表单每次输入重建 15 个字段 | 低端机掉帧 | 字段 const / RepaintBoundary；必要时下沉文本控制器局部刷新 |

---

## 15. 附录：需求 → 实现映射

| 需求 | 实现 |
| --- | --- |
| §6.1 顶部栏 | `VehicleEditorHeader` + `VehicleEditorPresenter.subtitleOf` |
| §6.2 动力类型 | `PowertrainSelector` + controller `setPowertrain` + `_SpecValues` 缓存 |
| §6.3 身份信息 | `VehicleIdentityCard` + `_syncControllers` + 快捷车型常量 |
| §6.3.2 / §7.2 车牌 | `VehiclePlateInput` + `PlateInputFormatter` + `normalizePlateBody` / `fullPlate` / `samePlate` |
| §6.4 规格 | `VehicleSpecsCard` + `_NumberField` / `_DateField` + `parseWanToCents` |
| §6.5 偏好 | `VehiclePreferencesCard` + 主驾锁定 + `nextMaintenanceKm` / `insuranceExpiry` |
| §6.6 底部栏 | `VehicleEditorBottomBar` + `VehicleEditorController.save` |
| §6.7 省份弹层 | `ProvincePickerSheet` + `showProvincePicker` |
| §6.8 未保存离开 | `PopScope` + `DiscardChangesSheet` |
| §6.9 归档 | `showArchiveVehicleSheet` + `vehicleCommandProvider.archive` + `VehicleEditorResult.archived` |
| §6.10 保存 | `validateVehicleEditorDraft` + `createVehicle` / `updateVehicle` + `VehicleScopeInvalidator` |
| §7.4 动力规格 | `VehicleRecord` 新字段 + `buildVehicle` / `buildRecord` |
| §7.8 新车辆空数据 | `MockHomeRepository._emptyDashboard` + `Consumption.hasData` + `Maintenance.hasProgress` |
| §8 / §9 接口 | `VehicleRepository` 新方法 + `VehicleEditorSnapshot` / `VehicleEditorResult` |
| §9 全局状态 | `VehicleScopeInvalidator` + `normalizeScopes` + `selectedVehicleIdProvider` |
| §10 非功能 | 骨架、深色 token、无障碍语义、动效 |
| §12 验收 | §12 测试方案 |

---

## 16. 实施记录（v0.2）

### 16.1 已落地文件

| 层 | 文件 |
| --- | --- |
| 模型 | `lib/features/vehicles/domain/vehicle_editor_models.dart`、`lib/features/vehicles/data/vehicle_store.dart`（`VehicleRecord` 新字段 / `add` / `update` / `byPlate`） |
| 推导 | `lib/features/vehicles/domain/vehicle_editor_presenter.dart`、`lib/features/vehicles/data/vehicle_editor_catalog.dart` |
| 仓库 | `vehicle_repository.dart`、`mock_vehicle_repository.dart`（编辑器快照 / 创建 / 更新）；`ledger_repository.dart` / `mock_ledger_repository.dart`（最近里程与保养里程） |
| 状态 | `lib/features/vehicles/domain/vehicle_editor_providers.dart`、`.../domain/providers.dart`（`VehicleScopeInvalidator`） |
| 页面 | `vehicle_editor_page.dart`、`vehicle_editor_routes.dart`、`vehicle_editor_style.dart` |
| 组件 | `widgets/vehicle_editor_header.dart`、`powertrain_selector.dart`、`vehicle_editor_field.dart`、`vehicle_plate_input.dart`、`province_picker_sheet.dart`、`vehicle_editor_bottom_bar.dart`、`discard_changes_sheet.dart`、`vehicle_editor_skeleton.dart` |
| 入口 | `vehicle_management_page.dart`、`widgets/vehicle_switcher.dart`、`widgets/garage_section.dart` |
| 空数据 | `home_models.dart`（`Consumption.hasData` / `Maintenance.hasProgress`）、`mock_home_repository.dart`、`consumption_card.dart`、`maintenance_card.dart`、`vehicle_presenter.dart` |
| 归档弹层 | `vehicle_confirm_sheets.dart` 的 `showArchiveVehicleSheet` 改为接收 `Vehicle` |
| 测试 | `vehicle_editor_presenter_test.dart`、`vehicle_editor_page_test.dart`、`home_new_vehicle_test.dart`，并扩展 store / mock repo 测试 |

### 16.2 与方案的差异

| # | 方案 | 实现 | 原因 |
| --- | --- | --- | --- |
| 1 | `LedgerRepository.latestOdometer(vehicleId)` | 接口命名为 `latestOdometerForVehicle` | 避免与 Mock 现有同步 `latestOdometer` 方法重名 |
| 2 | 昵称以独立胶囊展示 | 追加到 `VehiclePresenter.specLine`，显示为「昵称 · 配置」 | 不新增车辆卡布局分支，避免 1.3 倍字号溢出 |
| 3 | 底部操作栏放 `bottomNavigationBar` | 页面 Column 内 + `resizeToAvoidBottomInset: false` + `viewInsets` padding | 键盘弹出时操作栏稳定贴在键盘上方 |
| 4 | 表单每次变更同步全部控制器 | 只在首次就绪与动力类型切换时同步 | 避免用户输入小数点时被格式化回写导致光标跳动 |
| 5 | 车辆管理页滚动使用 `GlobalKey` 直接包车辆卡 | 用 `KeyedSubtree` 包 `GlobalKey`，内层保留 `ValueKey` | 兼容既有测试与列表定位 |
| 6 | 设计稿默认油品含柴油 | 只提供 92 / 95 / 98 | 记账页 `FuelDetail.fuelGrade` 仅支持汽油标号 |
| 7 | `VehicleEditorSnapshot` 版本冲突 | Mock `version = 1`，不模拟并发冲突 | 生产由服务端返回版本；Mock 保持简单 |
| 8 | OCR / 车型库 | OCR 胶囊 Toast 占位，搜索图标不渲染 | 未实现能力不展示假入口 |
| 9 | 身份 / 规格 / 偏好拆成三个独立 card 文件 | 三个卡片内联在 `vehicle_editor_page.dart`，公共输入组件抽到 `vehicle_editor_field.dart` | 减少跨文件传参与控制器同步复杂度 |

### 16.3 验证

- `flutter analyze`：No issues found。
- `flutter test`：307 个测试全部通过；本轮新增 33 个（presenter 12、页面 7、store 6、仓库 4、空看板 4）。
- Widget 测试覆盖：新增态渲染、必填校验、动力切换、省份弹层、保存写回、编辑回显、脏返回确认、编辑页归档。
- 单元测试覆盖：车牌规范化与校验、动力字段范围、里程回退、重复车牌、购车信息、映射与主驾、空看板与保养覆盖。
- 未做真机手工验收；合并后由 CI 构建 APK。

### 16.4 后续

- 真机验收（Android arm64）与深色模式截图。
- HTTP `VehicleRepository` 实现与 400 / 404 / 409 映射。
- OCR 证件识别、车型库检索、车辆照片 / VIN / 保养周期（P1）。
- 归档车辆恢复后的 10 辆上限规则（需求 Q12）。

---

## 17. 变更记录

| 版本 | 日期 | 说明 |
| --- | --- | --- |
| v0.1 | 2026-11-15 | 首版：定义编辑器数据模型、仓库 / store 扩展、表单状态与校验、车牌规则、保存 / 归档 / 未保存流程、新车辆空看板与保养覆盖、测试与实施拆分 |
| v0.2 | 2026-11-15 | P1 实施：落地页面、动态字段、车牌弹层、保存 / 归档 / 脏保护、空看板与 33 个新测试；补充实现差异与验证结果 |
