# 账单页技术方案 · 明细与流水记录

| 项目 | 内容 |
| --- | --- |
| 关联需求 | [账单页需求文档 v0.2](../requirements/ledger.md) |
| 设计稿 | [Stitch · 账单·明细与流水记录](https://stitch.google.com/projects/9615374848161425677?node-id=509df27d171c476ea2901ab6dbae2636) |
| 客户端 | Flutter 3.50.0 stable / Dart 3.14 |
| 平台 | Android（arm64 优先）、iOS |
| 文档版本 | v0.2（M0–M3 已实施） |
| 状态 | M0–M3 已实施；接口契约以最终后端文档为准 |

> 本文档基于**仓库当前已有实现**（`lib/features/home/**` 已落地静态首页，依赖仅 `material_ui`、`flutter_riverpod`、`fl_chart`、`intl`）编写。所有新增目录、文件与重构均为拟实施内容，按 `feat/ledger-page` 分支推进。

---

## 1. 目标与约束

### 1.1 技术目标

- 账单 Tab 首次进入 ≤ 1s 可交互；切换筛选后首屏数据 ≤ 500ms，有缓存 ≤ 120ms。
- 1000 条以上记录滚动 60fps；分页按游标加载，不重复、不丢数据。
- 汇总卡与列表独立加载、独立失败、独立重试；切换筛选丢弃过期响应。
- 复用首页的设计 token、卡片容器、底部导航、格式化与 Mock 仓库模式，避免出现第二套视觉与第二套规范。
- 记录卡完全由数据驱动：分类 → 图标 / 浅底色 / 副标题 / 右侧指标，UI 内不出现 `switch (powertrain)` 之类的业务分支。

### 1.2 约束

- **不新增第三方依赖**：柱状图用 Flutter 基础组件（`Row` + `AnimatedContainer`）实现，不需要图表库；金额格式化沿用 `intl`。若后续做导出图片，再评估 `screenshot` / `share_plus`。
- 金额全链路使用 **整数分**（`int cents`），与现有 `formatters.dart` 一致，不引入 `Money` 类。
- 设计稿未覆盖的交互（月份选择器、筛选面板、详情页）由客户端先做最小实现，接口未定稿前用 Mock。
- 不引入 `go_router`：当前 `CheXiaoJiApp` 使用 `MaterialApp(home: HomePage)` + `IndexedStack`，本期沿用，详情页用 `Navigator.push`。

---

## 2. 现状与复用清单

| 现有能力 | 位置 | 本页用法 |
| --- | --- | --- |
| 色彩主题扩展 | `lib/app/theme/app_colors.dart` → `AppPalette` / `AppColors` / `context.palette` | 全部颜色取值，新增 `primaryFaint` 等按需补充 |
| 间距 / 圆角 / 阴影 | `lib/app/theme/app_tokens.dart` → `AppTokens` / `context.tokens` | 页面边距、卡片阴影、导航高度 |
| 字体 | `lib/app/theme/app_typography.dart` | `displayHero`、`headlineSm`、`bodyLg`、`labelSm` 等 |
| 卡片容器 | `lib/features/home/presentation/widgets/home_card.dart` → `HomeCard` | **上移到 `core/widgets`** 后复用 |
| 骨架 / 错误 / 空态 | 同上 → `SkeletonBox` / `SectionError` / `EmptyState` | 直接复用 |
| 底部导航 + FAB | `lib/features/home/presentation/widgets/home_bottom_nav.dart` | **上移并改名 `AppBottomNav`**，供 Tab 壳共用 |
| 分类语义色 / 图标 | `lib/features/home/presentation/home_style.dart` → `ExpenseCategoryVisual` | 直接复用；如分类枚举迁移则一并移动 |
| 金额 / 里程 / 百分比格式化 | `lib/core/format/formatters.dart` | 复用并新增 `splitYuanParts`、`formatDayHeader` |
| 车辆列表 / 选中车辆 | `lib/features/home/domain/providers.dart` → `vehiclesProvider` | 筛选 chip 数据源；本期跨 feature 引用 |
| Mock 仓库模式 | `lib/features/home/data/mock_home_repository.dart` | 保持同构，新增 `MockLedgerRepository` |
| 顶栏毛玻璃实现 | `home_page.dart` → `_HeaderDelegate` | 提取为 `core/widgets/blurred_header_delegate.dart` |

> 现有首页的「账单 / 统计 / 我的」三个 Tab 是 `_ComingSoonTab` 占位，本次把 index 1 替换为 `LedgerPage`。

---

## 3. 结构调整（M0）

账单页需要与首页共用顶栏行为、底部导航与卡片样式，先做一次小范围重构，避免在 `features/ledger` 中复制粘贴：

```
lib/
├── app/
│   ├── app.dart                  # 保持不变
│   └── tab_shell.dart            # 新增：IndexedStack + AppBottomNav + FAB
├── core/
│   ├── domain/
│   │   └── enums.dart            # 新增：PowertrainType / ExpenseCategory / TrendDirection
│   ├── widgets/
│   │   ├── app_card.dart         # 由 home_card.dart 迁移（HomeCard → AppCard）
│   │   ├── skeleton_box.dart
│   │   ├── section_error.dart
│   │   ├── empty_state.dart
│   │   ├── app_bottom_nav.dart   # 由 HomeBottomNav 迁移，保留 selectedIndex/onTap/onFab
│   │   └── blurred_header_delegate.dart
│   └── format/formatters.dart    # 追加账单相关格式化
└── features/
    ├── home/
    │   └── domain/home_models.dart   # 加 `export '../../core/domain/enums.dart';`
    └── ledger/
        ├── data/
        │   ├── ledger_repository.dart
        │   ├── ledger_api.dart          # 接口契约（暂不实现）
        │   └── mock_ledger_repository.dart
        ├── domain/
        │   ├── ledger_models.dart       # 汇总 / 记录 / 分页 / 筛选
        │   ├── ledger_grouping.dart     # 按天分组、扁平化行数据
        │   ├── ledger_queries.dart      # 带值相等的查询对象
        │   └── providers.dart
        └── presentation/
            ├── ledger_page.dart
            ├── ledger_style.dart        # 分类浅底 / 徽标 / 胶囊配色
            ├── utils/money_display.dart # 整数大字 + 小数小字
            └── widgets/
                ├── ledger_header.dart
                ├── ledger_summary_card.dart
                ├── ledger_daily_bars.dart
                ├── ledger_vehicle_chips.dart
                ├── ledger_category_chips.dart
                ├── ledger_filter_result_bar.dart
                ├── ledger_day_header.dart
                ├── ledger_record_card.dart
                ├── ledger_records_sliver.dart
                ├── ledger_footer.dart
                ├── ledger_month_picker_sheet.dart
                └── ledger_filter_sheet.dart   # P1
```

关键点：

- `home_models.dart` 通过 `export` 保留原有类名，首页与测试无需改 import，降低重构风险。
- `HomePage` 不再自己持有 `_selectedTab` 与 `HomeBottomNav`；`AppTabShell` 负责 Tab 状态、FAB 与滚动回顶。`HomePage` 暴露 `ScrollController` 或提供 `scrollToTop()`。
- Tab 壳需要**懒加载**：`IndexedStack` 会在启动时构建所有子页，账单页的首次请求不应在首页启动时发出。用 `_visitedTabs` 集合控制，首次点击账单 Tab 才构建 `LedgerPage`，之后保留状态。
- 首页 Widget 测试中的 `find.text('车小记')`、车辆切换、保养警示等断言不受影响；`HomeBottomNav` 的 key 与文案保持不变，测试仅需补 `AppTabShell` 的包裹（如果测试直接 pump `CheXiaoJiApp`，无需改动）。

---

## 4. 数据流

```
AppTabShell (IndexedStack index=1)
        │
        ▼
LedgerPage ── watch ──> ledgerFilterProvider (month / vehicleId / category / sort)
        │                        │
        │                        ├── ledgerSummaryProvider(scope)   ── 汇总卡
        │                        └── ledgerRecordsProvider(query)   ── 流水列表
        ▼
LedgerRepository ──> LedgerApi ──> 后端（当前为 MockLedgerRepository）
        │
        └── 内存缓存：Map<scopeKey, (summary, cachedAt)>
```

- 汇总查询键 = `month + vehicleId`；列表查询键 = `month + vehicleId + category + sort`。
- 分类切换只重建列表 provider；车辆 / 月份切换同时重建两者。
- 列表内部维护游标分页状态，`loadMore()` 只追加不重建首屏。
- 每次筛选切换递增 `requestGeneration`，旧响应到达时直接丢弃（`StaleLedgerResponse`），与首页 `HomeRepository` 的序号兜底策略一致。

---

## 5. 数据模型

### 5.1 查询对象

Riverpod 的 family 参数需要值相等，`List` 默认按引用比较，因此用不可变值对象而不是 `record`：

```dart
@immutable
class LedgerScope {
  const LedgerScope({required this.month, this.vehicleId});

  /// 归一化到当月 1 日 00:00（本地时区）。
  final DateTime month;

  /// null = 全部车辆。
  final String? vehicleId;

  LedgerScope copyWith({DateTime? month, String? vehicleId, bool clearVehicle = false}) => ...;

  @override
  bool operator ==(Object other) =>
      other is LedgerScope &&
      other.month.year == month.year &&
      other.month.month == month.month &&
      other.vehicleId == vehicleId;

  @override
  int get hashCode => Object.hash(month.year, month.month, vehicleId);
}

enum LedgerSort { timeDesc, amountDesc, category }

@immutable
class LedgerQuery extends LedgerScope {
  const LedgerQuery({
    required super.month,
    super.vehicleId,
    this.category,
    this.sort = LedgerSort.timeDesc,
  });

  /// null = 全部类型。
  final ExpenseCategory? category;
  final LedgerSort sort;

  @override
  bool operator ==(Object other) =>
      other is LedgerQuery && super == other &&
      other.category == category && other.sort == sort;

  @override
  int get hashCode => Object.hash(super.hashCode, category, sort);
}
```

> `LedgerFilter` 的 UI 状态（含月份选择器是否展开等）不放进 provider，避免重建列表；面板的临时选择在弹层 `StatefulWidget` 内维护，点「完成」才写回。

### 5.2 汇总模型

```dart
class LedgerMonthSummary {
  const LedgerMonthSummary({
    required this.month,
    required this.totalCents,
    required this.count,
    required this.energyCents,
    required this.serviceCents,
    required this.dailyAverageCents,
    required this.daily,
    this.momPercent,
    this.momTrend = TrendDirection.none,
  });

  final DateTime month;
  final int totalCents;
  final int count;
  final int energyCents;          // 充电 + 加油
  final int serviceCents;         // 保养 + 洗车
  final int dailyAverageCents;    // total ÷ 当月自然日天数，服务端可下发，客户端兜底计算
  final List<LedgerDailyPoint> daily;
  final double? momPercent;       // null = 上月无数据
  final TrendDirection momTrend;

  int get peakCents => daily.isEmpty ? 0 : daily.map((d) => d.amountCents).reduce(max);
  DateTime? get peakDate => ...;
}

class LedgerDailyPoint {
  const LedgerDailyPoint({
    required this.date,
    required this.amountCents,
    this.dominantCategory,
  });
  final DateTime date;
  final int amountCents;
  final ExpenseCategory? dominantCategory;
}
```

派生逻辑放在 domain，便于单测：

```dart
int dailyAverage(int totalCents, DateTime month) {
  final days = DateTime(month.year, month.month + 1, 0).day;
  return totalCents == 0 ? 0 : (totalCents / days).round();
}

int barHeight(int amountCents, int peakCents) {
  if (peakCents <= 0) return 8;
  final ratio = (amountCents / peakCents).clamp(0.0, 1.0);
  return (8 + 24 * ratio).roundToDouble();
}
```

### 5.3 记录模型

```dart
class LedgerRecord {
  const LedgerRecord({
    required this.id,
    required this.vehicleId,
    required this.vehicleShortName,
    required this.category,
    required this.title,
    required this.amountCents,
    required this.occurredAt,
    this.badgeText,
    this.badgeKind = LedgerBadgeKind.none,
    this.metrics = const LedgerMetrics(),
    this.statusText,
    this.note,
  });
  ...
}

enum LedgerBadgeKind { none, vehicle, meta }

class LedgerMetrics {
  const LedgerMetrics({
    this.kwh,
    this.liters,
    this.unitPriceCentsPerLiter,
    this.odometerKm,
    this.distanceKm,
    this.durationMinutes,
    this.plate,
    this.paymentMethod,
  });
  ...
}

class LedgerRecordsPage {
  const LedgerRecordsPage({required this.items, this.nextCursor, required this.hasMore});
  ...
}
```

**副标题与右副的拼装放在 domain**（`ledger_record_presenter.dart` 或在 `LedgerRecord` 上做扩展），UI 只读结果：

```dart
extension LedgerRecordPresentation on LedgerRecord {
  String get expenseText => amountCents >= 0
      ? '-${formatYuanDetail(amountCents)}'
      : '+${formatYuanDetail(amountCents.abs())}';

  String? get subtitle {
    final parts = <String>[
      if (metrics.kwh != null) '${formatOneDecimal(metrics.kwh!)} kWh',
      if (metrics.liters != null) '${formatTwoDecimals(metrics.liters!)} L',
      if (metrics.unitPriceCentsPerLiter != null)
        '单价 ${formatYuanDetail(metrics.unitPriceCentsPerLiter!)}/L',
      if (metrics.odometerKm != null) '里程 ${formatKm(metrics.odometerKm!)}',
      if (metrics.durationMinutes != null) formatDuration(metrics.durationMinutes!),
      if (metrics.plate != null) metrics.plate!,
      if (statusText != null) statusText!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// 充电 / 加油的单价胶囊；null 时回退 statusText。
  String? get unitPricePillText => switch (category) {
    ExpenseCategory.charging => metrics.kwh == null
        ? null
        : formatUnitPrice((amountCents / metrics.kwh!).round(), 'kWh'),
    ExpenseCategory.fuel => metrics.liters == null
        ? null
        : formatUnitPrice((amountCents / metrics.liters!).round(), 'L'),
    _ => null,
  };
}
```

> 需求文档 §6.4 的字段矩阵与这里的拼装顺序一一对应；新增分类只改扩展，不改 Widget。Q3 已定稿：充电用 `¥/kWh`、加油用 `¥/L`，与首页「最近记录」一致，每公里成本不再出现在列表。

### 5.4 分组与行模型

懒加载列表需要把「组头 + 记录」拍平成同一种行，才能用 `SliverList.builder` 增量渲染：

```dart
sealed class LedgerRow {
  const LedgerRow();
}

class LedgerDayHeaderRow extends LedgerRow {
  const LedgerDayHeaderRow({required this.day, required this.count, required this.totalCents, required this.accent});
  final DateTime day;
  final int count;
  final int totalCents;
  final Color accent;
}

class LedgerRecordRow extends LedgerRow {
  const LedgerRecordRow(this.record);
  final LedgerRecord record;
}

class LedgerResultBarRow extends LedgerRow {
  const LedgerResultBarRow({required this.category, required this.count, required this.totalCents});
  ...
}
```

```dart
List<LedgerRow> buildLedgerRows(
  List<LedgerRecord> records, {
  ExpenseCategory? filteredCategory,
  DateTime? now,
}) {
  // 1. 按本地日期分组，日期倒序
  // 2. 组内按 occurredAt 倒序，无时刻排末尾（稳定排序）
  // 3. 生成 group header：count / total / 主导分类色（今天强制 primary）
  // 4. 若 filteredCategory != null，在最前面插入 LedgerResultBarRow
}
```

- 分组结果用 `ref.watch(...).select()` 或在 `LedgerListState` 里缓存，避免每帧重算。
- 跨年文案、周几使用手写常量表（`const ['周一', … '周日']`），避免 `intl` 的 locale 数据初始化（`initializeDateFormatting`）成本。
- `now` 可注入，便于测试「今天 / 昨天 / 前天」与跨零点。

---

## 6. 数据层

### 6.1 仓库接口

```dart
abstract class LedgerRepository {
  Future<LedgerMonthSummary> fetchSummary(LedgerScope scope);
  Future<LedgerRecordsPage> fetchRecords(LedgerQuery query, {String? cursor, int limit = 30});
}

abstract class LedgerApi {
  Future<Map<String, dynamic>> getSummary({required String month, required String vehicleIds});
  Future<Map<String, dynamic>> getRecords({...});
}
```

- 当前阶段 `MockLedgerRepository` 直接返回设计稿数据（2026-11 口径，与首页 Mock 同一批车辆），并支持：
  - 按月份生成 24 个月的历史数据（用于测试月份切换）；
  - 生成 120 条以上记录（用于测试分页与滚动性能）；
  - 按 `vehicleId` / `category` 过滤；
  - 模拟 300ms 延迟与可注入的失败开关。
- `LedgerApi` 先只定义签名与 DTO mapper，接入后端时新增 `HttpLedgerApi`，`ledgerRepositoryProvider` 换实现即可。

### 6.2 接口

| 方法 | 路径 | 用途 | 时机 |
| --- | --- | --- | --- |
| GET | `/api/v1/ledger/summary?month=&vehicleIds=` | 月度汇总 + 日序列 + 环比 | 进入页面 / 切月 / 切车 / 下拉刷新 |
| GET | `/api/v1/ledger/records?month=&vehicleIds=&categories=&cursor=&limit=&sort=` | 流水分页 | 进入页面 / 任一筛选变化 / 滚动加载 |

- `vehicleIds=all` 表示全部车辆，否则逗号分隔。
- `cursor` 为空取第一页；响应携带 `nextCursor` 与 `hasMore`，客户端不自行推算页码。
- 请求失败策略：汇总失败不影响列表；列表失败保留已加载数据，只把 footer 置为错误态。
- 缓存：内存 `Map<String, _CachedSummary>`，key 为 `month|vehicleId`，TTL 5 分钟；本期不落盘（未引入 `shared_preferences`），后续接入时复用首页的缓存 key 规范。

### 6.3 竞态与取消

```dart
class LedgerRepositoryImpl implements LedgerRepository {
  final _api = LedgerApiImpl();
  int _generation = 0;

  @override
  Future<LedgerMonthSummary> fetchSummary(LedgerScope scope) async {
    final gen = ++_generation;
    final json = await _api.getSummary(month: formatMonthKey(scope.month), vehicleIds: ...);
    if (gen != _generation) throw const StaleLedgerResponse();
    return LedgerSummaryMapper.fromJson(json);
  }
}
```

- UI 对 `StaleLedgerResponse` 静默忽略，不展示错误。
- 列表分页使用独立的 `_listGeneration`，切筛选时自增，旧页响应同样丢弃。

---

## 7. 状态管理

### 7.1 Provider 设计

```dart
final ledgerRepositoryProvider = Provider<LedgerRepository>((ref) => MockLedgerRepository());

/// 当前筛选（月份 / 车辆 / 分类 / 排序）。
final ledgerFilterProvider =
    NotifierProvider.autoDispose<LedgerFilterNotifier, LedgerFilter>(LedgerFilterNotifier.new);

class LedgerFilterNotifier extends AutoDisposeNotifier<LedgerFilter> {
  @override
  LedgerFilter build() => LedgerFilter(month: DateTime.now());

  void selectMonth(DateTime month) { ... }
  void selectVehicle(String? vehicleId) { ... }
  void selectCategory(ExpenseCategory? category) { ... }
  void reset() { ... }
}

final ledgerSummaryProvider = FutureProvider.autoDispose
    .family<LedgerMonthSummary, LedgerScope>((ref, scope) {
      return ref.watch(ledgerRepositoryProvider).fetchSummary(scope);
    });

final ledgerRecordsProvider = NotifierProvider.autoDispose
    .family<LedgerRecordsNotifier, LedgerListState, LedgerQuery>(
      LedgerRecordsNotifier.new,
    );

class LedgerRecordsNotifier extends AutoDisposeFamilyNotifier<LedgerListState, LedgerQuery> {
  @override
  LedgerListState build(LedgerQuery arg) {
    _loadFirstPage();
    return const LedgerListState.loading();
  }

  Future<void> loadMore() { ... }
  Future<void> refresh() { ... }
  Future<void> retry() { ... }
}
```

> Riverpod 3 的 `AutoDisposeNotifier` / `AutoDisposeFamilyNotifier` 写法与仓库现有 `Notifier` 用法一致；若具体 API 名称在锁定版本中有差异，按 `providers.dart` 现有模式调整，不影响设计。

`LedgerListState`：

```dart
class LedgerListState {
  const LedgerListState({
    required this.items,
    required this.rows,
    required this.cursor,
    required this.hasMore,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.isNextPageFailed = false,
    this.error,
  });

  final List<LedgerRecord> items;
  final List<LedgerRow> rows;      // 分组后的行，随 items / 分类变化重算
  final String? cursor;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isRefreshing;
  final bool isNextPageFailed;
  final Object? error;             // 仅首屏失败时非空
}
```

- `loadMore()`：`isLoadingMore` 时直接返回；成功后按 `id` 去重追加，重算 `rows` 并保持滚动位置。
- `refresh()`：清空游标与 items，重新取首页；汇总由 `ledgerSummaryProvider` 单独 `invalidate`。
- 首屏失败：`error` 非空，页面渲染 `SectionError`；分页失败：`isNextPageFailed = true`，footer 显示重试，不清空已有数据。

### 7.2 状态展示

| 状态 | 汇总卡 | 列表 |
| --- | --- | --- |
| 首屏加载中 | 骨架（金额 / 三列 / 柱状图） | 2–3 个组头骨架 + 4 张卡片骨架 |
| 有缓存 | 直接显示 | 直接显示 |
| 首屏失败 | 「汇总加载失败 · 重试」 | 「加载失败 · 重试」 |
| 分页加载中 | — | footer 转圈 |
| 分页失败 | — | footer「加载失败，点击重试」 |
| 无数据 | 0 值 | 对应空态（§6.4e） |
| 离线 | 缓存 + 顶部离线提示条 | 同左 |

---

## 8. UI 实现

### 8.1 页面骨架

```dart
Scaffold(
  extendBody: true,
  backgroundColor: palette.background,
  body: RefreshIndicator(
    onRefresh: _refresh,
    child: CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPersistentHeader(pinned: true, delegate: BlurredHeaderDelegate(height: 64, child: LedgerHeader())),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, tokens.contentBottomPadding + bottomInset),
          sliver: SliverList(delegate: SliverChildListDelegate([
            const LedgerSummaryCard(),
            const SizedBox(height: 12),
            const LedgerVehicleChips(),
            const SizedBox(height: 8),
            const LedgerCategoryChips(),
            const SizedBox(height: 12),
          ])),
        ),
        // 行列表：组头 + 记录卡 + 结果条
        LedgerRowsSliver(query: query, state: listState),
        // footer：加载中 / 重试 / 没有更多
        SliverToBoxAdapter(child: LedgerFooter(...)),
      ],
    ),
  ),
)
```

- 顶部栏与筛选区之间只有 8px；筛选区滚动离开视口后，顶部栏保持 pinned。
- 列表行 `SliverList.builder`，不把全部记录塞进 `SliverChildListDelegate`，保证懒构建。
- `LedgerPage` 用 `ConsumerStatefulWidget`，持有 `ScrollController` 与 `loadMore` 的 200px 阈值监听；`AppTabShell` 通过 `GlobalKey` 或回调触发「重复点击 Tab 回顶」。

### 8.2 顶部栏 `LedgerHeader`

- 36×36 圆形容器：`AppPalette.surfaceContainer` 底、`outlineVariant` 1px 描边、`primaryText` 图标。
- 标题 `AppTypography.headlineMd`。
- 右侧两个 36×36 `Material` 圆形按钮，`surface` 底 + `cardShadow`，图标 18px。
- 筛选按钮角标：`Positioned(right: 2, top: 2)` 的 6×6 `primary` 圆点，由 `hasActiveFilter` 控制。
- 顶部栏背景：`background.withValues(alpha: 0.86)` + `BackdropFilter(blur 16)`，与首页一致。

### 8.3 月度汇总卡 `LedgerSummaryCard`

```
Container(radius: 32, padding: 20, surface, border 1px #EFF4FF, cardShadow)
├── Stack
│   ├── 装饰光斑（IgnorePointer + ImageFilter.blur）
│   └── Column
│       ├── Row[月份胶囊, Spacer, 环比胶囊]
│       ├── SizedBox(12)
│       ├── Row[¥20px, 整数38px, 小数11px, Spacer, 共 N 笔支出]
│       ├── SizedBox(20)
│       ├── Container(top border) → Row[3 × 子指标]
│       ├── SizedBox(12)
│       ├── Row[当月日开销波动, Spacer, 峰值标注]
│       └── SizedBox(4) + LedgerDailyBars(height: 36)
```

- 月份胶囊：`InkWell` + `Container`，点击 `showModalBottomSheet` 打开 `LedgerMonthPickerSheet`。
- 金额展示用 `MoneyDisplay`：

```dart
class MoneyDisplay extends StatelessWidget {
  const MoneyDisplay({required this.cents, this.currencyStyle, this.integerStyle, this.decimalStyle});
  ...
  @override
  Widget build(BuildContext context) {
    final parts = splitYuanParts(cents);   // ('1,120', '.50')
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: '¥', style: currencyStyle),
        TextSpan(text: parts.integer, style: integerStyle),
        TextSpan(text: parts.decimal, style: decimalStyle),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
```

`Text.rich` 中不同字号的 `TextSpan` 会自动按基线对齐，无需手写 `WidgetSpan`；`maxLines: 1` + `ellipsis` 保证 375pt 不换行。

- 环比胶囊：复用「上升玫红 / 下降绿」的规则，`TrendDirection` 决定图标与底色；`momPercent == null` 时文案「较上月 —」且无图标。
- 三列子指标：`Row` + `Expanded`，第 2、3 列加 1px 左分隔；数值 `headlineSm`，颜色按需求文档。
- `LedgerDailyBars`：

```dart
class LedgerDailyBars extends StatelessWidget {
  const LedgerDailyBars({required this.points, required this.peakDate, required this.today});
  ...
  @override
  Widget build(BuildContext context) {
    final peak = ...;
    return SizedBox(
      height: 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final p in points)
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              width: 6,
              height: barHeight(p.amountCents, peak),
              decoration: BoxDecoration(
                color: _barColor(p, isToday: p.date.isSameDay(today), isPeak: ...),
                borderRadius: BorderRadius.circular(999),
                border: _ringFor(p),   // 2px 环：今天绿色 / 峰值橙色
              ),
            ),
        ],
      ),
    );
  }
}
```

- 柱宽 6、31 根时总宽 186 + 30×4 = 306px，390pt 屏幕下可用宽度 358px，留白充足；375pt 下 `spaceBetween` 自适应，不需要横向滚动。
- 无记录日也要渲染 8px 底座，保证「每天都有柱子」的视觉节奏。
- 用 `AnimatedContainer` 而不是 `CustomPainter`：动画免费、可无障碍跳过、代码量小；外层包 `RepaintBoundary`。

### 8.4 筛选区

- `LedgerVehicleChips`：`SingleChildScrollView(scrollDirection: horizontal)` + `Row`；chip 高 32，间距 8。
  - 「全部车辆 (N)」+ 车辆 chips；`vehiclesProvider` 提供数据，加载中显示 3 个 96×32 骨架。
  - 选中车辆 chip：`onSurface` 底 + `表面浅色` 字；未选中：`surface` 底 + 1px `outlineVariant` + `cardShadow`。
  - 圆点颜色复用 `PowertrainVisual.color`。
- `LedgerCategoryChips`：8 个 chip（全部类型 + 7 分类），选中态 `primary`@40% 底 + `#002114` 字 + `primary`@30% 描边。
- `LedgerResultBarRow`：`Container` 浅绿底、12px 圆角、左右 12px，文案「已筛选：保养 · 1 笔 · ¥480.00」+ 右侧「清除」`TextButton`。
- 两个 chip 行都在页面级横向滚动容器内，避免嵌套滚动冲突（外层 `CustomScrollView` 只做纵向）。

### 8.5 流水列表

- `LedgerRowsSliver` 直接消费 `rows`：

```dart
SliverList.builder(
  itemCount: rows.length,
  itemBuilder: (context, index) => switch (rows[index]) {
    LedgerDayHeaderRow row => LedgerDayHeader(row: row),
    LedgerResultBarRow row => LedgerResultBar(row: row),
    LedgerRecordRow row => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: LedgerRecordCard(record: row.record),
      ),
  },
)
```

- `LedgerDayHeader`：高 22，左右 4 内边距；色条 6×14 圆角；标题 `headlineSm`；右侧 `labelMd` 次要色。
- `LedgerRecordCard`：

```dart
Row(
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    IconTile(44, category),
    SizedBox(width: 12),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Flexible(child: Text(title, maxLines: 1, overflow: ellipsis)), if (badge != null) BadgeChip()]),
          if (subtitle != null) Text(subtitle, maxLines: 1, overflow: ellipsis),
        ],
      ),
    ),
    SizedBox(width: 8),
    ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 84),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(expenseText, style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.w800)),
          if (costPill != null) Pill(...) else if (status != null) Text(status),
        ],
      ),
    ),
  ],
)
```

- 图标底：分类色 `withValues(alpha: 0.14)`；车辆徽标底：动力色 12%–20%，文字用对应深色 token。
- 金额列 `minWidth: 84` 保证多行右对齐；标题用 `Flexible` 避免长名挤压金额。
- 卡片 `InkWell` + `Material`，按下态用 `AnimatedScale(0.98, 120ms)`。
- 列表行全部为纯 `StatelessWidget`，数据变化才重建；不要在卡片内 `watch` provider。

### 8.6 月份选择器

- `showModalBottomSheet(isScrollControlled: true)`，高度约 60% 屏。
- 顶部「选择月份」+ 关闭按钮；内容为年份横向 chip + 12 个月份网格（3×4）。
- 当前月高亮；未来月份置灰且不可点；可选范围最近 36 个月（与需求一致）。
- 选择后立即写回 `ledgerFilterProvider.selectMonth(...)`，弹层关闭，列表回到顶部并重置分页。

### 8.7 导出与筛选面板（P1）

- 导出：`showModalBottomSheet` 三个选项。CSV 用 `dart:io` 写临时文件 + 分享插件（需新增依赖，届时单独评审）；本期先隐藏或 Toast 占位。
- 筛选面板：`StatefulWidget` 内维护草稿，点「完成」写入 `ledgerFilterProvider`；排序会改变 `LedgerQuery.sort`，从而重建列表 provider。

### 8.8 主题、格式化与无障碍

- 所有颜色走 `context.palette` / `AppColors`；汇总卡 32 圆角新增 `tokens.radiusSummary = 32`（`AppTokens` 扩展字段，light/dark 同值）。
- `formatters.dart` 追加：

```dart
({String integer, String decimal}) splitYuanParts(int cents) {
  final text = NumberFormat('#,##0.00').format(cents.abs() / 100);
  final index = text.lastIndexOf('.');
  return (integer: text.substring(0, index), decimal: text.substring(index));
}

String formatMonthLabel(DateTime month) => DateFormat('yyyy年M月').format(month);

const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

String formatDayHeader(DateTime day, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final diff = DateTime(n.year, n.month, n.day).difference(DateTime(day.year, day.month, day.day)).inDays;
  final label = switch (diff) {
    0 => '今天',
    1 => '昨天',
    2 => '前天',
    _ => null,
  };
  final base = day.year == n.year ? '${day.month}月${day.day}日' : '${day.year}年${day.month}月${day.day}日';
  return label != null ? '$label · $base' : '$base · ${_weekdays[day.weekday - 1]}';
}
```

- 无障碍：记录卡包 `Semantics(container: true, button: true, label: '...')`，把日期、分类、标题、金额、车辆拼成一句；筛选 chip 用 `Semantics(selected: ...)`；柱状图提供整体摘要「本月共 16 笔，峰值 6 月 15 日 480 元」。
- 深色模式：分类浅底改为 `分类色.withValues(alpha: 0.18)`，卡片底 `AppPalette.dark.surface`，描边 `outlineVariant`；对比度用真机核对。

---

## 9. 性能

| 优化点 | 措施 |
| --- | --- |
| 首次进入 | Tab 懒加载，未点击账单 Tab 不发请求；打开后先请求汇总（轻）再请求列表首页 |
| 列表渲染 | `SliverList.builder` 懒构建；行 widget 全 `const` / 纯函数；不嵌套 `ListView` |
| 分页 | 游标 30 条/页；`hasMore == false` 后不再触发；请求中加锁 |
| 分组计算 | 仅在 items / filter 变化时重算 `rows`，不在 `build` 中重算 |
| 柱状图 | `AnimatedContainer` + `RepaintBoundary`；31 个 widget 成本可忽略 |
| 滚动监听 | `ScrollController` 回调里只判断阈值，不 `setState` |
| 图片 | 本期无图片；后续记录缩略图需 `cacheWidth` |
| 构建范围 | 汇总卡与列表各自 `Consumer`，切分类时不重建汇总卡 |
| 内存 | 最多保留 10 页（300 条）；超出后从头丢弃并允许重新请求 |

指标：账单 Tab 首帧 ≤ 1s；筛选切换数据渲染 ≤ 500ms；1000 条滚动掉帧率 < 1%。

---

## 10. 错误与边界处理

| 场景 | 处理 |
| --- | --- |
| 无车辆 | 车辆 chips 只显示「全部车辆 (0)」，列表空态提示先添加车辆 |
| 当月无记录 | 汇总 0 值 + 柱状图全底座 + 空态「本月还没有记录」 |
| 筛选无结果 | 结果条 + 空态「没有符合条件的记录 / 清除筛选」 |
| 上月无数据 | 环比显示「较上月 —」，不显示箭头 |
| 里程 / 电量缺失 | 不显示对应副标题段与单价胶囊，不留空 `·` |
| 金额为负（退款） | 显示正数并带「退款」标记，不计入支出笔数 |
| 汇总失败 | 汇总卡独立重试，列表照常 |
| 列表首屏失败 | 列表区错误 + 重试，汇总照常 |
| 分页失败 | footer 重试，已加载数据保留 |
| 快速切筛选 | 请求序号丢弃旧响应；chip 选中态不回滚 |
| 月份跨年 | 环比取上年 12 月；组头显示年份 |
| 时区变化 / 跨零点 | 页面重新进入或下拉刷新时重算「今天」与分组 |
| 车辆被删除 | 单车筛选回退到「全部车辆」+ Toast |
| 登录过期 | 拦截并跳登录，登录后恢复筛选状态 |
| 重复记录 id | 追加时按 id 去重，保证列表稳定 |

---

## 11. 测试方案

### 11.1 单元测试

- `formatDayHeader`：今天 / 昨天 / 前天 / 本周其他日 / 跨年 / 跨零点。
- `splitYuanParts`：整数金额（`.00`）、千分位、小于 1 元、负数取绝对值。
- `dailyAverage`：整月 30 / 31 / 28 天，总额 0。
- `barHeight`：峰值为 0、单日峰值、比例取整。
- `buildLedgerRows`：分组顺序、组内排序（无时刻排末尾）、组头统计、今天颜色、筛选结果条、空列表。
- `LedgerRecordPresentation`：七类记录的副标题拼装、缺失字段跳过、胶囊与状态文案互斥。
- `LedgerQuery` / `LedgerScope` 的 `==` / `hashCode`：月份同日不同时、车辆 null 与具体 id。
- `LedgerRecordsNotifier`：首页加载、加载更多去重、分页失败保留数据、切换筛选丢弃过期响应。
- `MockLedgerRepository`：按车辆 / 分类过滤，总与分组自洽。

### 11.2 Widget 测试

- 汇总卡：金额三段字号、环比上涨 / 下降 / 无数据、三列颜色、柱数 = 已过天数。
- 月份选择：打开弹层、未来月份禁用、选择后汇总与列表刷新。
- 筛选：车辆 chip 单选、分类 chip 单选、结果条出现 / 清除、汇总不随分类变化。
- 列表：组头 + 组内记录数量、七类记录副标题、金额右对齐（`Text.maxLines == 1`）。
- 分页：滚动到底追加下一页、footer 三态、无重复。
- 状态：首屏骨架、汇总失败、列表失败、空月、筛选无结果。
- 导航：切到账单 Tab 时首页状态保留；重复点击账单 Tab 回到顶部。
- Golden（可选）：390×844 浅色 / 深色各一张，固定 Mock 数据、关闭动画。

### 11.3 CI

- PR 阶段沿用现有 workflow：`flutter pub get` + `flutter analyze` + `flutter test`。
- 覆盖率目标：`features/ledger/domain` 与 `data` ≥ 80%；关键交互有 Widget 测试。
- Golden 不作为必过项，避免字体渲染差异阻塞。

---

## 12. 实施拆分

| 阶段 | 内容 | 产出 |
| --- | --- | --- |
| M0 结构重构 | 迁移 `HomeCard` / `SkeletonBox` / `SectionError` / `EmptyState` / `HomeBottomNav`，新增 `AppTabShell` 与懒加载；`HomePage` 去导航 | 首页行为不变，账单 Tab 可挂载空页 |
| M1 静态账单页 | 顶部栏、汇总卡、双行 chips、分组流水（Mock 数据静态渲染） | 视觉对齐设计稿 |
| M2 数据与交互 | 模型 / 仓库 / providers、月份选择、车辆与分类筛选、汇总联动 | 筛选与月份切换可用 |
| M3 分页与状态 | 游标分页、下拉刷新、骨架 / 空态 / 错误态、竞态处理 | 长列表与异常场景完整 |
| M4 入口与联动 | FAB 跳记账页、记账返回刷新、首页「全部 / 查看全部」跳账单并带筛选 | 两页闭环 |
| M5 打磨 | 深色模式、无障碍、性能、导出 / 筛选面板（P1）、测试补齐 | 达到验收清单 |

分支建议：

- `refactor/tab-shell`（M0）
- `feat/ledger-page`（M1–M3）
- `feat/ledger-export`（P1 导出，可独立）

每个阶段保持 `flutter analyze` / `flutter test` 通过后合入功能分支；按仓库规范通过 PR 合并到 `main`。

**当前进度**：M0（共享组件迁移 + `AppTabShell` 懒加载）、M1（静态账单页）与 M2–M3（筛选、分页、骨架 / 空态 / 错误态、竞态）已完成；M4 的入口联动、M5 的导出 / 筛选面板与深色核对待后续迭代。

---

## 13. 风险与待确认

| 风险 | 影响 | 应对 |
| --- | --- | --- |
| 汇总与列表示例数据不自洽（Q1） | 验收时数字对不上 | 以本文档口径为准重造 Mock；接口字段固定为 `energyCents` / `serviceCents` |
| ~~`/km` 胶囊与首页单价不一致~~ | 已按 Q3 定稿统一为单价胶囊 | 已实现 `unitPricePillText` |
| 分类枚举缺「洗车」、命名不统一（Q4） | 筛选与图标映射返工 | 先按 8 项实现，服务端 key 以 `ExpenseCategory` 为准 |
| 设计稿无深色稿 | 深色视觉偏差 | 按 `AppPalette.dark` 推导并标注待核对 |
| 月份选择器 / 筛选面板无设计 | 交互与视觉不统一 | 复用 BottomSheet 与 chip 样式，评审时确认 |
| IndexedStack 全量构建 | 启动即发账单请求 | Tab 懒加载，未访问不构建 |
| 分页与新增记录并发 | 列表重复或遗漏 | 游标分页 + `id` 去重；返回页面时刷新首屏 |
| 数据量大时分组计算 | 滚动掉帧 | 仅数据变化时重算，行模型轻量，避免在 build 中排序 |
| 导出需新增依赖 | 评审成本 | P1 单独分支，先确认分享插件与权限 |
| 详情页未设计 | 点击无闭环 | 本期半屏摘要（复用记账页字段），下一迭代做整页详情 |

待确认（与需求文档 §13 同步）：

1. 维保服务口径与设计稿示例数据的修正。
2. ~~费用胶囊用 `¥/km` 还是 `¥/kWh`、`¥/L`~~（已定：单价胶囊）。
3. 分类筛选项是否补齐「洗车」并与其他分类合并方式。
4. 账单页车辆筛选是否与首页选中车辆联动。
5. 筛选条件是否跨会话记忆。
6. 月度汇总是否跟随分类筛选。
7. 记录详情页与编辑页的排期。
8. 后端是否提供游标分页与 `daily` 日序列聚合。
9. 深色设计稿时间点。

---

## 14. 附录：需求 → 实现映射

| 需求模块 | Widget / 类 | Provider | 测试重点 |
| --- | --- | --- | --- |
| 顶部栏 | `LedgerHeader` | `ledgerFilterProvider`（筛选角标） | 标题、角标显隐、毛玻璃 |
| 月度汇总卡 | `LedgerSummaryCard` / `MoneyDisplay` | `ledgerSummaryProvider(scope)` | 金额分段、环比三态、三列配色 |
| 日开销柱 | `LedgerDailyBars` | 同上 | 柱数、峰值、今天 / 峰值环 |
| 月份选择 | `LedgerMonthPickerSheet` | `ledgerFilterProvider.selectMonth` | 未来月份禁用、跨年 |
| 车辆筛选 | `LedgerVehicleChips` | `vehiclesProvider` + `ledgerFilterProvider` | 单选、动力色圆点、全部车辆 |
| 分类筛选 | `LedgerCategoryChips` | `ledgerFilterProvider` | 8 项、选中态、只影响列表 |
| 结果提示条 | `LedgerResultBar` | `LedgerQuery.category` | 文案、清除 |
| 日期分组 | `LedgerDayHeader` / `buildLedgerRows` | `LedgerRecordsNotifier` | 文案、顺序、组内统计 |
| 记录卡 | `LedgerRecordCard` / `LedgerRecordPresentation` | 同上 | 七类副标题、金额右对齐、胶囊 |
| 分页 | `LedgerFooter` / `loadMore()` | `LedgerRecordsNotifier` | 追加去重、失败重试、到底 |
| 空 / 错 / 骨架 | `EmptyState` / `SectionError` / `SkeletonBox` | — | 三种空态、模块级失败 |
| 底部导航 / FAB | `AppBottomNav` / `AppTabShell` | Tab 状态 | 选中态、懒加载、回顶 |


---

## 15. 实施记录（v0.2）

### 15.1 实际落地的文件

```
lib/core/
├── domain/enums.dart                     # PowertrainType / TrendDirection / ExpenseCategory
├── domain/vehicle.dart                   # Vehicle
├── presentation/category_style.dart      # 分类 / 动力语义色与图标（跨页共用）
├── widgets/app_card.dart                 # AppCard（原 HomeCard）
├── widgets/skeleton_box.dart
├── widgets/section_error.dart
├── widgets/empty_state.dart
├── widgets/app_bottom_nav.dart           # 原 HomeBottomNav
├── widgets/blurred_header_delegate.dart
├── widgets/money_display.dart            # ¥ + 整数大字 + 小数小字
└── format/formatters.dart                # 追加 splitYuanParts / formatDayTitle / formatUnitPrice 等

lib/app/tab_shell.dart                    # Tab 容器 + 懒加载 + 回顶 + FAB

lib/features/ledger/
├── data/ledger_repository.dart
├── data/mock_ledger_repository.dart      # 确定性 Mock：月份、车辆、分类、游标分页
├── domain/ledger_models.dart
├── domain/ledger_grouping.dart           # 按天分组 + 行拍平 + 结果条
├── domain/ledger_presenter.dart          # 副标题 / 单价胶囊 / 金额文案
├── domain/providers.dart                 # 筛选、汇总、游标分页 notifier
└── presentation/
    ├── ledger_page.dart
    └── widgets/                          # header / summary / bars / chips / day header / record card / footer / month picker
```

### 15.2 与设计稿的差异

| 项 | 处理 |
| --- | --- |
| 充电 / 加油胶囊 | 由 `¥/km` 改为 `¥/kWh`、`¥/L`（Q3） |
| 分类筛选项 | 补齐「洗车」，共 8 项（Q4） |
| 分组色条 | 使用分类语义色，今天固定主色（Q5） |
| 筛选绿点 | 仅非默认筛选时显示（Q6） |
| 汇总与列表口径 | 汇总跟随月份 + 车辆；分类筛选只影响列表并展示结果条（Q10） |
| 记录点击 / 导出 / 金额与支付筛选 | 本期占位提示，P1 迭代补齐 |
| 深色模式 | 沿用首页推导的 `AppPalette.dark`，待正式深色稿核对 |

### 15.3 测试

- `test/ledger/ledger_domain_test.dart`：分组顺序与组头统计、结果条、七类副标题与单价胶囊、金额正负、日期与金额格式化。
- `test/widget_test.dart`：账单 Tab 展示汇总 / 筛选 / 流水、分类筛选结果条与清除、月份选择器打开。
