# 我的页技术方案 · 个人中心与车主服务

| 项目 | 内容 |
| --- | --- |
| 关联需求 | [我的页需求文档 v0.1](../requirements/profile.md) |
| 设计稿 | [Stitch · 我的·个人中心与车主服务](https://stitch.google.com/projects/9615374848161425677?node-id=6b44826af9d8481ca5d97af011401ef0) |
| 客户端 | Flutter 3.50.0 stable / Dart 3.14 |
| 平台 | Android（arm64 优先）、iOS |
| 文档版本 | v0.1（拟实施） |
| 状态 | 方案待评审；接口契约未定稿，等待后端确认 |

> 本文档基于**仓库当前实现**编写：首页、账单、单笔详情、月度报表、统计页已落地；我的 Tab 仍是 `AppTabShell` 中的 `_ComingSoonTab`，index = 3。所有新增目录、文件与重构均为拟实施内容，按 `feat/profile-page` 分支推进。
> 依赖现状：`material_ui`、`flutter_riverpod ^3.5.0`、`fl_chart ^1.3.1`、`intl ^0.20.3`、`pdf`、`printing`、`share_plus`、`path_provider`。本页**不新增第三方依赖**。

---

## 1. 目标与约束

### 1.1 技术目标

- 我的 Tab 首次进入 ≤ 1s 可交互；车库切换 ≤ 300ms，命中已加载快照 ≤ 100ms。
- 资料、车库、工具状态三个数据块**独立加载、独立失败**，任一失败不影响其余模块。
- 车库「本月能耗支出 / 笔数」与账单页同月同范围汇总一致；「累计记录」与账本生命周期统计一致。
- 快速连续切换车辆时，卡片只呈现最后一次选择，不出现旧车数据覆盖新车。
- 未实现能力（OCR / 云端 / 离线 / 退出）由数据层的**能力标记**驱动，UI 不写死伪造状态或数量。
- 复用现有设计 token、卡片、按钮、骨架、错误组件、格式化与 Mock 仓库；本页不引入第二套视觉规范。
- 页面滚动、车辆切换保持 60fps；设置区与工具箱不产生额外网络请求。

### 1.2 约束

- **不新增依赖**：头像使用渐变底 + 首字，不引入图片加载库；版本号使用常量；设置项 P0 只读，不做本地持久化。
- 金额全链路使用**整数分**（`int cents`）；千分位与小数格式化沿用 / 扩展 `intl` 封装。
- 不引入路由库：仍使用 `Navigator.push`；跨 Tab 跳转由 `appTabProvider` 负责；我的页不改动壳的路由结构。
- `AppTabShell` 的 `IndexedStack` 与懒加载机制保持不变：我的 Tab 首次点击才构建。
- 设计稿的 24–28px 卡片圆角按全站现状收敛为 16px；品牌统一「车小记」；手机号掩码由服务端返回。
- 接口未定稿：UI 只依赖 domain 模型；数据层可在 `MockProfileRepository` 与未来的 `HttpProfileRepository` 之间切换，页面与 provider 不改。
- CI 在 PR 阶段只跑 `flutter analyze` 与 `flutter test`，不构建 APK；合并 `main` 后打包。
- Mock 数据只覆盖最近 24 个月（与 `MockLedgerRepository` 一致）；「累计」统计在该窗口内计算。
- 无登录 / 会话模块：P0 不渲染退出登录；相关接口只保留未实现的 API 声明。

---

## 2. 现状与复用清单

| 现有能力 | 位置 | 本页用法 |
| --- | --- | --- |
| 色彩主题 | `lib/app/theme/app_colors.dart` → `AppPalette` / `AppColors` / `context.palette` | 全部颜色；动力色 `PowertrainVisual` |
| 间距 / 圆角 / 阴影 | `lib/app/theme/app_tokens.dart` → `AppTokens` / `context.tokens` | 页面边距、卡片、胶囊、底部留白 |
| 字体 | `lib/app/theme/app_typography.dart` | `headlineMd/Sm`、`bodyLg/Md/Sm`、`labelMd/Sm` |
| 卡片容器 | `lib/core/widgets/app_card.dart` → `AppCard` | 资料卡、车辆卡、工具卡、设置卡 |
| 骨架 / 错误 / 空态 | `lib/core/widgets/skeleton_box.dart`、`section_error.dart`、`empty_state.dart` | 模块级加载、失败与空态 |
| 顶栏毛玻璃 | `lib/core/widgets/blurred_header_delegate.dart` | 吸顶顶部栏 |
| 顶栏组件 | `lib/core/widgets/app_tab_header.dart` → `AppTabHeader` | 头像 + 品牌 + 铃铛；需新增 `avatarInitial` |
| 底部导航 + FAB | `lib/core/widgets/app_bottom_nav.dart` → `AppBottomNav` | 由 `AppTabShell` 统一持有，我的 Tab 高亮 |
| Tab 状态 | `lib/app/tab.dart` → `appTabProvider` | 跨 Tab 跳转与选中态 |
| 车辆 / 枚举 | `lib/core/domain/vehicle.dart`、`enums.dart` | `Vehicle`、`PowertrainType`、`MaintenanceStatus` |
| 动力语义色 / 图标 | `lib/core/presentation/category_style.dart` | 胶囊色点、车辆卡图标与徽标 |
| 格式化 | `lib/core/format/formatters.dart` | `formatYuanCompact`、`formatKmValue`、`formatOneDecimal` 等；追加一位小数金额与计数 |
| 车辆列表 / 选中态 | `lib/features/home/domain/providers.dart` → `vehiclesProvider`、`selectedVehicleIdProvider` | 车辆胶囊与资料卡计数；**只读车辆列表，不写回选中态** |
| 未读数 | `lib/features/home/domain/providers.dart` → `unreadCountProvider` | 顶栏铃铛红点 |
| 首页车辆 Mock | `lib/features/home/data/mock_home_repository.dart` | 车辆、保养周期、每公里能耗成本 |
| 账单 Mock | `lib/features/ledger/data/mock_ledger_repository.dart` | 本月能耗记录、生命周期记录数与首笔时间 |
| 账单查询 | `lib/features/ledger/domain/ledger_models.dart` → `LedgerQuery`、`LedgerMonthSummary` | 本月聚合与口径校验 |
| 月度报表 | `lib/features/report/presentation/monthly_report_page.dart` | 工具卡「账单导出与报表」直达 |
| 报表范围 | `lib/features/report/domain/report_models.dart` → `ReportScope` | 当前自然月 + 车库当前车辆（全部资产 → null） |
| 说明弹层样式 | `lib/features/ledger/presentation/ledger_page.dart` → `_showSortSheet` | 圆角 28、surface 底的底部弹层基准 |
| 主题模式 | `lib/features/home/domain/providers.dart` → `themeModeProvider` | 深色模式回归；本期不在我的页加入口 |
| Tab 壳 | `lib/app/tab_shell.dart` | index 3 由占位替换为 `ProfilePage` |

### 2.1 需要抽象的耦合点

| 问题 | 影响 | 处理（M0） |
| --- | --- | --- |
| `AppTabShell` index 3 是私有 `_ComingSoonTab` | 无法接入真实页面 | 替换为 `ProfilePage(scrollController: ...)`；保留懒加载集合 |
| `AppTabHeader` 的 `_Avatar` 私有且硬编码「林」 | 我的页需要账号头像；首页也无法复用 | 新增公共 `ProfileAvatar`，`AppTabHeader` 增加 `avatarInitial` 参数并默认 `'林'`，视觉不变 |
| `LedgerRepository` 没有生命周期统计 | 资料卡「累计记录 / 记账天数」需要全量口径 | 新增 `fetchLifetimeStats()`；Mock 直接聚合 24 个月，不新增网络调用 |
| 车库需要「车辆 + 保养 + 每公里能耗」 | 首页 `HomeDashboard` 与车库卡片语义不同，直接复用会带入 Hero / 构成耦合 | 数据层依赖 `HomeRepository` 读取车辆与保养，组装 `GarageData`；展示层只认 `GarageData` |
| `vehiclesProvider` / `selectedVehicleIdProvider` 位于 home feature | 我的页跨 feature 读取 | 本期只读复用；后续与统计页一起把车辆列表迁到 `core`（非本页阻塞项） |
| 报表入口路由在账单页内联 | 我的页需要同样的入口 | 新增 `openMonthlyReport(context, scope)`（`features/report/presentation/report_routes.dart`）；账单页可选改为调用，行为不变 |
| 每个页面各写一份 `_toast` | SnackBar 位置与样式重复 | 新增 `core/presentation/toast.dart` → `showAppToast`；我的页使用，其他页面可逐步收敛 |
| 我的页设置齿轮需要滚动定位 | 资料卡在滚动视图内 | `ProfilePage` 使用 `ConsumerStatefulWidget` + `GlobalKey`，`Scrollable.ensureVisible` |
| 设置项 P0 只读 | 未来需要持久化偏好 | 模型与 provider 先按可编辑设计；P0 数据层返回默认值，不改状态；P1 再接存储 / 后端 |

---

## 3. 结构调整（M0）

```
lib/
├── app/
│   └── tab_shell.dart                       # 修改：index 3 → ProfilePage
├── core/
│   ├── domain/
│   │   └── app_info.dart                    # 新增：应用名 / 版本号常量
│   ├── format/
│   │   └── formatters.dart                  # 追加：一位小数金额、计数、能耗量
│   ├── presentation/
│   │   └── toast.dart                       # 新增：统一 SnackBar（位置 / 时长 / 样式）
│   └── widgets/
│       ├── app_tab_header.dart              # 修改：+ avatarInitial；_Avatar → ProfileAvatar
│       └── profile_avatar.dart              # 新增：渐变底 + 首字 + 状态点 + 可选尺寸
├── features/
│   ├── ledger/
│   │   ├── data/
│   │   │   ├── ledger_repository.dart       # 修改：+ fetchLifetimeStats()
│   │   │   └── mock_ledger_repository.dart  # 修改：实现生命周期统计 + 缓存
│   │   └── domain/
│   │       └── ledger_models.dart           # 修改：+ LedgerLifetimeStats
│   ├── report/
│   │   └── presentation/
│   │       └── report_routes.dart           # 新增：openMonthlyReport(context, scope)
│   └── profile/
│       ├── data/
│       │   ├── profile_repository.dart
│       │   ├── profile_api.dart
│       │   └── mock_profile_repository.dart
│       ├── domain/
│       │   ├── profile_models.dart
│       │   ├── garage_aggregation.dart
│       │   ├── profile_presenter.dart
│       │   └── providers.dart
│       └── presentation/
│           ├── profile_page.dart
│           ├── profile_style.dart
│           └── widgets/
│               ├── profile_header.dart
│               ├── profile_summary_card.dart
│               ├── garage_section.dart
│               ├── garage_vehicle_card.dart
│               ├── owner_toolbox.dart
│               ├── settings_list.dart
│               ├── account_footer.dart
│               ├── privacy_sheet.dart
│               └── about_sheet.dart
```

关键点：

- **懒加载不变**：`AppTabShell._visitedTabs` 已覆盖 `AppTab.profile`；只需把占位换成 `ProfilePage`，不要为了「预热」而在启动时构建。
- **`ProfileAvatar`**：签名 `ProfileAvatar({required String initial, double size = 40, bool showStatusDot = true})`；渐变、描边、阴影参数从现有 `_Avatar` 迁移，保证首页像素不变。首页沿用默认 40，我的页顶栏传 36、资料卡传 56。
- **`AppTabHeader`**：只增参数，不改布局；`showGreeting: false` 时标题即为品牌名，我的页直接复用。
- **`openMonthlyReport`**：封装 `Navigator.of(context).push(MaterialPageRoute(...))`；返回 `Future<void>`，调用方不等待结果。
- **`showAppToast`**：统一 `SnackBarBehavior.floating`、`margin: EdgeInsets.fromLTRB(16, 0, 16, 96)`、2s；避免被我页底部导航遮挡。
- **不新增路由文件**：车辆管理 / 添加 / 登录页尚未实现，本期只保留入口 Toast，避免悬空路由常量。
- **`profile_style.dart`**：集中间距、图标尺寸、工具卡定义（key / 标题 / 副标题 / 图标 / 语义色）与胶囊最大宽度，避免 Widget 内散落魔法数字。

---

## 4. 数据流

```
ProfilePage
├── ProfileHeader ──────────────► profileOverviewProvider ─┐
├── ProfileSummaryCard ─────────► profileOverviewProvider  │
│   └── vehiclesProvider ─────────────────────────────────┤
├── GarageSection ──────────────► vehiclesProvider         │
│   ├── profileGarageVehicleIdProvider (null = 全部资产)    │
│   └── profileGarageProvider(vehicleId) ──────────────────┤
├── OwnerToolbox ───────────────► profileServicesProvider ─┤
├── SettingsList ───────────────► profilePreferencesProvider
└── AccountFooter ──────────────► profileOverviewProvider  │
                                                            ▼
                                             ProfileRepository
                                        ┌───────────┴────────────┐
                                        ▼                        ▼
                                HomeRepository            LedgerRepository
                             (车辆 / 保养 / 每公里成本)   (本月记录 / 生命周期统计)
```

- 页面不直接调用仓库；所有数据经 provider 暴露 `AsyncValue`。
- `ProfileRepository` 的实现负责跨仓库组装；页面只消费 `ProfileOverview`、`GarageData`、`ProfileServices`、`ProfilePreferences`。
- 下拉刷新：`invalidate(profileOverviewProvider)`、`invalidate(vehiclesProvider)`、`invalidate(profileGarageProvider)`（族失效全部实例）、`invalidate(profileServicesProvider)`；随后 `await` 当前车库的 future 以驱动 `RefreshIndicator`。
- 车辆切换：只改 `profileGarageVehicleIdProvider`，页面 watch 新的 family；不 invalidate 资料与工具。
- 报表入口：直接读取当前 `GarageData` 的 `vehicleId` 与当前自然月构造 `ReportScope`，不经过 provider。

---

## 5. 数据模型

### 5.1 基础类型

```dart
enum UnitSystem { metric, imperial }

enum CurrencyCode { cny }

enum SyncState { local, syncing, synced, failed }

enum GarageTipKind { charging, fuel, mixed, energySummary, empty }
```

- `MaintenanceStatus` 继续使用 `core/domain/enums.dart` 的 `normal / warning / overdue`；车库额外需要「未设置」，用 `GarageMaintenance.enabled == false` 表达，不扩展全局枚举。
- `PowertrainType` 沿用 core；`powertrain` 在全部资产快照中为 `null`。

### 5.2 账号与资料

```dart
@immutable
class ProfileUser {
  const ProfileUser({
    required this.id,
    required this.nickname,
    required this.verifiedOwner,
    required this.tagline,
    this.avatarUrl,
    this.phoneMasked,
  });

  final String id;
  final String nickname;

  /// 预留：P1 头像上传后使用；P0 为 null，UI 走首字头像。
  final String? avatarUrl;
  final bool verifiedOwner;
  final String tagline;

  /// 服务端掩码后的手机号，客户端不自行拼接完整号码。
  final String? phoneMasked;
}

@immutable
class ProfileStats {
  const ProfileStats({
    required this.accountDays,
    required this.recordCount,
    this.firstRecordAt,
  });

  final int accountDays;
  final int recordCount;
  final DateTime? firstRecordAt;
}

@immutable
class ProfileOverview {
  const ProfileOverview({
    required this.user,
    required this.stats,
    this.dataUpdatedAt,
  });

  final ProfileUser user;
  final ProfileStats stats;
  final DateTime? dataUpdatedAt;
}
```

约定：

- 页面「关联车辆」不放进 `ProfileStats`，直接取 `vehiclesProvider` 的长度，避免车辆列表与计数来自两个快照。
- `accountDays` 由服务端返回；Mock 由 `firstRecordAt` 计算。客户端提供纯函数用于 Mock 与一致性校验。
- `GarageVehicle.shortName` 由数据层用 `shortNameFor(vehicle.name)` 生成（§6.8），不复用 `LedgerRecord.vehicleShortName`，避免账单 Mock 的简称与车辆列表不一致。
- `GarageVehicle.energyCostPerKmCents = (HomeSummary.energyCostPerKm * 100).round()`；为 0 或缺失时为 `null`，展示层回退「本月已记 n 笔」。

### 5.3 车库

```dart
@immutable
class GarageVehicle {
  const GarageVehicle({
    required this.id,
    required this.name,
    required this.shortName,
    required this.plate,
    required this.powertrain,
    required this.powertrainLabel,
    required this.odometerKm,
    this.energyCostPerKmCents,
  });

  final String id;
  final String name;
  final String shortName;
  final String plate;
  final PowertrainType powertrain;
  final String powertrainLabel;
  final int odometerKm;

  /// 历史平均每公里能源成本（分），用于车辆副标题；null 时回退「本月已记 n 笔」。
  final int? energyCostPerKmCents;
}

@immutable
class MonthEnergy {
  const MonthEnergy({
    required this.amountCents,
    required this.count,
    this.kwh,
    this.liters,
  });

  final int amountCents;
  final int count;

  /// 单能源或可比较时返回；全部资产混合能源时为 null。
  final double? kwh;
  final double? liters;
}

@immutable
class GarageMaintenance {
  const GarageMaintenance({
    required this.enabled,
    required this.status,
    this.vehicleId,
    this.vehicleName,
    this.remainingKm,
    this.remainingDays,
  });

  final bool enabled;
  final MaintenanceStatus status;
  final String? vehicleId;
  final String? vehicleName;
  final int? remainingKm;
  final int? remainingDays;

  bool get isOverdue => enabled && (remainingKm ?? 0) <= 0;
}

@immutable
class GarageTip {
  const GarageTip({required this.kind, required this.text});

  final GarageTipKind kind;
  final String text;
}

@immutable
class GarageSnapshot {
  const GarageSnapshot({
    required this.badge,
    required this.plateText,
    required this.title,
    required this.subtitle,
    required this.odometerKm,
    required this.monthEnergy,
    required this.maintenance,
    required this.tip,
    this.vehicleId,
    this.powertrain,
  });

  /// null = 全部资产。
  final String? vehicleId;
  final String badge;
  final String plateText;
  final String title;
  final String subtitle;
  final PowertrainType? powertrain;
  final int odometerKm;
  final MonthEnergy monthEnergy;
  final GarageMaintenance maintenance;
  final GarageTip tip;
}

@immutable
class GarageData {
  const GarageData({
    required this.vehicles,
    required this.snapshot,
    this.dataUpdatedAt,
  });

  final List<GarageVehicle> vehicles;
  final GarageSnapshot snapshot;
  final DateTime? dataUpdatedAt;
}
```

### 5.4 工具与偏好

```dart
@immutable
class ProfileServiceStatus {
  const ProfileServiceStatus({
    required this.available,
    this.count,
    this.state,
    this.lastSyncAt,
    this.pendingCount,
  });

  final bool available;
  final int? count;
  final SyncState? state;
  final DateTime? lastSyncAt;
  final int? pendingCount;
}

@immutable
class ProfileServices {
  const ProfileServices({
    required this.report,
    required this.voucher,
    required this.sync,
    required this.offline,
  });

  final ProfileServiceStatus report;
  final ProfileServiceStatus voucher;
  final ProfileServiceStatus sync;
  final ProfileServiceStatus offline;
}

@immutable
class ProfilePreferences {
  const ProfilePreferences({
    this.unitSystem = UnitSystem.metric,
    this.currency = CurrencyCode.cny,
    this.notificationsEnabled = false,
    this.maskSensitive = false,
  });

  final UnitSystem unitSystem;
  final CurrencyCode currency;
  final bool notificationsEnabled;
  final bool maskSensitive;
}
```

- P0 的偏好是只读快照；`updatePreferences` 只在 P1 实现，P0 不调用。
- `ProfileServiceStatus.available == false` 时 UI 不读取 `count / lastSyncAt / pendingCount`，即使后端误传也不展示。

### 5.5 生命周期统计（ledger 扩展）

```dart
@immutable
class LedgerLifetimeStats {
  const LedgerLifetimeStats({
    required this.recordCount,
    this.firstRecordAt,
  });

  final int recordCount;
  final DateTime? firstRecordAt;
}
```

- 放在 `ledger_models.dart`，与 `LedgerMonthSummary` 同层；后续统计页 / 首页若需要「累计」可直接复用。
- 口径：所有车辆、最近 24 个月（Mock 窗口）、未删除记录。

---

## 6. 聚合口径与纯函数

所有函数放在 `features/profile/domain/garage_aggregation.dart`，接收显式参数与 `now`，便于单测；不读取全局状态。

### 6.1 记账天数

```dart
int computeAccountDays(DateTime? firstRecordAt, DateTime now) {
  if (firstRecordAt == null) return 0;
  final first = DateTime(
    firstRecordAt.year,
    firstRecordAt.month,
    firstRecordAt.day,
  );
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(first).inDays + 1;
  return days < 0 ? 0 : days;
}
```

- 负数（时钟回拨 / 未来记录）一律归零。
- 展示层 `0` → 「— 天」，与「无记录」区分。

### 6.2 本月能耗聚合

```dart
MonthEnergy aggregateMonthEnergy(
  Iterable<LedgerRecord> records, {
  required DateTime month,
  required DateTime now,
}) {
  final start = DateTime(month.year, month.month);
  final end = DateTime(month.year, month.month + 1);
  var amount = 0;
  var count = 0;
  var kwh = 0.0;
  var liters = 0.0;
  var hasKwh = false;
  var hasLiters = false;

  for (final record in records) {
    if (record.category != ExpenseCategory.charging &&
        record.category != ExpenseCategory.fuel) {
      continue;
    }
    if (record.occurredAt.isBefore(start) ||
        !record.occurredAt.isBefore(end) ||
        record.occurredAt.isAfter(now)) {
      continue;
    }
    amount += record.amountCents;
    count++;
    final recordKwh = record.metrics.kwh;
    final recordLiters = record.metrics.liters;
    if (recordKwh != null && recordKwh > 0) {
      kwh += recordKwh;
      hasKwh = true;
    }
    if (recordLiters != null && recordLiters > 0) {
      liters += recordLiters;
      hasLiters = true;
    }
  }

  return MonthEnergy(
    amountCents: amount,
    count: count,
    kwh: hasKwh ? kwh : null,
    liters: hasLiters ? liters : null,
  );
}
```

- 退款记录金额为负，按原值计入支出总额；数量仍按正值累加。
- 当前月只统计到 `now`，避免 Mock 生成未来时刻。

### 6.3 全部资产快照

```dart
GarageSnapshot buildGarageSnapshot({
  required String? vehicleId,          // null = 全部资产
  required List<GarageVehicle> vehicles,
  required List<LedgerRecord> monthRecords,
  required Map<String, Maintenance> maintenanceByVehicle,
  required DateTime now,
}) { ... }
```

规则：

1. 单辆车：
   - `badge = vehicle.powertrainLabel`，`plateText = vehicle.plate`，`title = vehicle.name`；
   - `subtitle`：`energyCostPerKmCents != null` → `累计能耗 ¥{two decimals}/km`，否则 `本月已记 {n} 笔`；
   - `odometerKm` 取车辆值；`monthEnergy` 由该车本月能耗记录聚合；
   - `maintenance` 由 `maintenanceByVehicle[vehicleId]` 转为 `GarageMaintenance`。
2. 全部资产：
   - `badge = '全部资产'`，`plateText = '{n} 辆在役'`，`title = '我的全部车辆'`；
   - `subtitle = powertrainComposition(vehicles)`；
   - `odometerKm = sum`；
   - `monthEnergy`：金额与笔数求和；若所有车辆同为一种能源则保留 kWh / L，否则两者置 `null`；
   - `maintenance = pickMostUrgent(maintenanceByVehicle, vehicles)`；
   - `tip = buildAllAssetsTip(monthEnergy)`。
3. 空车辆：返回空态快照（`title = '我的全部车辆'`、`plateText = '0 辆在役'`、金额 0、`maintenance.enabled = false`、`tip.kind = empty`）；页面改用 `EmptyState`，不渲染指标卡。

### 6.4 动力构成

```dart
String powertrainComposition(List<GarageVehicle> vehicles) {
  final ev = vehicles.where((v) => v.powertrain == PowertrainType.ev).length;
  final hybrid = vehicles.where((v) =>
      v.powertrain == PowertrainType.hev || v.powertrain == PowertrainType.phev).length;
  final ice = vehicles.where((v) => v.powertrain == PowertrainType.ice).length;
  return [
    if (ev > 0) '纯电 $ev',
    if (hybrid > 0) '混动 $hybrid',
    if (ice > 0) '燃油 $ice',
  ].join(' · ');
}
```

- 混动合并为「混动」，与设计稿「纯电 · 混动 · 燃油」一致；不区分 HEV / PHEV 的计数文案。
- 空列表返回「暂无车辆」。

### 6.5 保养紧迫度

```dart
GarageMaintenance pickMostUrgent(
  Map<String, Maintenance> maintenanceByVehicle,
  List<GarageVehicle> vehicles,
) {
  final candidates = <({GarageVehicle vehicle, Maintenance maintenance})>[
    for (final vehicle in vehicles)
      if (maintenanceByVehicle[vehicle.id] case final m? when m.enabled)
        (vehicle: vehicle, maintenance: m),
  ];
  if (candidates.isEmpty) {
    return const GarageMaintenance(
      enabled: false,
      status: MaintenanceStatus.normal,
    );
  }
  final positive = candidates.where((c) => c.maintenance.remainingKm > 0);
  final pool = positive.isNotEmpty ? positive : candidates;
  final picked = pool.reduce(
    (a, b) => a.maintenance.remainingKm <= b.maintenance.remainingKm ? a : b,
  );
  final m = picked.maintenance;
  final status = m.remainingKm <= 0
      ? MaintenanceStatus.overdue
      : m.isWarning
          ? MaintenanceStatus.warning
          : MaintenanceStatus.normal;
  return GarageMaintenance(
    enabled: true,
    status: status,
    vehicleId: picked.vehicle.id,
    vehicleName: picked.vehicle.shortName,
    remainingKm: m.remainingKm,
    remainingDays: m.remainingDays,
  );
}
```

- 优先未超期车辆中剩余最少的一辆；若全部超期，取剩余（负数）最小的一辆。
- `Maintenance.isWarning` 已包含 `progressPercent > 80`，直接复用，不重复定义阈值。

### 6.6 提示条

```dart
GarageTip buildGarageTip({
  required MonthEnergy energy,
  required List<LedgerRecord> monthEnergyRecords,
  required PowertrainType? powertrain,
}) { ... }
```

- 单能源：
  - 充电：`本月充电 {n} 次`；若有效电量 > 0 且金额 > 0，追加 `· 平均 ¥{amount/qty}/kWh`。
  - 加油：`本月加油 {n} 次`；追加 `· 平均 ¥{amount/qty}/L`。
- 插混（混合能源）：`本月充电 {n} 次 · 加油 {m} 次`；若两类都有有效单价，追加 `· 电 ¥x/kWh · 油 ¥y/L`（超出单行省略）。
- 全部资产：`本月共 {n} 笔能耗记录 · 合计 ¥{amount}`。
- 无记录：`本月暂无能耗记录`，`kind = empty`。
- 平均单价：分子只累加「金额 > 0 且数量 > 0」的记录，分母为对应数量之和；退款不参与平均单价，但计入支出总额。
- 计算结果与 `MonthEnergy` 同一次记录遍历，避免二次请求。

### 6.7 展示推导（presenter）

`profile_presenter.dart` 输出纯字符串，避免 Widget 内散落格式化：

```dart
class ProfileSummaryView {
  final String initial;
  final String nickname;
  final String tagline;
  final bool verifiedOwner;
  final String accountDaysText;   // '328 天' / '— 天'
  final String recordCountText;   // '142 笔'
  final String vehicleCountText;  // '3 辆'
  final String? phoneText;        // '138 **** 9208'
}

class GarageCardView {
  final String badge;
  final String plateText;
  final String title;
  final String subtitle;
  final String odometerText;
  final String energyAmountText;  // '¥312.4'
  final String energySubText;     // '184 kWh · 6 笔'
  final String maintenanceValue;  // '1,574' / '已超期 120'
  final String maintenanceUnit;   // 'km 后' / 'km' / '未设置保养周期'
  final MaintenanceStatus maintenanceStatus;
  final String tipText;
  final GarageTipKind tipKind;
}
```

格式化规则见需求 §7.3；新增函数：

```dart
String formatYuanOneDecimal(int cents) =>
    '¥${NumberFormat('#,##0.0').format(cents / 100)}';

String formatCount(int value) => NumberFormat('#,##0').format(value);

String formatEnergyQuantity(double value, {required String unit}) {
  final text = unit == 'L'
      ? value.toStringAsFixed(2)
      : value.toStringAsFixed(1);
  return '${trimTrailingZero(text)} $unit';
}
```

- `trimTrailingZero` 只去掉 `.0` / `.00`，保留 `184.5`；不得去掉整数位的 0。
- 金额展示一律通过 formatter，不在 Widget 里 `toStringAsFixed`。

### 6.8 车辆简称

```dart
const _brandPrefixes = <String>[
  '比亚迪', '丰田', '宝马', '奔驰', '奥迪', '大众', '本田',
  '吉利', '理想', '小鹏', '蔚来', '特斯拉', '长安', '奇瑞',
];

String shortNameFor(String name) {
  for (final brand in _brandPrefixes) {
    final prefix = '$brand ';
    if (name.startsWith(prefix)) {
      return name.substring(prefix.length);
    }
  }
  return name;
}
```

- 示例：「比亚迪 汉 EV」→「汉 EV」；「丰田 凯美瑞 双擎」→「凯美瑞 双擎」；「宝马 3系 325Li」→「3系 325Li」。
- 无品牌空格的名字保留原名：「宋PLUS DM-i」→「宋PLUS DM-i」，不按第一个空格硬切。
- 未收录品牌保留全名；胶囊最大宽度 160，超出由 UI 省略，不截断数据。
- 单测覆盖上述四个示例与空字符串。

---

## 7. 数据层

### 7.1 仓库接口

```dart
abstract class ProfileRepository {
  Future<ProfileOverview> fetchOverview();

  Future<GarageData> fetchGarage({String? vehicleId, DateTime? month});

  Future<ProfileServices> fetchServices();

  Future<ProfilePreferences> fetchPreferences();

  /// P1：设置保存；P0 不调用。
  Future<ProfilePreferences> updatePreferences(ProfilePreferences preferences);

  /// P1：退出登录；P0 不调用。
  Future<void> logout();
}
```

### 7.2 接口声明

```dart
/// 我的页接口契约（暂不实现）。
abstract class ProfileApi {
  Future<Map<String, dynamic>> getOverview({required String timezone});

  Future<Map<String, dynamic>> getGarage({
    required String vehicleId,
    required String month,
    required String timezone,
  });

  Future<Map<String, dynamic>> getServices();

  Future<Map<String, dynamic>> getPreferences();

  Future<Map<String, dynamic>> updatePreferences(Map<String, dynamic> body);

  Future<void> logout();
}

/// 过期响应：UI 静默忽略。
class StaleProfileResponse implements Exception {
  const StaleProfileResponse();
}
```

### 7.3 Mock 实现

`MockProfileRepository` 注入现有仓库，保证与首页 / 账单同源：

```dart
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => MockProfileRepository(
    home: ref.watch(homeRepositoryProvider),
    ledger: ref.watch(ledgerRepositoryProvider),
  ),
);
```

- **不要把 `MockLedgerRepository` 重新 new 一份**：账本的删除 / 缓存状态在 provider 实例上，另建实例会导致车库金额与账单页不一致。
- `fetchOverview`：
  - 用户固定为 `林漪 / 认证车主 / 车小记 · 驱动每公里透明 / 138 **** 9208`；
  - `lifetime = await ledger.fetchLifetimeStats()`；
  - `accountDays = computeAccountDays(lifetime.firstRecordAt, now)`；
  - `recordCount = lifetime.recordCount`。
- `fetchGarage`：
  1. `vehicles = await home.fetchVehicles()`；
  2. 逐车 `home.fetchDashboard(id)`（`Future.wait`）取保养与 `energyCostPerKm`；
  3. `records = await ledger.fetchRecords(LedgerQuery(month: 当前月, vehicleId: vehicleId), limit: 500)`；
  4. 若 `hasMore == true`（极端月份）继续按 cursor 拉取，合并后再聚合，避免金额缺失；
  5. 调用 `buildGarageSnapshot`，组装 `GarageData`。
- `fetchServices`：`report.available = true`；`voucher / sync / offline.available = false`；`sync.state = SyncState.local`；其余字段为 null。
- `fetchPreferences`：返回默认 `metric / cny / false / false`。
- `updatePreferences` / `logout`：抛 `UnimplementedError`，P0 不调用；P1 实现后替换。
- Mock 延迟统一 120–160ms，与现有仓库一致；`fetchLifetimeStats` 不额外延迟，避免首屏被两次延迟叠加。

### 7.4 接口契约（后端实现依据）

完整 JSON 见 [需求 §8](../requirements/profile.md#8-接口契约草案待后端确认)。客户端约束：

- `GET /profile/overview` 返回账号资料与累计统计；`stats.accountDays` 由服务端按首笔记录计算，客户端不重新计算（仅 Mock 使用纯函数）。
- `GET /profile/garage` 同时返回车辆列表与当前范围快照；`vehicleId=all` 表示全部资产。
- `snapshot.vehicleId == null` 表示全部资产；`monthEnergy.kwh / liters` 混合能源时必须为 `null`。
- `maintenance.status` 与 core 枚举对齐；`none` 表示未设置，`remainingKm` 必须为 `null`。
- `tip.text` 由服务端返回最终文案；客户端只负责换行与省略，不在端上拼接业务文案（Mock 由纯函数生成，便于测试）。
- 工具状态：`available == false` 时 UI 降级为「即将上线 / 本地数据」，不展示 `count`。
- 错误码：`PROFILE_NOT_FOUND`、`VEHICLE_NOT_FOUND`、`SERVICE_UNAVAILABLE`、`PREFERENCE_INVALID`、`SESSION_EXPIRED`、`RATE_LIMITED`，映射见需求 §8。

### 7.5 竞态与缓存

| 场景 | 处理 |
| --- | --- |
| 快速切换车辆 | 每个 `vehicleId` 是独立 family；页面只 watch 当前 key，旧 key 的结果不会覆盖新 key |
| 同一车辆重复刷新 | provider 保留最新 future；旧 future 完成不触发 UI 更新 |
| 下拉刷新 | `invalidate(profileGarageProvider)` 失效全部实例；当前卡立即进入 refreshing 状态 |
| 刷新失败但有旧值 | 保留旧值 + `showAppToast('刷新失败')`；不把整卡切成错误态 |
| 首屏无缓存失败 | 对应模块 `SectionError` + 重试 |
| 车辆被删除 | 当前 key 请求得到 `VEHICLE_NOT_FOUND` → 选中回到 `null` + Toast；再 invalidate 车辆与车库 |
| 数据时效 | `dataUpdatedAt` 仅用于「数据更新于」提示；不与本地时钟比较判定过期 |

- 不引入本地数据库 / 磁盘缓存：Mock 阶段内存即可；P1 云端同步时再评估持久化。
- 页面被 `IndexedStack` 保活，provider 在页面挂载期间保持；切走 Tab 不主动 refetch，回到页面沿用缓存并可由用户下拉刷新。

---

## 8. 状态管理

### 8.1 Provider 设计

```dart
final profileRepositoryProvider = Provider<ProfileRepository>((ref) => ...);

final profileOverviewProvider =
    FutureProvider.autoDispose<ProfileOverview>((ref) {
  return ref.watch(profileRepositoryProvider).fetchOverview();
});

/// 车库当前范围：null = 全部资产。
final profileGarageVehicleIdProvider =
    NotifierProvider<ProfileGarageVehicleIdNotifier, String?>(
  ProfileGarageVehicleIdNotifier.new,
);

final profileGarageProvider =
    FutureProvider.autoDispose.family<GarageData, String?>((ref, vehicleId) {
  return ref.watch(profileRepositoryProvider).fetchGarage(vehicleId: vehicleId);
});

final profileServicesProvider =
    FutureProvider.autoDispose<ProfileServices>((ref) {
  return ref.watch(profileRepositoryProvider).fetchServices();
});

final profilePreferencesProvider =
    FutureProvider.autoDispose<ProfilePreferences>((ref) {
  return ref.watch(profileRepositoryProvider).fetchPreferences();
});
```

- `ProfileGarageVehicleIdNotifier`：`build() => null`；`select(String? id)` 相同值直接 return；车辆删除时 `select(null)`。
- 不需要 `selectedVehicleIdProvider` 的联动；我的页选择是**独立状态**，不写回首页。
- `profileGarageProvider` 的 key 为可空 `String?`；Riverpod family 支持 nullable 参数。

### 8.2 失效矩阵

| 事件 | 失效 |
| --- | --- |
| 下拉刷新 | `profileOverviewProvider`、`vehiclesProvider`、`profileGarageProvider`（全部）、`profileServicesProvider` |
| 切换车辆 | 无（watch 新 family） |
| 记账成功 / 删除记录（P1） | `profileOverviewProvider`、`profileGarageProvider`（全部） |
| 车辆增删改（P1） | `vehiclesProvider`、`profileGarageProvider`（全部）、`profileOverviewProvider` |
| 设置保存（P1） | `profilePreferencesProvider` |
| 登录 / 登出（P1） | `profileOverviewProvider`、`vehiclesProvider`、`profileGarageProvider`、`profileServicesProvider`、`profilePreferencesProvider` |

### 8.3 状态展示

| 数据 | 加载 | 失败 | 空 |
| --- | --- | --- | --- |
| 资料 | 头像圆 + 两行文字 + 三个数字骨架 | 卡片内 `SectionError('资料加载失败')` + 重试；头像「?」 | 不适用 |
| 车辆列表 | 胶囊骨架 4 个 + 车辆卡骨架 | 车库 `SectionError('车辆加载失败')` + 重试 | `EmptyState('还没有添加车辆')` + 添加按钮 |
| 车库快照 | 当前卡指标骨架；胶囊保持可切换 | 卡片顶部错误条 + 重试；保留车名 / 车牌 | 金额 0、提示「本月暂无能耗记录」 |
| 工具状态 | 页脚骨架 | 报表保持可用；其余按不可用展示，不报错 | — |
| 偏好 | 右侧值骨架 | 显示默认「公制 · CNY」，不阻塞 | — |

---

## 9. UI 实现

### 9.1 页面骨架

```dart
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key, required this.scrollController});

  final ScrollController scrollController;
  ...
}
```

- `ConsumerStatefulWidget` 仅为持有 `_settingsKey`；其他状态交给 provider。
- `CustomScrollView`（`key: Key('profile-scroll')`）+ `SliverPersistentHeader(pinned: true, delegate: BlurredHeaderDelegate(height: tokens.headerHeight, child: ProfileHeader()))`。
- `SliverPadding` 使用 `pagePadding`，底部 `contentBottomPadding + bottomInset`。
- 子项顺序：`ProfileSummaryCard` → 20 → `GarageSection` → 20 → `OwnerToolbox` → 20 → `SettingsList` → 20 → `AccountFooter`。
- 外层 `Center + ConstrainedBox(maxWidth: 448)`、`SafeArea(bottom: false)`、`RefreshIndicator`，与首页 / 统计页一致。
- 设置齿轮滚动：

```dart
void _scrollToSettings() {
  final target = _settingsKey.currentContext;
  if (target == null) return;
  Scrollable.ensureVisible(
    target,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOutCubic,
  );
}
```

### 9.2 顶部栏 `ProfileHeader`

- `ConsumerWidget`，watch `profileOverviewProvider` 与 `unreadCountProvider`。
- 复用 `AppTabHeader(showGreeting: false, title: '车小记', avatarInitial: ..., trailing: _Bell())`；头像 `ProfileAvatar(size: 36)`。
- `avatarInitial`：昵称首字符；loading 时为 `'车'`（中性），失败 `'?'`。
- 铃铛：36×36 圆形，`surface` 底 + `outlineVariant` 描边；未读点 6px `secondary`；点击 `showAppToast(context, '消息中心待接入')`。
- 顶部栏整体 `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.15)`，避免品牌名被系统字号撑破。

### 9.3 资料卡 `ProfileSummaryCard`

- 结构：`AppCard(padding: EdgeInsets.all(20))` → 顶部行 → 分隔线 → 三列统计。
- 装饰光晕：`Positioned` 渐变圆 + `blur`，`IgnorePointer`；深色下降低透明度，不参与语义树。
- 头像：`ProfileAvatar(initial: view.initial, size: 56, ringColor: primary.withValues(alpha: 0.2))`。
- 认证标签：`primary` 12% 底 + `primaryText` 文字，`labelSm`。
- 齿轮：36×36 `surfaceContainer` 圆角 12，`Icons.settings_rounded`；点击回调由页面传入。
- 三列统计：`Row` + `Expanded` + 1px 分隔线（高度 24）；数值 `FittedBox(scaleDown)` 包裹，单位与标签上下排列。
- 语义：整卡 `Semantics(label: ..., container: true)`，子节点 `excludeSemantics`，避免重复朗读。
- 加载 / 失败按 §8.3。

### 9.4 车库区 `GarageSection`

- watch `vehiclesProvider`、`profileGarageVehicleIdProvider`、`profileGarageProvider(selectedId)`。
- 标题行：强调条（4×16，`primary`）+ 标题 + 右侧「管理爱车 >」。
- 胶囊条：
  - `SizedBox(height: 34)` + 横向 `ListView.separated`，`padding: EdgeInsets.zero`，使用默认 physics；每项外层补 5px 透明上下内边距，保证点击区域 ≥ 44；
  - 第一项「全部资产」+ 数量徽标；
  - 每项 `_GaragePill`：动力色点 + 简称；选中 `onSurface` 底 / `surface` 文字，未选 `surface` 底 / `outline` 文字 / `outlineVariant` 描边；
  - 点击 `ref.read(profileGarageVehicleIdProvider.notifier).select(id)`；
  - `Key('garage-pill-all')` / `Key('garage-pill-<id>')` 供测试。
- 车辆卡：`AppCard(padding: EdgeInsets.all(20))`，背景光晕，`AnimatedSwitcher(duration: 120ms)` 包裹内容；切换时 `ValueKey(selectedId ?? 'all')`。
- 指标行：`Row` + 三个 `Expanded` 小格（`surfaceContainer.withValues(alpha: 0.6)`、圆角 8、内边距 10）；不换行。
- 提示条：顶部虚线分隔（`border` 用 `outlineVariant` 60%，`dash` 可用 `CustomPainter` 或直接 1px 实线，P0 采用实线以降低复杂度）；左侧 16px 图标 + 文案单行省略；右侧「+ 添加新车」胶囊按钮。
- 空 / 错误按 §8.3；无车辆时用 `EmptyState`，不渲染快照卡。
- 管理 / 添加：`showAppToast`，不导航。

### 9.5 车辆卡 `GarageVehicleCard`

- 入参 `GarageCardView` + `GarageSnapshot`（颜色 / 图标需要原始枚举）。
- 徽标颜色：`powertrain?.badgeTextColor(palette)` + `powertrain?.softColor`；全部资产用 `primaryText` + `primary` 12%。
- 车牌：`surfaceContainer` 底、`labelMd`、字距 0.5；全部资产显示 `plateText`（如「4 辆在役」）。
- 动力图标：`AppColors` 对应色；`Icons.garage_rounded` 用于全部资产。
- 指标：
  - 里程 `formatKmValue`，单位「公里」；副文可在全部资产时省略。
  - 能耗金额 `formatYuanOneDecimal`，主色；副文按 §6.6 / 需求 §7.3 组合。
  - 保养：按 `maintenanceStatus` 取色；`isOverdue` 时显示「已超期 {abs}」；`enabled == false` 显示「— / 未设置保养周期」。
- 提示条图标：`charging → bolt_rounded`、`fuel → local_gas_station_rounded`、`mixed → ev_station_rounded`、`energySummary → verified_rounded`、`empty → info_outline_rounded`；`empty` 用 `outline`，异常态用 `error`。
- 长文本：标题 `maxLines: 1`、`overflow: ellipsis`；副标题单行；指标数值不省略，用 `FittedBox`。

### 9.6 工具箱 `OwnerToolbox`

- watch `profileServicesProvider`；2×2 `Row` + `Expanded`，两行；每行 `IntrinsicHeight` 保证等高。
- 工具卡：`_ToolCard`，入参 `title / subtitle / icon / tint / available / footer / onTap / key`。
- 可用卡：
  - 页脚 `primary` 文字 + `arrow_forward_rounded`；
  - 按下缩放 0.98；整卡 `InkWell`。
- 不可用卡：
  - 整卡 `Opacity(0.72)`，`onTap` 仍可触发 Toast（让用户知道原因）；
  - 页脚「即将上线」/「本地数据」+ 状态点（`outline`，不显示绿色成功点）；
  - `Semantics(button: true, label: '{title}，即将上线')`；仍可点击查看原因，不使用 `enabled: false` 屏蔽语义。
- 报表点击：

```dart
void _openReport(BuildContext context, WidgetRef ref) {
  final vehicleId = ref.read(profileGarageVehicleIdProvider);
  openMonthlyReport(
    context,
    ReportScope(month: monthStart(DateTime.now()), vehicleId: vehicleId),
  );
}
```

- 不读取账单页的月份筛选；我的页始终以进入时自然月为准。
- 不检查报表是否为空；`MonthlyReportPage` 已有空态与导出校验。

### 9.7 设置列表 `SettingsList`

- watch `profilePreferencesProvider`；`AppCard(padding: EdgeInsets.zero)` + 4 个 `_SettingRow` + `Divider(height: 1)`。
- 行：36×36 图标容器（`surfaceContainer` 底、圆角 12）→ 标题 + 副标题 → 右侧值 + `chevron_right_rounded`。
- 右侧值：`公制 · CNY`（`outline`）、`查看`（`primary`）、`未开启`（`outline`）、`v1.0.0`（`outline`）。
- 点击：
  - 单位：`showAppToast('偏好设置待接入')`；
  - 隐私：`showModalBottomSheet(builder: (_) => const PrivacySheet())`；
  - 通知：`showAppToast('通知设置待接入')`；
  - 关于：`showModalBottomSheet(builder: (_) => const AboutSheet())`。
- 弹层统一样式：`backgroundColor: palette.surface`、顶部圆角 28、顶部 4×40 拖拽条、内边距 20、底部 `SafeArea`。
- `AboutSheet`：`AppInfo.name`、`AppInfo.version`、一句话介绍、三行静态信息；不提供外链。
- `PrivacySheet`：四条说明（本机存储、手机号掩码、报表临时文件 24h、未实现加密不承诺）；不读取用户数据，纯静态。
- 不使用 `ListTile`，避免 Material 默认高度 / padding 与设计不一致。

### 9.8 账号区 `AccountFooter`

- watch `profileOverviewProvider`；`user.phoneMasked != null` 时显示「当前绑定手机：{masked} · 手机号已掩码显示」。
- P0 **不渲染**退出按钮；`sessionProvider`（P1）不存在时整段只保留手机号说明。
- 文案使用 `labelSm` + `outline` 60%，居中，距底部 12。
- P1 退出按钮与确认单按需求 §6.6 实现；确认单使用 `showModalBottomSheet`，`isDismissible: true`，请求中禁用按钮。

### 9.9 主题与无障碍

- 所有颜色取 `context.palette`；动力 / 分类语义色取 `AppColors`；不出现 `Colors.white` / `Colors.grey`。
- 深色：
  - 卡片 `palette.surface`、指标格 `palette.surfaceContainer`；
  - 选中胶囊 `onSurface` / `surface` 自动反转；
  - 图标底色用语义色 16% 透明度，深色下仍可读；
  - 光晕透明度减半。
- 语义：
  - 资料卡合并朗读；
  - 车辆卡合并朗读（车名、车牌、里程、能耗、保养）；
  - 胶囊 `selected` 状态；
  - 工具卡包含可用 / 不可用状态；
  - 设置行包含当前值；
  - 弹层标题使用 `Semantics(header: true)`。
- 点击区域 ≥ 44×44：胶囊高度 34 但外层 `InkWell` 可加 `padding` 扩展；设置行高 56；铃铛 36 外围 4px 透明区域。
- 文本缩放：顶栏与指标数值 `maxScaleFactor 1.15`；正文允许 1.3；卡片高度自适应，禁止 `overflow`。

### 9.10 关键 Key（测试用）

| Key | 位置 |
| --- | --- |
| `profile-scroll` | 页面滚动视图 |
| `profile-summary-card` | 资料卡 |
| `profile-settings-button` | 资料卡齿轮 |
| `garage-pill-all` / `garage-pill-<id>` | 车辆胶囊 |
| `garage-card` | 车辆卡 |
| `garage-add-vehicle` | 添加新车 |
| `garage-manage` | 管理爱车 |
| `tool-report` / `tool-voucher` / `tool-sync` / `tool-offline` | 工具卡 |
| `settings-units` / `settings-privacy` / `settings-notifications` / `settings-about` | 设置行 |
| `profile-account-footer` | 账号区 |

---

## 10. 性能

- **懒加载**：我的 Tab 首次点击才构建；不在 App 启动时请求资料 / 车库。
- **同源复用**：车辆列表与账单数据均来自已有 provider 的仓库实例；`MockLedgerRepository` 的月份缓存避免重复生成。
- **并发取数**：`fetchGarage` 内 `Future.wait` 并行取各车 dashboard；全部资产一次 `fetchRecords`（limit 500），不分车 N 次请求。
- **渲染**：页面为少量静态卡片，无图表与图片；使用 `const` 子组件、`AppCard` 复用；`AnimatedSwitcher` 仅包裹卡片内容，不重建胶囊。
- **重绘隔离**：资料卡、车库卡、工具卡、设置卡各自 watch 所需 provider，避免一个 provider 更新导致整页重建。
- **首屏预算**：Mock 延迟 160ms × 2（overview + garage）≈ 320ms，满足 ≤ 1s；`fetchLifetimeStats` 复用月份缓存，不叠加延迟。
- **内存**：车库 family 按车辆数缓存，最多 10 辆；离开页面由 autoDispose 释放（页面保活期间不释放）。
- **滚动**：`CustomScrollView` + 吸顶头；无长列表，60fps 无压力；底部留白避免导航遮挡。

---

## 11. 错误与边界

| 场景 | 处理 |
| --- | --- |
| 资料接口 404 | 资料卡错误 + 重试；车库与设置正常 |
| 车库接口失败 | 车库错误 + 重试；资料正常；保留胶囊 |
| 工具状态失败 | 报表可用；其余按不可用展示；不弹全局错误 |
| 偏好失败 | 显示默认值；不阻塞页面 |
| 无车辆 | 空态 + 添加入口；胶囊只有「全部资产 0」；资料卡 0 辆 |
| 无记录 | 记账天数「—」、累计 0；车辆卡金额 0 + 空提示 |
| 车辆被删除（P1） | 回退全部资产 + Toast；invalidate 车库 |
| 选中车辆在刷新后消失 | 同上；不保留悬空 key |
| 首笔记录在未来（脏数据） | 记账天数归零，显示「—」 |
| 当前月无能耗但有其他开销 | 能耗卡显示 0，不隐藏车辆卡 |
| 金额为负（退款） | 支出总额按负值计入；平均单价不计退款 |
| 长昵称 / 长车名 | 单行省略；头像首字取第一个字素 |
| 超长数字（≥ 6 位） | `FittedBox` 缩放，不换行 |
| 字号放大 1.3 | 卡片高度自适应；副标题省略；指标不溢出 |
| 深色模式 | 无硬编码白底；选中胶囊反转；光晕降低透明度 |
| 断网 / 超时（P1） | 保留旧值 + Toast「刷新失败」；首屏无数据则模块错误 |
| 时区 / 跨月 | 以本地时区自然月为准；月末 23:59 记录归属当月 |

---

## 12. 测试方案

### 12.1 单元测试

`test/profile/garage_aggregation_test.dart`

- `computeAccountDays`：首笔当天 = 1；跨月 / 跨年 / 闰日；未来记录 = 0；null = 0。
- `aggregateMonthEnergy`：只统计充电 / 加油；排除其他分类；排除上月与未来；退款计入金额；kWh / L 分别累计；无数量时返回 null。
- `buildGarageSnapshot`（单车）：徽标、车牌、副标题（有 / 无每公里成本）、三指标。
- `buildGarageSnapshot`（全部资产）：里程求和；金额 / 笔数求和；同能源保留 kWh；混合能源置 null；动力构成；最紧迫保养。
- `pickMostUrgent`：正常取最小正剩余；预警标记；全部超期取最大超期；未设置返回 disabled。
- `buildGarageTip`：纯电 / 燃油 / 插混 / 全部资产 / 无记录；平均单价排除退款。
- `powertrainComposition`：四类组合与空列表。

`test/profile/profile_presenter_test.dart`

- 资料卡文案：天数、笔数、辆数；空值「—」。
- 车辆卡：金额一位小数、能耗量单位、保养四种状态、超期文案。
- 长数字千分位；版本号格式。

`test/profile/mock_profile_repository_test.dart`

- `fetchOverview` 的 `recordCount` 等于账本 24 个月未删除记录数；`accountDays` 与首笔记录一致。
- `fetchGarage(vehicleId: null)` 的能耗金额等于账单同月全车 `energyCents`；单车等于该车能源支出。
- 全部资产里程等于各车之和；混合能源时 kWh / L 为 null。
- `fetchServices`：报表可用、其余不可用；不使用伪造 count。
- `fetchPreferences`：默认公制 + CNY。

`test/profile/formatters_test.dart`（或并入现有 formatters 测试）

- `formatYuanOneDecimal`：0、312.4、1,148.2、负数。
- `formatCount`：0、142、1,248。
- `formatEnergyQuantity`：184.0 → `184 kWh`、184.5 → `184.5 kWh`、5.20 → `5.20 L`。

### 12.2 Widget 测试

`test/profile/profile_page_test.dart`

- 首屏渲染：品牌「车小记」、昵称、认证标签、三项统计、车库标题、四张工具卡、四行设置。
- 默认「全部资产」；点击某车胶囊后，卡片标题与金额切换；再点回「全部资产」恢复合计。
- 全部资产卡：里程合计、能耗合计、保养紧迫车辆标注。
- 报表工具：点击后 push `MonthlyReportPage`，`initialScope` 月份为当前自然月、`vehicleId` 为 null / 选中车辆。
- 不可用工具：显示「即将上线 / 本地数据」，点击出现对应 Toast，不出现伪造数字。
- 设置：关于弹层显示版本；隐私弹层显示四条说明；点击单位 / 通知出现 Toast。
- 账号区：显示掩码手机号；**不出现**「退出当前账号」与「AES-256」。
- 空车辆：显示空态与「添加车辆」；资料卡「0 辆」。
- 错误：资料失败只影响资料卡；车库失败只影响车库区。
- 车辆切换：连续点选时最终卡片与最后一次选择一致。
- 语义：资料卡 / 车辆卡 / 工具状态可被 `Semantics` 找到。

`test/widget_test.dart` 或壳测试

- 我的 Tab 首次点击才构建（懒加载）。
- 我的 Tab 选中态正确；重复点击滚动回顶不崩溃。

### 12.3 手工验收

- 375 / 390 / 430pt；深色 / 浅色；字号 1.3；横竖屏不溢出。
- 下拉刷新；断网 / 超时（P1）；快速切换 10 次不出现旧数据。
- 报表入口在「全部资产」与单车下的车辆范围正确。
- 与账单页核对同月能源支出；与首页核对车辆里程。

### 12.4 CI

- PR：`flutter analyze` + `flutter test`。
- 合并 `main`：追加 `flutter build apk --release --target-platform android-arm64`。
- 新增测试全部为纯 Dart / Widget 测试，无网络、无平台通道依赖。

---

## 13. 实施拆分

### M0 · 公共能力与壳改造

- `AppTabShell` index 3 → `ProfilePage`；保持懒加载。
- 新增 `ProfileAvatar`，`AppTabHeader` 加 `avatarInitial`，首页视觉不变。
- 新增 `showAppToast`、`AppInfo`、`openMonthlyReport`。
- 追加 formatters 与单测。
- Ledger 扩展 `LedgerLifetimeStats` / `fetchLifetimeStats()` + Mock 实现。

### M1 · 模型、口径与 Mock

- `profile_models.dart`、`garage_aggregation.dart`、`profile_presenter.dart`。
- `ProfileRepository` / `ProfileApi` / `MockProfileRepository`。
- providers 与失效关系。
- 聚合、presenter、Mock 单元测试。

### M2 · 资料卡与车库

- `ProfilePage` 骨架 + `RefreshIndicator` + 吸顶头。
- `ProfileHeader`、`ProfileSummaryCard`。
- `GarageSection`、车辆胶囊、`GarageVehicleCard`、全部资产卡、空 / 错态。
- 车辆切换动画与 Key。

### M3 · 工具箱、设置与账号区

- `OwnerToolbox`（报表直达、三张占位卡）。
- `SettingsList` + `AboutSheet` + `PrivacySheet`。
- `AccountFooter`（掩码手机号，无退出）。
- Toast / 弹层样式统一。

### M4 · 打磨与收尾

- 深色模式回归、字号 1.3、长文本与超长数字。
- 语义与点击区域。
- Widget 测试补齐；快速切换压力手测。
- 更新需求 / 技术文档的「实施记录」，同步接口契约状态。

---

## 14. 风险与待确认

| 风险 | 影响 | 应对 |
| --- | --- | --- |
| 设计稿中存在大量未实现能力的成功态 | 用户误以为功能可用 | 能力标记驱动；P0 统一「即将上线 / 本地数据」，详见需求 §13.1 |
| 无登录 / 会话模块 | 退出、云端同步、隐私设置无法闭环 | P0 隐藏退出；云端与隐私只做说明；登录优先排期 |
| 设置项不持久化 | 用户改不了、改了也不保存 | P0 明确只读；P1 接入存储 / 后端后再开放编辑 |
| 生命周期统计在 Mock 下需遍历 24 个月 | 首屏多一次聚合 | 复用 `_recordsFor` 缓存；不加延迟；真实接口由服务端返回 |
| 全部资产混合能源无法相加 kWh / L | 设计稿单一单位无法照搬 | 只展示金额与笔数，副文标注「共 n 笔」 |
| 车库与首页车辆选中态不一致 | 用户困惑 | 我的页独立选择，默认全部资产；不写回首页（待确认 Q1） |
| 车辆 / 保养数据来自 home feature | 跨 feature 依赖 | 仅数据层依赖，UI 只认 `GarageData`；后续迁 core |
| 版本号常量与 pubspec 不同步 | 关于页显示错误 | `AppInfo.version` 与 `pubspec.yaml` 同步维护；P1 接 `package_info_plus`（需评审新依赖） |
| 头像无图片资源 | 无法还原设计稿写真 | 首字渐变头像，与首页一致；P1 支持上传 |
| 报表入口月份与账单页筛选不同 | 用户预期差异 | 固定进入时自然月，需求 §6.4 已明确 |
| 接口契约未定稿 | 后端字段变化 | 页面只依赖 domain 模型；HTTP 层做 DTO 映射 |

待产品确认项见 [需求 §13.2](../requirements/profile.md#132-待产品确认)。

---

## 15. 附录：需求 → 实现映射

| 需求 | 实现 |
| --- | --- |
| §6.1 顶部栏 | `ProfileHeader` + `AppTabHeader(avatarInitial)` + `ProfileAvatar` |
| §6.2 个人资料卡 | `ProfileSummaryCard` + `profileOverviewProvider` + presenter |
| §6.3 车库资产与车辆 | `GarageSection`、`GarageVehicleCard`、`profileGarageVehicleIdProvider`、`profileGarageProvider` |
| §6.4 车主核心工具箱 | `OwnerToolbox` + `profileServicesProvider` + `openMonthlyReport` |
| §6.5 系统设置与偏好 | `SettingsList` + `profilePreferencesProvider` + `PrivacySheet` / `AboutSheet` |
| §6.6 账号区 | `AccountFooter`（P0 掩码手机号；P1 退出） |
| §6.7 底部导航与 FAB | `AppTabShell` + `AppBottomNav`（不新增） |
| §6.8 加载 / 空 / 错误 / 刷新 | `SkeletonBox`、`SectionError`、`EmptyState`、`RefreshIndicator` |
| §7.1–§7.4 口径 | `garage_aggregation.dart`、`LedgerLifetimeStats` |
| §7.3 格式化 | `formatters.dart` 扩展 + `profile_presenter.dart` |
| §8 接口契约 | `ProfileApi` / `ProfileRepository` / `MockProfileRepository` |
| §9 全局状态 | §8 本章 provider 与失效矩阵 |
| §10 非功能 | §9 / §10 / §11 本章 |
| §12 验收 | §12 测试方案 + 手工验收 |

---

## 16. 变更记录

| 版本 | 日期 | 变更 |
| --- | --- | --- |
| v0.1 | 2026-11-14 | 首版：基于 Stitch「我的·个人中心与车主服务」与当前仓库实现，定义公共头像 / 生命周期统计 / 车库聚合 / Mock 数据层 / provider 结构 / UI 拆分 / 测试与里程碑；明确未实现能力的能力标记方案 |
