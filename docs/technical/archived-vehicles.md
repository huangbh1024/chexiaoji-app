# 已归档车辆技术方案 · 封存档案库

| 项目 | 内容 |
| --- | --- |
| 关联需求 | [已归档车辆需求文档 v0.1](../requirements/archived-vehicles.md) |
| 关联方案 | [车辆管理技术方案](vehicle-management.md)、[月度报表技术方案](monthly-report.md)、[账单技术方案](ledger.md)、[单笔详情技术方案](expense-detail.md) |
| 设计稿 | [已归档车辆查看与恢复页](https://stitch.google.com/projects/9615374848161425677?node-id=24fe8ba805aa41f5a3d53fa2d3946be3)、[彻底删除危险警示弹窗](https://stitch.google.com/projects/9615374848161425677?node-id=d7642ceaebd34d129620e9f35a885b8b) |
| 客户端 | Flutter 3.50.0 stable / Dart 3.14 |
| 平台 | Android（arm64 优先）、iOS |
| 文档版本 | v0.2（P0 已实现） |
| 状态 | P0 已实现（Mock）；接口未确认 |

> 本文档基于**仓库当前已有实现**编写：车辆管理、归档 / 恢复、删除拦截、首页、账单、统计、我的页、记账、单笔详情、月度报表均已落地；依赖为 `material_ui`、`flutter_riverpod 3.5`、`fl_chart`、`intl`、`pdf`、`printing`、`share_plus`、`path_provider`。
> 本页是归档车辆的**唯一读写入口**：恢复、查看历史报表、彻底删除都在这里完成；车辆管理页只保留「已归档车辆」工具卡作为入口。
> 核心难点不是页面本身，而是**彻底删除后的跨页一致性**：车辆档案消失，但历史流水继续计入账目，只是失去车辆归属。方案按「档案销毁 + 流水脱钩」实现（需求 §7.5，Q1）。

---

## 1. 目标与约束

### 1.1 技术目标

- 从车辆管理页进入本页，首屏 ≤ 1s（Mock，含 140ms 模拟延迟）；下拉刷新 ≤ 800ms；恢复 / 彻底删除 ≤ 300ms。
- **单一数据源**：归档车辆与在库车辆同由 `VehicleStore` 持有；本页不维护第二份车辆数组，新增的汇总指标由仓库聚合后一次性返回。
- **写入串行**：同一时刻只允许一个恢复 / 删除；弹层内维护 loading 与失败态，避免重复提交和状态竞争。
- **删除可证明**：彻底删除后，账单「全部车辆」合计不变、该车流水仍可查看、单笔详情显示「已解绑」、所有按车选择器不再出现该车。
- **强确认不可绕过**：车牌尾号 + 知情勾选由客户端即时校验，服务端再次校验；校验逻辑集中在 presenter，可单测。
- **不伪造能力**：无云端备份、无归档原因字段时，界面不出现对应承诺；缺失指标显示「— / 未录入」。
- 不新增依赖、不新增图片资源；深色模式复用 `AppPalette.dark` / `AppTokens.dark`。

### 1.2 约束

- 不引入 `go_router`：继续 `Navigator.push(MaterialPageRoute)` + `showModalBottomSheet`。
- 金额全链路整数分（`int cents`），里程整数 km，展示统一走 `formatters.dart`。
- 本页是二级页，不渲染底部导航与中央 FAB。
- 归档车辆不可记账、不可编辑、不可设为主驾、不参与保养 / 保险提醒。
- 彻底删除仅对归档车辆开放；在用车辆仍走车辆管理页既有的「删除 / 归档」规则。
- 彻底删除**不删除历史流水**，只移除车辆档案与车辆归属（需求 Q1，待产品最终确认）。
- Mock 数据只存在内存，重启恢复种子；接口接入后由服务端持久化。
- 不新增公共 token；本页局部圆角 / 间距常量放在 `archived_vehicles_style.dart`。

---

## 2. 现状与复用清单

| 现有能力 | 位置 | 本页用法 |
| --- | --- | --- |
| 色彩 token | `lib/app/theme/app_colors.dart` → `AppPalette` | 页面、卡片、危险色、动力色 |
| 间距 / 圆角 / 阴影 | `lib/app/theme/app_tokens.dart` → `AppTokens` | 页面边距、顶部栏高度、底部留白 |
| 字体 | `lib/app/theme/app_typography.dart` | `headlineMd`、`headlineSm`、`bodySm`、`bodyMd`、`labelMd`、`labelSm` |
| 车辆基础模型 | `lib/core/domain/vehicle.dart` → `Vehicle` | 车名、车牌、动力、里程 |
| 动力色与图标 | `lib/core/presentation/category_style.dart` → `PowertrainVisual` | 车辆图标、动力点、指标强调色 |
| 金额 / 里程 / 日期格式化 | `lib/core/format/formatters.dart` | `formatKmValue`、`formatYuanCompact`、`formatOneDecimal` |
| 车库状态 | `lib/features/vehicles/data/vehicle_store.dart` → `VehicleStore` | `archived` 列表、恢复、新增 `purge` |
| 车库仓库 | `lib/features/vehicles/data/vehicle_repository.dart` → `VehicleRepository` | 新增 `fetchArchivedGarage` / `purgeArchivedVehicle` |
| 车库弹层 | `lib/features/vehicles/presentation/widgets/vehicle_sheet_shell.dart` | 恢复弹层、危险弹层；扩展最大高度参数 |
| 归档车辆模型 | `lib/features/vehicles/domain/vehicle_models.dart` → `ArchivedVehicle` | 车辆管理页入口计数；本页新增 `ArchivedVehicleSummary` |
| 恢复命令 | `lib/features/vehicles/domain/providers.dart` → `VehicleCommandNotifier.restore` | 直接复用；补充失效范围 |
| 写状态 | 同上 → `vehicleCommandProvider` | 新增 `purge` 类型与错误文案 |
| 归档入口卡 | `.../widgets/archived_entry_card.dart` | 入口不变，点击改为推入本页 |
| 旧恢复弹层 | `.../widgets/archived_vehicles_sheet.dart` | **移除**（由本页取代） |
| 账单流水统计 | `lib/features/ledger/data/ledger_repository.dart` | 新增单车全历史统计 |
| 月度报表聚合 | `lib/features/report/domain/report_aggregation.dart` | 支持车辆不在在库列表时的快照补全 |
| 月度报表范围栏 | `.../widgets/report_scope_bar.dart` | 展示「{车名}（已归档）」 |
| 单笔详情车辆卡 | `lib/features/expense_detail/presentation/widgets/detail_vehicle_card.dart` | 车辆不存在时显示「已解绑」且无箭头 |
| 空 / 错 / 骨架 | `lib/core/widgets/empty_state.dart`、`section_error.dart`、`skeleton_box.dart` | 空列表、加载失败、加载中 |
| Toast | `lib/core/presentation/toast.dart` → `showAppToast` | 成功 / 失败轻提示 |
| 路由写法 | `lib/features/vehicles/presentation/vehicle_management_routes.dart` | 新增 `openArchivedVehicles` |

### 2.1 现有实现与本页的差异

| 项 | 现状 | 本页处理 |
| --- | --- | --- |
| 归档入口 | 车辆管理页底部工具卡 → 底部弹层，仅支持恢复 | 工具卡 → 独立页面；弹层文件移除 |
| 归档列表数据 | `GarageOverview.archivedVehicles` 只有 `vehicle / specLabel / sortOrder / archivedAt` | 新增 `ArchivedGarage` + `ArchivedVehicleSummary`，含累计花费、笔数、能耗、最近记账时间 |
| 恢复确认 | 弹层内点「恢复」立即执行 | 新增恢复确认弹层；说明车库为空时成为主驾 |
| 彻底删除 | 仅能删除无流水在库车；归档车没有删除入口 | 归档车支持强确认彻底删除；在用车规则不变 |
| 删除语义 | `delete` 拦截有流水车辆，不级联流水 | `purge` 删除档案、保留流水并解除归属 |
| 单车历史汇总 | 只有 `countRecords(vehicleId)` | 新增 `fetchVehicleStats(vehicleId)`（总额 / 笔数 / 最近时间） |
| 报表车辆解析 | `buildMonthlyReport` 只识别在库车辆 | 车辆不在列表时用流水快照合成 brief |
| 详情车辆归属 | `vehicleBound` 由 Mock 固定为 `true` | 车辆不存在时返回 `false`，显示「已解绑」 |
| 归档原因 | 无字段 | P0 不展示；P1 在归档弹窗采集 |

---

## 3. 结构调整

### 3.1 新增 / 调整文件

```
lib/features/vehicles/
├── data/
│   ├── vehicle_repository.dart              # + fetchArchivedGarage / purgeArchivedVehicle / 新错误码
│   ├── mock_vehicle_repository.dart         # + 归档汇总组装 / 删除校验
│   └── vehicle_store.dart                   # + purge()
├── domain/
│   ├── vehicle_models.dart                  # + ArchivedVehicleSummary / ArchivedGarage
│   ├── vehicle_presenter.dart               # + 封存天数 / 尾号 / 归档卡片指标 / 报表可用性
│   └── providers.dart                       # + archivedGarageProvider / purge 命令 / 失效范围
└── presentation/
    ├── vehicle_management_page.dart          # 入口改为推入本页，移除 old sheet
    ├── archived_vehicles_page.dart           # 新增：页面骨架与状态分发
    ├── archived_vehicles_routes.dart         # 新增：openArchivedVehicles
    ├── archived_vehicles_style.dart          # 新增：局部圆角 / 间距 / 危险色透明度
    └── widgets/
        ├── archived_vehicles_header.dart     # 顶部栏
        ├── archive_notice_card.dart          # 档案封存机制说明卡
        ├── archived_vehicle_card.dart        # 归档车辆卡
        ├── archived_vehicle_metrics.dart     # 三指标托盘
        ├── archived_vehicle_actions.dart     # 彻底删除 / 查看历史报表 / 恢复
        ├── archived_empty_state.dart         # 空态
        ├── archive_security_card.dart        # 资产安全与报表联动说明
        ├── archived_vehicles_skeleton.dart   # 骨架
        ├── restore_archived_vehicle_sheet.dart
        ├── purge_archived_vehicle_sheet.dart
        └── archived_vehicles_sheet.dart      # 删除（旧恢复弹层）
```

其他模块：

```
lib/features/ledger/domain/ledger_models.dart      # + VehicleLedgerStats
lib/features/ledger/data/ledger_repository.dart    # + fetchVehicleStats
lib/features/ledger/data/mock_ledger_repository.dart
lib/features/report/domain/report_models.dart      # + ReportVehicleBrief.isArchived
lib/features/report/domain/report_aggregation.dart # 快照补全
lib/features/report/data/mock_report_repository.dart
lib/features/report/presentation/widgets/report_scope_bar.dart
lib/features/report/presentation/monthly_report_page.dart
lib/features/expense_detail/data/mock_expense_detail_repository.dart
lib/features/expense_detail/domain/providers.dart
lib/core/domain/enums.dart                         # + PowertrainLabel 扩展
```

### 3.2 修改现有文件

| 文件 | 改动 | 影响 |
| --- | --- | --- |
| `vehicle_repository.dart` | 新增 `fetchArchivedGarage`、`purgeArchivedVehicle`；错误码 `notArchived`、`plateTailMismatch` | Mock / HTTP 两套实现 |
| `vehicle_store.dart` | 新增 `purge(String id)`，仅允许归档记录 | 车辆管理页与测试 |
| `mock_vehicle_repository.dart` | 归档汇总用 `ledger.fetchVehicleStats` + `home.fetchDashboard`；删除前校验尾号 | Mock 行为 |
| `vehicle_presenter.dart` | `DeleteBlockReason` 不变；新增 `plateTailOf`、`archiveDurationLabel`、`archivedMetricsOf`、`canOpenArchivedReports` | 可单测的纯函数 |
| `providers.dart` | 新增 `archivedGarageProvider`；`VehicleCommandKind` 增加 `purge`；失效矩阵补充归档列表 | 恢复 / 归档 / 删除后列表同步 |
| `vehicle_management_page.dart` | `_openArchived` 改为 `openArchivedVehicles(context)`；删除旧 import | 入口替换 |
| `archived_vehicles_sheet.dart` | 删除文件 | 无其他引用 |
| `ledger_repository.dart` / `mock_ledger_repository.dart` | 新增 `fetchVehicleStats`，复用 24 个月窗口与 `_deletedIds` | 归档指标、删除影响清单 |
| `report_aggregation.dart` | `buildMonthlyReport` 增加 `archivedVehicleIds` 参数；车辆不在列表时用流水快照合成 brief | 归档车报表 |
| `mock_report_repository.dart` | 注入 `VehicleStore?`，把归档 id 传给聚合 | 报表范围栏标注 |
| `report_scope_bar.dart` | 接收当前归档车辆，追加「（已归档）」chip | 归档车报表范围 |
| `monthly_report_page.dart` | 把 `report.vehicles` 中的归档 brief 传给范围栏 | 同上 |
| `mock_expense_detail_repository.dart` | 注入 `vehicleExists` 回调；车辆不存在时 `vehicleBound = false` | 删除后详情显示「已解绑」 |
| `detail_vehicle_card.dart` / 详情页 | `onTap` 仅在 `vehicleBound` 时传入 | 无跳转箭头 |
| `enums.dart` | 新增 `PowertrainLabel` 扩展（纯电 / 插电混动 / 油电混动 / 纯燃油） | 报表快照与归档卡复用 |

### 3.3 页面局部常量

```dart
// lib/features/vehicles/presentation/archived_vehicles_style.dart
abstract final class ArchivedVehiclesStyle {
  static const noticeRadius = 26.0;
  static const cardRadius = 28.0;
  static const cardPadding = 20.0;
  static const cardGap = 12.0;
  static const innerRadius = 16.0;
  static const metricTrayRadius = 16.0;
  static const iconBox = 48.0;

  /// 危险图标底盘与弹层。
  static const dangerIconSize = 56.0;
  static const dangerIconRadius = 20.0;
  static const dangerSheetMaxHeight = 0.92;
}
```

局部常量避免污染 `AppTokens`；若后续「大圆角卡片」成为跨页规范，再提升为公共 token。

---

## 4. 数据流

```
┌────────────────────────────────────────────────────────────┐
│ ArchivedVehiclesPage                                       │
│                                                            │
│  watch archivedGarageProvider ──► VehicleRepository        │
│                                     .fetchArchivedGarage() │
│                                          │                 │
│                                          ├─ VehicleStore.archived
│                                          ├─ LedgerRepository
│                                          │    .fetchVehicleStats(id)
│                                          └─ HomeRepository
│                                               .fetchDashboard(id)
│                                                    （能耗冻结值）
│                                                            │
│  watch vehicleCommandProvider ──► restore / purge          │
│                                          │                 │
│                                          ▼                 │
│                                   VehicleStore 写入         │
│                                          │                 │
│                                          ▼                 │
│                       invalidate 归档列表 / 车库 / 车辆列表 / │
│                       首页 / 账单 / 统计 / 我的页 / 报表     │
└────────────────────────────────────────────────────────────┘
```

- 读：页面只 watch `archivedGarageProvider` 与 `vehicleCommandProvider`，不直接读 store。
- 写：恢复复用 `restore`；彻底删除新增 `purge(id, plateTail)`。
- 删除后流水仍由 `ledgerRepository` 提供，车辆归属字段保留原 id 作为历史痕迹；展示使用记录快照。

---

## 5. 数据模型

### 5.1 归档车辆汇总

```dart
// lib/features/vehicles/domain/vehicle_models.dart
@immutable
class ArchivedVehicleSummary {
  const ArchivedVehicleSummary({
    required this.vehicle,
    required this.specLabel,
    required this.sortOrder,
    required this.archivedAt,
    required this.lifetimeSpendCents,
    required this.recordCount,
    this.averageConsumption,
    this.latestRecordAt,
  });

  final Vehicle vehicle;
  final String specLabel;
  final int sortOrder;
  final DateTime archivedAt;

  /// 该车全部未删除流水合计（分）。
  final int lifetimeSpendCents;

  final int recordCount;

  /// 归档前最后一次有效能耗读数；无数据为 null。
  final EnergyValue? averageConsumption;

  /// 最近一条流水时间；无流水为 null。用于「查看历史报表」定位月份。
  final DateTime? latestRecordAt;

  String get id => vehicle.id;
  PowertrainType get powertrain => vehicle.powertrain;
}

@immutable
class ArchivedGarage {
  const ArchivedGarage({
    required this.vehicles,
    required this.fetchedAt,
  });

  /// 按 archivedAt 倒序。
  final List<ArchivedVehicleSummary> vehicles;
  final DateTime fetchedAt;
}
```

- 不扩展既有 `ArchivedVehicle`：`GarageOverview` 保持轻量，车辆管理页入口只关心数量；归档页使用独立快照，避免首次进入车辆管理页时多算每车历史汇总。
- `EnergyValue` 复用 `home_models.dart`，单位由仓库返回，不在 UI 硬编码。

### 5.2 单车历史统计

```dart
// lib/features/ledger/domain/ledger_models.dart
@immutable
class VehicleLedgerStats {
  const VehicleLedgerStats({
    required this.totalSpendCents,
    required this.recordCount,
    required this.energyRecordCount,
    this.firstRecordAt,
    this.latestRecordAt,
  });

  final int totalSpendCents;
  final int recordCount;

  /// 充电 + 加油笔数，用于删除影响清单。
  final int energyRecordCount;

  final DateTime? firstRecordAt;
  final DateTime? latestRecordAt;
}
```

```dart
// lib/features/ledger/data/ledger_repository.dart
Future<VehicleLedgerStats> fetchVehicleStats(String vehicleId);
```

Mock 口径：近 24 个月、未删除记录、退款按负数计入；生产接口返回全生命周期。文档与文案统一写「累计」，不写「本月」。

### 5.3 展示推导

```dart
// lib/features/vehicles/domain/vehicle_presenter.dart
abstract final class ArchivedVehiclePresenter {
  /// 车牌去空格与分隔符后取末 5 位；不足 5 位取全部。
  static String plateTailOf(String plate, {int length = 5});

  /// 封存天数：0 → 「今日封存」，其余「封存 n 天」。
  static String archiveDurationLabel(DateTime archivedAt, {DateTime? now});

  /// 归档卡三指标，缺失返回 muted 的「— / 未录入」。
  static List<VehicleMetric> metricsOf(
    ArchivedVehicleSummary vehicle,
  );

  static String consumptionLabel(PowertrainType type);

  /// 有流水才允许打开历史报表。
  static bool canOpenReports(ArchivedVehicleSummary vehicle);

  /// 删除影响清单第一项文案（0 笔时特殊处理）。
  static String impactRecordsText(ArchivedVehicleSummary vehicle);
}
```

复用现有 `VehicleMetric` / `VehicleMetricTone`，不新增颜色语义。指标映射：

| 槽位 | EV / PHEV | HEV / ICE |
| --- | --- | --- |
| 1 封存总里程 | `formatKmValue(odometerKm)` + `km` | 同左 |
| 2 累计记账花费 | `formatYuanCompact(lifetimeSpendCents)`（千分位、四舍五入到元） | 同左 |
| 3 历史平均电耗 | `averageConsumption`，1 位小数，`kWh/百公里` | 标签「历史综合油耗」，`L/100km` |

缺失值：

```dart
VehicleMetric _missing(String label) => VehicleMetric(
  label: label,
  value: '—',
  unit: '未录入',
  tone: VehicleMetricTone.muted,
  missing: true,
);
```

尾号实现：

```dart
static String plateTailOf(String plate, {int length = 5}) {
  final normalized = plate
      .replaceAll(RegExp(r'[\s·•\-]'), '')
      .toUpperCase();
  if (normalized.isEmpty) {
    return '';
  }
  return normalized.length <= length
      ? normalized
      : normalized.substring(normalized.length - length);
}
```

---

## 6. 数据层

### 6.1 仓库接口

```dart
abstract class VehicleRepository {
  String? get primaryVehicleId;

  Future<GarageOverview> fetchGarage();
  Future<ArchivedGarage> fetchArchivedGarage();

  Future<void> setPrimary(String vehicleId);
  Future<void> archive(String vehicleId);
  Future<void> restore(String vehicleId);
  Future<void> delete(String vehicleId);

  /// 彻底删除归档车辆档案；[plateTail] 由客户端与服务端双重校验。
  Future<void> purgeArchivedVehicle(
    String vehicleId, {
    required String plateTail,
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
  unknown,
}
```

### 6.2 `VehicleStore.purge`

```dart
/// 删除归档车辆档案。仅归档记录可删除；在库车辆走 delete 规则。
void purge(String id) {
  final record = require(id);
  if (!record.isArchived) {
    throw const VehicleStoreException(VehicleStoreError.notArchived);
  }
  _records.removeWhere((item) => item.id == id);
  if (_primaryVehicleId == id) {
    _primaryVehicleId = null;
  }
}
```

- 归档车辆不可能是默认主驾（`archive` 已处理继任），`primaryVehicleId` 兜底清空。
- 不触碰账单仓库：流水保留、解除归属是上层语义。

### 6.3 Mock 仓库

```dart
@override
Future<ArchivedGarage> fetchArchivedGarage() async {
  await Future<void>.delayed(delay);
  final records = store.archived;
  final summaries = await Future.wait([
    for (final record in records) _archivedSummary(record),
  ]);
  return ArchivedGarage(
    vehicles: List<ArchivedVehicleSummary>.unmodifiable(summaries),
    fetchedAt: _now(),
  );
}

Future<ArchivedVehicleSummary> _archivedSummary(VehicleRecord record) async {
  final stats = await ledger.fetchVehicleStats(record.id);
  final dashboard = await home.fetchDashboard(record.id);
  return ArchivedVehicleSummary(
    vehicle: record.vehicle,
    specLabel: record.specLabel,
    sortOrder: record.sortOrder,
    archivedAt: record.archivedAt ?? _now(),
    lifetimeSpendCents: stats.totalSpendCents,
    recordCount: stats.recordCount,
    averageConsumption: dashboard.consumption.primary,
    latestRecordAt: stats.latestRecordAt,
  );
}

@override
Future<void> purgeArchivedVehicle(
  String vehicleId, {
  required String plateTail,
}) async {
  await Future<void>.delayed(delay);
  final record = store.byId(vehicleId);
  if (record == null) {
    throw const VehicleOperationException(VehicleErrorCode.notFound);
  }
  if (!record.isArchived) {
    throw const VehicleOperationException(VehicleErrorCode.notArchived);
  }
  if (ArchivedVehiclePresenter.plateTailOf(record.vehicle.plate) !=
      plateTail.trim().toUpperCase()) {
    throw const VehicleOperationException(
      VehicleErrorCode.plateTailMismatch,
    );
  }
  store.purge(vehicleId);
}
```

- Mock 的 `home.fetchDashboard` 对归档 id 仍可返回能耗（种子数据），所以在 Mock 阶段直接取 `consumption.primary`；HTTP 实现由 `GET /garage/archived` 返回 `averageConsumption`。
- 封存总里程取 `record.vehicle.odometerKm`；生产接口返回**归档时冻结**的表显里程。Mock 中记账写入的最新里程由 `MockHomeRepository` 在读取时覆盖，不回写 store，归档后可能略低于最后一次录入，属已知限制（R3）。
- `fetchArchivedGarage` 每次进入页面重新计算，不做缓存；数据量级 ≤ 10 辆。
- 每车最多 2 次仓库调用（账单统计 + dashboard），由 `Future.wait` 并行。

### 6.4 账单统计

```dart
@override
Future<VehicleLedgerStats> fetchVehicleStats(String vehicleId) async {
  final now = DateTime.now();
  final from = DateTime(now.year, now.month - 23);
  final records = recordsBetween(from, now)
      .where((record) => record.vehicleId == vehicleId)
      .toList(growable: false);

  return VehicleLedgerStats(
    totalSpendCents: _sum(records),
    recordCount: records.length,
    energyRecordCount: records
        .where(
          (record) =>
              record.category == ExpenseCategory.charging ||
              record.category == ExpenseCategory.fuel,
        )
        .length,
    firstRecordAt: records.isEmpty ? null : records.first.occurredAt,
    latestRecordAt: records.isEmpty ? null : records.last.occurredAt,
  );
}
```

`recordsBetween` 已排除已删除流水，并按发生时间升序返回，可直接取首尾作为最早 / 最近时间。

### 6.5 Provider

```dart
/// 归档页快照：每车汇总 + 最近流水时间。
final archivedGarageProvider = FutureProvider.autoDispose<ArchivedGarage>((ref) {
  return ref.watch(vehicleRepositoryProvider).fetchArchivedGarage();
});
```

- `autoDispose`：离开页面即释放，下次进入拿到最新数据；避免在车辆管理页常驻计算。
- 页面下拉刷新：`ref.invalidate(archivedGarageProvider)` 后 await future。

### 6.6 错误映射

| `VehicleErrorCode` | 弹层文案 |
| --- | --- |
| `notArchived` | 该车辆已恢复，请在车库中操作。 |
| `notFound` | 该车辆已不存在，列表已刷新。 |
| `plateTailMismatch` | 车牌尾号不匹配，请重新输入。 |
| `conflict` | 车辆信息已更新，请重试。 |
| `unknown` | 删除失败，请重试。 |

恢复失败沿用 `VehicleCommandNotifier._messageFor` 的既有文案，新增 `notArchived` 分支即可。

---

## 7. 状态管理

### 7.1 页面读取

```dart
class ArchivedVehiclesPage extends ConsumerStatefulWidget {
  const ArchivedVehiclesPage({super.key});

  @override
  ConsumerState<ArchivedVehiclesPage> createState() =>
      _ArchivedVehiclesPageState();
}

class _ArchivedVehiclesPageState
    extends ConsumerState<ArchivedVehiclesPage> {
  final Set<String> _removingIds = {};

  @override
  Widget build(BuildContext context) {
    final garage = ref.watch(archivedGarageProvider);
    final command = ref.watch(vehicleCommandProvider);
    final palette = context.palette;
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: palette.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448),
          child: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: palette.primary,
              onRefresh: () => _refresh(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: BlurredHeaderDelegate(
                      height: tokens.headerHeight,
                      child: ArchivedVehiclesHeader(
                        count: garage.value?.vehicles.length,
                        isLoading: garage.isLoading,
                        hasError: garage.hasError,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      tokens.pagePadding,
                      4,
                      tokens.pagePadding,
                      tokens.contentBottomPadding +
                          MediaQuery.paddingOf(context).bottom,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(
                        _content(context, garage, command),
                      ),
                    ),
                  ),
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

- 顶部栏计数在加载中显示「正在读取封存档案…」，失败显示「档案读取失败，点击重试」，空列表显示「暂无封存座驾」。
- 列表与计数来自同一 `ArchivedGarage` 快照，避免一个显示新数量、一个显示旧卡片。

### 7.2 写命令

```dart
enum VehicleCommandKind { setPrimary, archive, restore, delete, purge }

Future<bool> purge(String vehicleId, String plateTail) {
  return _run(
    VehicleCommandKind.purge,
    () => ref
        .read(vehicleRepositoryProvider)
        .purgeArchivedVehicle(vehicleId, plateTail: plateTail),
    affectedVehicleId: vehicleId,
  );
}
```

- `_run` 保持串行：`state.isBusy` 时直接返回 false。
- 成功后的失效清单在 `_invalidateAll` 中追加 `archivedGarageProvider`。
- `_normalizeScopes(affectedVehicleId)` 继续处理账单 / 统计 / 我的页 / 选中车辆；归档车通常不在这些作用域中，但保留兜底。

### 7.3 失效矩阵

| 操作 | 归档列表 | 车库 `garageProvider` | 车辆列表 | 首页 | 账单 | 统计 | 我的页 | 报表 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 归档 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 恢复 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 彻底删除 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 设为默认主驾 | — | ✅ | — | ✅ | — | — | ✅ | — |
| 删除无流水在库车 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

`归档` 与 `delete` 新增对 `archivedGarageProvider` 的失效：归档会把车辆移入列表，删除可能影响入口计数。

### 7.4 作用域归一化

- 恢复：车辆回到 `sortOrder = max + 1`；若车库原本为空，`VehicleStore.restore` 会把 `primaryVehicleId` 设为该车；命令层随后把 `selectedVehicleIdProvider` 指向主驾。
- 彻底删除：
  - 车辆不是默认主驾，通常不涉及 `selectedVehicleIdProvider`；
  - 若账单 / 统计筛选、我的页车库范围仍指向该 id，`_normalizeScopes` 回退到主驾或 `null`；
  - 报表范围是页面局部状态，不做全局归一化；已打开的历史报表仍可查看（流水保留）。
- 恢复成功后，车辆管理页的归档入口计数在刷新时更新；若 `archivedGarageProvider` 因页面停留未刷新，返回时 `autoDispose` 已释放，下次进入重新拉取。

### 7.5 竞态与生命周期

- 弹层提交期间 `_submitting = true`，危险按钮 loading；页面卡片按钮 `command.isBusy` 时禁用。
- 用户快速返回：命令继续执行；页面 `mounted` 检查后再 Toast；返回车辆管理页时数据已失效并刷新。
- 服务端返回 `notFound`：弹层关闭、列表刷新、Toast「该车辆已不存在，列表已刷新」。
- Mock 同步写：`VehicleStore` 变更后 `garageProvider` 与 `archivedGarageProvider` 同时失效，读到的是一致的车辆集合。

---

## 8. UI 实现

### 8.1 页面骨架

- `Scaffold` + `Center(maxWidth: 448)` + `SafeArea` + `RefreshIndicator` + `CustomScrollView`，与车辆管理页一致。
- 吸顶栏用 `SliverPersistentHeader` + `BlurredHeaderDelegate`。
- 内容顺序：说明卡 → 列表标题 → 归档卡列表 → 安全说明卡；空列表时说明卡 → 空态 → 安全说明卡。
- 页面不渲染底部导航与 FAB。

### 8.2 顶部栏 `ArchivedVehiclesHeader`

- 40 × 40 圆形返回按钮（`Navigator.maybePop`）。
- 标题「已归档车辆」；副标题由 `count / isLoading / hasError` 三态生成。
- 右侧留空，不为 P1 搜索预留不可见热区。
- 吸顶时背景 `surface` 85% + 毛玻璃，底部 1px 透明描边。

### 8.3 说明卡 `ArchiveNoticeCard`

- `Container` 渐变背景 + 两个 `Positioned` 装饰圆（`IgnorePointer`）。
- 图标底盘 44 × 44、圆角 14；标题行使用 `Wrap`，避免 1.3 倍字号下徽标溢出。
- 正文 `bodyMd`、行高 20/13；不包含任何操作。

### 8.4 归档卡 `ArchivedVehicleCard`

```dart
ArchivedVehicleCard(
  key: ValueKey<String>(summary.id),
  summary: summary,
  busy: command.isBusy || removing,
  onRestore: () => _restore(summary),
  onReport: () => _openReport(summary),
  onPurge: () => _purge(summary),
)
```

- 头部：动力图标 + 车名 + 配置徽标（`Wrap`）；车牌胶囊 + 动力点 + 动力文案；右侧封存徽标。
- 三指标使用 `Row` + `Expanded`，中间列 1px 左分隔线；`FittedBox` 仅包数值，避免大字号溢出。
- 元信息：`event_note` 图标 + 归档日期；不渲染原因。
- 背景装饰使用 `Positioned` + `IgnorePointer`，不参与点击。
- 卡片不提供整体点击（避免与内部按钮冲突）。

### 8.5 操作行 `ArchivedVehicleActions`

- 左侧 `TextButton.icon`「彻底删除」：`outline` 文字，`MaterialStateProperty` 按压态变为 `error`。
- 右侧两个 `FilledButton` 胶囊：
  - 「查看历史报表」：`surfaceContainer` 底、`onSurface` 文字；无流水时 `onPressed: null` 并降低透明度。
  - 「恢复至车库」：`primary` 底、`onPrimary` 文字（设计稿为 `primaryContainer` + `onPrimaryContainer`；实现沿用主色按钮规范）。
- 最小高度 36，外层 `SizedBox` 保证触控 ≥ 44；按钮之间 8 间距；窄屏允许换行（`Wrap`）。

### 8.6 恢复弹层

```dart
Future<bool?> showRestoreArchivedVehicleSheet(
  BuildContext context,
  ArchivedVehicleSummary vehicle, {
  required bool garageEmpty,
  required Future<String?> Function() onConfirm,
}) {
  return showVehicleSheet<bool>(
    context,
    (_) => _RestoreArchivedVehicleSheet(
      vehicle: vehicle,
      garageEmpty: garageEmpty,
      onConfirm: onConfirm,
    ),
  );
}
```

- 复用 `VehicleSheetShell` 的 32 顶部圆角、拖拽把手与安全区。
- 图标 `unarchive`，主色 15% 底。
- 正文按 `garageEmpty` 追加「当前车库没有在用车辆，恢复后该车将成为默认主驾。」
- 提交中 `SheetActionButton(busy: true)`；失败在正文下方显示 `error` 文案并恢复按钮。
- 成功后 `Navigator.pop(true)`；页面负责 Toast 与列表刷新。
- `showVehicleSheet(isDismissible: false, enableDrag: false)` + `PopScope(canPop: !_submitting)`：只允许通过「取消」退出；提交中禁止系统返回。

### 8.7 危险弹层 `PurgeArchivedVehicleSheet`

```dart
Future<bool?> showPurgeArchivedVehicleSheet(
  BuildContext context,
  ArchivedVehicleSummary vehicle, {
  required Future<String?> Function(String plateTail) onConfirm,
}) {
  return showVehicleSheet<bool>(
    context,
    (_) => _PurgeArchivedVehicleSheet(
      vehicle: vehicle,
      onConfirm: onConfirm,
    ),
    maxHeightFactor: ArchivedVehiclesStyle.dangerSheetMaxHeight,
  );
}
```

`showVehicleSheet` 扩展：

```dart
Future<T?> showVehicleSheet<T>(
  BuildContext context,
  WidgetBuilder builder, {
  double maxHeightFactor = 0.74,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (sheetContext) => VehicleSheetShell(
      maxHeightFactor: maxHeightFactor,
      child: builder(sheetContext),
    ),
  );
}
```

状态与校验：

```dart
class _PurgeArchivedVehicleSheetState
    extends State<_PurgeArchivedVehicleSheet> {
  late final TextEditingController _tailController = TextEditingController();
  late final String _expectedTail =
      ArchivedVehiclePresenter.plateTailOf(widget.vehicle.vehicle.plate);

  bool _acknowledged = false;
  bool _submitting = false;
  String? _error;

  bool get _tailMatches =>
      _tailController.text.trim().toUpperCase() == _expectedTail;

  bool get _canSubmit => _tailMatches && _acknowledged && !_submitting;

  Future<void> _submit() async {
    if (!_canSubmit) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await widget.onConfirm(_expectedTail);
    if (!mounted) {
      return;
    }
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _submitting = false;
      _error = error;
    });
  }
}
```

输入框：

```dart
TextField(
  controller: _tailController,
  maxLength: 5,
  textCapitalization: TextCapitalization.characters,
  inputFormatters: [
    FilteringTextInputFormatter.deny(RegExp(r'[\s·•\-]')),
    LengthLimitingTextInputFormatter(5),
    _UpperCaseTextFormatter(),
  ],
  onChanged: (_) => setState(() {}),
  decoration: InputDecoration(
    hintText: '请输入 $_expectedTail',
    counterText: '',
    suffixIcon: _tailMatches
        ? const Icon(Icons.check_circle_rounded)
        : null,
    // 其余样式按 AppTheme 输入框规范
  ),
)
```

- `_UpperCaseTextFormatter` 处理粘贴的小写内容；`textCapitalization` 只影响软键盘。
- 车牌为空时（理论上不会）`_expectedTail` 为空，弹层应回退为「输入完整车牌」；实现按 `ArchivedVehiclePresenter.plateTailOf` 结果分支，不在 UI 写死 5 位。
- 弹层内容用 `SingleChildScrollView` 包裹；底部追加 `MediaQuery.viewInsetsOf(context).bottom` 的 padding，保证键盘弹出时危险按钮可滚动可见。
- 危险按钮：
  - 未满足条件：`backgroundColor = palette.error.withValues(alpha: 0.4)`，`onPressed: null`；
  - 满足条件：`palette.error` 实心、白字；
  - 提交中显示 18 圈 loading；
  - **不做 `animate-pulse`**。
- 安全按钮「暂不删除，保留归档」位于危险按钮上方，`surfaceContainer` 底、`shield` 图标；点击直接 `pop(false)`。
- 弹层 `isDismissible: false`、`enableDrag: false`，外层 `PopScope(canPop: !_submitting)`；提交中无法通过遮罩、下滑或系统返回关闭，避免命令已成功但页面收不到结果。
- 勾选行使用 `InkWell` + 自绘 20 × 20 方框，避免 `Checkbox` 默认 48 触控区挤压布局；`Semantics(checked: ...)`。
- 错误文案位于按钮上方，`Semantics(liveRegion: true)`。

### 8.8 卡片移出与列表刷新

命令成功后 provider 立即失效，列表会在 140ms 后返回新数据；若直接重建，卡片会瞬间消失。实现采用本地镜像 + 短暂过渡：

```dart
Future<void> _afterRemoved(
  ArchivedVehicleSummary vehicle, {
  required bool restored,
}) async {
  final name = vehicle.vehicle.name;
  setState(() => _removingIds.add(vehicle.id));
  await Future<void>.delayed(
    MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 250),
  );
  if (!mounted) {
    return;
  }
  setState(() => _removingIds.remove(vehicle.id));
  ref.invalidate(archivedGarageProvider);
  ref.invalidate(garageProvider);
  showAppToast(
    context,
    restored ? '已成功将「$name」恢复至常用车库' : '已彻底删除「$name」的车辆档案',
  );
}
```

- 卡片外层 `AnimatedSize`（250ms）+ `AnimatedOpacity`，`_removingIds` 命中时高度收为 0。
- 开启「减少动态效果」时跳过等待，直接刷新。
- 计数在 provider 刷新后更新；过渡期间允许计数短暂滞后，避免出现「数量已减、卡片还在」的跳变。

### 8.9 加载 / 空 / 错误

| 状态 | 实现 |
| --- | --- |
| 首次加载 | `ArchivedVehiclesSkeleton`：顶部栏真实文案 + 2 张骨架卡；说明卡与安全说明卡正常渲染 |
| 空列表 | `ArchivedEmptyState`：64 圆形 `garage_home`、标题、正文、「返回常用车库」按钮 |
| 加载失败 | 列表区 `SectionError('封存档案加载失败', onRetry: ...)`；说明卡与安全说明卡保留 |
| 刷新失败（有缓存） | 保留旧内容，顶部细条「刷新失败，点击重试」 |
| 写操作失败 | 弹层内错误文案；卡片与计数保持 |

### 8.10 深色模式

- 全部颜色走 `context.palette`；危险弹层的 `errorSoft` 在深色下为 `#4A1D1D`，图标与文字使用 `error`（`#FFB4AB`）。
- 动力色在深色下沿用 `PowertrainVisual`，浅底透明度从 14% 调到 20%，保证图标可辨识。
- 说明卡渐变在深色下使用 `surfaceContainerLow → surfaceContainer`，不使用白色描边。

### 8.11 无障碍

- 顶部返回、删除、报表、恢复按钮均有 `Semantics(label: ...)`。
- 危险弹层标题与影响清单使用 `Semantics(header: true)`；错误与解锁状态 `liveRegion`。
- 输入框 `keyboardType: TextInputType.text`、`autofillHints: null`、`enableSuggestions: false`。
- 勾选框提供 `checked` 与 `label`；点击整行可切换。
- 所有按钮触控区 ≥ 44 × 44；颜色不是唯一信息载体（图标 + 文案 + 禁用态）。
- 系统字号 1.3 倍时，危险弹层可滚动，按钮不截断。

---

## 9. 交互与跳转

### 9.1 入口

```dart
// lib/features/vehicles/presentation/archived_vehicles_routes.dart
Future<void> openArchivedVehicles(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const ArchivedVehiclesPage()),
  );
}
```

车辆管理页：

```dart
ArchivedEntryCard(
  count: overview.archivedVehicles.length,
  onTap: () => openArchivedVehicles(context),
)
```

旧 `showArchivedVehiclesSheet` 与其 widget 文件删除；无其他页面引用。

### 9.2 查看历史报表

```dart
Future<void> _openReport(ArchivedVehicleSummary vehicle) async {
  final latest = vehicle.latestRecordAt;
  if (latest == null) {
    showAppToast(context, '该车辆暂无历史流水');
    return;
  }
  await openMonthlyReport(
    context,
    ReportScope(month: DateTime(latest.year, latest.month), vehicleId: vehicle.id),
  );
}
```

报表侧改动：

1. `buildMonthlyReport` 在 `scopedVehicles` 为空时，用流水中该车的快照合成 `Vehicle`：

```dart
var scopedVehicles = scope.vehicleId == null
    ? vehicles
    : vehicles.where((v) => v.id == scope.vehicleId).toList(growable: false);

if (scope.vehicleId != null && scopedVehicles.isEmpty) {
  final sample = records
      .where((record) => record.vehicleId == scope.vehicleId)
      .firstOrNull;
  if (sample != null) {
    scopedVehicles = [
      Vehicle(
        id: sample.vehicleId,
        name: sample.vehicleName ?? sample.vehicleShortName,
        plate: sample.metrics.plate ?? '',
        powertrain: sample.powertrain,
        powertrainLabel: sample.powertrain.label,
        odometerKm: _latestOdometer(records),
      ),
    ];
  }
}
```

2. `ReportVehicleBrief` 增加 `isArchived`（默认 `false`）；`buildMonthlyReport` 增加 `Set<String> archivedVehicleIds = const {}`。
3. `MockReportRepository` 注入 `VehicleStore?`，把归档车辆 id 传入聚合。
4. `MonthlyReportPage` 从 `report.vehicles` 取 `isArchived == true` 的 brief，传给 `ReportScopeBar`；范围栏渲染「{车名}（已归档）」，切换月份保持选中。
5. 如果报表请求失败（例如接口不再返回该车），页面显示既有错误态，不崩溃。

> 报表总额、笔数、分类、里程、能耗全部来自流水，不依赖在库车辆列表；合成 brief 只影响车辆名称展示与 odometer。

### 9.3 删除后的「孤儿流水」

- 流水的 `vehicleId` 保留原 id，`vehicleName` / `metrics.plate` / `powertrain` 快照仍在；账单列表、统计最近记录、导出 CSV/PDF 继续使用快照展示。
- 账单车辆筛选、统计车辆选择器、首页车辆切换条只列在库车辆，因此删除后不再出现该车。
- 单笔详情：
  - `MockExpenseDetailRepository` 增加可选 `vehicleExists` 回调；
  - `vehicleBound = vehicleExists?.call(record.vehicleId) ?? true`；
  - 详情页仅当 `detail.vehicleBound` 为 `true` 时传入 `onTap`；
  - 徽标显示「已解绑」，与既有 `_BindBadge` 逻辑一致。
- 月度报表「全部车辆」口径继续包含孤儿流水；按车入口不再提供。
- 若未来需要「恢复已删除车辆的流水归属」，需要独立的车辆档案重建流程，不在本期范围。

### 9.4 系统返回

- 顶部返回与系统返回都直接 `pop`。
- 写操作进行中允许返回；命令在后台完成，Toast 由仍挂载的页面展示；页面销毁后不展示。
- 返回车辆管理页后，入口计数与车库列表在 provider 失效后刷新。

---

## 10. 性能

| 项 | 目标 / 做法 |
| --- | --- |
| 首屏 | Mock 140ms 延迟 + 每车并行 2 次查询；≤ 10 辆车时 ≤ 1s |
| 刷新 | 重新拉取归档快照；不重建整页 |
| 列表 | `SliverList` 懒构建；卡片无图片资源 |
| 过渡 | 250ms 收起动画；开启减少动效时跳过 |
| 报表 | 复用 `monthlyReportProvider` 的缓存与分页拉取，不重复请求账单 |
| 内存 | `autoDispose` 释放归档快照；不缓存全量流水 |
| 稳定性 | 快速进入 / 返回不产生重复请求；命令串行化 |

---

## 11. 错误与边界

| 场景 | 预期表现 |
| --- | --- |
| 归档列表为空 | 空态；顶部计数 0；仍显示说明卡与安全说明卡 |
| 恢复最后一辆归档车 | 卡片移出 → 空态；车辆回到车库末尾 |
| 车库原本为空时恢复 | 车辆成为默认主驾；弹层正文已说明 |
| 无流水车辆查看报表 | 按钮禁用；点击 Toast「该车辆暂无历史流水」 |
| 车牌尾号不匹配 | 危险按钮保持禁用；输入框无报错，仅不显示对勾 |
| 服务端尾号校验失败 | 弹层内错误文案；输入与勾选保留 |
| 车辆已恢复（并发） | 409 `VEHICLE_NOT_ARCHIVED` → 关闭弹层、刷新、Toast |
| 车辆已被删除（并发） | 404 → 关闭弹层、刷新、Toast |
| 删除时网络失败 | 弹层保留，按钮恢复；不产生假成功 |
| 重复点击危险按钮 | loading 期间禁用；命令层 `isBusy` 兜底 |
| 流水统计失败 | 卡片仍展示，累计花费 / 能耗显示「—」；不影响恢复 |
| 归档日期缺失 | 按「今日封存」显示；恢复 / 删除仍可用 |
| 超长车名 / 配置 | 单行省略，车牌不换行 |
| 1.3 倍字号 | 卡片增高，危险弹层滚动，按钮文案不截断 |
| 深色模式 | 对比度 ≥ 4.5:1；危险色不刺眼 |
| 已删除车辆的历史详情 | 显示「已解绑」，无跳转箭头 |

---

## 12. 测试方案

### 12.1 单元测试

| 文件 | 覆盖 |
| --- | --- |
| `test/vehicles/archived_vehicle_presenter_test.dart` | 尾号提取（普通 / 新能源 / 含分隔符 / 过短）、封存天数（今日 / 42 天 / 时钟回拨）、四类动力指标映射与缺失值、报表可用性 |
| `test/vehicles/vehicle_store_test.dart` | `purge` 仅归档可删、删除后列表 / 主驾不变、非归档抛 `notArchived` |
| `test/vehicles/mock_vehicle_repository_test.dart` | `fetchArchivedGarage` 汇总正确、倒序、尾号校验、`notFound` / `notArchived` / `plateTailMismatch` |
| `test/ledger/mock_ledger_repository_vehicle_stats_test.dart` | 单车总额 / 笔数 / 能耗笔数 / 最近时间；已删除流水排除；退款计负 |
| `test/report/report_aggregation_test.dart` | 归档车辆 scope 合成 brief；总额与账单一致；`isArchived` 标记 |
| `test/expense_detail/mock_expense_detail_repository_test.dart` | 车辆不存在时 `vehicleBound == false` |

### 12.2 Widget 测试

| 场景 | 断言 |
| --- | --- |
| 归档列表渲染 | 车名、车牌、封存天数、三指标、归档日期；无「云端」文案 |
| 空列表 | 空态标题 / 返回按钮；无列表标题 |
| 恢复 | 点击 → 弹层文案 → 确认 → Toast 与计数 |
| 危险弹层初始 | 危险按钮禁用；「暂不删除」可点 |
| 尾号输入 | 输入错误保持禁用；输入正确 + 勾选后解锁 |
| 删除成功 | 卡片移出、计数减一、Toast；空列表进空态 |
| 删除失败 | 弹层保留、错误文案、按钮恢复 |
| 报表禁用 | 无流水时按钮禁用并 Toast |
| 加载失败 | `SectionError` 与重试 |

Widget 测试通过 provider override 注入带归档记录的 `VehicleStore`，避免修改全局 Mock 种子（现有 4 辆在库车保持不变）。

### 12.3 手工验收

- 真机（Android arm64）走完：归档 → 进入本页 → 恢复；归档 → 彻底删除（尾号 + 勾选）→ 查账单合计不变 → 打开历史流水详情显示「已解绑」。
- 深色模式、1.3 倍字号、320 宽屏、键盘弹出、快速返回各走一遍。
- 检查无「云端备份」「多端同步」等未实现文案。

### 12.4 CI

- PR：`flutter analyze` + `flutter test`（不打包）。
- 合并 `main`：检查 + arm64 release APK。
- 本次改动不涉及 CI 配置。

---

## 13. 实施拆分

| 阶段 | 分支 | 内容 |
| --- | --- | --- |
| M1 | `feat/archived-vehicles-page` | 模型 / 仓库接口 / Mock 汇总 / `archivedGarageProvider` / 页面、卡片、三指标、空态、骨架 / 入口替换 |
| M2 | `feat/archived-vehicles-restore` | 恢复确认弹层、恢复后计数与 Toast、失效范围补齐 |
| M3 | `feat/archived-vehicles-purge` | `purge` 命令与 store / Mock 校验、危险弹层、双因子校验、卡片移出、作用域归一化、详情「已解绑」 |
| M4 | `feat/archived-vehicles-report` | 报表快照补全、范围栏「已归档」、报表入口 |
| M5 | `test/archived-vehicles` | 单测 / Widget 测试 / 手工验收 / 文档实施记录 |

依赖顺序：M1 → M2 → M3 → M4 → M5。M3 的详情「已解绑」可独立于 M4 合并。

---

## 14. 风险与待确认

| # | 风险 | 影响 | 处置 |
| --- | --- | --- | --- |
| R1 | 「档案销毁 + 流水脱钩」与产品预期不一致 | 账单口径、用户认知 | 需求 Q1；若改为级联删除，需要同步改文案、账单 / 统计 / 报表与验收项 |
| R2 | 报表合成车辆信息依赖流水快照，旧数据可能缺车牌 | 报表展示不完整 | 车牌回退空字符串；报表已有 `—` 占位；生产由接口返回车辆快照 |
| R3 | Mock 账单生成器与里程回写不感知归档 / 删除 | 同一会话内后续月份可能仍生成该车记录；封存总里程可能略低于最后一次录入 | Mock 已知限制；页面汇总以当前仓库记录为准，不宣称实时冻结；生产由接口返回归档快照 |
| R4 | 双因子确认的可访问性 | 视障用户输入车牌困难 | 提供语义标签、允许粘贴、错误实时播报；产品确认是否对无障碍场景降级为「勾选 + 二次确认」 |
| R5 | 车牌规则（新能源 8 位 / 无车牌 / 特殊字符） | 校验不可用 | 统一 `plateTailOf`；不足 5 位取全部；无车牌走 Q7 回退方案 |
| R6 | 删除后按车报表入口残留 | 打开空报表 | 报表入口仅从本页提供；报表页对孤立 scope 使用快照降级 |
| R7 | 归档数量增长 | 列表性能与检索 | 当前 ≤ 10 辆；P1 搜索 / 筛选；必要时分页 |
| R8 | 深色稿未提供 | 视觉验收 | 按 `AppPalette.dark` 推导，待设计复核 |

---

## 15. 附录：需求 → 实现映射

| 需求 | 实现 |
| --- | --- |
| §6.1 顶部栏 | `ArchivedVehiclesHeader` + `BlurredHeaderDelegate` |
| §6.2 封存机制说明卡 | `ArchiveNoticeCard` |
| §6.3 列表标题 | 页面内 `_SectionTitle` |
| §6.4 归档车辆卡 | `ArchivedVehicleCard` + `ArchivedVehicleMetrics` + `ArchivedVehicleActions` |
| §6.5 恢复 | `showRestoreArchivedVehicleSheet` + `vehicleCommandProvider.restore` |
| §6.6 历史报表 | `openMonthlyReport` + 报表快照补全 |
| §6.7 彻底删除 | `showPurgeArchivedVehicleSheet` + `purge` 命令 + `VehicleStore.purge` |
| §6.8 空态 | `ArchivedEmptyState` |
| §6.9 安全说明卡 | `ArchiveSecurityCard` |
| §6.10 状态与反馈 | `AsyncValue` 分发 + `SectionError` + `showAppToast` |
| §7.1–7.4 指标口径 | `ArchivedVehiclePresenter` + 仓库聚合 |
| §7.5 删除数据规则 | `VehicleStore.purge`（档案）+ 流水保留（不改账单仓库） |
| §8 接口契约 | `VehicleRepository` / `LedgerRepository` 扩展 |
| §9 全局状态 | `archivedGarageProvider` + 失效矩阵 |
| §10 非功能 | 骨架、动效、无障碍、深色 token |
| §12 验收 | §12 测试方案 |

---

## 16. 实施记录（v0.2）

### 16.1 已落地文件

| 层 | 文件 |
| --- | --- |
| 模型 | `lib/features/vehicles/domain/vehicle_models.dart`（`ArchivedVehicleSummary` / `ArchivedGarage`）、`lib/features/ledger/domain/ledger_models.dart`（`VehicleLedgerStats`） |
| 仓库 | `vehicle_repository.dart`、`mock_vehicle_repository.dart`、`vehicle_store.dart`、`ledger_repository.dart`、`mock_ledger_repository.dart` |
| 推导 | `vehicle_presenter.dart`（`ArchivedVehiclePresenter`）、`core/domain/enums.dart`（`PowertrainLabel`）、`core/format/formatters.dart`（`formatArchiveDate`） |
| 状态 | `lib/features/vehicles/domain/providers.dart`（`archivedGarageProvider`、`purge` 命令、失效范围） |
| 页面 | `archived_vehicles_page.dart`、`archived_vehicles_routes.dart`、`archived_vehicles_style.dart` |
| 组件 | `archived_vehicles_header.dart`、`archive_notice_card.dart`、`archived_vehicle_card.dart`、`archived_vehicle_metrics.dart`、`archived_vehicle_actions.dart`、`archived_empty_state.dart`、`archive_security_card.dart`、`archived_vehicles_skeleton.dart`、`restore_archived_vehicle_sheet.dart`、`purge_archived_vehicle_sheet.dart` |
| 入口 | `vehicle_management_page.dart` 改为 `openArchivedVehicles`；删除 `archived_vehicles_sheet.dart` |
| 报表 | `report_aggregation.dart` 快照补全；`monthly_report_page.dart`、`report_scope_bar.dart`、`report_routes.dart` 支持归档车辆 chip |
| 详情 | `mock_expense_detail_repository.dart` 支持 `vehicleExists`；车辆不存在时显示「已解绑」 |
| 测试 | `archived_vehicle_presenter_test.dart`、`archived_vehicles_page_test.dart`、`mock_ledger_repository_vehicle_stats_test.dart`、`report_archived_scope_test.dart`，并扩展 store / mock repo / 详情 / 车辆管理页测试 |

### 16.2 与方案的差异

| # | 方案 | 实现 | 原因 |
| --- | --- | --- | --- |
| 1 | `ReportVehicleBrief` 增加 `isArchived`，报表仓库注入 store | 未加字段；`MonthlyReportPage` / `ReportScopeBar` 增加可选 `archivedVehicle` brief，由归档页直接传入 | 避免报表仓库耦合车辆 store，chip 跨月份保持稳定 |
| 2 | `buildMonthlyReport` 增加 `archivedVehicleIds` | 保留纯函数签名，仅增加「车辆不在列表时用流水快照合成 brief」 | 金额 / 笔数始终来自流水，快照只补抬头信息 |
| 3 | 无车牌回退车名末 4 字 | P0 禁用删除并提示「该车辆缺少车牌，无法确认删除」 | 车辆模型要求车牌；回退规则与接口校验需产品确认，放 Q7 / P1 |
| 4 | 卡片逐卡 250ms 收起 | 命令成功时记录 `_displayed` 快照 + `AnimatedSize`，250ms 后释放并刷新 | provider 失效会先于弹层关闭，需本地快照保证动画完整 |
| 5 | 删除影响清单原文「月度效能报表…抹除」 | 改为「按车统计不再可查看；已导出报表与账单总额不受影响」 | 流水保留、报表文件不回收，避免误导 |
| 6 | 设计稿顶部搜索 / 筛选图标 | 不渲染 | P1，列表规模小 |
| 7 | 弹层默认可下滑 / 遮罩关闭 | 恢复与危险弹层改为不可手势关闭，提交中拦截系统返回 | 命令成功后弹层被提前关闭会导致本地移除状态无法收尾 |

### 16.3 验证

- `flutter analyze`：No issues found。
- `flutter test`：274 个测试全部通过；本轮新增 27 个（presenter 11、页面 5、store 2、仓库 4、账单统计 2、报表 2、详情 1）。
- Widget 测试覆盖：列表渲染、空态、双因子解锁、尾号错误、删除成功、恢复与默认主驾、入口跳转。
- 未做真机手工验收与深色模式截图复核；合并前由 CI 执行 analyze / test。

### 16.4 后续

- 真机验收（Android arm64）与深色模式截图。
- HTTP `VehicleRepository` / `LedgerRepository` 实现与 409 / 404 映射。
- 无车牌回退、搜索筛选、归档原因、批量清理与回收站（P1）。
- Mock 账单生成器感知归档 / 删除生命周期，提升演示一致性。

---

## 17. 变更记录

| 版本 | 日期 | 说明 |
| --- | --- | --- |
| v0.1 | 2026-11-15 | 首版：定义归档页数据模型、仓库 / store / 命令扩展、双因子删除弹层、报表快照补全、孤儿流水处理、测试与实施拆分 |
| v0.2 | 2026-11-15 | P0 实施：落地页面、恢复、历史报表与双因子彻底删除；补充实施记录、实现差异与验证结果 |
