# 记账页技术方案 · 全能开销录入

| 项目 | 内容 |
| --- | --- |
| 关联需求 | [记账页需求文档 v0.2](../requirements/expense-entry.md) |
| 设计稿 | [Stitch · 记账·全能开销录入页（全新浅色规范版）](https://stitch.google.com/projects/9615374848161425677?node-id=d0f29ca3b8e848b38e8a77ff08c268aa) |
| 客户端 | Flutter 3.50.0 stable / Dart 3.14 |
| 平台 | Android（arm64 优先）、iOS |
| 文档版本 | v0.2（M0–M4 已实施，M5 部分完成） |
| 状态 | P0 已实施；接口未定，继续使用 Mock；OCR / 离线草稿为 P1 |

> 本文档基于**仓库当前实现**编写：首页、账单、统计、我的、单笔详情、月度报表均已落地（Riverpod 3 + `material_ui` + `fl_chart` + `intl`）；记账页 P0 已按本文档实现，全局 FAB 与详情底部按钮已接线。接口未定，仓库内使用 Mock 仓库。
>
> 设计稿的静态状态存在自相矛盾（选中「充电」却渲染「加油明细」；车辆卡 42,150 km 与里程卡 18,375 → 18,426 不是同一辆车）。本文档以需求文档 §7 的口径为准，示例数据仅作视觉参考。

---

## 1. 目标与约束

### 1.1 技术目标

- 从点击 FAB / 详情按钮到页面可交互 ≤ 500ms；默认值与里程基线并行请求，不串行阻塞。
- 金额、单价、里程、分类参数任意变化到预估条更新 ≤ 100ms（纯函数同步计算，无网络）。
- 保存请求 P90 ≤ 1.5s；保存成功后首页、账单、统计、报表在返回时呈现新数据，不出现「记了但看不到」。
- 页面只有一个主输入（金额），其余展示值全部由纯函数推导；UI 层不重复实现业务公式。
- 参数卡完全由分类驱动：新增 / 调整字段只改 `domain` 与对应参数 Widget，不在页面里堆 `if (category == ...)`。
- 复用现有设计 token、卡片容器、分类语义色、格式化、Mock 仓库与测试模式，不出现第二套视觉规范。

### 1.2 约束

- **状态管理沿用 Riverpod 3**，不引入 Bloc / Provider / GetX；family 参数必须是值相等对象。
- **金额全链路使用整数分**（`int cents`），新增 `parseYuanToCents`，禁止用 `double` 存金额。
- **唯一新增依赖：`image_picker`**（Flutter 官方插件，拍照 / 相册）。若评审不接受新依赖，凭证入口降级为 P1 并置灰，其余字段照常交付；不得自行引入 `camera`、`file_picker`、`image` 等替代链。
- **不引入 `go_router`**：沿用 `Navigator.of(context, rootNavigator: true).push`，页面为全屏 `MaterialPageRoute(fullscreenDialog: true)`。
- **Mock 只有一个事实源**：录入写回扩展后的 `MockLedgerRepository`，账单、详情、统计、报表读同一批记录；不在 `expense_entry` 内维护第二份记录列表。
- **表单不做全局状态持久化**：P0 输入只存在内存与 provider 中；旋转、切后台不丢（Widget 不重建），进程被杀后丢失（P1 草稿）。
- **不新增图片 / 图标资源**：沿用 Material Icons 与现有 `AppColors` / `AppPalette`；凭证缩略图来自本地文件。
- **页面不能出现在底部 Tab 中**：它是全屏路由，底部导航与 FAB 由 `AppTabShell` 持有，进入本页后自然隐藏。

---

## 2. 现状与复用清单

| 现有能力 | 位置 | 本页用法 |
| --- | --- | --- |
| 色彩 token | `lib/app/theme/app_colors.dart` → `AppPalette` / `AppColors` / `context.palette` | 全部颜色；不新增硬编码 |
| 间距 / 圆角 / 阴影 | `lib/app/theme/app_tokens.dart` → `AppTokens` / `context.tokens` | 卡片圆角、间距、阴影；新增 `radiusEntryCard = 28` |
| 字体 | `lib/app/theme/app_typography.dart` | `displayHero`、`headlineSm`、`bodyMd`、`labelMd` 等 |
| 卡片容器 | `lib/core/widgets/app_card.dart` → `AppCard` | 车辆卡 / 金额卡 / 参数卡 / 里程卡 / 备注卡；`radius: 28` |
| 顶栏毛玻璃 | `lib/core/widgets/blurred_header_delegate.dart` | 本页顶部栏复用同一 delegate |
| 轻提示 | `lib/core/presentation/toast.dart` → `showAppToast` | 切换车辆、保存结果、校验首错 |
| 分类语义色 / 图标 | `lib/core/presentation/category_style.dart` → `ExpenseCategoryVisual` | 胶囊、参数卡标题点、图标 |
| 金额 / 里程 / 单位格式化 | `lib/core/format/formatters.dart` | `formatYuanDetail`、`formatKm`、`formatKwh`、`formatLiters`、`formatUnitPrice`、`formatDuration` |
| 车辆列表 / 选中车辆 | `lib/features/home/domain/providers.dart` → `vehiclesProvider` / `selectedVehicleIdProvider` | 车辆卡数据与默认车辆 |
| 车辆实体 | `lib/core/domain/vehicle.dart` → `Vehicle` | id / name / plate / powertrain / odometerKm；本期需补电池容量、油箱容量 |
| 分类枚举 | `lib/core/domain/enums.dart` → `ExpenseCategory` / `PowertrainType` | 7 分类与动力类型默认分类 |
| 账单 Mock | `lib/features/ledger/data/mock_ledger_repository.dart` | **扩展**：手动记录写入、按时间回溯里程、更新后失效汇总 |
| 详情页入口 | `lib/features/expense_detail/presentation/widgets/detail_bottom_bar.dart` | 「再记一笔 / 编辑此笔账单」改为打开本页 |
| 详情仓库模式 | `lib/features/expense_detail/data/expense_detail_repository.dart` | 本页仓库接口 / 异常 / Mock 同构 |
| 全局 FAB | `lib/app/tab_shell.dart` → `AppBottomNav.onFab` | 替换 Toast 为打开本页 |
| 测试模式 | `test/expense_detail/*`、`test/ledger/*` | 纯函数单测 + Widget 测试 + Mock 仓库测试 |

> 目前 FAB 文案仍是「记账页待接入」；详情页「再记一笔」「编辑此笔账单」也仍是 Toast。本页落地后三处入口同时闭环。

---

## 3. 结构调整（M0）

### 3.1 新增目录

```
lib/features/expense_entry/
├── data/
│   ├── expense_entry_repository.dart        # 仓库接口 + 异常
│   ├── mock_expense_entry_repository.dart   # 包 MockLedgerRepository
│   └── receipt_picker.dart                  # image_picker 封装（可注入 / 可 Fake）
├── domain/
│   ├── expense_entry_models.dart            # Args / Draft / Defaults / Baseline / State
│   ├── expense_entry_detail.dart            # sealed 分类参数
│   ├── expense_entry_math.dart              # 电量 / 升数 / SOC / 时长 / 里程 纯函数
│   ├── expense_entry_validation.dart        # 校验规则与错误文案
│   ├── expense_entry_presenter.dart         # 分类文案、预估条、时间与里程展示
│   └── providers.dart                       # controller + repository provider
└── presentation/
    ├── expense_entry_page.dart
    ├── expense_entry_routes.dart            # openExpenseEntry(...)
    ├── expense_entry_style.dart             # 本页圆角 / 字段格 / 胶囊样式
    └── widgets/
        ├── entry_header.dart
        ├── entry_vehicle_card.dart
        ├── entry_vehicle_sheet.dart
        ├── entry_category_chips.dart
        ├── entry_amount_card.dart
        ├── entry_amount_input.dart
        ├── entry_telemetry_pill.dart
        ├── entry_params_card.dart
        ├── entry_charging_params.dart
        ├── entry_fuel_params.dart
        ├── entry_parking_params.dart
        ├── entry_toll_params.dart
        ├── entry_maintenance_params.dart
        ├── entry_car_wash_params.dart
        ├── entry_insurance_params.dart
        ├── entry_mileage_card.dart
        ├── entry_meta_card.dart
        ├── entry_note_receipts_card.dart
        ├── entry_receipt_grid.dart
        ├── entry_bottom_bar.dart
        └── sheets/
            ├── entry_time_sheet.dart
            ├── entry_place_sheet.dart
            ├── entry_payment_sheet.dart
            └── entry_receipt_source_sheet.dart
```

### 3.2 修改现有文件

| 文件 | 改动 |
| --- | --- |
| `lib/app/tab_shell.dart` | `onFab` 改为 `openExpenseEntry(context, args: ExpenseEntryArgs.create(...))`；删除 Toast「记账页待接入」 |
| `lib/features/expense_detail/presentation/widgets/detail_bottom_bar.dart` | 「再记一笔」「编辑此笔账单」改为回调到 route；保存后刷新详情 |
| `lib/features/expense_detail/presentation/expense_detail_page.dart` | 接收入口回调，跳转本页；编辑返回后 `invalidate(expenseDetailProvider(id))` |
| `lib/features/ledger/data/mock_ledger_repository.dart` | 新增 `_manualRecords`、`insertRecord`、`updateRecord`、`latestOdometer`、`odometerBaseline`；`recordById` / `_recordsFor` / 汇总纳入手动记录 |
| `lib/features/home/data/mock_home_repository.dart` | 新增可选 `odometerResolver`；`fetchVehicles()` 将车辆当前里程与账单最新里程取较大值 |
| `lib/features/home/domain/providers.dart` | `homeRepositoryProvider` 注入 `odometerResolver: ref.watch(mockLedgerRepositoryProvider).latestOdometer`（仅 Mock 阶段） |
| `lib/core/domain/vehicle.dart` | 追加可空 `batteryCapacityKwh`、`tankCapacityL`、`defaultFuelGrade`（接口未就绪时 Mock 填值） |
| `lib/core/domain/enums.dart` | 迁入 `PaymentChannel`（原在 `expense_detail_models.dart`），供录入页与详情页共用 |
| `lib/core/format/formatters.dart` | 新增 `parseYuanToCents`、`formatYuanInput`、`formatOdometerDelta`、`formatOccurredAtLabel`、`formatSoc` |
| `lib/app/theme/app_tokens.dart` | 新增 `radiusEntryCard = 28`（不改动现有 token 值） |
| `pubspec.yaml` | 新增 `image_picker`（版本按 `flutter pub add` 锁定的最新稳定版） |
| `ios/Runner/Info.plist` | 增加 `NSCameraUsageDescription`、`NSPhotoLibraryUsageDescription` |
| `android/app/src/main/AndroidManifest.xml` | 相机权限；Android 13+ 相册按 `image_picker` 文档声明 |
| `test/expense_entry/**` | 新增单测、Widget 测试与 Mock 仓库测试 |

关键点：

- `MockLedgerRepository` 目前按月份确定性生成数据，并通过 `_deletedIds` 控制删除。手动新增记录需要**独立存储**（`_manualRecords`），并在 `_recordsFor(month)` 合并、按 `occurredAt` 重新排序；`_idIndex` 同步登记。这样账单 / 统计 / 报表不需要第二套 Mock。
- `MockHomeRepository.fetchVehicles()` 读的是静态 `_cars`，不随录入更新。新增可选注入 `odometerResolver`（`int? Function(String vehicleId)`），`fetchVehicles()` 返回的里程取 `max(car.vehicle.odometerKm, odometerResolver?.call(id) ?? 0)`；`homeRepositoryProvider` 在 Mock 阶段传入 `mockLedgerRepositoryProvider.latestOdometer`。这样不改变 `MockHomeRepository.ledger` 的接口类型，现有测试无需改动；保存成功后 `ref.invalidate(vehiclesProvider)` 即可让首页、车辆卡、我的车库同步。
- `Vehicle` 新增字段全部可空，现有 4 辆 Mock 车与测试不受影响；缺省时录入页隐藏 SOC 与「充满 / 加满」。
- `PaymentChannel` 迁到 `core/domain/enums.dart`，`expense_detail_models.dart` 用 `export` 保留旧引用，避免大范围改 import；录入页与详情页共用同一枚举。
- `ExpenseCategory.other` 在录入页展示为「车险车税」，账单页仍是「保险/其他」。本期按设计稿，P1 再拆 `insurance` 枚举（见 §14）。
- `radiusEntryCard = 28` 是新增 token，`AppCard` 已支持传入 `radius`，无需改 `AppCard`。

---

## 4. 数据流

```
AppTabShell / ExpenseDetailPage
        │  openExpenseEntry(context, args)
        ▼
ExpenseEntryPage (ConsumerStatefulWidget)
        │  ref.watch(expenseEntryControllerProvider(args))
        ▼
ExpenseEntryController (Notifier)
   ├── build(args)
   │     ├── repo.fetchDefaults(vehicleId)
   │     ├── repo.fetchOdometerBaseline(vehicleId, before: occurredAt)
   │     └── edit 时 repo.fetchDraft(recordId)
   ├── 输入事件 → state.draft（唯一事实源）
   ├── 纯函数 → 预估条 / SOC / 时长 / 里程
   └── save() → repo.create / repo.update
                     │
                     ├── MockLedgerRepository.insertRecord / updateRecord
                     └── 成功后 invalidate 依赖 provider
        │  Navigator.pop(ExpenseEntryResult.saved(recordId))
        ▼
来源页（首页 / 账单 / 详情）刷新
```

要点：

- 页面**不直接**持有业务状态，只持有 `TextEditingController` 与焦点；输入写入 controller 的 draft。
- 预估条、数量、SOC、时长、区间里程全部由 `expense_entry_math.dart` 纯函数计算，Widget 不写公式。
- 里程基线随「车辆」与「发生时间」变化重新查询；请求带 generation token，丢弃过期响应。
- 保存成功先写 Mock / 服务端，再失效依赖 provider；不采用「先改本地列表再回滚」的乐观写入（P1 可加）。
- 编辑模式的预填优先使用详情页传入的快照（首帧不空白），随后用 `fetchDraft` 补齐参数与凭证。

### 4.1 入口与参数

```dart
@immutable
class ExpenseEntryArgs {
  const ExpenseEntryArgs.create({
    this.initialVehicleId,
    this.initialCategory,
    this.initialOccurredAt,
    this.initialPlace,
  }) : mode = ExpenseEntryMode.create,
       recordId = null;

  const ExpenseEntryArgs.edit({required String this.recordId})
    : mode = ExpenseEntryMode.edit,
      initialVehicleId = null,
      initialCategory = null,
      initialOccurredAt = null,
      initialPlace = null;

  final ExpenseEntryMode mode;
  final String? recordId;
  final String? initialVehicleId;
  final ExpenseCategory? initialCategory;
  final DateTime? initialOccurredAt;
  final String? initialPlace;
}
```

- FAB：`ExpenseEntryArgs.create(initialVehicleId: ref.read(selectedVehicleIdProvider), initialCategory: null)`。
- 详情「再记一笔」：`create(initialVehicleId: record.vehicleId, initialCategory: record.category, initialOccurredAt: DateTime.now(), initialPlace: record.description)`；不预填金额、备注、凭证。
- 详情「编辑此笔账单」：`edit(recordId: record.id)`。
- 参数对象必须实现 `==` / `hashCode`（family 需要值相等），见 §5.1。

### 4.2 返回结果

```dart
sealed class ExpenseEntryResult {
  const ExpenseEntryResult();
}

class ExpenseEntrySaved extends ExpenseEntryResult {
  const ExpenseEntrySaved({required this.recordId, required this.isNew});
  final String recordId;
  final bool isNew;
}

class ExpenseEntryCancelled extends ExpenseEntryResult {
  const ExpenseEntryCancelled();
}
```

- 保存成功 `pop(ExpenseEntrySaved(...))`；放弃 `pop(ExpenseEntryCancelled())` 或不带结果。
- 来源页只关心是否保存成功；具体刷新统一通过 provider 失效完成，不靠返回值传数据。
- 系统返回 / 关闭按钮走同一 `PopScope` 逻辑；保存中禁止 pop。

---

## 5. 数据模型

### 5.1 只读参数与值相等

```dart
enum ExpenseEntryMode { create, edit }

@immutable
class ExpenseEntryArgs {
  // 见 §4.1
  @override
  bool operator ==(Object other) =>
      other is ExpenseEntryArgs &&
      other.mode == mode &&
      other.recordId == recordId &&
      other.initialVehicleId == initialVehicleId &&
      other.initialCategory == initialCategory &&
      other.initialOccurredAt == initialOccurredAt &&
      other.initialPlace == initialPlace;

  @override
  int get hashCode => Object.hash(
    mode, recordId, initialVehicleId, initialCategory,
    initialOccurredAt, initialPlace,
  );
}
```

### 5.2 草稿

```dart
@immutable
class ExpenseEntryDraft {
  const ExpenseEntryDraft({
    required this.vehicleId,
    required this.category,
    required this.amountCents,
    required this.occurredAt,
    required this.paymentChannel,
    required this.paymentLabel,
    this.place,
    this.odometerKm,
    this.lastOdometerKm,
    this.note,
    this.receipts = const <ReceiptAttachment>[],
    this.detail = const EmptyEntryDetail(),
  });

  /// null 表示尚未选车（正常流程不应出现，无车辆时页面显示空态）。
  final String? vehicleId;
  final ExpenseCategory category;

  /// 0 表示空输入；支出恒为正。
  final int amountCents;
  final DateTime occurredAt;

  final PaymentChannel paymentChannel;
  final String paymentLabel;
  final String? place;

  /// 本次仪表里程；null = 用户清空。
  final int? odometerKm;

  /// 发生时间之前最近一条读数；null = 首次记录。
  final int? lastOdometerKm;

  final String? note;
  final List<ReceiptAttachment> receipts;
  final EntryCategoryDetail detail;

  int? get distanceKm => (odometerKm != null && lastOdometerKm != null)
      ? odometerKm! - lastOdometerKm!
      : null;

  ExpenseEntryDraft copyWith({...});
}
```

- 构造期用 `ExpenseEntryDraft.empty(args)` 生成占位草稿：金额 0、发生时间取 `args.initialOccurredAt ?? DateTime.now()`、支付取默认、`detail` 为 `EmptyEntryDetail()`；默认值返回后由 controller 覆盖，不算脏。
- `amountCents == 0` 表示空，不额外维护 `hasAmount`。
- `distanceKm` 可能为负，由校验层拦截；UI 展示前先校验。
- `detail` 与 `category` 必须匹配；切换分类时 `detail` 整组替换，见 §7.1。

### 5.3 分类参数（sealed）

```dart
sealed class EntryCategoryDetail {
  const EntryCategoryDetail();
  ExpenseCategory get category;
}

class EmptyEntryDetail extends EntryCategoryDetail {
  const EmptyEntryDetail();
  @override
  ExpenseCategory get category => ExpenseCategory.other; // 仅占位
}

class ChargingDetail extends EntryCategoryDetail {
  const ChargingDetail({
    this.unitPriceCentsPerKwh = 120,
    this.socStart = 20,
    this.kwh,
    this.socEnd,
  });
  final int unitPriceCentsPerKwh;
  final int socStart;
  /// 只读推导值，便于保存时直接序列化。
  final double? kwh;
  final int? socEnd;
  @override
  ExpenseCategory get category => ExpenseCategory.charging;
}

class FuelDetail extends EntryCategoryDetail {
  const FuelDetail({
    this.unitPriceCentsPerLiter = 785,
    this.fuelGrade = 95,
    this.liters,
  });
  final int unitPriceCentsPerLiter;
  final int fuelGrade;
  final double? liters;
  @override
  ExpenseCategory get category => ExpenseCategory.fuel;
}

class ParkingDetail extends EntryCategoryDetail {
  const ParkingDetail({
    this.rateCentsPerHour = 800,
    this.durationMinutes,
    this.lotName,
  });
  final int rateCentsPerHour;
  final int? durationMinutes;
  final String? lotName;
  @override
  ExpenseCategory get category => ExpenseCategory.parking;
}

class TollDetail extends EntryCategoryDetail {
  const TollDetail({this.entryStation, this.exitStation, this.roadName, this.distanceKm});
  final String? entryStation;
  final String? exitStation;
  final String? roadName;
  final int? distanceKm;
  @override
  ExpenseCategory get category => ExpenseCategory.toll;
}

class MaintenanceDetail extends EntryCategoryDetail {
  const MaintenanceDetail({this.item, this.shopName, this.odometerKm});
  final String? item;
  final String? shopName;
  final int? odometerKm;
  @override
  ExpenseCategory get category => ExpenseCategory.maintenance;
}

class CarWashDetail extends EntryCategoryDetail {
  const CarWashDetail({this.serviceType = '标准洗车', this.shopName});
  final String serviceType;
  final String? shopName;
  @override
  ExpenseCategory get category => ExpenseCategory.carWash;
}

class InsuranceDetail extends EntryCategoryDetail {
  const InsuranceDetail({
    this.coverageType = '商业险',
    this.policyNo,
    this.periodStart,
    this.periodEnd,
  });
  final String coverageType;
  final String? policyNo;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  @override
  ExpenseCategory get category => ExpenseCategory.other;
}
```

- `ChargingDetail.kwh` / `FuelDetail.liters` / `ParkingDetail.durationMinutes` 是派生值，保存前由 `expense_entry_math.dart` 重算一次，避免 UI 与请求不一致。
- `MaintenanceDetail.odometerKm` 与草稿的 `odometerKm` 双向同步，保存时以草稿为准。
- `EmptyEntryDetail` 只用于构造期占位；页面不会渲染它对应的参数卡。

### 5.4 默认值、基线与凭证

```dart
@immutable
class ExpenseEntryDefaults {
  const ExpenseEntryDefaults({
    this.defaultCategory,
    this.paymentChannel = PaymentChannel.wechat,
    this.paymentLabel = '微信支付',
    this.lastPlace,
    this.recentPlaces = const <String>[],
    this.unitPrices = const EntryUnitPrices(),
    this.fuelGrade = 95,
    this.batteryCapacityKwh,
    this.tankCapacityL,
    this.lastSoc,
    this.lastOdometerKm,
  });
  ...
  /// 上次同车充电结束 SOC；null 时开始 SOC 默认 20%。
  final int? lastSoc;
}

@immutable
class EntryUnitPrices {
  const EntryUnitPrices({
    this.chargingCentsPerKwh = 120,
    this.fuelCentsPerLiter = 785,
    this.parkingCentsPerHour = 800,
  });
  ...
}

@immutable
class OdometerBaseline {
  const OdometerBaseline({
    this.lastReadingKm,
    this.recordedAt,
    this.recordId,
    this.currentOdometerKm,
  });
  final int? lastReadingKm;
  final DateTime? recordedAt;
  final String? recordId;
  final int? currentOdometerKm;

  bool get isFirstRecord => lastReadingKm == null;
}

@immutable
class ReceiptAttachment {
  const ReceiptAttachment({
    required this.localPath,
    this.remoteId,
    this.isDeleted = false,
    this.uploadProgress,
  });
  final String localPath;
  final String? remoteId;
  final bool isDeleted;
  final double? uploadProgress;

  ReceiptAttachment copyWith({...});
}
```

### 5.5 页面状态

```dart
@immutable
class ExpenseEntryState {
  const ExpenseEntryState({
    required this.args,
    required this.draft,
    required this.defaults,
    this.isLoadingDefaults = true,
    this.defaultsError,
    this.isLoadingBaseline = false,
    this.baselineError,
    this.isSaving = false,
    this.saveError,
    this.uploadedReceipts = 0,
    this.totalReceipts = 0,
    this.validation = const EntryValidation.none(),
    this.isCategoryManuallySelected = false,
    this.hasUnsavedChanges = false,
  });

  final ExpenseEntryArgs args;
  final ExpenseEntryDraft draft;
  final ExpenseEntryDefaults defaults;

  /// 保存阶段凭证上传进度；未上传时为 0。
  final int uploadedReceipts;
  final int totalReceipts;
  final bool isLoadingDefaults;
  final Object? defaultsError;
  final bool isLoadingBaseline;
  final Object? baselineError;
  final bool isSaving;
  final Object? saveError;
  final EntryValidation validation;
  final bool isCategoryManuallySelected;
  final bool hasUnsavedChanges;

  bool get canSave =>
      !isSaving &&
      !isLoadingDefaults &&
      !isLoadingBaseline &&
      draft.vehicleId != null &&
      draft.amountCents > 0;

  ExpenseEntryState copyWith({...});
}
```

- `hasUnsavedChanges` 由 controller 与初始快照比较后写入；不放在 Widget 里算，避免每帧比较。
- `validation` 保存首错字段与文案，页面用 `GlobalKey` 滚动到对应字段。

### 5.6 推导与校验纯函数

```dart
// expense_entry_math.dart
double? kwhFromAmount(int amountCents, int unitPriceCentsPerKwh) {
  if (amountCents <= 0 || unitPriceCentsPerKwh <= 0) return null;
  return amountCents / unitPriceCentsPerKwh; // 分 ÷ (分/kWh) = kWh
}

double? litersFromAmount(int amountCents, int unitPriceCentsPerLiter) { ... }

int? socEndFromKwh({
  required int socStart,
  required double? kwh,
  required double? batteryCapacityKwh,
}) {
  if (kwh == null || batteryCapacityKwh == null || batteryCapacityKwh <= 0) {
    return null;
  }
  return (socStart + kwh / batteryCapacityKwh * 100).round().clamp(0, 100);
}

int? parkingMinutes(int amountCents, int rateCentsPerHour) {
  if (amountCents <= 0 || rateCentsPerHour <= 0) return null;
  return (amountCents / rateCentsPerHour * 60).round();
}

double? costPerKm(int amountCents, int? distanceKm) {
  if (amountCents <= 0 || distanceKm == null || distanceKm <= 0) return null;
  return amountCents / 100 / distanceKm;
}

int? mileageDelta(int? currentKm, int? lastKm) {
  if (currentKm == null || lastKm == null) return null;
  return currentKm - lastKm;
}

int? fullChargeCents({
  required double? batteryCapacityKwh,
  required int socStart,
  required int unitPriceCentsPerKwh,
}) {
  if (batteryCapacityKwh == null || batteryCapacityKwh <= 0) return null;
  final kwh = batteryCapacityKwh * (100 - socStart) / 100;
  return (kwh * unitPriceCentsPerKwh).round();
}
```

```dart
// expense_entry_validation.dart
class EntryValidation {
  const EntryValidation({this.field, this.message});
  const EntryValidation.none() : field = null, message = null;
  final EntryField? field;
  final String? message;
  bool get isValid => message == null;
  bool isField(EntryField f) => field == f;
}

enum EntryField { amount, occurredAt, odometer, chargingPrice, soc, fuelPrice, parkingRate, tollDistance, note, receipt, insurancePeriod }
```

- 校验顺序固定为：金额 → 车辆 → 时间 → 里程 → 分类参数 → 备注 / 凭证；保存时只返回首错。
- 格式约束（输入过滤器）在 Widget 层，业务校验在 domain 层；两者共享同一组边界常量，避免「输入能打进去但保存报错」。

### 5.7 金额解析

```dart
/// 仅接受 `123` / `123.4` / `123.45`；整数最多 6 位。
/// 返回 null 表示非法或空。
int? parseYuanToCents(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final match = RegExp(r'^(\d{0,6})(?:\.(\d{0,2}))?$').firstMatch(text);
  if (match == null) return null;
  final yuanText = match.group(1) ?? '';
  final fractionText = (match.group(2) ?? '').padRight(2, '0');
  final yuan = int.tryParse(yuanText.isEmpty ? '0' : yuanText) ?? 0;
  return yuan * 100 + int.parse(fractionText);
}
```

- 不使用 `double.parse`，避免 `0.29 * 100 = 28.999…`。
- 输入过滤器与解析器共用同一正则；粘贴 `1,000` 时先由过滤器拒绝，不静默清洗。
- 失焦时用 `formatYuanInput(cents)` 补齐两位小数；金额为 0 时输入框显示空串。

---

## 6. 数据层

### 6.1 仓库接口

```dart
abstract class ExpenseEntryRepository {
  /// 录入默认值：默认分类、支付方式、单价、油品、容量、最近地点。
  Future<ExpenseEntryDefaults> fetchDefaults(String vehicleId);

  /// 发生时间之前最近一条里程读数；编辑时排除自身。
  Future<OdometerBaseline> fetchOdometerBaseline({
    required String vehicleId,
    required DateTime before,
    String? excludeRecordId,
  });

  /// 编辑模式读取完整草稿（分类参数、凭证、备注）。
  Future<ExpenseEntryDraft> fetchDraft(String recordId);

  Future<LedgerRecord> createExpense(ExpenseEntryDraft draft);

  Future<LedgerRecord> updateExpense(String recordId, ExpenseEntryDraft draft);

  /// 保存前上传新增凭证；已上传的复用 remoteId。
  Future<List<ReceiptAttachment>> uploadReceipts(
    List<ReceiptAttachment> receipts, {
    void Function(String localPath, double progress)? onProgress,
  });
}

sealed class ExpenseEntryException implements Exception {
  const ExpenseEntryException(this.message, [this.cause]);
  final String message;
  final Object? cause;
}

class ExpenseEntryNetworkException extends ExpenseEntryException { ... }
class ExpenseEntryValidationException extends ExpenseEntryException { ... }
class ExpenseEntryConflictException extends ExpenseEntryException {
  const ExpenseEntryConflictException(this.latest, [super.message = '记录已更新']);
  final LedgerRecord latest;
}
class ExpenseEntryVehicleMissingException extends ExpenseEntryException { ... }
class ExpenseEntryOdometerConflictException extends ExpenseEntryException {
  const ExpenseEntryOdometerConflictException(this.baseline, [super.message = '里程读数已更新']);
  final OdometerBaseline baseline;
}
```

- 异常与 `expense_detail_repository.dart` 同构，页面只按异常类型给文案，不解析字符串。
- 保存失败必须携带 `cause`，便于日志排查；日志不打印金额、车牌、地点、备注。

### 6.2 Mock 实现

```dart
class MockExpenseEntryRepository implements ExpenseEntryRepository {
  MockExpenseEntryRepository(
    this.ledger,
    this.home, {
    this.delay = const Duration(milliseconds: 120),
    ReceiptPicker? picker,
  }) : picker = picker ?? const ImagePickerReceiptPicker();

  final MockLedgerRepository ledger;
  final HomeRepository home;
  final Duration delay;
  final ReceiptPicker picker;

  @override
  Future<ExpenseEntryDefaults> fetchDefaults(String vehicleId) async {
    await Future<void>.delayed(delay);
    final vehicles = await home.fetchVehicles();
    final vehicle = vehicles.firstWhere(
      (item) => item.id == vehicleId,
      orElse: () => throw const ExpenseEntryVehicleMissingException(),
    );
    final powertrain = vehicle.powertrain;
    return ExpenseEntryDefaults(
      defaultCategory: switch (powertrain) {
        PowertrainType.ev || PowertrainType.phev => ExpenseCategory.charging,
        PowertrainType.hev || PowertrainType.ice => ExpenseCategory.fuel,
      },
      paymentChannel: PaymentChannel.wechat,
      paymentLabel: '微信免密支付',
      unitPrices: const EntryUnitPrices(),
      fuelGrade: vehicle.defaultFuelGrade ?? 95,
      batteryCapacityKwh: vehicle.batteryCapacityKwh,
      tankCapacityL: vehicle.tankCapacityL,
      lastSoc: null, // P1：从该车最近一条充电记录读取结束 SOC
      lastOdometerKm: ledger.latestOdometer(vehicleId),
    );
  }

  @override
  Future<OdometerBaseline> fetchOdometerBaseline({
    required String vehicleId,
    required DateTime before,
    String? excludeRecordId,
  }) async {
    await Future<void>.delayed(delay);
    return ledger.odometerBaseline(
      vehicleId: vehicleId,
      before: before,
      excludeRecordId: excludeRecordId,
    );
  }

  @override
  Future<LedgerRecord> createExpense(ExpenseEntryDraft draft) async {
    await Future<void>.delayed(delay);
    final record = buildRecordFromDraft(draft, id: 'rec_manual_${_nextId++}');
    ledger.insertRecord(record);
    return record;
  }

  @override
  Future<LedgerRecord> updateExpense(String recordId, ExpenseEntryDraft draft) async {
    await Future<void>.delayed(delay);
    final existing = ledger.recordById(recordId);
    if (existing == null) throw const ExpenseEntryValidationException('记录不存在或已被删除');
    final record = buildRecordFromDraft(draft, id: recordId, createdAt: existing.occurredAt);
    ledger.updateRecord(record);
    return record;
  }
}
```

`buildRecordFromDraft` 与 `MockLedgerRepository._buildRecord` 共用字段映射：

| `LedgerRecord` 字段 | 来源 |
| --- | --- |
| `id` | 新建递增 / 编辑保留原 id |
| `vehicleId` | `draft.vehicleId` |
| `vehicleShortName` | 车辆名去品牌前缀（如「汉 EV」） |
| `vehicleName` | 车辆全名，导出用 |
| `powertrain` | 车辆动力类型 |
| `category` | `draft.category` |
| `title` | 地点 / 门店 / 分类参数（§6.2.1） |
| `amountCents` | `draft.amountCents` |
| `occurredAt` | `draft.occurredAt` |
| `badgeText` | 停车「B2区」等无法推导时不填；不硬凑 |
| `description` | 分类副标题（§6.2.1） |
| `metrics.kwh` / `liters` / `odometerKm` / `distanceKm` / `durationMinutes` / `plate` / `paymentMethod` | 由 draft 计算 |
| `statusText` | 支付方式展示名（如「微信支付」） |
| `note` | `draft.note` |

#### 6.2.1 标题与副标题

| 分类 | title | description |
| --- | --- | --- |
| 充电 | `place ?? '充电'` | `充入 83.3 kWh`（无电量则「新能源补能」） |
| 加油 | `place ?? '加油'` | `12.74 L · 95#`（无升数则「燃油加注」） |
| 停车 | `place ?? parking.lotName ?? '停车'` | `停车 3.5 小时`（无时长则「停车缴费」） |
| 过路费 | `roadName ?? '$entryStation → $exitStation' ?? '过路费'` | `高速通行`（有里程追加 `· 51 km`） |
| 保养维修 | `maintenance.item ?? '保养维修'` | `place ?? '常规保养'` |
| 洗车美容 | `place ?? '洗车美容'` | `serviceType` |
| 车险车税 | `coverageType` 映射（商业险 / 交强险 / 车船税） | `policyNo` 后 6 位或「保险 / 税费」 |

- 账单页现有 `LedgerRecordPresentation` 会按分类重新拼副标题；本页只需保证字段完整，**不复制账单页的拼装逻辑**。
- 标题不超过 30 字；超长由账单卡片单行省略。

### 6.3 里程基线

```dart
OdometerBaseline odometerBaseline({
  required String vehicleId,
  required DateTime before,
  String? excludeRecordId,
}) {
  LedgerRecord? latest;
  for (var i = 0; i < 24; i++) {
    final month = DateTime(before.year, before.month - i);
    for (final record in _recordsFor(month)) {
      if (record.vehicleId != vehicleId) continue;
      if (record.id == excludeRecordId) continue;
      if (_deletedIds.contains(record.id)) continue;
      final km = record.metrics.odometerKm;
      if (km == null || km <= 0) continue;
      if (record.occurredAt.isAfter(before)) continue;
      if (latest == null || record.occurredAt.isAfter(latest.occurredAt)) {
        latest = record;
      }
    }
  }
  return OdometerBaseline(
    lastReadingKm: latest?.metrics.odometerKm,
    recordedAt: latest?.occurredAt,
    recordId: latest?.id,
    // 由调用方从车辆资料补齐；Mock 在 repository 层注入当前里程。
    currentOdometerKm: currentOdometerFor(vehicleId),
  );
}
```

- 只回扫 24 个月（与 `recordById` 一致）；更早的历史读数 P1 由服务端返回。
- 编辑模式必须传 `excludeRecordId`；否则基线是自己的旧读数，区间恒为 0。
- `currentOdometerKm` 取车辆资料里程，与账单最新读数取较大值，避免资料滞后；Mock 的 `currentOdometerFor(vehicleId)` 从注入的 `HomeRepository.fetchVehicles()` 查找，生产实现直接读接口返回值。
- 该实现是 O(24 个月 × 当月记录数)，只在切车 / 改时间时调用，不进入 `build`。

### 6.4 MockLedgerRepository 的扩展

```dart
// 手动新增 / 编辑记录
final List<LedgerRecord> _manualRecords = [];
final Map<String, LedgerRecord> _overrides = {};

void insertRecord(LedgerRecord record) {
  _manualRecords.add(record);
  _idIndex[record.id] = record;
  _monthCache.remove(_monthKey(record.occurredAt));
  _lifetimeCache = null;
}

void updateRecord(LedgerRecord record) {
  final index = _manualRecords.indexWhere((item) => item.id == record.id);
  if (index >= 0) {
    _manualRecords[index] = record;
  } else {
    _overrides[record.id] = record; // 编辑生成数据：按 id 覆盖
  }
  _idIndex[record.id] = record;
  _monthCache.clear();
  _lifetimeCache = null;
}

int? latestOdometer(String vehicleId) { ... }

```

- `_recordsFor(month)` 合并顺序：生成记录 → 手动记录 → `_overrides` 覆盖 → 过滤 `_deletedIds` → 按 `occurredAt` 倒序。
- 编辑生成记录时不能直接改 `_monthCache` 里的不可变列表；用 `_overrides` 映射在读取时替换，避免破坏确定性。
- `_monthCache.clear()` 成本很低（最多 24 个月），保存是低频操作，不做增量失效。
- 手动记录 id 用 `rec_manual_<递增>`，与生成记录 `rec_*` 不冲突；服务端接入后由后端返回真实 id。
- 新增 `latestOdometer` 后，`MockHomeRepository` 通过 `odometerResolver` 复用，见 §3.2；车辆资料仍以 `MockHomeRepository` 为准，避免在账单 Mock 再维护一份车辆表。

### 6.5 接口映射与容错

| 客户端字段 | 接口字段 | 容错 |
| --- | --- | --- |
| `amountCents` | `amountCents` | 缺失 / ≤ 0 → 校验失败 |
| `occurredAt` | `occurredAt` ISO 8601 | 无时区时按本地时区解析 |
| `paymentChannel` | `payment.channel` | 未知枚举 → `PaymentChannel.other`，保留 label |
| `detail` | `detail.type` + 字段 | type 与 category 不匹配 → 422，客户端提示并保留输入 |
| `receipts` | `receiptIds` | 上传失败只影响凭证，不阻止保存？**P0 阻止保存**，避免丢票 |
| `lastOdometerKm` | `lastOdometerKm` | 服务端 409 时刷新基线并提示 |
| `fuelGrade` | `detail.fuelGrade` int | 非 92/95/98 → 默认 95 |

- 接口返回的记录直接使用后端 `record`，不自行拼 `LedgerRecord`；Mock 才走 `buildRecordFromDraft`。
- 金额、单价全部是整数分；服务端若返回字符串，统一在 `fromJson` 解析，UI 不接触 JSON。
- 时间统一 `toLocal()` 展示，保存时 `toIso8601String()` 带时区。

---

## 7. 状态管理

### 7.1 Provider 设计

```dart
final expenseEntryRepositoryProvider = Provider<ExpenseEntryRepository>((ref) {
  return MockExpenseEntryRepository(
    ref.watch(mockLedgerRepositoryProvider),
    ref.watch(homeRepositoryProvider),
  );
});

final expenseEntryControllerProvider = NotifierProvider.autoDispose
    .family<ExpenseEntryController, ExpenseEntryState, ExpenseEntryArgs>(
      ExpenseEntryController.new,
    );

class ExpenseEntryController extends Notifier<ExpenseEntryState> {
  ExpenseEntryController(this.args);

  final ExpenseEntryArgs args;
  int _baselineGeneration = 0;
  int _defaultsGeneration = 0;
  bool _saving = false;
  late ExpenseEntryDraft _initialDraft;

  @override
  ExpenseEntryState build() {
    _bootstrap();
    return ExpenseEntryState(
      args: args,
      draft: ExpenseEntryDraft.empty(args),
    );
  }

  Future<void> _bootstrap() async { ... }
  void selectVehicle(String vehicleId) { ... }
  void selectCategory(ExpenseCategory category) { ... }
  void setAmountCents(int cents) { ... }
  void applyPreset(EntryPreset preset) { ... }
  void setUnitPrice(...) { ... }
  void setSocStart(int value) { ... }
  void setFuelGrade(int grade) { ... }
  void setParkingRate(int centsPerHour) { ... }
  void setDetailText(...) { ... }
  void setOdometerKm(int? km) { ... }
  void setOccurredAt(DateTime time) { ... }
  void setPlace(String? place) { ... }
  void setPayment(PaymentChannel channel, String label) { ... }
  void setNote(String? note) { ... }
  void addReceipt(ReceiptAttachment receipt) { ... }
  void removeReceipt(ReceiptAttachment receipt) { ... }
  Future<void> retryDefaults() { ... }
  Future<void> retryBaseline() { ... }
  Future<ExpenseEntryResult?> save() { ... }
}
```

- 写法与 `ExpenseDetailController` 一致：family 参数由构造函数接收，`build()` 同步返回初始态，异步加载在 `build()` 内触发。
**初始化顺序**

1. `build()` 返回占位草稿后，`_bootstrap()` 先 `await ref.read(vehiclesProvider.future)`。
2. 选车优先级：`args.initialVehicleId` → `selectedVehicleIdProvider` → 车辆列表第一辆；无车辆则进入空态，不发默认值 / 基线请求。
3. 编辑模式并行 `fetchDraft(recordId)`；创建模式直接使用占位草稿。
4. 车辆确定后，**并行**请求 `fetchDefaults(vehicleId)` 与 `fetchOdometerBaseline(...)`；两者都返回后才把 `isLoadingDefaults` / `isLoadingBaseline` 置 false。
5. 默认值只填充用户尚未改动的字段；`_initialDraft` 在全部加载完成、金额归一化后记录，避免加载过程被误判为「已修改」。
6. 初始化失败按 §11 处理：默认值失败用本地兜底继续；基线失败允许保存但提示不校验里程。

- `state` 只在 controller 内更新；页面通过方法调用，不直接 `state = ...`。
- 输入类方法不做异步请求；只有 `selectVehicle` / `setOccurredAt` 触发基线重查，`_bootstrap` 触发默认值。
- `save()` 内部用 `_saving` 加锁，并检查 `ref.mounted`。

### 7.2 分类切换与参数重置

```dart
void selectCategory(ExpenseCategory category) {
  if (state.draft.category == category) return;
  final detail = defaultDetailFor(
    category,
    unitPrices: state.defaults.unitPrices,
    fuelGrade: state.defaults.fuelGrade,
    socStart: state.defaults.lastSoc,
    lotName: state.draft.place,
  );
  state = state.copyWith(
    draft: state.draft.copyWith(category: category, detail: detail),
    isCategoryManuallySelected: true,
    validation: const EntryValidation.none(),
  );
  _recomputeDerived();
}
```

| 切换场景 | 保留 | 清空 / 重置 |
| --- | --- | --- |
| 用户点分类胶囊 | 金额、时间、车辆、支付、备注、凭证、地点 | 旧分类专属参数 → 新分类默认参数 |
| 切换车辆（未手动选分类） | 金额、时间、支付、备注、凭证、地点 | 分类改为动力默认；参数重置；里程读数与基线清空 |
| 切换车辆（已手动选分类） | 分类、金额、时间、支付、备注、凭证 | 参数重置为新车辆默认值；里程清空 |
| 编辑模式加载完成 | 全部原记录字段 | — |
| 修改发生时间 | 全部字段 | 仅重查基线，不改参数 |

- `defaultDetailFor` 统一构造参数默认值，避免每个 Widget 各写一份。
- `_recomputeDerived()` 在金额或单价变化后重算 `kwh` / `liters` / `durationMinutes`，保证保存值与展示一致。
- 地点与停车 `lotName`、保养 / 洗车 `shopName` 的同步在 controller 的 `setPlace` / `setDetailText` 中处理，UI 不双向写。

### 7.3 脏检查

- `_initialDraft` 在默认值 / 编辑数据加载完成、且 draft 被归一化后记录。
- 每次会修改 draft 的方法末尾调用 `_updateDirty()`：

```dart
void _updateDirty() {
  state = state.copyWith(hasUnsavedChanges: state.draft != _initialDraft);
}

void _markClean() {
  _initialDraft = state.draft;
  state = state.copyWith(hasUnsavedChanges: false);
}
```

- `ExpenseEntryDraft` 与所有 `EntryCategoryDetail` 实现 `==` / `hashCode`；`receipts` 按路径与删除标记比较。
- 加载默认值本身**不**标记脏；只有用户操作才比较。
- 保存成功后 `_markClean()`，再返回结果，确保页面 pop 时不被误认为未保存。
- 切换车辆 / 分类后如果用户改回原值，允许重新变为「未修改」——按值比较，而不是按操作次数。

### 7.4 保存流程

```dart
Future<ExpenseEntryResult?> save() async {
  if (_saving || !state.canSave) return null;
  final validation = validateDraft(
    draft: state.draft,
    defaults: state.defaults,
    mode: args.mode,
  );
  if (!validation.isValid) {
    state = state.copyWith(validation: validation);
    return null;
  }

  _saving = true;
  state = state.copyWith(isSaving: true, saveError: null, validation: const EntryValidation.none());
  try {
    final repo = ref.read(expenseEntryRepositoryProvider);
    final uploaded = await repo.uploadReceipts(
      state.draft.receipts,
      onProgress: (path, progress) => _updateUploadProgress(path, progress),
    );
    if (!ref.mounted) return null;
    final draft = state.draft.copyWith(receipts: uploaded);
    final record = args.mode == ExpenseEntryMode.create
        ? await repo.createExpense(draft)
        : await repo.updateExpense(args.recordId!, draft);
    if (!ref.mounted) return null;
    _invalidateDependents(record.id);
    _markClean();
    state = state.copyWith(isSaving: false);
    return ExpenseEntrySaved(recordId: record.id, isNew: args.mode == ExpenseEntryMode.create);
  } on ExpenseEntryConflictException catch (error) {
    if (!ref.mounted) return null;
    state = state.copyWith(isSaving: false, saveError: error);
    rethrow;
  } catch (error) {
    if (!ref.mounted) return null;
    state = state.copyWith(isSaving: false, saveError: error);
    return null;
  } finally {
    _saving = false;
  }
}
```

- 页面在 `await save()` 后：
  - 返回 `ExpenseEntrySaved` → `Navigator.pop(result)` + Toast「已记入账本」。
  - 返回 `null` → 依据 `state.validation` 滚动到首错字段，或 Toast「保存失败，请重试」。
  - 冲突异常 → 弹「重新载入 / 仍要保存」。
- 保存前先 `FocusScope.of(context).unfocus()`，避免键盘遮挡错误提示。
- 凭证上传在 `isSaving` 内完成：`totalReceipts > 0 && uploadedReceipts < totalReceipts` 时，按钮文案为「上传凭证 x/y」；全部完成后切换为「保存中…」。
- `_updateUploadProgress` 只更新计数与进度，不修改草稿内容；上传失败时 `isSaving` 复位，本地缩略图保留。

### 7.5 失效矩阵

| 变更 | 需要失效的 provider |
| --- | --- |
| 新建记录 | `ledgerRecordsProvider`、`ledgerSummaryProvider`、`homeDashboardProvider`、`breakdownProvider`、`recordsProvider`、`trendProvider`、`statsOverviewProvider`、`statsBreakdownProvider`、`statsRecentProvider`、`statsTrendProvider`、`monthlyReportProvider`、`profileOverviewProvider`、`vehiclesProvider` |
| 编辑记录 | 同新建 + `expenseDetailProvider(recordId)` |
| 仅本地交互（切分类 / 改金额） | 无 |
| 车辆切换 | `vehiclesProvider` 不失效（只读最新快照）；如车辆资料可能变更，重新 `refresh` |
| 保存成功返回 | 来源页不主动刷新，依赖上面的失效；详情页额外 `invalidate` 自身 |

- 全部失效都是 `ref.invalidate`，不手动改 provider 状态；`autoDispose` 的 provider 在下次被 watch 时重新请求。
- `monthlyReportProvider` 是 family（按月份），保存的月份可能不是当前报表月份；直接用 `ref.invalidate(monthlyReportProvider)` 失效整个 family。
- 不失效 `ledgerFilterProvider` / `statsFilterProvider` / `appTabProvider`，保持用户当前筛选与 Tab。
- 若后端提供 `summaryDirty` / 版本号，可退化为按需 refresh；P0 全量失效，成本可接受。

### 7.6 竞态与生命周期

- 基线请求带 `_baselineGeneration`；车辆或时间变化时先递增，响应回来只应用最新一版。
- 默认值请求带 `_defaultsGeneration`；切换车辆时旧响应不得覆盖新车辆参数。
- 连续切换车辆：中间车辆的基线结果直接丢弃，不写 state。
- 页面 `pop` 后 controller 随 `autoDispose` 释放；异步回调写 state 前必须检查 `ref.mounted`。
- 保存过程中切换车辆 / 分类：保存按钮禁用，页面其他字段仍可改；此时不允许再次保存，直到上一次返回。
- `image_picker` 返回时页面可能已失焦或销毁；拿到文件后先检查 `ref.mounted` 再写 state。
- 从后台恢复不重新拉默认值；只有下拉刷新（P1）或重新进入才刷新。

---

## 8. UI 实现

### 8.1 页面骨架

```dart
class ExpenseEntryPage extends ConsumerStatefulWidget {
  const ExpenseEntryPage({super.key, required this.args});
  final ExpenseEntryArgs args;

  @override
  ConsumerState<ExpenseEntryPage> createState() => _ExpenseEntryPageState();
}

class _ExpenseEntryPageState extends ConsumerState<ExpenseEntryPage> {
  final _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => _handleClose(),
      child: Scaffold(
        backgroundColor: palette.background,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: Column(
                children: [
                  const EntryHeader(),
                  Expanded(
                    child: CustomScrollView(
                      controller: _scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              const EntryVehicleCard(),
                              const SizedBox(height: 20),
                              const EntryCategoryChips(),
                              const SizedBox(height: 12),
                              const EntryAmountCard(),
                              const SizedBox(height: 20),
                              const EntryParamsCard(),
                              const SizedBox(height: 20),
                              const EntryMileageCard(),
                              const SizedBox(height: 20),
                              const EntryMetaCard(),
                              const SizedBox(height: 20),
                              const EntryNoteReceiptsCard(),
                              const SizedBox(height: 8),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: const EntryBottomBar(),
      ),
    );
  }
}
```

- 顶部栏放在 `Column` 外，天然固定，不参与滚动；比 `SliverPersistentHeader` 更简单，也避免滚动时重复模糊。
- 底栏用 `bottomNavigationBar`：键盘弹起时 Scaffold 会把底栏抬到键盘上方；若个别机型不跟随，改用 `AnimatedPadding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom))` 包裹底栏。
- `SafeArea(bottom: false)` 让底栏自己处理底部安全区；内容区底部预留 24，避免最后一张卡贴住底栏。
- 页面级 `Scaffold` 不设置 `extendBody`，本页没有底部导航。
- 每个卡片内部是独立 `Consumer`，只 watch 自己需要的切片（见 §8.12）。

### 8.2 顶部栏 `EntryHeader`

```
SizedBox(height: 56 + topInset)
└── Stack
    ├── 背景：surface 80% + BackdropFilter(blur 16) + 滚动后底部 1px 分隔
    └── Row
        ├── 40×40 圆形关闭（surface + cardShadow）
        ├── Expanded(Center(Text('记一笔开销')))
        └── OCR 胶囊（白底 + document_scanner + 'OCR识别'）
```

- 关闭按钮命中区用 `Material` + `InkWell` 包 44×44，视觉圆 40。
- 标题 `AppTypography.headlineSm`，编辑模式文案「编辑这笔开销」。
- OCR 胶囊 `height: 34`、`padding: EdgeInsets.symmetric(horizontal: 12)`、圆角 `radiusPill`；加载 / 保存中 `onPressed: null`。
- 滚动后分隔线：用 `_scrollController` 的 offset 判断，阈值 4px；不需要 `setState` 频繁刷新，监听只切换一个 `ValueNotifier<bool>`。

### 8.3 车辆卡 `EntryVehicleCard` 与浮层

- 卡片用 `AppCard(radius: 28, padding: EdgeInsets.fromLTRB(12, 12, 16, 12))`。
- 右侧水印：`Positioned(right: 0, top: 0, bottom: 0, width: 144)` + `IgnorePointer` + 主色 15% → 透明渐变，`ClipRRect` 裁切到卡片圆角。
- 车辆图标：`Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, color: palette.primary.withValues(alpha: .16)))`，图标用 `powertrain.icon` 22、`palette.primaryText`。
- 动力徽标用 `PowertrainVisual.badgeTextColor(palette)` + 16% 底色；文案取 `vehicle.powertrainLabel`。
- 切换按钮 `TextButton` 自定义 `styleFrom`，高度 28，`minimumSize: Size(0, 28)`，`tapTargetSize: MaterialTapTargetSize.padded` 保证命中区。
- 无车辆：卡片内显示「还没有添加车辆」+ `TextButton`「去添加」；点击 `showAppToast('车辆管理待接入')`，P1 跳车辆管理。
- 浮层 `showModalBottomSheet<Vehicle>`：

```dart
showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  builder: (_) => const EntryVehicleSheet(),
);
```

- 浮层高度 `min(0.6 * screenHeight, 72 + vehicles.length * 72 + 16)`；`ListView.separated`。
- 选中项 2px 主色描边用 `Container(decoration: BoxDecoration(border: Border.all(color: primary, width: 2)))`，不要用 `Card` 的 elevation 模拟。
- 选择后 `Navigator.pop(vehicleId)`，页面调用 `controller.selectVehicle(id)`；自动分类与 Toast 由 controller / 页面处理。
- 浮层不直接改 provider，保持“返回结果 → 页面统一处理”，便于取消时不触发请求。

### 8.4 分类胶囊 `EntryCategoryChips`

- 结构：`Column`（标题行 + 36 高横向 `ListView.separated`）。
- 胶囊用 `Material` + `InkWell` + `AnimatedContainer(duration: 150ms)`；选中 / 未选中两套 `BoxDecoration`。
- 选中态：`color: palette.primary`、文字白、图标白、`boxShadow: [BoxShadow(color: primary.withValues(alpha: .3), blurRadius: 8, offset: Offset(0, 2))]`。
- 未选中态：`color: palette.surface`、`border: 1px palette.cardBorder`、`boxShadow: tokens.cardShadow`、图标 `category.color`、文字 `onSurfaceVariant`。
- 内边距：选中 `horizontal: 16`，未选中 `horizontal: 14`；高度 36；图标 18。
- 分类文案用 `ExpenseCategoryEntryLabel` 扩展（`maintenance → 保养维修`、`carWash → 洗车美容`、`other → 车险车税`），不改 `ExpenseCategory.label`，避免影响账单页。
- 无障碍：`Semantics(button: true, selected: isSelected, label: '${label}，支出分类')`。

### 8.5 金额卡 `EntryAmountCard`

```
AppCard(radius: 28, padding: 20)
└── Column
    ├── Row[Text('实付金额 (元)'), Spacer]
    ├── SizedBox(height: 8)
    ├── Row[¥ 20/700, Expanded(AmountTextField), ClearButton]
    ├── Container(height: 1, color: surfaceContainerHigh)
    ├── SizedBox(height: 12)
    ├── EntryTelemetryPill()
    ├── SizedBox(height: 16)
    └── Row[5 × Expanded(PresetChip)]
```

- 金额输入用 `TextField`，`style: AppTypography.displayHero`，`decoration: InputDecoration.collapsed(hintText: '0.00')`，`cursorHeight: 28`，`cursorWidth: 2`，`cursorColor: primary`。
- `keyboardType: TextInputType.numberWithOptions(decimal: true)`；`textInputAction: TextInputAction.done`。
- 输入过滤器：

```dart
class AmountInputFormatter extends TextInputFormatter {
  static final _pattern = RegExp(r'^\d{0,6}(\.\d{0,2})?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty || _pattern.hasMatch(text)) return newValue;
    return oldValue;
  }
}
```

- 首字符 `.` 在 `onChanged` 中补 `0`：统一在 formatter 内处理，粘贴 `.5` 也能通过。
- 清空按钮用 `IconButton` 24 视觉 + 44 命中区；`onPressed` 清空 controller 与 provider，不重新聚焦。
- 快捷金额用 `Row` + 5 个 `Expanded`；高度 32；窄屏（< 375）仍用 5 等分，文字 11px 可容纳「¥1000」。
- 预设点击调用 `controller.applyPreset(...)`，controller 更新金额后，金额输入框在 `didUpdateWidget` / `ref.listen` 中同步文本（见 §8.12）。
- 金额卡内部只 watch `amountCents`、`category`、`odometer`、`detail.unitPrice`，不 watch 备注 / 凭证，避免输入备注时重建金额输入框。

### 8.6 预估条 `EntryTelemetryPill`

- 容器 `height: 32`、`borderRadius: radiusPill`、主色 15% 底 + 主色 30% 描边；`SingleChildScrollView(scrollDirection: Axis.horizontal)` 包内容。
- 左侧固定；右侧由 `List<TelemetrySegment>` 拼装，段间 `Text(' · ', style: outlineVariant)`。
- 数据由 `EntryTelemetryPresenter.build(draft, vehicle)` 返回：

```dart
@immutable
class TelemetrySegment {
  const TelemetrySegment({required this.prefix, required this.value, required this.suffix});
  final String prefix;
  final String value;
  final String suffix;
}

class EntryTelemetryPresenter {
  static List<TelemetrySegment> build(ExpenseEntryDraft draft, Vehicle? vehicle) {
    return switch (draft.detail) {
      ChargingDetail d => [
          if (costPerKm(draft.amountCents, draft.distanceKm) case final v?)
            TelemetrySegment(prefix: '约 ', value: '¥${v.toStringAsFixed(2)}', suffix: ' / km'),
          if (d.kwh case final v?)
            TelemetrySegment(prefix: '充入约 ', value: v.toStringAsFixed(1), suffix: ' kWh'),
        ],
      FuelDetail d => [ ... ],
      ParkingDetail d => [ ... ],
      TollDetail d => [ if (d.distanceKm case final v?) TelemetrySegment(...) ],
      _ => const <TelemetrySegment>[],
    };
  }
}
```

- 保养 / 洗车 / 保险返回空列表，Widget 直接 `SizedBox.shrink()`，不占位。
- 过路费不展示折扣 / 金额推导，只展示用户填写的通行里程。
- 预估条不接收点击，`IgnorePointer` 可选；语义上朗读为一句「能耗预估：约 0.17 元每公里，充入约 83.3 千瓦时」。

### 8.7 参数卡 `EntryParamsCard`

```dart
class EntryParamsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(
      expenseEntryControllerProvider(args).select((s) => s.draft.category),
    );
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, .02), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: switch (category) {
        ExpenseCategory.charging => const EntryChargingParams(key: ValueKey('charging')),
        ExpenseCategory.fuel => const EntryFuelParams(key: ValueKey('fuel')),
        ExpenseCategory.parking => const EntryParkingParams(key: ValueKey('parking')),
        ExpenseCategory.toll => const EntryTollParams(key: ValueKey('toll')),
        ExpenseCategory.maintenance => const EntryMaintenanceParams(key: ValueKey('maintenance')),
        ExpenseCategory.carWash => const EntryCarWashParams(key: ValueKey('carWash')),
        ExpenseCategory.other => const EntryInsuranceParams(key: ValueKey('insurance')),
      },
    );
  }
}
```

- 每个参数卡共用 `EntryParamsShell`（卡头、分隔线、内边距、`AnimatedSize`），只替换字段区；避免 7 份卡片容器重复。
- 字段格 `EntryFieldCell`：`label`、`value`（`Text` / `TextField`）、`unit`、`trailing`、`errorText`；数值格与文本格同高（≥ 64）。
- 数值输入统一用 `EntryNumberField`：`keyboardType: number`、过滤器、`textAlign: TextAlign.right`、聚焦底部主色线。
- 文本输入统一 `EntryTextField`：`maxLength`、`counterText: ''`、单行、失焦提交。
- SOC 区块单独用 `EntrySocBlock`：开始 / 结束胶囊 + 进度条（`ClipRRect` + `Row` 两段 `Container`，已充部分 `LinearGradient`）。
- 油品 / 洗车类型 / 险种用 `EntryChoiceChips`，单选；选中橙色 / 主色按分类。
- 保障周期用 `showDateRangePicker`，`firstDate: 2000-01-01`、`lastDate: now + 20 年`；返回值同步到 draft。

### 8.8 里程卡 `EntryMileageCard`

- 通过 `ref.watch` 取 `draft.odometerKm`、`draft.lastOdometerKm`、`state.isLoadingBaseline`、`state.baselineError`。
- 上次读数：`lastOdometerKm == null ? '首次记录' : formatKm(lastOdometerKm!)`；加载中显示 `SkeletonBox(width: 88, height: 16)`。
- 本次里程输入 `EntryNumberField`，右对齐，后缀 `km`；默认值由 controller 在基线返回后写入（仅当用户未手动改过本次里程）。
- 区间行：`delta = mileageDelta(...)`；`delta == null → '—'`；`delta < 0 → '不能小于上次读数'`（error 色）；否则 `formatOdometerDelta(delta)`。
- 大跨度确认在保存前由 controller 触发 `showDialog`（domain 不直接弹窗）；页面拿到 `EntryValidation.warning` 后弹确认，确认后 `controller.save(force: true)`。
- 折叠态：`EntryMileageTeaser` 一行「补充里程（选填）」+ `expand_more`；展开后渲染同一张卡，`AnimatedSize` 200ms。
- 里程卡只 watch 里程相关字段，不因金额变化重建。

### 8.9 三行卡 `EntryMetaCard` 与浮层

- `AppCard(radius: 28, padding: EdgeInsets.zero)`，内部 `Column` + 3 个 `EntryMetaRow` + `Divider(height: 1)`。
- 行高 56，`InkWell` 整行点击；左侧 32 圆形图标容器，中间标题，右侧值 + `chevron_right` 16。
- 值 `maxWidth: 190`，`TextOverflow.ellipsis`；空地点显示「未填写」`outline`。
- 时间行值用 `formatOccurredAtLabel(draft.occurredAt, now: DateTime.now())`。
- 地点行打开 `EntryPlaceSheet`（`TextField` + 最近地点胶囊 + 完成 / 清空），返回 `String?`；`null` 表示清空。
- 支付行打开 `EntryPaymentSheet`，返回 `(PaymentChannel, String)?`；列表项含 8px 圆点与 `check`。
- 时间行打开 `EntryTimeSheet`：快捷项 + 「选择日期与时间」；日期用 `showDatePicker`，时间用 `showTimePicker`；返回时间后 controller 重查基线。
- 三个浮层都用 `showModalBottomSheet(useSafeArea: true, isScrollControlled: true)`，圆角 32。

### 8.10 备注与凭证 `EntryNoteReceiptsCard`

- 备注 `TextField`：`maxLength: 200`、`maxLines: 3`、`minLines: 1`、`counterText: ''`；自绘 `N/200` 提示，只在聚焦或 > 150 字时显示。
- 凭证网格用 `GridView.count(crossAxisCount: 4, shrinkWrap: true, physics: NeverScrollableScrollPhysics())`；`childAspectRatio: 1`。
- 已传缩略图：`Image.file(File(path), fit: BoxFit.cover, cacheWidth: 200)`；右上角删除按钮 20 + `close` 12；点击打开 `showDialog` + `InteractiveViewer`。
- 添加槽：`DottedBorder` 无现成依赖，用 `CustomPaint` 画虚线圆角矩形（自绘 `_DashedRRectPainter`，不新增包）。
- 空槽：`Icon(receipt/image, color: outlineVariant.withValues(alpha: .4))`，`IgnorePointer`。
- 点击添加槽：`showModalBottomSheet` 三个选项；选择后调用 `ReceiptPicker.pick(source)`：

```dart
abstract class ReceiptPicker {
  Future<PickedReceipt?> pick(ReceiptSource source);
}

class ImagePickerReceiptPicker implements ReceiptPicker {
  const ImagePickerReceiptPicker();

  @override
  Future<PickedReceipt?> pick(ReceiptSource source) async {
    final file = await ImagePicker().pickImage(
      source: source == ReceiptSource.camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    return PickedReceipt(path: file.path, sizeBytes: await file.length());
  }
}
```

- `ReceiptPicker` 是注入点：Widget 测试用 `FakeReceiptPicker` 返回固定文件，不触发真实相机。
- 超过 4 张：添加槽隐藏；若通过其他途径拿到第 5 张，controller 拒绝并 Toast。
- 权限拒绝由 `image_picker` 抛 `PlatformException`；页面捕获后按 `code` 给「相机 / 相册权限被拒绝」文案。
- 上传在 `save()` 前由 controller 调用 `repo.uploadReceipts(...)`（接口见 §8.10.1），逐个文件上传并更新 `ReceiptAttachment.uploadProgress`；任一失败即中断保存并保留本地文件。

#### 8.10.1 凭证上传接口补充

```dart
Future<List<ReceiptAttachment>> uploadReceipts(
  List<ReceiptAttachment> localReceipts, {
  void Function(String localPath, double progress)? onProgress,
});
```

- Mock 实现直接把本地路径当作 `remoteId`，`progress` 立刻到 1.0；接口接入后替换。
- 已上传且未删除的凭证复用 `remoteId`，不重复上传；新增的才上传。
- 编辑模式删除已有凭证：在 `draft.receipts` 中保留 `isDeleted: true` 的项，保存时服务端据此解绑；UI 不显示已删除项。

### 8.11 底部栏 `EntryBottomBar`

- 用 `Material` + `Container`：背景 `surface.withValues(alpha: .9)`、`BackdropFilter(blur 20)`、上阴影；左右内边距 16、上 12、下 `16 + bottomInset`。
- 最大宽度 448 由外层 `Center` + `ConstrainedBox` 控制；`bottomNavigationBar` 本身占满宽度时，内部再居中。
- 按钮 `SizedBox(height: 52)` + `DecoratedBox` 渐变（`primary` → `#3FDFA5`）+ `InkWell`；图标 20 + 文案。
- 禁用态：`Opacity(opacity: .4)` + `onTap: null`；不要只改颜色，避免深色模式对比度不足。
- 保存中：`SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))` + 「保存中…」；凭证尚未传完时文案为「上传凭证 x/y」。
- 点击顺序：`FocusScope.unfocus()` → `controller.save()` → 处理结果；按钮自身不做校验。

### 8.12 重建范围与输入控制器

- 页面所有卡片都是独立 `Consumer`，用 `ref.watch(provider.select(...))` 指定切片：

| Widget | watch 的切片 |
| --- | --- |
| `EntryHeader` | `isSaving`、`mode` |
| `EntryVehicleCard` | `draft.vehicleId`、`vehiclesProvider` |
| `EntryCategoryChips` | `draft.category` |
| `EntryAmountCard` | `draft.amountCents`、`draft.category`、`isLoadingBaseline` |
| `EntryTelemetryPill` | `draft.amountCents`、`draft.distanceKm`、`draft.detail` |
| `EntryParamsCard` | `draft.category`、对应 detail |
| `EntryMileageCard` | `draft.odometerKm`、`lastOdometerKm`、`isLoadingBaseline`、`baselineError` |
| `EntryMetaCard` | `draft.occurredAt`、`place`、`paymentLabel` |
| `EntryNoteReceiptsCard` | `note`、`receipts` |
| `EntryBottomBar` | `canSave`、`isSaving` |

- 文本输入不直接由 provider 驱动 `TextEditingController.text` 的每次重建设置，否则光标会跳到末尾：

```dart
void _syncAmountText(int cents) {
  final text = cents == 0 ? '' : formatYuanInput(cents);
  if (_amountController.text == text) return;
  _amountController.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
}
```

- 只有在**外部**改变金额（快捷金额、清空、编辑预填）时调用 `_syncAmountText`；用户键入时先写 controller，再写 provider，不回写文本。
- 参数卡内的文本输入同理：输入框自己持有 `TextEditingController`，`didUpdateWidget` 时仅在值不同步且未聚焦时更新。
- 金额输入框在页面 pop / 焦点丢失时 `dispose`；不要在 controller 中持有 `TextEditingController`，避免内存泄漏。

### 8.13 深色模式、无障碍与键盘

**深色**

- 所有颜色来自 `context.palette`；不写 `Colors.white` / `Color(0xFF...)`。
- 卡片 `palette.surface`，字段格 `palette.surfaceContainer`，分隔线 `palette.outlineVariant`，主色底文字用 `palette.onSurface` / 白按对比度取。
- 选中胶囊 `palette.primary` 白字；未选中卡片阴影在深色下改用 `tokens.cardShadow`（已含深色值）。
- 错误态 `palette.error` + `errorSoft`；深色下 `errorSoft` 已是深红，不再叠加透明度。
- 凭证缩略图在深色下保持原图，加 1px `outlineVariant` 描边避免白底图片糊在一起。

**无障碍**

- 关闭 / OCR / 清空 / 删除凭证 / 切换车辆等图标按钮都包 `Semantics(label: ...)`；纯图标按钮不使用 `Tooltip` 代替语义。
- 金额输入 `Semantics(label: '实付金额，单位元')`；里程输入 `Semantics(label: '本次仪表里程，单位公里')`。
- 分类胶囊 `Semantics(selected: ...)`；支付选项 `Semantics(selected: ...)`。
- 预估条整体包一句语义，内部片段 `excludeSemantics: true`，避免朗读成一堆数字。
- 错误文案 `Semantics(liveRegion: true)`；保存失败 Toast 使用 `ScaffoldMessenger` 自带播报。
- 最小点击区 44；分类胶囊 36 视觉高度，用 `MaterialTapTargetSize.padded` 补足。
- 支持 1.3 倍字号：卡片高度用 `IntrinsicHeight` / 自适应，金额输入不设固定高度，底栏文字 `maxLines: 1` + `FittedBox` 或 `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.2)`。

**键盘与焦点**

- 金额 → 里程 → 备注的焦点顺序由 `FocusTraversalOrder` 控制；`textInputAction`：金额 `done`、里程 `next`、备注 `done`。
- 点击卡片空白处收起键盘：`GestureDetector(onTap: FocusScope.of(context).unfocus, behavior: HitTestBehavior.opaque)` 仅包在非输入区域，避免拦截输入框。
- 键盘弹起时 `Scrollable.ensureVisible(focusedContext, alignment: .25, duration: 200ms)`，由 `Focus` 的 `onFocusChange` 触发。
- 保存前 `unfocus()`；保存失败后滚动到首错字段，不自动重新聚焦（避免再次弹键盘）。
- 日期 / 时间 / 支付 / 地点浮层打开前先 `unfocus()`，避免键盘与浮层叠加。

---

## 9. 交互与跳转

### 9.1 入口接线

| 入口 | 位置 | 参数 |
| --- | --- | --- |
| 全局 FAB | `AppTabShell` → `AppBottomNav.onFab` | `ExpenseEntryArgs.create(initialVehicleId: ref.read(selectedVehicleIdProvider))` |
| 详情「再记一笔」 | `DetailBottomBar.onRepeat` | `create(initialVehicleId: record.vehicleId, initialCategory: record.category, initialOccurredAt: DateTime.now(), initialPlace: record.description)` |
| 详情「编辑此笔账单」 | `DetailBottomBar.onEdit` | `edit(recordId: record.id)` |
| 账单空态「记一笔」 | `LedgerPage` 空态按钮（P1） | `create(initialOccurredAt: DateTime.now())` |
| 首页最近记录「再记一笔」 | `RecentRecords` 菜单（P1） | 同详情「再记一笔」 |

```dart
// expense_entry_routes.dart
Future<ExpenseEntryResult?> openExpenseEntry(
  BuildContext context, {
  required ExpenseEntryArgs args,
}) {
  return Navigator.of(context, rootNavigator: true).push<ExpenseEntryResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ExpenseEntryPage(args: args),
    ),
  );
}
```

- 不需要新建 `ProviderScope`：路由在 `MaterialApp` 的同一棵树下，直接使用父级容器；页面在测试中通过外层 `ProviderScope(overrides: ...)` 注入假仓库即可。
- `fullscreenDialog: true` 让 iOS 呈现为从下往上推入，符合「任务型表单」心智；Android 仍是标准页面转场。
- 返回结果由来源页 `await`；不通过全局变量或回调传递。
- 从 `AppTabShell` 打开时，`Navigator` 使用根导航；Tab 壳的 `IndexedStack` 与底部导航留在下层，返回后滚动位置不变。

### 9.2 关闭与放弃

```dart
Future<void> _handleClose() async {
  if (ref.read(expenseEntryControllerProvider(widget.args)).isSaving) {
    return;
  }
  final state = ref.read(expenseEntryControllerProvider(widget.args));
  if (!state.hasUnsavedChanges) {
    Navigator.of(context).pop(const ExpenseEntryCancelled());
    return;
  }
  final discard = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(widget.args.mode == ExpenseEntryMode.create ? '放弃这笔记录？' : '放弃修改？'),
      content: Text(widget.args.mode == ExpenseEntryMode.create
          ? '已填写的内容不会保存。'
          : '本次修改不会保存。'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('继续编辑')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: context.palette.error),
          child: const Text('放弃'),
        ),
      ],
    ),
  );
  if (discard == true && mounted) {
    Navigator.of(context).pop(const ExpenseEntryCancelled());
  }
}
```

- `PopScope(canPop: false)` 拦截系统返回与侧滑；确认后主动 `pop`。
- 键盘弹起时，第一次返回由 Flutter 收起键盘（`TextField` 默认行为），不会触发 `PopScope`；不需要额外处理。
- 关闭按钮与系统返回共用 `_handleClose`，避免两套逻辑。
- 保存成功后直接 `pop(ExpenseEntrySaved)`，不再走确认。

### 9.3 保存与返回

```dart
Future<void> _handleSave() async {
  FocusScope.of(context).unfocus();
  final controller = ref.read(expenseEntryControllerProvider(widget.args).notifier);
  final result = await controller.save();
  if (!mounted) return;

  if (result is ExpenseEntrySaved) {
    Navigator.of(context).pop(result);
    showAppToast(context, widget.args.mode == ExpenseEntryMode.create ? '已记入账本' : '修改已保存');
    return;
  }

  final state = ref.read(expenseEntryControllerProvider(widget.args));
  if (state.validation.isValid && state.saveError != null) {
    showAppToast(context, '保存失败，请重试');
    return;
  }
  _scrollToField(state.validation.field);
  if (state.validation.message != null) {
    showAppToast(context, state.validation.message!);
  }
}
```

- Toast 在 pop 之后调用：`ScaffoldMessenger` 挂在更上层，页面关闭后仍能显示；若使用页面自己的 `Scaffold` 会随页面销毁，注意用根 `ScaffoldMessenger`。
- 来源页的刷新由 controller 的 `invalidate` 完成，不依赖返回值；返回值只用于 UI 文案 / 详情页是否刷新。
- 编辑模式保存成功后，详情页在 `await` 返回后 `ref.invalidate(expenseDetailProvider(recordId))`。
- 保存失败不 pop，保留所有输入与滚动位置。

### 9.4 编辑模式

- 参数为 `ExpenseEntryArgs.edit(recordId)`；页面标题「编辑这笔开销」，按钮「保存修改」。
- 首帧可用详情页传入的 `LedgerRecord` 快照渲染车辆、金额、分类、时间、里程；随后 `fetchDraft` 补齐参数、备注、凭证。
- 里程基线必须传 `excludeRecordId: recordId`，否则区间为 0；修改发生时间后按新时间回溯。
- 允许修改车辆与分类：修改后按 §7.2 重置参数、重查基线；保存时为 PATCH，服务端整组替换 `detail`。
- 编辑模式下删除已有凭证：UI 移除并生成 `ReceiptAttachment(isDeleted: true, remoteId: ...)` 占位，保存时提交；用户取消可恢复。
- 编辑模式不提供「删除这笔记录」；删除仍在详情页的更多菜单。

### 9.5 OCR 入口

- P0：点击 `showAppToast(context, 'OCR 识别将在下一版开放')`，按钮保持可见，避免用户以为入口消失。
- P1：打开相机 / 相册，上传票据 → 服务端识别 → 返回 `{amountCents, occurredAt, place, category, detail}` → 打开确认浮层（历史节点 `cbce5c4d…`）→ 用户确认后写回 draft。
- 接入时复用本页 controller 的 `hydrateFromOcr(...)`；OCR 不直接保存，必须经过用户确认。
- 识别失败 / 超时 Toast「未识别到票据信息」，保留手动输入。

### 9.6 跨页一致性

| 页面 | 保存后的表现 |
| --- | --- |
| 首页 | `homeDashboardProvider` / `recordsProvider` 失效，回到首页时本月开销、最近记录更新；车辆卡里程取最新读数 |
| 账单 | 列表与汇总失效；若当前筛选不含新记录（如筛选其他分类），列表不变但汇总（跟随车辆 + 月份）更新 |
| 统计 | 概览 / 分类 / 趋势失效，下次进入统计页重新聚合 |
| 报表 | `monthlyReportProvider` 失效；已生成的旧文件不自动重生成，下次导出使用新数据 |
| 我的 | `profileOverviewProvider` 失效，总支出 / 记录数更新 |
| 详情 | 编辑后详情失效并重新加载；「再记一笔」不影响当前详情 |

- 金额、分类、时间、车辆在本页与账单卡片、详情、报表中必须同源；本页只写结构化字段，不写展示文案。
- 新增记录的 `title` / `description` 由 §6.2.1 生成；账单页展示时仍按分类重新推导副标题，避免两套文案。

---

## 10. 性能

| 优化点 | 措施 |
| --- | --- |
| 首次进入 | 默认值与基线并行；先渲染本地草稿与车辆快照，不等网络 |
| 请求次数 | 进入页只发 2 个请求（默认值 + 基线）；金额 / 参数变化不发请求 |
| 重建范围 | 每个卡片独立 `Consumer` + `select`；输入备注不重建金额卡与车辆卡 |
| 金额输入 | 纯本地解析，`parseYuanToCents` 无正则回溯风险；预估条同步计算 |
| 里程基线 | 只在切车 / 改时间时请求；Mock 为同步内存查询，正式接口需索引 |
| 参数切换 | `AnimatedSwitcher` 只替换参数卡子树；金额卡与三行卡不重建 |
| 凭证 | 选择时压缩到长边 1600 / 质量 80；缩略图 `cacheWidth: 200`；最多 4 张 |
| 滚动 | `CustomScrollView` + 少量卡片，无长列表；每次重建的 widget 数量 < 60 |
| 保存 | 单次请求 + 全量 provider 失效；失效不触发当前页重建 |
| 内存 | 不持有原图；`ReceiptAttachment` 只存路径；页面退出释放控制器 |

指标：路由推入到可交互 ≤ 500ms；输入到预估条更新 ≤ 100ms；保存 P90 ≤ 1.5s；滚动无掉帧（60fps）。

---

## 11. 错误与边界

| 场景 | 处理 |
| --- | --- |
| 无车辆 | 页面显示空态，隐藏表单与保存按钮；关闭可用；「去添加」Toast |
| 车辆在录入过程中被删除 | 保存返回 404 → Toast「车辆已不存在」，重新加载车辆列表并回到车辆选择 |
| 默认值接口失败 | 本地兜底值 + Toast；不阻塞录入；下次切车重试 |
| 基线接口失败 | 区间行显示重试；允许保存，保存前提示「本次不校验里程」 |
| 基线返回晚于用户输入 | generation 丢弃旧响应；不覆盖用户已填的本次里程 |
| 分类参数与分类不匹配 | controller 内保证只有 `defaultDetailFor(category)` 能写入；接口 422 时提示并不 pop |
| 金额输入非法（粘贴） | formatter 拒绝；不静默改写；空串 = 0 |
| 金额为 0 / 空 | 保存禁用；预估条不计算 |
| 里程倒挂 | 字段错误 + 保存禁用；不提交 |
| 里程跨度 > 5,000 km | 保存前二次确认；确认后提交 |
| 发生时间晚于现在 | 字段错误 + 保存禁用；时间选择器禁用未来 |
| 单价 / 费率越界 | 字段错误；不提交 |
| 凭证第 5 张 | 添加槽隐藏；controller 拒绝并 Toast |
| 凭证超过 5MB | 选择后立即拒绝并提示；不加入列表 |
| 相机 / 相册权限拒绝 | 提示设置路径；保留页面，不产生空槽 |
| 图片损坏 / 无法读取 | 删除该缩略图并 Toast「图片读取失败」 |
| 上传中断 | 保留本地文件与已上传进度；重试只补未完成的 |
| 保存网络失败 | 保留全部输入；按钮恢复；Toast |
| 保存 409 里程冲突 | 刷新基线并提示「里程读数已更新」，用户确认后重试 |
| 保存 409 记录冲突 | 弹「重新载入 / 仍要保存」；重新载入丢弃本地修改 |
| 重复点击保存 | `_saving` 锁 + 幂等键；只产生一笔记录 |
| 页面销毁时请求返回 | `ref.mounted` 检查；不写 state、不弹 Toast |
| 文本放大 1.3 倍 | 卡片自适应；分类横滑；底栏文案不换行 |
| 深色模式 | 全部颜色走 palette；图片加描边 |
| 从后台恢复 | 保留输入与滚动位置；不自动刷新默认值 |

---

## 12. 测试方案

### 12.1 单元测试

- `parseYuanToCents`：空串、整数、一位 / 两位小数、三位小数拒绝、6 位整数上限、前导 0、`.` 开头、粘贴非法字符。
- `kwhFromAmount` / `litersFromAmount` / `parkingMinutes`：单价为 0、金额为 0、四舍五入边界。
- `socEndFromKwh`：容量缺失、0%、100% 上限、开始 90% 且充入超过容量。
- `costPerKm`：里程为 null / 0 / 负、金额为 0。
- `mileageDelta`：首次记录、0 增量、负增量、大跨度。
- `fullChargeCents`：容量缺失、SOC 100、单价边界。
- `validateDraft`：每条规则的首错字段与文案；金额优先级最高。
- `EntryTelemetryPresenter`：7 个分类的片段数量、缺失数据隐藏、过路费不展示折扣。
- `EntryCategoryEntryLabel`：保养 / 洗车 / 保险文案映射，不影响 `ExpenseCategory.label`。
- `defaultDetailFor`：每个分类的默认值；切换分类后旧字段不残留。
- `ExpenseEntryDraft ==`：任意字段变化、凭证顺序、detail 不同子类。
- `MockExpenseEntryRepository`：创建后 `recordById` 可查、汇总与列表包含新记录、编辑后金额 / 分类更新。
- `MockLedgerRepository.odometerBaseline`：正常回溯、补录早于全部记录、排除自身、已删除记录跳过、24 个月窗口外。
- 保存流程：成功失效依赖、失败保留 state、重复保存只调用一次、`ref.mounted` 保护。

### 12.2 Widget 测试

测试用 `ProviderScope(overrides: [...])` 注入 `FakeExpenseEntryRepository` 与固定的 `vehiclesProvider`，不触发网络与相机。

- 首屏：车辆卡、7 个分类胶囊、金额 `0.00`、保存禁用。
- 分类切换：参数卡标题 / 字段随之切换；旧分类参数不残留；金额保留。
- 金额输入：输入 `12.345` 只保留 `12.34`；清空按钮；失焦补齐 `12.34`。
- 快捷金额：点击 `¥50` 后金额与预估条更新；「充满」在容量缺失时不存在。
- 预估条：充电 / 加油 / 停车 / 过路费文案；保养 / 洗车 / 保险不显示。
- 里程卡：默认车辆里程；输入小于上次读数显示错误且保存禁用；清空后区间显示 `—`。
- 时间：默认「今天 HH:mm」；选择未来时间保存被拦截（用固定时钟注入）。
- 备注：200 字上限；计数提示出现阈值。
- 凭证：FakePicker 添加 1 张出现缩略图；添加第 5 张被拒；删除后恢复添加槽。
- 保存：成功 pop 并回调结果；失败保留输入与按钮；重复点击只调用一次。
- 未保存关闭：弹确认；继续编辑不 pop；放弃 pop。
- 编辑模式：标题 / 按钮文案；字段预填；保存走 update。
- 无车辆：空态与禁用保存。
- 无障碍：关闭 / OCR / 分类胶囊有语义标签与 selected 状态；错误文案 `liveRegion`。
- 键盘：聚焦里程时 `ensureVisible` 被调用（可用 fake ScrollController 断言）。

### 12.3 手工验收

- Android 真机：数字键盘、日期时间选择、相机 / 相册、深色模式、返回手势。
- iOS：`fullscreenDialog` 转场、侧滑返回、相册权限文案、底部安全区。
- 375 / 390 / 430pt 三档宽度；1.3 倍字号；横屏（如支持）不崩溃。
- 与账单 / 详情 / 统计 / 报表交叉核对同一笔记录的金额、分类、时间、车辆、里程。

### 12.4 CI

- PR 阶段沿用 `.github/workflows/flutter-android.yml`：`flutter pub get` + `flutter analyze` + `flutter test`；不构建 APK。
- 覆盖率目标：`features/expense_entry/domain` 与 `data` ≥ 80%；关键交互有 Widget 测试。
- Golden 不作为必过项，避免字体渲染差异阻塞；如加 golden，固定 390×844、浅色 / 深色各一张，关闭动画。

---

## 13. 实施拆分

| 阶段 | 内容 | 产出 |
| --- | --- | --- |
| M0 结构 | 新增 `expense_entry` 目录、route、repository 接口；扩展 `MockLedgerRepository`（手动记录、基线）；`Vehicle` 补容量字段；FAB 接线 | 能打开空页面并返回；Mock 可写入 |
| M1 静态表单 | 顶部栏、车辆卡 / 浮层、分类胶囊、金额卡、快捷金额 | 视觉对齐设计稿，无业务推导 |
| M2 参数与推导 | 7 个参数卡、预估条、SOC、单价、里程卡、纯函数与校验 | 金额 ↔ 参数 ↔ 里程联动正确 |
| M3 元信息与凭证 | 时间 / 地点 / 支付浮层、备注、凭证选择 / 压缩 / 预览 | 表单字段完整 |
| M4 保存闭环 | 保存 / 编辑、未保存确认、失效矩阵、失败与冲突处理 | 从 FAB / 详情进入可完成记账 |
| M5 打磨 | 深色、无障碍、键盘、文本放大、测试补齐、性能核验 | 达到验收清单 |

分支建议：

- `feat/expense-entry`：M0–M4 同一功能分支，按阶段提交。
- `feat/expense-entry-receipts`：若 `image_picker` 评审滞后，凭证单独拆分支，先合主流程。
- `feat/expense-entry-ocr`：P1，独立分支。

每阶段保持 `flutter analyze` / `flutter test` 通过；按仓库规范通过 PR 合并到 `main`。

**当前进度**：未实施（文档评审中）。

---

## 14. 风险与待确认

| 风险 | 影响 | 应对 |
| --- | --- | --- |
| 设计稿静态状态自相矛盾 | 验收时「选中充电却显示加油」 | 以 `category` 驱动参数卡；示例数据重造 |
| `image_picker` 新依赖未获准 | 凭证无法交付 | P0 主流程不依赖；凭证单独分支 / 置灰降级 |
| 车辆资料缺电池容量 / 油箱容量 | SOC 与「充满 / 加满」不可用 | 字段缺失即隐藏，不做估算；服务端补齐后自动生效 |
| `ExpenseCategory.other` 在录入页叫「车险车税」 | 无法录入「其他」类开销 | P1 拆分 `insurance` 枚举；本期在文档与文案中明示 |
| 底栏在某些 Android 机型不随键盘上移 | 保存按钮被遮挡 | 优先 `bottomNavigationBar`；必要时 `AnimatedPadding` + `viewInsets` 兜底，真机验证 |
| Mock 手动记录与月份缓存 | 保存后列表 / 汇总不一致 | 写入后清空 `_monthCache` 与 `_lifetimeCache`；测试覆盖跨月 |
| 里程基线只回扫 24 个月 | 老车 / 长历史补录基线缺失 | P1 服务端按索引查询；客户端显示「首次记录」并允许保存 |
| 保存后全量失效 provider | 页面返回时多个请求并发 | `autoDispose` 只在被 watch 时请求；首页 / 账单通常只 watch 其一 |
| 凭证含个人信息 | 隐私泄露 | 只在应用私有目录临时保存；保存成功 / 放弃后清理；不进日志与埋点 |
| 兜底单价 1.20 / 7.85 / 8.00 被当作真实价 | 用户少填 / 误填 | 字段可编辑；首次使用提示「默认单价，请按实际调整」（P1） |
| 金额输入光标跳动 | 体验差 | 外部改值才回写 controller；输入中不回写 |

待确认（与需求文档 §13 同步）：

1. 车辆资料是否提供电池容量、油箱容量、默认油品（Q15）。
2. 单价默认值来源与是否按站点记忆（Q16）。
3. 里程基线接口能否按发生时间回溯并排除自身（Q17）。
4. 凭证上传方式：multipart 还是预签名（Q18）。
5. 编辑并发字段：`If-Match` 还是 `version`（Q19）。
6. 编辑模式是否允许改车辆 / 分类（Q20）。
7. 保存成功后是否退出本页（Q21）。
8. 深色设计稿是否沿用历史节点（Q22）。
9. 支付账户 / 支付渠道跨页命名（Q23）。
10. OCR 是否本期承诺（Q24）。

---

## 15. 附录：需求 → 实现映射

| 需求模块 | Widget / 类 | Provider / 仓库 | 测试重点 |
| --- | --- | --- | --- |
| 顶部栏 | `EntryHeader` | `isSaving` / `mode` | 关闭确认、OCR 占位、滚动分隔线 |
| 车辆卡 | `EntryVehicleCard` | `vehiclesProvider` + `selectVehicle` | 骨架、动力徽标、无车辆态 |
| 车辆浮层 | `EntryVehicleSheet` | `selectVehicle` | 选中态、取消不改变、自动分类 |
| 分类胶囊 | `EntryCategoryChips` | `selectCategory` | 7 项、选中态、参数联动 |
| 金额卡 | `EntryAmountCard` / `EntryAmountInput` | `setAmountCents` | 输入过滤、清空、失焦格式化 |
| 快捷金额 | `EntryPresetChips` | `applyPreset` | 7 组配置、选中高亮、容量缺失隐藏 |
| 能耗预估 | `EntryTelemetryPill` / `EntryTelemetryPresenter` | 纯函数 | 片段、隐藏、无假值 |
| 参数卡 | `EntryParamsCard` + 7 个子卡 | `setUnitPrice` / `setSocStart` / … | 分类切换、字段边界、双向同步 |
| 里程卡 | `EntryMileageCard` | `fetchOdometerBaseline` + `setOdometerKm` | 默认值、倒挂、折叠、大跨度确认 |
| 三行卡 | `EntryMetaCard` | `setOccurredAt` / `setPlace` / `setPayment` | 时间格式、地点清空、支付默认 |
| 备注与凭证 | `EntryNoteReceiptsCard` / `EntryReceiptGrid` | `setNote` / `addReceipt` / `removeReceipt` | 200 字、4 张、权限、预览 |
| 底部栏 | `EntryBottomBar` | `canSave` / `save` | 禁用、保存中、重复点击 |
| 保存闭环 | `ExpenseEntryController` | `createExpense` / `updateExpense` | 失效矩阵、失败保留、冲突 |
| 编辑模式 | `ExpenseEntryPage(args.edit)` | `fetchDraft` / `updateExpense` | 预填、标题、基线排除自身 |
| 路由 | `openExpenseEntry` | — | FAB / 详情入口、返回结果 |

---

## 16. 实施记录（v0.2）

### 16.1 实际落地的文件

```
lib/core/
├── domain/enums.dart                       # 新增 PaymentChannel
├── domain/vehicle.dart                     # 电池容量 / 油箱容量 / 默认油品
├── format/formatters.dart                  # parseYuanToCents / formatYuanInput / formatOdometerDelta / formatOccurredAtLabel
└── presentation/payment_style.dart         # 支付渠道文案与圆点色（详情页共用）

lib/features/expense_entry/
├── data/
│   ├── expense_entry_repository.dart
│   ├── mock_expense_entry_repository.dart  # 写回 MockLedgerRepository + 会话内凭证
│   └── receipt_picker.dart                 # image_picker 封装与异常
├── domain/
│   ├── expense_entry_detail.dart           # sealed 分类参数
│   ├── expense_entry_models.dart           # Args / Draft / Defaults / Baseline / Preset / Result
│   ├── expense_entry_math.dart
│   ├── expense_entry_validation.dart
│   ├── expense_entry_presenter.dart
│   └── providers.dart                      # controller + repository + picker
└── presentation/
    ├── expense_entry_page.dart
    ├── expense_entry_routes.dart
    ├── expense_entry_style.dart
    └── widgets/                            # header / vehicle card+sheet / category / amount / telemetry
                                            # params（7 类合并）/ mileage / meta+sheets / note+receipts / bottom
```

改造文件：

- `lib/app/tab_shell.dart`：FAB 打开记账页。
- `lib/features/expense_detail/presentation/expense_detail_page.dart`：底部「再记一笔 / 编辑此笔账单」打开记账页，编辑保存后失效详情。
- `lib/features/ledger/data/mock_ledger_repository.dart`：手动记录、按 id 覆盖、最新里程、按时间回溯基线。
- `lib/features/home/data/mock_home_repository.dart` 与 `home/domain/providers.dart`：`odometerResolver`，保存后车辆卡里程同步。
- `lib/features/expense_detail/domain/expense_detail_models.dart` / `expense_detail_presenter.dart`：`PaymentChannel` 迁到 core，支付样式复用。
- `pubspec.yaml`：新增 `image_picker`；iOS / Android 相机与相册权限。

### 16.2 与方案的差异

| 项 | 实际处理 |
| --- | --- |
| Widget 文件拆分 | 为控制文件数量，金额卡合并输入与快捷金额，7 个参数卡合并到 `entry_params_card.dart`，时间/地点/支付浮层合并到 `entry_meta_card.dart`，未改变模块边界 |
| 凭证 | 使用 `image_picker` 拍照 / 相册，保存时上传；Mock 用本地路径作为 `remoteId`，并在会话内保存凭证，编辑可读回 |
| 默认值 | Mock 返回固定单价 1.20 / 7.85 / 8.00 与车辆容量；接口接入后由服务端返回 |
| 里程基线 | Mock 按 24 个月回溯并排除自身；真实接口按 §8.2 实现 |
| 首次记录 | Mock 总会生成历史数据，UI 上的「首次记录」路径仅由领域逻辑覆盖，需接口联调后回归 |
| 校验反馈 | 已做字段内错误与 Toast 首错；自动滚动到首错字段未实现（P1） |
| OCR | 仍为占位 Toast，识别与确认浮层未实现 |
| 无障碍 | 关键按钮、分类胶囊、错误文案已有语义；真机 TalkBack / 1.3 倍字号尚未系统验收 |
| 深色 | 全部走 `AppPalette`，基础可用；正式深色稿核对未做 |

### 16.3 测试

- `test/expense_entry/expense_entry_domain_test.dart`：金额解析、推导公式、校验、默认参数、Draft 值相等。
- `test/expense_entry/mock_expense_entry_repository_test.dart`：默认值、基线、创建 / 编辑写回账单与车辆里程、凭证上传。
- `test/expense_entry/expense_entry_page_test.dart`：首屏、金额与预估、分类切换、里程倒挂、未保存关闭、保存返回、凭证添加、编辑预填。
- `test/widget_test.dart`：FAB 打开记账页、真实 Mock 保存后回到首页。
- `flutter analyze` 无问题；`flutter test` 210 项通过。

---

## 17. 变更记录

| 版本 | 日期 | 说明 |
| --- | --- | --- |
| v0.2 | 2026-11-15 | P0 实施：新增 `expense_entry` feature、Mock 仓库扩展、FAB / 详情入口、凭证选择、测试；补充实施记录与差异说明 |
| v0.1 | 2026-11-15 | 初稿：基于 Stitch「记账·全能开销录入页（全新浅色规范版）」设计页面结构、7 分类参数、金额主输入、里程基线、保存 / 编辑闭环、Mock 扩展与测试方案 |
