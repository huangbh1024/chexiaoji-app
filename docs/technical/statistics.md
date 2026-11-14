# 统计页技术方案 · 能耗与开销深度分析

| 项目 | 内容 |
| --- | --- |
| 关联需求 | [统计页需求文档 v0.1](../requirements/statistics.md) |
| 设计稿 | [Stitch · 统计与能耗深度分析页（联动与走势优化版）](https://stitch.google.com/projects/9615374848161425677?node-id=eca4e1e065c94589b5cb5d2fdece1540) |
| 客户端 | Flutter 3.50.0 stable / Dart 3.14 |
| 平台 | Android（arm64 优先）、iOS |
| 文档版本 | v0.2（M0–M4 已实施，Mock 数据） |
| 状态 | P0 已实现；接口契约未定稿，等待后端接入 |

> 本文档基于**仓库当前实现**编写：首页、账单、单笔详情、月度报表已落地；统计 Tab 仍是 `AppTabShell` 中的 `_ComingSoonTab`，index = 2。所有新增目录、文件与重构均为拟实施内容，按 `feat/statistics-page` 分支推进。
> 依赖现状：`material_ui`、`flutter_riverpod ^3.5.0`、`fl_chart ^1.3.1`、`intl ^0.20.3`、`pdf`、`printing`、`share_plus`、`path_provider`。本页**不新增第三方依赖**。

---

## 1. 目标与约束

### 1.1 技术目标

- 统计 Tab 首次进入 ≤ 1s 可交互；周期 / 车辆切换后首屏 ≤ 500ms，命中缓存 ≤ 120ms。
- 车辆范围与周期切换后，Hero、双指标、趋势、构成、最近记录在 400ms 内完成替换；有缓存时 ≤ 100ms。
- 快速连续切换（车辆 / 周期 / 粒度）不出现旧数据覆盖新数据；过期响应必须丢弃。
- 图表滚动、点按、粒度切换保持 60fps；图表局部重绘，不触发整页重建。
- 聚合口径与账单页 / 月度报表一致：同范围同车辆的总额、笔数、分类金额必须相等。
- 复用现有设计 token、卡片、导航、格式化、Mock 仓库与图表基础设施，避免出现第二套视觉与第二套规范。

### 1.2 约束

- **不新增依赖**：曲线与环形图使用已引入的 `fl_chart`；迷你走势、进度环、Hero 波浪使用 `CustomPainter`；金额格式化沿用 `intl`。
- 金额全链路使用**整数分**（`int cents`）；每公里成本以「分/公里」整数返回，展示时除 100，避免浮点误差。
- 不引入路由库：现有 `MaterialApp(home: AppTabShell)` + `IndexedStack` 保持不变；跨 Tab 跳转通过新增 `appTabProvider` 完成，二级页仍用 `Navigator.push`。
- 设计稿的 32px 卡片圆角按全站现状收敛为 16px；分类色沿用 `AppColors`；品牌文案统一「车小记 / 数据统计」。
- 接口未定稿：UI 只依赖 domain 模型；数据层可在 `MockStatsRepository` 与未来的 `HttpStatsRepository` 之间切换，页面与 provider 不改。
- CI 在 PR 阶段只跑 `flutter analyze` 与 `flutter test`，不构建 APK；合并 `main` 后打包。
- Mock 数据只覆盖最近 24 个月（与 `MockLedgerRepository` 一致）；「全部」范围在 Mock 下等价于「最近 24 个月」。

---

## 2. 现状与复用清单

| 现有能力 | 位置 | 本页用法 |
| --- | --- | --- |
| 色彩主题 | `lib/app/theme/app_colors.dart` → `AppPalette` / `AppColors` / `context.palette` | 全部颜色；分类色 `ExpenseCategoryVisual` |
| 间距 / 圆角 / 阴影 | `lib/app/theme/app_tokens.dart` → `AppTokens` / `context.tokens` | 页面边距、卡片、导航、底部留白 |
| 字体 | `lib/app/theme/app_typography.dart` | `displayHero`、`headlineLg/Md/Sm`、`bodyMd/Sm`、`labelMd/Sm` |
| 卡片容器 | `lib/core/widgets/app_card.dart` → `AppCard` | 双指标、趋势、构成、最近记录 |
| 骨架 / 错误 / 空态 | `lib/core/widgets/skeleton_box.dart`、`section_error.dart`、`empty_state.dart` | 每个模块独立加载与失败 |
| 顶栏毛玻璃 | `lib/core/widgets/blurred_header_delegate.dart` | sticky 顶部栏 |
| 底部导航 + FAB | `lib/core/widgets/app_bottom_nav.dart` → `AppBottomNav` | 由 `AppTabShell` 统一持有 |
| 分类语义色 / 图标 | `lib/core/presentation/category_style.dart` | 环形图、图例、记录图标 |
| 车辆 / 枚举 | `lib/core/domain/vehicle.dart`、`enums.dart` | `Vehicle`、`PowertrainType`、`ExpenseCategory`、`TrendDirection` |
| 格式化 | `lib/core/format/formatters.dart` | `formatYuanCompact`、`formatExpense`、`formatSignedPercent`、`formatKmValue`、`formatOneDecimal`、`formatMonthLabel`、`formatDayTitle` |
| 账单记录 / 查询 | `lib/features/ledger/domain/ledger_models.dart` | `LedgerRecord`、`LedgerQuery`、`monthStart`、`LedgerMetrics` |
| 账单 Mock | `lib/features/ledger/data/mock_ledger_repository.dart` | 生成最近 24 个月记录，作为统计 Mock 数据源 |
| 里程口径 | `lib/features/report/domain/report_aggregation.dart` → `computeDistanceKmByVehicle` | 周期行驶里程（按车取读数极差，兜底单笔里程求和） |
| 趋势图 | `lib/features/home/presentation/widgets/trend_card.dart` → `LineChart` 配置 | 曲线、渐变面积、虚线网格、Y/X 轴的实现基准 |
| 环形图 | `lib/features/home/presentation/widgets/breakdown_card.dart` → `PieChart` | 环形图、中心合计、图例布局的实现基准 |
| 迷你走势 | `consumption_card.dart` → `SparklinePainter`（public） | 抽取到 `core/widgets` 后复用 |
| 进度环 | `maintenance_card.dart` → `_RingPainter`（private） | 抽取为公共 `ProgressRing` |
| Hero 波浪 | `hero_card.dart` → `_HeroWavePainter`（private） | 抽取为公共 `HeroWaveBackground` |
| 首页 Mock 维护数据 | `lib/features/home/data/mock_home_repository.dart` | 保养周期 / 剩余里程 / 剩余天数的 Mock 来源 |
| Tab 壳 | `lib/app/tab_shell.dart` | index 2 由占位替换为 `StatsPage`；Tab 状态上提 |

### 2.1 需要抽象的耦合点

| 问题 | 影响 | 处理（M0） |
| --- | --- | --- |
| `AppTabShell` 用私有 `_selectedIndex` 管理 Tab | 统计页「查看全部」无法切到账单 Tab | 新增 `appTabProvider`（`NotifierProvider<AppTabNotifier, AppTab>`），壳监听它，页面通过 `ref.read` 切换 |
| `HomeHeader` 把问候、标题、右侧操作写死 | 统计页需要「车辆胶囊 + 通知」的变体 | 抽出 `AppTabHeader`（标题 + 可选问候 + trailing），首页与统计页共用 |
| `_HeroWavePainter` / `_RingPainter` 私有 | 统计页 Hero / 保养卡无法复用 | 原样迁到 `core/widgets/`，首页改为引用，视觉不变 |
| `SparklinePainter` 位于 home feature | 跨 feature 引用不清晰 | 迁到 `core/widgets/sparkline.dart`，home 改 import |
| `computeDistanceKmByVehicle` 位于 report feature | 统计页依赖报表 feature | 迁到 `core/domain/distance.dart`；report 保留 re-export |
| `monthStart` 在 ledger / report 各有一份 | 口径重复 | 统一以 `ledger_models.dart` 为准，report 侧逐步收敛（非本页阻塞项） |
| `vehiclesProvider` / `selectedVehicleIdProvider` 位于 home feature | 统计页跨 feature 读取 | 本期只读复用；后续把车辆列表与选中态迁到 `core`（非本页阻塞项） |
| 首页趋势图 / 环形图与统计页需求相近但数据模型不同 | 复制图表代码可能产生两套样式 | M2 先实现 `StatsTrendChart` / `StatsDonut`，共用样式常量；M4 再评估合并 |

> 统计页不直接复用 `HomeHeroCard` / `ConsumptionCard` / `MaintenanceCard`：三者与 `homeDashboardProvider` 强耦合，且统计页的周期、范围与「全部车辆」语义不同。复用层次限定在**视觉原语**（Hero 背景、Sparkline、ProgressRing）与**格式化 / 颜色映射**。

---

## 3. 结构调整（M0）

```
lib/
├── app/
│   ├── tab_shell.dart                 # 修改：index 2 → StatsPage；Tab 状态上提
│   └── tab.dart                       # 新增：AppTab 枚举 + appTabProvider
├── core/
│   ├── domain/
│   │   └── distance.dart              # 新增：computeDistanceKmByVehicle + DistanceSource
│   ├── widgets/
│   │   ├── app_tab_header.dart        # 新增：通用顶部栏（头像 / 问候 / 标题 / trailing）
│   │   ├── hero_wave_background.dart  # 新增：Hero 波浪背景
│   │   ├── progress_ring.dart         # 新增：圆环进度
│   │   └── sparkline.dart             # 新增：迷你走势
│   └── format/
│       └── formatters.dart            # 追加：周期标签、累计年限、坐标轴金额
└── features/
    ├── home/
    │   ├── presentation/widgets/home_header.dart      # 改为组合 AppTabHeader
    │   ├── presentation/widgets/hero_card.dart        # 改用 HeroWaveBackground
    │   ├── presentation/widgets/consumption_card.dart # 改用 core Sparkline
    │   └── presentation/widgets/maintenance_card.dart # 改用 core ProgressRing
    ├── report/
    │   └── domain/report_aggregation.dart             # re-export core distance
    └── stats/
        ├── data/
        │   ├── stats_repository.dart
        │   ├── stats_api.dart
        │   └── mock_stats_repository.dart
        ├── domain/
        │   ├── stats_models.dart
        │   ├── stats_period.dart
        │   ├── stats_aggregation.dart
        │   ├── stats_presenter.dart
        │   └── providers.dart
        └── presentation/
            ├── stats_page.dart
            ├── stats_style.dart
            └── widgets/
                ├── stats_header.dart
                ├── stats_vehicle_sheet.dart
                ├── stats_period_bar.dart
                ├── stats_hero_card.dart
                ├── stats_energy_card.dart
                ├── stats_maintenance_card.dart
                ├── stats_trend_card.dart
                ├── stats_trend_chart.dart
                ├── stats_breakdown_card.dart
                ├── stats_donut.dart
                └── stats_recent_records.dart
```

关键点：

- **Tab 状态上提**：`AppTabShell` 仍需 `StatefulWidget` 持有 4 个 `ScrollController`，但选中项从 `appTabProvider` 读取；`_onTabSelected` 先 `ref.read(appTabProvider.notifier).select(tab)`，重复点击当前 Tab 时只滚动回顶部。
- **`AppTabHeader`**：签名建议 `AppTabHeader({required String title, Widget? trailing, bool showGreeting = true, Widget? leading})`；首页传 `trailing: _HomeHeaderActions()`，统计页传车辆胶囊 + 通知。问候语、头像、标题样式完全复用。
- **公共图元**：迁移时不改绘制参数；迁移后跑现有 Widget 测试与 golden（如有），确保首页像素不变。
- **`StatsPage` 懒加载**：沿用 `_visitedTabs` 机制，首次点击统计 Tab 才构建，避免冷启动时请求统计接口。

---

## 4. 数据流

```
AppTabShell (IndexedStack index=2)
        │
        ▼
StatsPage ── watch ──> statsFilterProvider (vehicleId / period / anchor)
        │                        │
        │                        ├── statsOverviewProvider(scope)   ── Hero + 能耗 + 保养
        │                        ├── statsBreakdownProvider(scope)  ── 环形图 + 图例
        │                        └── statsRecentProvider(scope)     ── 最近记录
        │
        │      statsTrendRangeProvider (7d/30d/6m/1y)
        │                        └── statsTrendProvider(query)      ── 趋势卡
        ▼
StatsRepository ──> StatsApi ──> 后端
        │            （当前为 MockStatsRepository）
        └── 内存缓存：Map<scopeKey, (data, cachedAt)>，TTL 60s
```

- 查询键：
  - 概览 / 构成 / 最近记录：`vehicleId|period|anchor(yyyy-MM-dd)`。
  - 趋势：`vehicleId|range|anchor(yyyy-MM-dd)`。
- 车辆 / 周期切换：重建概览、构成、最近记录；趋势粒度按默认映射重置后重建趋势。
- 趋势粒度切换：只重建趋势 provider，其余模块不动。
- 下拉刷新：`ref.invalidate` 以上四类 provider，并清空仓库缓存。
- 记账 / 删除 / 编辑成功后：M4 新增 `expenseMutationTickProvider`（`NotifierProvider<int>`）自增；统计页监听并失效当前范围的 provider。页面内部进入详情再返回时，直接失效当前 scope，不依赖全局事件。

---

## 5. 数据模型

### 5.1 枚举与范围

```dart
enum StatsPeriod {
  week('week'),
  month('month'),
  halfYear('half_year'),
  year('year'),
  all('all');

  const StatsPeriod(this.apiValue);
  final String apiValue;
}

enum StatsTrendRange {
  d7('7d', '7天'),
  d30('30d', '30天'),
  halfYear('6m', '半年'),
  year('1y', '1年');

  const StatsTrendRange(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

enum StatsRating { excellent, good, high, fleet, none }

// DistanceSource 由 core/domain/distance.dart 提供（M0 从 report 迁出）。

/// 页面筛选：vehicleId == null 表示全部车辆。
@immutable
class StatsFilter {
  const StatsFilter({
    this.vehicleId,
    this.period = StatsPeriod.month,
    required this.anchor,
  });

  final String? vehicleId;
  final StatsPeriod period;
  final DateTime anchor;

  StatsScope toScope() =>
      StatsScope(vehicleId: vehicleId, period: period, anchor: anchor);

  StatsFilter copyWith({
    String? vehicleId,
    bool clearVehicle = false,
    StatsPeriod? period,
    DateTime? anchor,
  }) => StatsFilter(
    vehicleId: clearVehicle ? null : (vehicleId ?? this.vehicleId),
    period: period ?? this.period,
    anchor: anchor ?? this.anchor,
  );
}

@immutable
class StatsScope {
  const StatsScope({
    required this.vehicleId,
    required this.period,
    required this.anchor,
  });

  final String? vehicleId;
  final StatsPeriod period;
  final DateTime anchor;

  StatsScope copyWith({
    String? vehicleId,
    bool clearVehicle = false,
    StatsPeriod? period,
    DateTime? anchor,
  }) => StatsScope(
    vehicleId: clearVehicle ? null : (vehicleId ?? this.vehicleId),
    period: period ?? this.period,
    anchor: anchor ?? this.anchor,
  );

  @override
  bool operator ==(Object other) => other is StatsScope
      && other.vehicleId == vehicleId
      && other.period == period
      && other.anchor.year == anchor.year
      && other.anchor.month == anchor.month
      && other.anchor.day == anchor.day;

  @override
  int get hashCode => Object.hash(vehicleId, period, anchor.year,
      anchor.month, anchor.day);
}

@immutable
class StatsRange {
  const StatsRange({
    required this.start,
    required this.end,
    required this.label,
    required this.shortLabel,
  });

  final DateTime start;      // 含
  final DateTime end;        // 含
  final String label;        // 2024年6月 / 本周 (6/24–6/30) / 2024上半年
  final String shortLabel;   // 本月 / 本周 / 上半年 / 全年 / 累计
}

@immutable
class StatsTrendQuery {
  const StatsTrendQuery({
    required this.vehicleId,
    required this.range,
    required this.anchor,
  });

  final String? vehicleId;
  final StatsTrendRange range;
  final DateTime anchor;
}
```

### 5.2 概览模型

```dart
@immutable
class StatsOverview {
  const StatsOverview({
    required this.scope,
    required this.range,
    required this.summary,
    required this.consumption,
    required this.maintenance,
    required this.dataUpdatedAt,
  });

  final StatsScope scope;
  final StatsRange range;
  final StatsSummary summary;
  final StatsConsumption consumption;
  final StatsMaintenance? maintenance; // 全部车辆时也返回「最紧迫」车辆
  final DateTime? dataUpdatedAt;
}

@immutable
class StatsSummary {
  const StatsSummary({
    required this.totalCents,
    required this.distanceKm,
    required this.distanceSource,
    required this.costPerKmCents,
    required this.energyCents,
    required this.energyCostPerKmCents,
    required this.previousTotalCents,
    required this.changePercent,
    required this.changeTrend,
    this.changeText,
    this.cumulativeYears,
  });

  final int totalCents;
  final int distanceKm;
  final DistanceSource distanceSource;
  final int? costPerKmCents;          // null → 显示「—」
  final int energyCents;
  final int? energyCostPerKmCents;
  final int? previousTotalCents;
  final double? changePercent;
  final TrendDirection changeTrend;
  final String? changeText;           // 全部范围：「累计 2.1 年」
  final double? cumulativeYears;
}

@immutable
class StatsConsumption {
  const StatsConsumption({
    required this.rating,
    required this.primary,
    this.secondary,
    this.sparkline = const <double>[],
  });

  final StatsRating rating;
  final StatsEnergyValue primary;
  final StatsEnergyValue? secondary;  // 插混第二行
  final List<double> sparkline;
}

@immutable
class StatsEnergyValue {
  const StatsEnergyValue({required this.value, required this.unit});

  final double value;
  final String unit; // kWh/100km | L/100km | CNY/km
}

@immutable
class StatsMaintenance {
  const StatsMaintenance({
    required this.enabled,
    required this.vehicleId,
    required this.vehicleName,
    required this.tag,
    required this.remainingKm,
    required this.progressPercent,
    required this.status,
    this.remainingDays,
  });

  final bool enabled;
  final String vehicleId;
  final String vehicleName;
  final String tag; // 小保养 / 大保养 / 首保/小保 / 综合管理
  final int remainingKm; // 可为负（超期）
  final int progressPercent; // 0–100
  final MaintenanceStatus status;
  final int? remainingDays;
}
```

`MaintenanceStatus` 复用 `features/home/domain/home_models.dart` 的枚举；M0 可迁到 `core/domain/enums.dart`（与 `PowertrainType` 一样），home 侧 re-export，避免统计页反向依赖 home。

### 5.3 趋势与构成模型

```dart
@immutable
class StatsTrend {
  const StatsTrend({
    required this.query,
    required this.from,
    required this.to,
    required this.totalCents,
    required this.previousTotalCents,
    required this.changePercent,
    required this.changeTrend,
    required this.axis,
    required this.peakIndex,
    required this.buckets,
  });

  final StatsTrendQuery query;
  final DateTime from;
  final DateTime to;
  final int totalCents;
  final int? previousTotalCents;
  final double? changePercent;
  final TrendDirection changeTrend;
  final StatsAxis axis;
  final int? peakIndex;
  final List<StatsBucket> buckets;
}

@immutable
class StatsBucket {
  const StatsBucket({
    required this.start,
    required this.label,
    required this.energyCents,
    required this.otherCents,
    required this.count,
    this.dominantCategory,
  });

  final DateTime start;
  final String label;             // 6/15、6月、24Q2
  final int energyCents;
  final int otherCents;
  final int count;
  final ExpenseCategory? dominantCategory;

  int get totalCents => energyCents + otherCents;
}

@immutable
class StatsAxis {
  const StatsAxis({required this.maxCents, required this.ticksCents});

  final int maxCents;
  final List<int> ticksCents; // [0, step, 2*step, 3*step]
}

@immutable
class StatsBreakdown {
  const StatsBreakdown({
    required this.totalCents,
    required this.count,
    required this.categories,
    required this.otherMerged,
  });

  final int totalCents;
  final int count;
  final List<StatsCategorySlice> categories;
  final bool otherMerged;
}

@immutable
class StatsCategorySlice {
  const StatsCategorySlice({
    required this.category,
    required this.amountCents,
    required this.count,
    required this.percent,
  });

  final ExpenseCategory category;
  final int amountCents;
  final int count;
  final int percent;
}

@immutable
class StatsRecord {
  const StatsRecord({
    required this.id,
    required this.vehicleId,
    required this.vehicleShortName,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.amountCents,
    required this.occurredAt,
    this.tag,
  });

  final String id;
  final String vehicleId;
  final String vehicleShortName;
  final ExpenseCategory category;
  final String title;
  final String? subtitle;
  final int amountCents;
  final DateTime occurredAt;
  final String? tag;
}
```

---

## 6. 聚合口径与纯函数

所有聚合放在 `stats_aggregation.dart`，纯函数、无 `BuildContext`、无网络，便于单测与 Mock / HTTP 共用。

### 6.1 周期解析

```dart
StatsRange resolveRange(StatsPeriod period, DateTime anchor) {
  switch (period) {
    case StatsPeriod.week:
      final day = DateTime(anchor.year, anchor.month, anchor.day);
      final monday = DateTime(day.year, day.month, day.day - (day.weekday - 1));
      final nextMonday = DateTime(monday.year, monday.month, monday.day + 7);
      final end = nextMonday.subtract(const Duration(milliseconds: 1));
      return StatsRange(
        start: monday,
        end: end,
        label: '${monday.month}/${monday.day}–${end.month}/${end.day}',
        shortLabel: '本周',
      );
    case StatsPeriod.month:
      final start = DateTime(anchor.year, anchor.month);
      final end = DateTime(anchor.year, anchor.month + 1, 0, 23, 59, 59, 999);
      return StatsRange(
        start: start,
        end: end,
        label: '${anchor.year}年${anchor.month}月',
        shortLabel: '本月',
      );
    case StatsPeriod.halfYear:
      final firstHalf = anchor.month <= 6;
      final startMonth = firstHalf ? 1 : 7;
      final start = DateTime(anchor.year, startMonth);
      final end = firstHalf
          ? DateTime(anchor.year, 7, 0, 23, 59, 59, 999)
          : DateTime(anchor.year, 13, 0, 23, 59, 59, 999);
      return StatsRange(
        start: start,
        end: end,
        label: '${anchor.year}${firstHalf ? '上半年' : '下半年'}',
        shortLabel: firstHalf ? '上半年' : '下半年',
      );
    case StatsPeriod.year:
      return StatsRange(
        start: DateTime(anchor.year),
        end: DateTime(anchor.year, 12, 31, 23, 59, 59, 999),
        label: '${anchor.year}年',
        shortLabel: '全年',
      );
    case StatsPeriod.all:
      // 由仓库补充首条记录时间；这里给出占位，shortLabel 固定。
      return StatsRange(
        start: DateTime(2000),
        end: DateTime.now(),
        label: '累计至今',
        shortLabel: '累计',
      );
  }
}
```

规则：

- 周一为一周起点（设计稿 6/24–6/30 即周一至周日）。
- 周期按设备本地时区；接口传 `tz` 时按该时区重算，客户端只负责展示。
- 结束时间为 `23:59:59.999`，用 `[start, end]` 闭区间比较。
- 未来周期不生成；锚点晚于今天时钳制到今天所在周期。
- `all` 的 `start` 由仓库取首条记录时间；无记录时 `start = end = now`，页面显示 0 / 空态。

### 6.2 环比与累计

```dart
StatsRange? previousRangeOf(StatsPeriod period, StatsRange current) {
  switch (period) {
    case StatsPeriod.week:
      return StatsRange(
        start: current.start.subtract(const Duration(days: 7)),
        end: current.end.subtract(const Duration(days: 7)),
        label: '', shortLabel: '',
      );
    case StatsPeriod.month:
      final prev = DateTime(current.start.year, current.start.month - 1);
      return resolveRange(StatsPeriod.month, prev);
    case StatsPeriod.halfYear:
      return resolveRange(
        StatsPeriod.halfYear,
        DateTime(current.start.year - 1, current.start.month),
      );
    case StatsPeriod.year:
      return resolveRange(StatsPeriod.year, DateTime(current.start.year - 1));
    case StatsPeriod.all:
      return null;
  }
}

({double? percent, TrendDirection trend}) compareWithPrevious(
  int currentCents,
  int? previousCents,
) {
  if (previousCents == null || previousCents == 0) {
    return (percent: null, trend: TrendDirection.none);
  }
  final percent = (currentCents - previousCents) / previousCents * 100;
  if (percent.abs() < 0.05) {
    return (percent: 0, trend: TrendDirection.flat);
  }
  return (
    percent: percent,
    trend: percent > 0 ? TrendDirection.up : TrendDirection.down,
  );
}
```

「累计 X.X 年」：

```dart
double? cumulativeYears(DateTime? firstRecordAt, DateTime now) {
  if (firstRecordAt == null) return null;
  final days = now.difference(firstRecordAt).inDays;
  if (days < 30) return null;         // 不足一个月显示「累计 N 天」由 presenter 处理
  return days / 365.25;
}
```

### 6.3 行驶里程与每公里成本

直接复用 `computeDistanceKmByVehicle(records)`：

- 按 `vehicleId` 分组，使用 `metrics.odometerKm` 的极差；
- 某车不足 2 条读数或极差 ≤ 0 时，兜底 `metrics.distanceKm` 求和；
- 多车时逐车计算后相加；
- 返回 `(km, source)`。

```dart
final distance = computeDistanceKmByVehicle(records);
final totalCents = records.fold(0, (sum, r) => sum + r.amountCents);
final energyCents = records
    .where((r) => r.category == ExpenseCategory.charging ||
                  r.category == ExpenseCategory.fuel)
    .fold(0, (sum, r) => sum + r.amountCents);

final costPerKmCents = distance.km <= 0 ? null : (totalCents / distance.km).round();
final energyCostPerKmCents = distance.km <= 0
    ? null
    : (energyCents / distance.km).round();
```

### 6.4 能耗

```dart
({double? kwhPer100km, double? litersPer100km}) consumptionOf(
  List<LedgerRecord> records,
  int distanceKm,
) {
  if (distanceKm <= 0) return (kwhPer100km: null, litersPer100km: null);
  final kwh = records
      .where((r) => r.category == ExpenseCategory.charging)
      .fold(0.0, (sum, r) => sum + (r.metrics.kwh ?? 0));
  final liters = records
      .where((r) => r.category == ExpenseCategory.fuel)
      .fold(0.0, (sum, r) => sum + (r.metrics.liters ?? 0));
  return (
    kwhPer100km: kwh > 0 ? kwh / distanceKm * 100 : null,
    litersPer100km: liters > 0 ? liters / distanceKm * 100 : null,
  );
}
```

按动力类型组装展示模型（presenter）：

| 动力 | primary | secondary | 单位 |
| --- | --- | --- | --- |
| EV | kwhPer100km | null | `kWh/100km` |
| HEV / ICE | litersPer100km | null | `L/100km` |
| PHEV | kwhPer100km | litersPer100km | 同上 |
| 全部车辆 | energyCostPerKmCents / 100 | null | `CNY/km` |

评分：

```dart
StatsRating ratingFor(double? current, double? baseline) {
  if (current == null || baseline == null || baseline <= 0) {
    return StatsRating.none;
  }
  final delta = (current - baseline) / baseline;
  if (delta <= -0.05) return StatsRating.excellent;
  if (delta >= 0.05) return StatsRating.high;
  return StatsRating.good;
}
```

- baseline = 该车（或车队）过去 6 个同长度周期的平均能耗；由 `MockStatsRepository` / 后端计算。
- 成本口径（全部车辆）不评分，固定 `StatsRating.fleet`。
- 基准不足 2 个周期时返回 `none`，UI 显示「—」。

### 6.5 构成与最大余数法

```dart
List<StatsCategorySlice> buildSlices(
  List<LedgerRecord> records,
  int totalCents,
) {
  final sums = <ExpenseCategory, int>{};
  final counts = <ExpenseCategory, int>{};
  for (final r in records) {
    if (r.amountCents == 0) continue;
    sums.update(r.category, (v) => v + r.amountCents, ifAbsent: () => r.amountCents);
    counts.update(r.category, (v) => v + 1, ifAbsent: () => 1);
  }
  var entries = sums.entries
      .where((e) => e.value > 0)
      .map((e) => _Slice(e.key, e.value, counts[e.key] ?? 0))
      .toList()
    ..sort((a, b) => b.amountCents.compareTo(a.amountCents));

  var otherMerged = false;
  if (entries.length > 6) {
    final keep = entries.take(5).toList();
    final rest = entries.skip(5);
    keep.add(_Slice(
      ExpenseCategory.other,
      rest.fold(0, (sum, s) => sum + s.amountCents),
      rest.fold(0, (sum, s) => sum + s.count),
    ));
    entries = keep;
    otherMerged = true;
  }

  // 单类 < 2% 并入「其他」
  if (entries.length > 2) {
    final small = entries.where((s) =>
        s.category != ExpenseCategory.other &&
        s.amountCents * 100 < totalCents * 2).toList();
    if (small.isNotEmpty) {
      final other = entries.firstWhere(
        (s) => s.category == ExpenseCategory.other,
        orElse: () => _Slice(ExpenseCategory.other, 0, 0),
      );
      entries = entries.where((s) => !small.contains(s)).toList()
        ..add(_Slice(
          ExpenseCategory.other,
          other.amountCents + small.fold(0, (sum, s) => sum + s.amountCents),
          other.count + small.fold(0, (sum, s) => sum + s.count),
        ))
        ..sort((a, b) => b.amountCents.compareTo(a.amountCents));
      otherMerged = true;
    }
  }

  final percents = largestRemainder(
    [for (final s in entries) s.amountCents],
    totalCents,
  );
  return [
    for (var i = 0; i < entries.length; i++)
      StatsCategorySlice(
        category: entries[i].category,
        amountCents: entries[i].amountCents,
        count: entries[i].count,
        percent: percents[i],
      ),
  ];
}

List<int> largestRemainder(List<int> amounts, int total) {
  if (total <= 0) return List<int>.filled(amounts.length, 0);
  final exact = [for (final a in amounts) a * 100 / total];
  final floors = [for (final v in exact) v.floor()];
  var diff = 100 - floors.fold(0, (a, b) => a + b);
  final order = List<int>.generate(amounts.length, (i) => i)
    ..sort((a, b) {
      final byFraction =
          (exact[b] - floors[b]).compareTo(exact[a] - floors[a]);
      return byFraction != 0 ? byFraction : a.compareTo(b);
    });
  for (var i = 0; i < diff; i++) {
    floors[order[i % order.length]]++;
  }
  return floors;
}
```

边界：

- 金额为负（退款）时，先按分类聚合；若合计 ≤ 0，UI 显示空态，不画环。
- `percent` 为 0 的分类仍可显示（金额 > 0 但占比 < 0.5%），但会被 < 2% 规则并入「其他」。
- 「其他」的颜色固定 `AppColors.other`，与分类枚举无关。

### 6.6 趋势分桶与坐标轴

```dart
List<StatsBucket> buildBuckets(
  List<LedgerRecord> records,
  StatsTrendRange range,
  DateTime anchor,
) {
  final now = DateTime(anchor.year, anchor.month, anchor.day);
  switch (range) {
    case StatsTrendRange.d7:
    case StatsTrendRange.d30:
      final days = range == StatsTrendRange.d7 ? 7 : 30;
      final start = now.subtract(Duration(days: days - 1));
      return [
        for (var i = 0; i < days; i++)
          _bucketForDay(records, DateTime(start.year, start.month, start.day + i)),
      ];
    case StatsTrendRange.halfYear:
    case StatsTrendRange.year:
      final months = range == StatsTrendRange.halfYear ? 6 : 12;
      final start = DateTime(now.year, now.month - (months - 1));
      return [
        for (var i = 0; i < months; i++)
          _bucketForMonth(records, DateTime(start.year, start.month + i)),
      ];
  }
}
```

- 日桶标签 `M/D`；月桶标签 `M月`；1 年窗口的 X 轴取 7 个等距点，可在季度首月显示 `24Q1` 形式。
- `dominantCategory`：桶内金额最大的分类；并列取枚举顺序靠前者。
- `peakIndex`：桶合计最大；并列取索引更大（更近）者。
- 上一窗口：窗口长度相同的紧邻前一段；`previousTotalCents` 为两条序列之和。

坐标轴：

```dart
StatsAxis buildAxis(List<StatsBucket> buckets) {
  final maxBucket = buckets.fold(0, (m, b) => math.max(m, b.totalCents));
  if (maxBucket <= 0) {
    return const StatsAxis(maxCents: 10000, ticksCents: [0, 2500, 5000, 7500, 10000]);
  }
  final step = _niceCeil(maxBucket / 3);
  final max = step * 3;
  return StatsAxis(
    maxCents: max,
    ticksCents: [0, step, step * 2, max],
  );
}

int _niceCeil(double value) {
  final magnitude = math.pow(10, (math.log(value) / math.ln10).floor()).toDouble();
  for (final m in const [1.0, 2.0, 5.0, 10.0]) {
    if (value <= m * magnitude) return (m * magnitude).round();
  }
  return (10 * magnitude).round();
}
```

示例：`maxBucket = ¥537` → `rawStep = 179` → `step = 200` → `max = 600`，刻度 `0/200/400/600`，与设计稿一致。

### 6.7 展示推导（presenter）

`stats_presenter.dart` 负责把模型转为具体文案，避免在 Widget 里写业务分支：

| 函数 | 输出 |
| --- | --- |
| `heroPeriodLabel(scope, range)` | `综合每公里成本 · 2024年6月` |
| `heroSubLabels(period)` | `('本月总开销', '本月行驶', '纯电能源成本')` |
| `changeLabel(period, trend, percent, changeText)` | `较上月 -8.2%` / `累计 2.1 年` / `暂无对比` |
| `consumptionFor(powertrain, data)` | 标题、单位、primary/secondary、图标 |
| `ratingLabel(rating)` | `优异` / `良好` / `偏高` / `车队` / `—` |
| `maintenanceStatusText(maintenance)` | `还有 1,574 km` / `已超期 320 km` / `请尽快保养` |
| `trendRangeLabel(range)` | `近 30 天` / `近 6 个月` / `近 1 年` |
| `breakdownBadge(period, count)` | `本月 · 共 6 笔` |
| `recordSubtitle(record, scope)` | `今天 08:42 · 42.6 kWh`，全部车辆时前置车辆短名 |

---

## 7. 数据层

### 7.1 仓库接口

```dart
abstract class StatsRepository {
  Future<StatsOverview> fetchOverview(StatsScope scope);
  Future<StatsBreakdown> fetchBreakdown(StatsScope scope);
  Future<StatsTrend> fetchTrend(StatsTrendQuery query);
  Future<List<StatsRecord>> fetchRecent(StatsScope scope, {int limit = 3});
}

abstract class StatsApi {
  Future<Map<String, dynamic>> getOverview({...});
  Future<Map<String, dynamic>> getBreakdown({...});
  Future<Map<String, dynamic>> getTrend({...});
  Future<Map<String, dynamic>> getRecent({...});
}
```

### 7.2 接口

| 方法 | 路径 | 用途 | 时机 |
| --- | --- | --- | --- |
| GET | `/api/v1/stats/overview?vehicleIds=&period=&anchor=&tz=` | Hero + 能耗 + 保养 | 进入 / 切车 / 切周期 / 刷新 |
| GET | `/api/v1/stats/breakdown?vehicleIds=&period=&anchor=&tz=` | 环形图与图例 | 同上 |
| GET | `/api/v1/stats/trend?vehicleIds=&range=&anchor=&tz=` | 趋势卡 | 进入 / 切车 / 切粒度 / 刷新 |
| GET | `/api/v1/stats/recent?vehicleIds=&period=&anchor=&limit=3` | 最近记录 | 同上 |

- `vehicleIds=all` 或逗号分隔；`period`、`range` 枚举见 §5.1。
- `anchor=YYYY-MM-DD`；服务端按 `tz` 解析为周期锚点。
- 响应字段与错误码见 §7.4。

### 7.3 Mock 实现

`MockStatsRepository` 复用一个 `MockLedgerRepository`（记录来源）与 `HomeRepository`（车辆 + 保养数据）：

```dart
class MockStatsRepository implements StatsRepository {
  MockStatsRepository({
    required this.ledger,
    required this.home,
    this.delay = const Duration(milliseconds: 120),
  });

  final MockLedgerRepository ledger;
  final HomeRepository home;
  final Duration delay;
```

M0 在 `MockLedgerRepository` 上新增一个只读方法，供统计一次取全范围：

```dart
/// 统计 / 报表测试使用：同步返回 [from, to] 内的未删除记录。
List<LedgerRecord> recordsBetween(DateTime from, DateTime to) {
  final result = <LedgerRecord>[];
  var cursor = DateTime(from.year, from.month);
  final end = DateTime(to.year, to.month);
  while (!cursor.isAfter(end)) {
    for (final record in _recordsFor(cursor)) {
      if (_deletedIds.contains(record.id)) continue;
      if (record.occurredAt.isBefore(from) || record.occurredAt.isAfter(to)) {
        continue;
      }
      result.add(record);
    }
    cursor = DateTime(cursor.year, cursor.month + 1);
  }
  return result;
}
```

这样「全部 / 30 天 / 半年」无需逐月走 `fetchRecords` 的 160ms 延迟，Mock 页面仍然流畅；生产环境由服务端聚合。

Mock 规则：

- 车辆列表取 `home.fetchVehicles()`；
- 保养取 `home.fetchDashboard(vehicleId).maintenance`，全部车辆时选 `remainingKm` 最小者；
- 记录取 `ledger.recordsBetween(range.start, range.end)`，按 `vehicleId` 过滤；
- 分类、金额、笔数与账单页来自同一批记录，保证一致性；
- 提供 `failureSwitch`（枚举 module）用于 Widget 测试注入错误；
- 延迟可配置，测试传 `Duration.zero`。

### 7.4 接口契约（后端实现依据）

#### 7.4.1 通用约定

| 项 | 约定 |
| --- | --- |
| Base URL | `/api/v1` |
| 认证 | `Authorization: Bearer <access_token>`；401 跳登录 |
| 金额 | 整数分，禁止浮点；每公里成本为「分/公里」整数 |
| 时间 | ISO 8601 带偏移，如 `2026-11-14T18:30:00+08:00` |
| 日期 | `YYYY-MM-DD` |
| 时区 | IANA 名称，默认 `Asia/Shanghai` |
| 枚举 | `period`：`week\|month\|half_year\|year\|all`；`range`：`7d\|30d\|6m\|1y`；`trend`：`up\|down\|flat\|none`；`rating`：`excellent\|good\|high\|fleet\|none` |
| 空值 | 无法计算用 `null`，0 用 `0` |
| 一致性 | 同一 `vehicleIds + period + anchor + tz` 的 `overview.totalCents` 必须等于 `breakdown.totalCents` |
| 版本 | `schemaVersion` 当前 1；不兼容变更升版本 |

#### 7.4.2 `GET /api/v1/stats/overview`

**Query**

| 参数 | 类型 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- | --- |
| `vehicleIds` | string | 否 | `all` | `all` 或逗号分隔，最多 10 个 |
| `period` | enum | 否 | `month` | 见上 |
| `anchor` | date | 否 | 今天 | 周期锚点日期 |
| `tz` | string | 否 | `Asia/Shanghai` | 非法值返回 `INVALID_TIMEZONE` |

**Response 200**

```json
{
  "schemaVersion": 1,
  "scope": {
    "vehicleIds": ["byd-han-ev"],
    "period": "month",
    "anchor": "2026-11-14",
    "from": "2026-11-01T00:00:00+08:00",
    "to": "2026-11-30T23:59:59+08:00",
    "label": "2026年11月"
  },
  "timezone": "Asia/Shanghai",
  "dataUpdatedAt": "2026-11-14T18:25:00+08:00",
  "summary": {
    "totalCents": 128600,
    "distanceKm": 2140,
    "distanceSource": "odometer",
    "costPerKmCents": 60,
    "energyCents": 38600,
    "energyCostPerKmCents": 18,
    "previousTotalCents": 140100,
    "changePercent": -8.2,
    "changeTrend": "down",
    "changeText": null,
    "cumulativeYears": null
  },
  "consumption": {
    "rating": "good",
    "primary": { "value": 14.8, "unit": "kWh/100km" },
    "secondary": null,
    "sparkline": [15.2, 14.9, 14.6, 14.8, 14.5, 14.7]
  },
  "maintenance": {
    "enabled": true,
    "vehicleId": "byd-han-ev",
    "vehicleName": "比亚迪 汉 EV",
    "tag": "小保养",
    "remainingKm": 1574,
    "remainingDays": 22,
    "progressPercent": 72,
    "status": "normal"
  }
}
```

字段补充：

| 字段 | 说明 |
| --- | --- |
| `scope.from/to` | 服务端按 `anchor + period + tz` 解析，客户端以此为准展示 |
| `costPerKmCents` | `totalCents / distanceKm` 四舍五入；`distanceKm = 0` 时为 `null` |
| `energyCostPerKmCents` | 能源（充电 + 加油）÷ 里程；无里程为 `null` |
| `changePercent` | 与上一周期比较；`period=all` 时为 `null` |
| `changeText` | 仅当无法用百分比表达时返回，如「累计 2.1 年」 |
| `cumulativeYears` | 仅 `period=all` 返回，1 位小数 |
| `consumption.primary.unit` | `kWh/100km` / `L/100km` / `CNY/km` |
| `consumption.secondary` | 仅 PHEV 返回 |
| `maintenance.vehicleId` | 全部车辆时为「最紧迫」车辆；单车主时为该车 |
| `maintenance.status` | `normal\|warning\|overdue` |

#### 7.4.3 `GET /api/v1/stats/trend`

**Query**：`vehicleIds`、`range=7d|30d|6m|1y`、`anchor`、`tz`。

**Response 200**

```json
{
  "schemaVersion": 1,
  "range": "30d",
  "from": "2026-10-16T00:00:00+08:00",
  "to": "2026-11-14T23:59:59+08:00",
  "totalCents": 128600,
  "previousTotalCents": 140100,
  "changePercent": -8.2,
  "changeTrend": "down",
  "axis": { "maxCents": 60000, "ticksCents": [0, 20000, 40000, 60000] },
  "peakIndex": 14,
  "buckets": [
    {
      "label": "6/1",
      "start": "2026-06-01",
      "energyCents": 1200,
      "otherCents": 0,
      "totalCents": 1200,
      "dominantCategory": "charging",
      "count": 1
    }
  ]
}
```

规则：

- `buckets.length` 固定：`7d → 7`、`30d → 30`、`6m → 6`、`1y → 12`。
- 无记录的桶也必须返回（金额 0），客户端按索引绘图，不自行补点。
- `peakIndex` 为合计最大的桶；全 0 时为 `null`。
- `axis` 可由服务端计算；若缺失，客户端用 §6.6 的纯函数兜底。
- `dominantCategory` 为桶内金额最大分类；无记录为 `null`。

#### 7.4.4 `GET /api/v1/stats/breakdown`

```json
{
  "schemaVersion": 1,
  "totalCents": 128600,
  "count": 6,
  "categories": [
    { "key": "maintenance", "label": "保养", "amountCents": 48000, "count": 1, "percent": 37 },
    { "key": "charging", "label": "充电", "amountCents": 38600, "count": 1, "percent": 30 }
  ],
  "otherMerged": false
}
```

- 服务端可直接返回合并后的分类；若返回原始分类，客户端按 §6.5 合并。
- `percent` 合计必须为 100（最大余数法）。
- `count` 为记录笔数，不是分类数。

#### 7.4.5 `GET /api/v1/stats/recent`

```json
{
  "schemaVersion": 1,
  "items": [
    {
      "id": "rec_01",
      "vehicleId": "byd-han-ev",
      "vehicleName": "汉 EV",
      "category": "charging",
      "title": "特来电科技园快充",
      "subtitle": "42.6 kWh",
      "occurredAt": "2026-11-14T08:42:00+08:00",
      "amountCents": 5110,
      "tag": "¥0.17/km"
    }
  ]
}
```

- 按 `occurredAt` 倒序，`limit` 默认 3，最大 10。
- `tag` 由服务端按分类给出：充电 / 加油为单价型每公里成本，保养为类型，停车为停车性质；无则 `null`。

#### 7.4.6 错误码

| HTTP | code | 场景 | 客户端处理 |
| --- | --- | --- | --- |
| 400 | `INVALID_PERIOD` | period / range 非法 | 回退默认月度并 Toast |
| 400 | `INVALID_TIMEZONE` | tz 非法 | 用本地时区重试一次 |
| 401 | `UNAUTHORIZED` | 登录过期 | 跳登录 |
| 403 | `VEHICLE_FORBIDDEN` | 无权访问某车 | 从范围移除并重试 |
| 404 | `VEHICLE_NOT_FOUND` | 车辆已删除 | 回退全部车辆 |
| 422 | `RANGE_TOO_LARGE` | 全部范围数据过大 | 降级为最近 12 个月并提示 |
| 500 | `INTERNAL` | 服务端异常 | 卡片级错误 + 重试 |

### 7.5 竞态与缓存

```dart
class StatsRepositoryImpl implements StatsRepository {
  int _generation = 0;

  @override
  Future<StatsOverview> fetchOverview(StatsScope scope) async {
    final gen = ++_generation;
    final json = await api.getOverview(...);
    if (gen != _generation) throw const StaleStatsResponse();
    return StatsOverviewMapper.fromJson(json);
  }
}
```

- 每个方法独立 generation；也可以按 scope 维度维护 `Map<String, int>`，避免趋势请求取消概览请求。
- UI 对 `StaleStatsResponse` 静默忽略。
- 内存缓存 key：`stats:overview:{vehicleId|all}:{period}:{anchor}`，TTL 60s；`refresh()` 清空当前 scope。
- 概览与构成必须同源：若两者 `totalCents` 不一致，构成重试一次；仍不一致则 Toast「数据已更新，请刷新」并显示概览值。
- 记账 / 删除后：`ref.invalidate(statsOverviewProvider(scope))` 等；或监听 M4 新增的 `expenseMutationTickProvider` 统一失效。

---

## 8. 状态管理

### 8.1 Provider 设计

```dart
final mockLedgerRepositoryProvider = Provider<MockLedgerRepository>(
  (ref) => MockLedgerRepository(),
); // 当前由 ledger/providers.dart 提供，统计页直接复用

final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => MockStatsRepository(
    ledger: ref.watch(mockLedgerRepositoryProvider),
    home: ref.watch(homeRepositoryProvider),
  ),
);

/// 页面筛选：范围 + 周期 + 锚点。非 autoDispose，切 Tab 回来保留。
final statsFilterProvider =
    NotifierProvider<StatsFilterNotifier, StatsFilter>(StatsFilterNotifier.new);

class StatsFilterNotifier extends Notifier<StatsFilter> {
  @override
  StatsFilter build() => StatsFilter(
    // 只读取一次初始值，不跟踪首页选中车辆，避免首页切车时重置统计页筛选。
    vehicleId: ref.read(selectedVehicleIdProvider),
    anchor: DateTime.now(),
  );

  void selectVehicle(String? vehicleId) { ... }
  void selectPeriod(StatsPeriod period) { ... }
  void selectAnchor(DateTime anchor) { ... }
}

final statsOverviewProvider = FutureProvider.autoDispose
    .family<StatsOverview, StatsScope>((ref, scope) {
      return ref.watch(statsRepositoryProvider).fetchOverview(scope);
    });

final statsBreakdownProvider = FutureProvider.autoDispose
    .family<StatsBreakdown, StatsScope>((ref, scope) { ... });

final statsRecentProvider = FutureProvider.autoDispose
    .family<List<StatsRecord>, StatsScope>((ref, scope) { ... });

/// 趋势粒度独立；默认跟随页面周期映射。
final statsTrendRangeProvider =
    NotifierProvider<StatsTrendRangeNotifier, StatsTrendRange>(
      StatsTrendRangeNotifier.new,
    );

class StatsTrendRangeNotifier extends Notifier<StatsTrendRange> {
  @override
  StatsTrendRange build() => StatsTrendRange.d30;

  void select(StatsTrendRange range) { ... }

  void applyPeriodDefault(StatsPeriod period) {
    state = switch (period) {
      StatsPeriod.week => StatsTrendRange.d7,
      StatsPeriod.month => StatsTrendRange.d30,
      StatsPeriod.halfYear => StatsTrendRange.halfYear,
      StatsPeriod.year || StatsPeriod.all => StatsTrendRange.year,
    };
  }
}

final statsTrendProvider = FutureProvider.autoDispose
    .family<StatsTrend, StatsTrendQuery>((ref, query) {
      return ref.watch(statsRepositoryProvider).fetchTrend(query);
    });
```

联动规则：

- 周期胶囊点击：

```dart
void _selectPeriod(WidgetRef ref, StatsPeriod period) {
  ref.read(statsFilterProvider.notifier).selectPeriod(period);
  ref.read(statsTrendRangeProvider.notifier).applyPeriodDefault(period);
}
```

- 车辆胶囊 / 弹层点击：只改 `statsFilterProvider`；选具体车辆时同步 `selectedVehicleIdProvider`（需求 Q10），选「全部车辆」不回写。
- 粒度胶囊点击：只改 `statsTrendRangeProvider`。
- 下拉刷新：`ref.invalidate(statsOverviewProvider(scope))`、`statsBreakdownProvider(scope)`、`statsRecentProvider(scope)`、`statsTrendProvider(query)`；`await` 概览 future 后结束刷新动画。

### 8.2 失效矩阵

| 操作 | overview | breakdown | recent | trend | 说明 |
| --- | --- | --- | --- | --- | --- |
| 切车辆范围 | ✅ | ✅ | ✅ | ✅ | 全部重建 |
| 切页面周期 | ✅ | ✅ | ✅ | ✅ | 趋势粒度先重置再重建 |
| 切趋势粒度 | — | — | — | ✅ | 只动趋势 |
| 切锚点 | ✅ | ✅ | ✅ | ✅ | 同周期切换 |
| 下拉刷新 | ✅ | ✅ | ✅ | ✅ | 清缓存 |
| 记账 / 删除 / 编辑 | ✅ | ✅ | ✅ | ✅ | 当前 scope 失效 |
| 主题切换 | — | — | — | — | 只重建颜色 |

### 8.3 状态展示

| 状态 | Hero | 双指标 | 趋势 | 构成 | 最近记录 |
| --- | --- | --- | --- | --- | --- |
| 加载中 | 骨架 | 骨架 | 骨架 | 骨架 | 骨架 |
| 有缓存 | 直接显示 | 直接显示 | 直接显示 | 直接显示 | 直接显示 |
| 失败 | 「汇总加载失败 · 重试」 | 各自错误 | 「走势加载失败 · 重试」 | 「构成加载失败 · 重试」 | 「记录加载失败 · 重试」 |
| 空范围 | 0 / `—` | 能耗 `—`、保养照常 | 空态 | 0 / 空态 | 空态 + 去记一笔 |
| 离线 | 缓存 + 顶部细条 | 同左 | 同左 | 同左 | 同左 |

---

## 9. UI 实现

### 9.1 页面骨架

```dart
class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key, required this.scrollController});
  final ScrollController scrollController;
  ...
}

class _StatsView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 448),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: context.palette.primary,
            onRefresh: () => _refresh(ref),
            child: CustomScrollView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: BlurredHeaderDelegate(
                    height: tokens.headerHeight,
                    child: const StatsHeader(),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    tokens.pagePadding,
                    tokens.spaceSm,
                    tokens.pagePadding,
                    tokens.contentBottomPadding + bottomInset,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const StatsPeriodBar(),
                      SizedBox(height: tokens.spaceMd),
                      const StatsHeroCard(),
                      SizedBox(height: tokens.spaceMd),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Expanded(child: StatsEnergyCard()),
                            SizedBox(width: tokens.gutter),
                            const Expanded(child: StatsMaintenanceCard()),
                          ],
                        ),
                      ),
                      SizedBox(height: tokens.spaceMd),
                      const StatsTrendCard(),
                      SizedBox(height: tokens.spaceMd),
                      const StatsBreakdownCard(),
                      SizedBox(height: tokens.spaceMd),
                      const StatsRecentRecords(),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- 与 `HomePage` / `LedgerPage` 一致：页面不自带 Scaffold / 底部导航，由 `AppTabShell` 统一持有。
- 周期切换不重建整个 `CustomScrollView`；各卡片 `watch` 自己的 provider。
- `IntrinsicHeight + Row` 让双指标卡等高；卡片内部用 `Spacer` 让底部走势 / 进度环对齐。

### 9.2 顶部栏 `StatsHeader`

- 由 `AppTabHeader` 组合：
  - `title: '数据统计'`，`showGreeting: true`；
  - `trailing: Row([StatsVehiclePill, SizedBox(8), StatsNotificationButton])`。
- `StatsVehiclePill`：读 `statsFilterProvider` 与 `vehiclesProvider`，展示圆点颜色（按动力类型；全部车辆用 `tertiary`）+ 名称 + `keyboard_arrow_down`。
- 点击打开 `StatsVehicleSheet`：

```dart
showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => const StatsVehicleSheet(),
);
```

- 弹层内容：
  - 顶部 48×4 拖拽条；
  - 标题「选择爱车」+ `directions_car`；
  - 列表：`全部车辆（汇总）`（副标题 `共 N 辆车合并核算`）+ 每辆车（动力胶囊、车牌）；
  - 选中项 `border: primary 20%`、`bg: primary 8%`、右侧 `check_circle`。
- 状态：`vehiclesProvider.when(...)`；无车辆时显示「添加爱车」按钮（跳车辆管理页，P1 若未接入则 Toast）。

### 9.3 周期区 `StatsPeriodBar`

- 外层 `Row`：左侧 5 段胶囊托盘（`Container` 白底 + 阴影 + `Row`），右侧日期胶囊。
- 胶囊托盘使用 `SingleChildScrollView(horizontal)` 兜底 375pt 以下宽度（正常 375pt 可完整放下）。
- 选中态：`AnimatedContainer(duration: 180ms)`，背景 `palette.onSurface`，文字 `palette.surface`，其余透明。
- 日期胶囊：`calendar_month` 图标 + `range.label`；`period == all` 时禁用点击。
- 点击日期胶囊打开周期选择器：
  - 月度：复用账单页 `LedgerMonthPickerSheet` 的交互模式（新建 `StatsAnchorSheet`，避免 feature 间耦合）。
  - 周：左右箭头切换上一周 / 下一周，下一周不可超过本周。
  - 半年：年份 + 上 / 下半年列表。
  - 年度：年份列表。
  - 范围：最近 24 个月 / 年份；更早数据仍可请求，但 Mock 为空。

### 9.4 Hero 卡 `StatsHeroCard`

- 复用 `HeroWaveBackground`（M0 抽取的 `CustomPaint`）叠在渐变容器上：

```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [palette.heroStart, palette.heroMid, palette.heroEnd],
    ),
    borderRadius: BorderRadius.circular(tokens.radiusCard),
    boxShadow: tokens.heroShadow,
  ),
  child: Stack(
    children: [
      const Positioned.fill(child: HeroWaveBackground()),
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(...),
      ),
    ],
  ),
)
```

- 顶部两枚胶囊：`Container` + `palette.surface.withValues(alpha: 0.20)`；上涨时 `AppColors.rise.withValues(alpha: 0.30)`。
- 主数值：`Text.rich` 或 `Row(crossAxisAlignment: baseline)`；整数与小数用 `formatTwoDecimals` 拆成 `0` 与 `.60`，整数 38px、小数同字号（设计稿统一 38px），`¥` 16px。
- 三列子指标：`Row` + 两个 `Container(width: 1, color: white 20%)` 分隔；`Expanded` 等宽。
- 骨架：`SkeletonBox` 覆盖标题、38px 数值、三列；高度与真实卡一致，避免切换时跳动。

### 9.5 双指标卡

**能耗卡 `StatsEnergyCard`**

```dart
AppCard(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [iconBadge, Spacer(), ratingChip]),
      const SizedBox(height: 10),
      Text(title, style: AppTypography.bodySm.copyWith(color: palette.outline)),
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        children: [
          Text(formatOneDecimal(value), style: AppTypography.headlineLg),
          const SizedBox(width: 4),
          Flexible(child: Text(unit, style: AppTypography.labelSm)),
        ],
      ),
      if (secondary != null) secondaryRow,
      const Spacer(),
      SizedBox(
        height: 32,
        child: CustomPaint(painter: SparklinePainter(primary: sparkline)),
      ),
    ],
  ),
)
```

- 插混第二行：橙色 14px/700，带 `+` 或换行；间距 6px。
- 评级胶囊：背景 `palette.surfaceContainer`，文字 `palette.outline`；`偏高` 用 `palette.error` 文字。
- 无走势数据时 `SizedBox(height: 32)` 占位，保持两卡等高。

**保养卡 `StatsMaintenanceCard`**

- 复用 `ProgressRing`（M0 抽取）：

```dart
ProgressRing(
  size: 32,
  strokeWidth: 3.5,
  progress: maintenance.progressPercent / 100,
  color: warning ? palette.error : palette.secondary,
  trackColor: palette.surfaceContainer,
  child: Text('${maintenance.progressPercent}%', style: AppTypography.labelSm),
)
```

- 状态色：正常 `secondary`；警示 / 超期 `error`；未设置时整卡显示 `OutlinedButton`。
- 全部车辆：标题下方 11px 文案 `凯美瑞 · 最紧迫`；类型胶囊使用该车类型。

### 9.6 趋势卡 `StatsTrendCard`

结构：

```
AppCard(padding: 20)
├── Row(title, legend)
├── Row(total, change, scopeLabel)
├── RangeSwitcher (7天/30天/半年/1年)
└── SizedBox(height: 176, child: RepaintBoundary(StatsTrendChart))
```

- 合计旁显示 `近 30 天`（`labelMd`，`outline`），解决与 Hero 口径不同的歧义。
- 粒度切换：`AnimatedContainer` 白底选中；点击后只改 `statsTrendRangeProvider`。
- 图例：绿点 + `能源(充/油)`；橙点 + `其他开销`（需求 Q6 建议；若产品坚持「维保与路费」只改文案）。
- 空态：保留坐标轴，中央文案「该区间暂无开销记录」。

### 9.7 趋势图 `StatsTrendChart`

基于 `fl_chart`，与首页 `TrendCard` 保持同一套视觉参数：

```dart
LineChart(
  LineChartData(
    minX: 0,
    maxX: (buckets.length - 1).toDouble(),
    minY: 0,
    maxY: axis.maxCents / 100,
    borderData: FlBorderData(show: false),
    gridData: FlGridData(
      drawVerticalLine: false,
      horizontalInterval: axis.ticksCents[1] / 100,
      getDrawingHorizontalLine: (value) => FlLine(
        color: palette.outlineVariant.withValues(alpha: 0.6),
        strokeWidth: 1,
        dashArray: const [4, 4],
      ),
    ),
    titlesData: FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 34,
          interval: axis.ticksCents[1] / 100,
          getTitlesWidget: (value, meta) => SideTitleWidget(
            meta: meta,
            space: 4,
            child: Text(
              formatYuanAxis(value),
              style: AppTypography.labelSm.copyWith(
                fontSize: 9, color: palette.outline,
              ),
            ),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 24,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final index = value.round();
            if (!axisLabelIndices.contains(index)) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(buckets[index].label, style: axisStyle),
            );
          },
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    ),
    lineTouchData: LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) => palette.onSurface.withValues(alpha: 0.94),
        getTooltipItems: (spots) {
          // 只返回一条合成文案：{日期} {主分类} {金额}
          ...
        },
      ),
    ),
    lineBarsData: [
      _bar(buckets, (b) => b.otherCents, palette.secondary),
      _bar(buckets, (b) => b.energyCents, palette.primary),
    ],
  ),
  duration: const Duration(milliseconds: 400),
  curve: Curves.easeOutCubic,
)
```

`_bar` 参数与首页一致：

- `isCurved: true`、`curveSmoothness: 0.32`、`preventCurveOverShooting: true`；
- `barWidth: 2.5`、`isStrokeCapRound: true`；
- `belowBarData` 使用同色渐变（顶部 30% → 底部 0）；
- 峰值点：`dotData` 的 `checkToShowDot` 仅在 `index == peakIndex` 时返回 `true`，`radius: 4`，白色填充 + 同色描边（与设计稿一致）；
- 触摸时 `handleBuiltInTouches: true`，`getTooltipItems` 只输出合并文案；避免两条序列各弹一个气泡。

X 轴 7 个标签：

```dart
List<int> axisLabelIndices(int length) {
  if (length <= 7) return List.generate(length, (i) => i);
  return [
    for (var i = 0; i < 7; i++) (i * (length - 1) / 6).round(),
  ];
}
```

`formatYuanAxis(value)`：≥ 1000 显示 `¥1.2k`（或千分位），否则 `¥600`；与设计稿一致，9px。

### 9.8 构成卡 `StatsBreakdownCard`

- 复用 `AppCard`；标题行 + 徽章。
- 左右布局：环图 128×128，图例 `Expanded`。
- 环图：

```dart
PieChart(
  PieChartData(
    startDegreeOffset: -90,
    centerSpaceRadius: 50,
    sectionsSpace: 2,
    sections: [
      for (final slice in breakdown.categories)
        PieChartSectionData(
          value: slice.amountCents.toDouble(),
          color: slice.category.color,
          radius: 14,
          showTitle: false,
        ),
    ],
  ),
  duration: const Duration(milliseconds: 500),
  curve: Curves.easeOutCubic,
)
```

- 中心：`合计支出` 10px + `¥1,286` 16px/700。
- 图例行：色点 10×10 + 分类名 13px/600 + 金额 16px/700 + 百分比 10px/400；行间 6px。
- 无数据：浅灰底环（`palette.surfaceContainer`）+ 中心 `¥0.00` + 右侧空态文案。
- 点击图例（P1）：

```dart
ref.read(ledgerFilterProvider.notifier)
  ..selectVehicle(scope.vehicleId)
  ..selectCategory(slice.category)
  ..selectMonth(monthOf(range.end));
ref.read(appTabProvider.notifier).select(AppTab.ledger);
```

- 若产品要求「其他」不可点击，则 `slice.category == ExpenseCategory.other` 时只切 Tab 不筛分类。

### 9.9 最近记录 `StatsRecentRecords`

- 复用 `AppCard`，标题「最近开销记录」+ `查看全部 >`。
- 行结构与首页 `RecentRecords` 类似，但数据源为 `statsRecentProvider`，且副信息包含车辆短名（全部车辆时）。
- 分类图标底色：`category.softColor`；图标色：`category.color`。
- 右侧标签：`record.tag`（接口给出 `¥0.17/km` / `小保养` / `临时停车`）；无则不渲染。
- 点击：`Navigator.push(ExpenseDetailPage(recordId: record.id))`；返回后失效当前 scope。
- 「查看全部」：切到账单 Tab；月度直接带月份 + 车辆，其他周期映射到 `range.end` 所在月（需求 Q13）。

### 9.10 主题与无障碍

- 深色主题使用 `context.palette` / `context.tokens`；Hero 渐变沿用 `heroStart/Mid/End`（深色下保持绿，白字可读）。
- 图表颜色从 palette 取，禁止硬编码；分类色用 `AppColors`（语义色不随明暗切换）。
- `Semantics`：
  - Hero：`综合每公里成本 0.60 元，较上月下降 8.2%`。
  - 能耗卡：`平均百公里电耗 14.8 千瓦时，评级良好`。
  - 保养卡：`下次小保养还有 1,574 公里，预计 22 天`。
  - 趋势图：`近 30 天花费 1,286 元，峰值 6 月 15 日保养 480 元`。
  - 环图：逐行朗读 `保养 480 元，占 37%`。
- 点击区域 ≥ 44×44（胶囊、图例行、日期胶囊）。
- 字号放大 1.3 倍：Hero 数字 `FittedBox(fit: BoxFit.scaleDown)`；图表坐标轴固定 9px；图例允许换行。

---

## 10. 性能

| 项 | 目标 | 措施 |
| --- | --- | --- |
| 首屏 | ≤ 1s 可交互 | 懒加载 Tab；概览与构成并行请求；骨架不等图片 |
| 周期 / 车辆切换 | ≤ 500ms | 内存缓存（60s）；只失效变化的 scope |
| 图表交互 | 60fps | `RepaintBoundary`；图表内部状态（选中点）不触发整页重建 |
| 聚合 | 主线程不卡顿 | Mock 用一次性内存聚合；生产由服务端聚合；客户端只合并分类与分桶 |
| 列表 | 3 条记录，无需虚拟化 | `Column` 足够 |
| 动画 | 400–500ms | 曲线 / 环图使用 `implicit` 动画；避免同时触发多个大范围重绘 |
| 包体 | 不增加 | 不引入图表 / 状态库新依赖 |

注意：

- `statsOverviewProvider` 与 `statsBreakdownProvider` 都依赖 `StatsScope`；`StatsScope` 必须实现 `==` / `hashCode`，否则 Riverpod family 每次重建都会重新请求。
- `StatsTrendQuery` 同理。
- 全部车辆「全部」范围在真实数据下可能过大；客户端在请求前检查记录数上限，超限降级为最近 12 个月并提示（与契约 422 对应）。

---

## 11. 错误与边界

| 场景 | 处理 |
| --- | --- |
| 车辆列表为空 | 整页空态；不请求统计接口；「添加爱车」跳转 |
| 当前车辆被删除 | `statsFilter` 回退「全部车辆」；Toast；重新请求 |
| 周期内无记录 | 所有金额 0；每公里 / 能耗 `—`；趋势、构成、最近记录空态；保养卡照常 |
| 里程 = 0 | `costPerKmCents` / `energyCostPerKmCents` 为 null → `—`；不显示 `Infinity` / `NaN` |
| 上一周期无数据 | `changePercent = null`，文案「暂无对比」 |
| 分类合计 ≠ Hero 合计 | 构成重试一次；仍不一致则提示刷新，不展示错误合计 |
| 记录金额为负（退款） | 按记录聚合；合计 ≤ 0 时构成空态 |
| 单分类占比极小 | 按 < 2% 规则并入「其他」 |
| 图表只有 1 个点 | 画点 + 水平线，不画曲线；提示可用 |
| 图表全 0 | Y 轴上限 `¥100`；不显示峰值气泡 |
| 日期跨年 / 闰年 | 用 `DateTime(y, m + 1, 0)` 取月末；单测覆盖 2024-02、2024-12、2025-01 |
| 未来周期 | 锚点钳制到今天所在周期；选择器禁止未来 |
| 接口 401 | 跳登录；返回后恢复筛选 |
| 接口 403 某车 | 从范围移除该车并重试；若只剩 0 辆 → 全部车辆 |
| 接口 422 范围过大 | 降级最近 12 个月 + 顶部提示 |
| 离线 | 会话缓存 + 顶部提示；无缓存则卡片错误态 |
| 快速连点 | generation 丢弃旧响应；选中态只跟最后一次 |

---

## 12. 测试方案

### 12.1 单元测试

`test/stats/stats_period_test.dart`

- 周一为一周起点；周日 23:59:59 属于本周；跨年周（2026-12-28 至 2027-01-03）。
- 月度边界：2 月（闰年 / 平年）、12 月、当前月。
- 半年：1–6 月 → 上半年；7–12 月 → 下半年；锚点为 6/30 与 7/1。
- 年度边界；未来锚点钳制。
- `previousRangeOf` 每种周期正确。
- 标签：`2024年6月`、`2024上半年`、`本周 (6/24–6/30)`、`累计至今`。

`test/stats/stats_aggregation_test.dart`

- 总开销 = 记录之和；能源 = 充电 + 加油。
- 里程：读数极差优先；不足 2 条用单笔距离；极差 ≤ 0 用兜底；多车相加。
- `costPerKmCents` / `energyCostPerKmCents` 在里程 0 时为 null。
- 电耗 / 油耗计算与四舍五入；插混双值；无对应记录为 null。
- 最大余数法：`[1,1,1] → 34/33/33`；`[1,2] → 33/67`；合计始终 100。
- 分类合并：>6 类、<2% 类、只有 1 类、0 类。
- 趋势分桶：7d → 7 桶、30d → 30、6m → 6、1y → 12；桶边界不重叠。
- 峰值索引：并列取更近；全 0 为 null。
- 坐标轴：537 → 600（step 200）；0 → 100；1200 → 1500（step 500）。
- 环比：上期为 0 / 本期 0 / 持平。
- 评分阈值：-5% / +5% 边界。

`test/stats/stats_presenter_test.dart`

- Hero 周期标签、子指标标签、环比文案。
- 四类动力的能耗标题 / 单位 / 双行。
- 评级文案与颜色。
- 保养四种状态文案。
- 全部车辆的最紧迫保养选择。
- 记录副标题与标签。

`test/stats/mock_stats_repository_test.dart`

- 概览与构成总额一致；笔数一致。
- 全部车辆 = 各车之和；分类金额与账单页同范围一致。
- 空范围返回 0 而不是异常。
- 保养最紧迫选择正确。
- `recordsBetween` 与 `fetchRecords` 结果一致。

### 12.2 Widget 测试

`test/stats/stats_page_test.dart`

- 进入统计 Tab：标题「数据统计」、5 个周期胶囊、Hero、双指标、趋势、构成、最近记录均渲染。
- 点击「周」：Hero 标签变「本周」、日期胶囊变本周、趋势粒度自动变「7天」。
- 点击「半年」：子指标标签变「上半年总开销」。
- 点击车辆胶囊：弹层出现 4 项；选中凯美瑞后 Hero / 能耗 / 保养标题更新。
- 点击「全部车辆」：能耗卡显示「综合能耗成本」，保养卡显示车辆名。
- 切换趋势粒度「7天」：仅趋势合计变化，Hero 不变。
- 空数据：趋势 / 构成 / 记录显示空态，Hero 显示 `¥0.00`。
- 概览失败：Hero 错误态，其他卡片正常；点击重试后恢复。
- 深色模式：无硬编码白底（可用 golden 或关键颜色断言）。
- 重复点击统计 Tab：滚动回顶部（若可测）。

### 12.3 手工验收

- iPhone 刘海 / Android 手势导航下底部与 FAB 位置。
- 字号放大 1.3 倍。
- 弱网 / 断网 / 登录过期。
- 24 个月历史数据切换流畅度。
- 快速连点车辆与周期。
- 浅色 / 深色截图对照设计稿。

### 12.4 CI

- `flutter analyze` 零 warning（沿用现有 lint）。
- `flutter test` 全绿；新增测试不得降低覆盖率门槛（仓库当前无强制门槛）。
- 不新增依赖，`pubspec.lock` 无变化。
- PR 阶段不构建 APK；合并后由 `flutter-android.yml` 打包。

---

## 13. 实施拆分

### M0 · 公共能力与壳改造

- 新增 `app/tab.dart`（`AppTab` + `appTabProvider`），改造 `AppTabShell` 使用 provider；index 2 替换为 `StatsPage` 占位。
- 抽取 `core/widgets/app_tab_header.dart`、`hero_wave_background.dart`、`progress_ring.dart`、`sparkline.dart`，改造首页引用。
- 迁移 `computeDistanceKmByVehicle` 到 `core/domain/distance.dart`，report re-export。
- `MockLedgerRepository.recordsBetween`。
- 通过现有首页 / 账单 Widget 测试，确保零回归。

**退出标准**：首页视觉与行为不变；统计 Tab 可显示空壳；`flutter analyze` / `test` 通过。

### M1 · 模型、口径与 Mock

- `stats_models.dart`、`stats_period.dart`、`stats_aggregation.dart`、`stats_presenter.dart`。
- `stats_repository.dart`、`mock_stats_repository.dart`、`stats_api.dart`（仅签名 + mapper）。
- 单元测试覆盖周期、聚合、分桶、百分比、坐标轴、Mock 一致性。

**退出标准**：纯函数测试全绿；Mock 可返回设计稿示例数据。

### M2 · 页面骨架与上半屏

- `StatsPage`、`StatsHeader`、`StatsVehicleSheet`、`StatsPeriodBar`、`StatsHeroCard`、`StatsEnergyCard`、`StatsMaintenanceCard`。
- 周期 / 车辆切换联动；骨架、错误、空态。
- Widget 测试覆盖切换与状态。

**退出标准**：上半屏与设计稿一致；周期 / 车辆切换无旧数据闪回。

### M3 · 趋势、构成与最近记录

- `StatsTrendCard`、`StatsTrendChart`、`StatsBreakdownCard`、`StatsDonut`、`StatsRecentRecords`。
- 粒度切换、峰值提示、图例跳转（P1）、记录跳详情。
- 图表空态、单点、全 0。

**退出标准**：四类时间范围与四类车辆范围组合均正确；图表 60fps。

### M4 · 打磨与收尾

- 深色模式核对、无障碍语义、字号放大。
- 下拉刷新、记账后失效、离线提示。
- 跨 Tab 跳转（查看全部 / 图例筛选）。
- 性能剖析（图表重建、provider 失效范围）。
- 文档「实施记录」与截图。

**退出标准**：需求 §12 验收清单全部通过。

---

## 14. 风险与待确认

| 风险 | 影响 | 应对 |
| --- | --- | --- |
| 页面周期与趋势粒度双控件容易被理解为同一口径 | 用户困惑 / 返工 | 默认映射 + 合计旁标注窗口名；需求 Q2 / Q3 确认 |
| 「全部车辆」的能耗与保养口径复杂 | 展示不自洽 | 按成本 / 最紧迫车辆口径；需求 Q4 / Q5 |
| 设计稿数据自相矛盾 | 验收争议 | 以需求 §7 口径为准；§13.1 已列差异 |
| `fl_chart` 触摸提示只能按序列生成 | 双曲线两个气泡 | 只对一条序列返回合成文案；或用自绘浮层 |
| 全部范围聚合数据量大 | 首屏慢 / 超时 | 服务端聚合；客户端 422 降级；Mock 限制 24 个月 |
| Tab 状态上提影响首页 | 回归 | 保持 `IndexedStack` 与 `_visitedTabs`；补壳层 Widget 测试 |
| 首页图元抽取造成像素变化 | 视觉回归 | 只搬代码不改参数；对比截图 |
| 深色稿缺失 | 视觉验收延期 | 先用 `AppPalette.dark`，标注待设计复核 |
| 品牌 / 颜色与设计稿不一致 | 设计质疑 | 需求 §4 与 Q1 / Q12 已说明理由 |
| 分类合并规则改变设计稿图例数量 | 与稿不一致 | 以金额一致性优先；产品确认 Q6 / 分类合并规则 |

---

## 15. 附录：需求 → 实现映射

| 需求章节 | 主要实现 | 关键逻辑 |
| --- | --- | --- |
| §6.1 顶部栏 | `StatsHeader` + `AppTabHeader` | 标题、问候、车辆胶囊、通知红点 |
| §6.2 车辆弹层 | `StatsVehicleSheet` + `StatsFilterNotifier` | 全部车辆 / 单车、动力标签、选中态 |
| §6.3 周期与日期 | `StatsPeriodBar`、`StatsAnchorSheet` | 周期解析、默认粒度映射、历史锚点 |
| §6.4 Hero | `StatsHeroCard` + `stats_presenter` | 每公里成本、环比、三列子指标 |
| §6.5 能耗卡 | `StatsEnergyCard` + `stats_aggregation` | 电耗 / 油耗 / 成本、评级、Sparkline |
| §6.6 保养卡 | `StatsMaintenanceCard` + `ProgressRing` | 剩余里程、天数、进度、警示 |
| §6.7 趋势 | `StatsTrendCard`、`StatsTrendChart` | 分桶、坐标轴、峰值、触摸提示 |
| §6.8 构成 | `StatsBreakdownCard`、`StatsDonut` | 合并、最大余数法、图例下钻 |
| §6.9 最近记录 | `StatsRecentRecords` | 周期内 3 条、详情跳转、查看全部 |
| §6.10 导航与 FAB | `AppTabShell`、`AppBottomNav` | 统计 Tab 高亮、回顶 |
| §6.11 状态 | 各卡片 `.when(...)` + `SectionError` | 骨架、空、错误、刷新 |
| §7 口径 | `stats_aggregation.dart` | 周期、里程、能耗、百分比、分桶 |
| §8 接口 | `stats_api.dart` + mapper | 路径、字段、错误码 |
| §9 状态 | `providers.dart` | family、失效矩阵、竞态 |
| §10 非功能 | 全部 | 性能、主题、无障碍 |

---

## 16. 实施记录（v0.2）

### 16.1 落地范围

已按 M0–M4 完成统计 Tab 的 **Mock 版本**，`AppTabShell` 的 index 2 由 `_ComingSoonTab` 替换为 `StatsPage`。真实接口、持久化缓存、离线与埋点尚未接入。

### 16.2 实际落地的文件

新增：

```
lib/app/tab.dart
lib/core/domain/distance.dart
lib/core/widgets/app_tab_header.dart
lib/core/widgets/hero_wave_background.dart
lib/core/widgets/progress_ring.dart
lib/core/widgets/sparkline.dart
lib/features/stats/data/stats_repository.dart
lib/features/stats/data/stats_api.dart
lib/features/stats/data/mock_stats_repository.dart
lib/features/stats/domain/stats_models.dart
lib/features/stats/domain/stats_period.dart
lib/features/stats/domain/stats_aggregation.dart
lib/features/stats/domain/stats_presenter.dart
lib/features/stats/domain/providers.dart
lib/features/stats/presentation/stats_page.dart
lib/features/stats/presentation/stats_header.dart
lib/features/stats/presentation/stats_vehicle_sheet.dart
lib/features/stats/presentation/stats_period_bar.dart
lib/features/stats/presentation/stats_hero_card.dart
lib/features/stats/presentation/stats_energy_card.dart
lib/features/stats/presentation/stats_maintenance_card.dart
lib/features/stats/presentation/stats_trend_card.dart
lib/features/stats/presentation/stats_trend_chart.dart
lib/features/stats/presentation/stats_breakdown_card.dart
lib/features/stats/presentation/stats_recent_records.dart
test/stats/stats_period_test.dart
test/stats/stats_aggregation_test.dart
test/stats/stats_presenter_test.dart
test/stats/mock_stats_repository_test.dart
test/stats/stats_page_test.dart
test/stats/stats_test_helpers.dart
```

修改：

- `lib/app/tab_shell.dart`：Tab 状态上提、统计 Tab 懒加载、跨 Tab 跳转。
- `lib/core/domain/enums.dart`：`MaintenanceStatus` 迁入 core，home 侧 re-export 不变。
- `lib/core/widgets/app_bottom_nav.dart`、`app_tab_header.dart`：字号放大时钳制 / 缩放，避免 1.3 倍字号溢出。
- `lib/features/home/presentation/widgets/{home_header,hero_card,consumption_card,maintenance_card}.dart`：改用 core 公共图元，视觉不变。
- `lib/features/ledger/data/mock_ledger_repository.dart`：新增 `recordsBetween` / `firstRecordAt`。
- `lib/features/report/domain/{report_models,report_aggregation}.dart`：里程来源改用 `core/domain/distance.dart`。
- `test/widget_test.dart`：统计 Tab 的断言从占位页改为真实页面。

### 16.3 与设计稿 / 方案的差异

| 项 | 落地 | 说明 |
| --- | --- | --- |
| 卡片圆角 | 16px | 与首页 / 账单页一致，设计稿 32px 按全站现状收敛 |
| 分类颜色 | `AppColors` | 保养琥珀、过路费紫、停车天蓝，不采用设计稿单页橙色 |
| 周期历史回看 | 周 / 月 / 半年 / 年度全部支持 | 方案原列 P1，实际已落地；「全部」不可选锚点 |
| 最近记录 | 已实现 | 方案列 P1，按周期内 3 条实现 |
| 图例跳转 | 已实现 | 分类图例与「查看全部」均跳转账单 Tab 并带车辆 / 月份 / 分类 |
| 趋势 1 年 X 轴 | 月标签 | 设计稿为季度节点；窗口仍为近 12 个月 |
| 保养类型标签 | 按动力与进度推导 | `MockHomeRepository` 无保养类型字段：PHEV → 首保/小保，进度 > 70% → 大保养，其余小保养 |
| 能耗迷你走势 | 周期内子窗口聚合 | PHEV / EV 用电耗，HEV / ICE 用油耗；全部车辆用能源成本 /km |
| 全部车辆保养卡 | 展示最紧迫车辆 | 点击下钻到该车（P1）未实现 |
| 网络与缓存 | 未接入 | `stats_api.dart` 仅定义契约；Mock 同步聚合，无 60s 缓存 / 离线提示 |
| 全局记账失效 | 部分实现 | 最近记录进详情返回、下拉刷新会失效当前范围；M4 设想的 `expenseMutationTickProvider` 未接入 |
| 深色模式 | 已适配 | 按 `AppPalette.dark` 推导，无正式深色稿 |

### 16.4 测试与 CI

- `flutter analyze`：0 issue。
- `flutter test`：143 个用例全部通过，其中统计页 49 个（周期 10、聚合 18、presenter 7、Mock 仓库 6、Widget 8）。
- Widget 覆盖：页面渲染、周期 / 趋势粒度联动、车辆切换、模块级错误、图表点按、图例跳转、最近记录跳转、1.3 倍字号。
- 无障碍：Hero、能耗、保养、趋势图均提供合成语义标签；底部导航与顶部栏在 1.3 倍字号下钳制缩放。
- CI：PR 阶段运行 `flutter analyze` 与 `flutter test`；合并 `main` 后由 `flutter-android.yml` 打包。
- 本 PR 未新增依赖，`pubspec.yaml` / `pubspec.lock` 无变化。

### 16.5 遗留

1. `HttpStatsRepository` 与 `StatsRepositoryImpl` 的竞态 / 缓存 / 离线能力。
2. 记账、编辑、删除后的全局失效事件。
3. 全部车辆保养卡下钻与车辆删除回退。
4. 真实中文字体下的截图核对与 golden 测试（测试环境仅验证布局，字形为 Ahem）。
5. 「全部」范围数据量过大时的客户端降级策略（当前 Mock 限制最近 24 个月）。

---

## 17. 变更记录

| 版本 | 日期 | 变更 |
| --- | --- | --- |
| v0.1 | 2026-11-14 | 首版技术方案：复用清单、M0 重构、数据模型、周期 / 聚合口径、趋势分桶与坐标轴、接口契约、Provider 设计、UI 与图表实现、测试与里程碑 |
| v0.2 | 2026-11-14 | M0–M4 已实施（Mock）：补充实际文件清单、与设计稿差异、测试结果与遗留项 |
