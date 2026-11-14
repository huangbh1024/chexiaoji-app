# 首页技术方案 · 能耗与开销仪表盘

| 项目 | 内容 |
| --- | --- |
| 关联需求 | [首页需求文档 v0.2](../requirements/home-dashboard.md) |
| 设计稿 | [Stitch · 首页（支持车辆卡片动态联动）](https://stitch.google.com/projects/9615374848161425677?node-id=b8bb7f74b65742cabb5505a398d09182) |
| 客户端 | Flutter 3.50.0 stable / Dart 3.14 |
| 平台 | Android（arm64 优先）、iOS |
| 文档版本 | v0.1（技术方案初稿） |
| 状态 | 待评审；接口契约以最终后端文档为准 |

> 本文档给出首页的实现方案、模块拆分、数据模型、状态流转、图表与动效实现、测试与里程碑。仓库当前只有 Flutter 脚手架，以下目录与依赖均为**拟新增**，评审通过后按 `feat/home-dashboard` 分支实施。

---

## 1. 目标与约束

### 1.1 技术目标

- 首屏（顶部栏 + 车辆区 + Hero + 双指标）在 390×844 下无需滚动即可见，4G 冷启动可交互 ≤ 2s。
- 车辆切换后所有模块在 400ms 内完成数据替换；有缓存时 ≤ 100ms。
- 四类动力（EV / HEV / PHEV / ICE）共用一套组件，通过数据驱动差异，不写四套页面。
- 每个模块可独立加载、失败、重试；快速切换车辆时不出现旧车数据覆盖新车数据。
- 浅色 / 深色主题、明暗 token 全量覆盖；金额、里程、能耗、日期格式统一。

### 1.2 约束

- 设计系统为 Lumina Velocity；颜色、字号、圆角、阴影以设计稿为准。
- CI 在 PR 阶段只跑 `flutter analyze` 与 `flutter test`，不构建 APK；合并 `main` 后才打包。
- 不引入重量级依赖；图表优先 `fl_chart`，轻量曲线自绘。
- 接口未定稿，网络层与 DTO 必须可替换，UI 不直接依赖 JSON 字段。

---

## 2. 技术选型

| 领域 | 方案 | 理由 |
| --- | --- | --- |
| 状态管理 | **Riverpod**（`flutter_riverpod`） | family / autoDispose 天然适配「按车辆、按区间」拉取与取消；易测试、无 BuildContext 依赖 |
| 路由 | `go_router` | 声明式路由，Tab 壳 + 记账页 / 车辆页便于深链 |
| 网络 | `dio` | 拦截器、`CancelToken`、超时与错误映射完善 |
| 图表 | `fl_chart` | 折线面积图、环形图开箱即用，支持渐变、触摸提示、隐式动画 |
| 日期 / 数字 | `intl` | 中文日期、千分位、小数位格式化 |
| 本地存储 | `shared_preferences` | 存上次选中车辆、主题、最近一次首页 JSON 缓存 |
| 模型 | `freezed` + `json_serializable` | 不可变模型、`copyWith`、JSON 解析，减少手写样板 |
| 测试 | `flutter_test` + `mocktail` | 单测 / Widget 测试，Mock 仓库与网络 |
| 代码生成 | `build_runner` | 生成 freezed / json 文件，生成物提交仓库，CI 不额外跑生成 |

补充：

- 脚手架中的 `material_ui` 依赖若未被使用，实施时一并清理，避免无意义依赖。
- 依赖版本以 `pub.dev` 当前稳定版为准，在 `pubspec.yaml` 中锁定次要版本。
- 不引入 Bloc / GetX；Riverpod 已覆盖本项目复杂度。
- 图表点按提示与暗色适配优先用 `fl_chart` 原生能力，避免自绘整张图。

---

## 3. 工程结构

```
lib/
├── main.dart                          # ProviderScope + App
├── app/
│   ├── app.dart                       # MaterialApp.router
│   ├── router.dart                    # /home /ledger /stats /profile /entry
│   └── theme/
│       ├── app_colors.dart            # 色板常量
│       ├── app_typography.dart        # 字号 / 行高 / 字重
│       ├── app_tokens.dart            # ThemeExtension：间距、圆角、阴影
│       └── app_theme.dart             # light / dark ThemeData
├── core/
│   ├── network/
│   │   ├── dio_client.dart            # BaseOptions、拦截器
│   │   └── api_exception.dart         # DioException → 领域异常
│   ├── format/
│   │   ├── money.dart                 # 分 → ¥ 文案
│   │   ├── number_format.dart         # 里程、能耗、百分比
│   │   └── date_label.dart            # 今天/昨天/前天
│   ├── storage/preferences.dart
│   └── widgets/
│       ├── skeleton_box.dart
│       ├── error_retry.dart
│       └── empty_state.dart
└── features/
    ├── vehicles/
    │   ├── data/vehicle_api.dart
    │   ├── data/vehicle_repository.dart
    │   └── domain/vehicle.dart        # 车辆模型（车辆页 / 记账页共用）
    └── home/
        ├── data/
        │   ├── home_api.dart
        │   ├── home_repository.dart
        │   ├── home_cache.dart
        │   └── dto/                    # 接口 DTO + fromJson
        ├── domain/
        │   ├── home_dashboard.dart     # summary + consumption + maintenance
        │   ├── breakdown.dart
        │   ├── trend.dart
        │   ├── record_item.dart
        │   └── providers.dart          # Riverpod providers
        └── presentation/
            ├── home_page.dart
            ├── widgets/
            │   ├── home_header.dart
            │   ├── vehicle_switcher.dart
            │   ├── vehicle_card.dart
            │   ├── hero_card.dart
            │   ├── consumption_card.dart
            │   ├── maintenance_card.dart
            │   ├── trend_card.dart
            │   ├── breakdown_card.dart
            │   ├── recent_records.dart
            │   └── home_bottom_nav.dart
            └── painters/
                ├── sparkline_painter.dart
                ├── ring_progress_painter.dart
                └── hero_wave_painter.dart
```

职责边界：

- **presentation** 只消费领域模型，不解析 JSON、不计算业务口径。
- **data** 负责请求、缓存、DTO ↔ 领域模型转换。
- **domain** 放不可变模型与聚合口径的派生 getter（如展示用颜色、警示态）。
- 车辆模型放在 `features/vehicles`，后续账单页、统计页、记账页共用。

---

## 4. 数据流

```
Widget (watch provider)
   │
   ▼
Riverpod Provider / FutureProvider.family
   │  selectedVehicleId / trendRange
   ▼
HomeRepository ──► HomeApi (dio) ──► 后端
   │                   │
   │                   └─ CancelToken（切换车辆 / 区间时取消）
   ▼
HomeCache (shared_preferences)  ← 成功响应 / 离线兜底
```

- UI 只 watch 自己需要的 provider，避免整页重建。
- 车辆切换即 `selectedVehicleIdProvider` 变化 → 旧车辆的 family provider 自动 dispose → `CancelToken.cancel()`；新车辆 provider 重新请求。
- 请求结果写入缓存；网络失败时仓库回退缓存，并在数据上标记 `isStale` / `cachedAt`。

---

## 5. 数据模型

### 5.1 枚举与基础类型

```dart
enum PowertrainType { ev, hev, phev, ice }

enum MaintenanceStatus { normal, warning, overdue }

enum TrendDirection { up, down, flat, none }

enum TrendRange {
  d7('7d', '7天'),
  d30('30d', '30天'),
  halfYear('6m', '半年'),
  year('1y', '1年');

  const TrendRange(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

enum ExpenseCategory {
  charging('charging', '充电', Color(0xFF00C48C)),
  fuel('fuel', '加油', Color(0xFFFC9D41)),
  maintenance('maintenance', '保养', Color(0xFFEAB308)),
  parking('parking', '停车', Color(0xFF0EA5E9)),
  toll('toll', '过路费', Color(0xFF8B5CF6)),
  carWash('carWash', '洗车', Color(0xFFEC4899)),
  other('other', '其他', Color(0xFF94A3B8));

  const ExpenseCategory(this.key, this.label, this.color);
  final String key;
  final String label;
  final Color color;
}
```

金额统一使用**整数分**（`int cents`），展示时再换算，避免浮点累加误差：

```dart
class Money {
  const Money(this.cents);
  final int cents;

  String get yuanCompact => '¥${NumberFormat('#,##0', 'zh_CN').format(cents / 100)}';
  String get yuanDetail => '¥${NumberFormat('#,##0.00', 'zh_CN').format(cents / 100)}';
  static String perKm(double value) => '¥${value.toStringAsFixed(2)}/km';
}
```

### 5.2 车辆

```dart
@freezed
abstract class Vehicle with _$Vehicle {
  const factory Vehicle({
    required String id,
    required String name,
    required String plate,
    required PowertrainType powertrain,
    required String powertrainLabel, // 纯电 / 油电混动 / 插电混动 / 纯燃油
    required String powertrainMeta,  // 纯电 · 18,426 km
    String? badge,                   // 油电双模 / 绿牌插混 / 95号汽油
    required int odometerKm,
    @Default(false) bool isDefault,
  }) = _Vehicle;

  factory Vehicle.fromJson(Map<String, dynamic> json) => _$VehicleFromJson(json);
}
```

### 5.3 首页聚合

```dart
@freezed
abstract class HomeDashboard with _$HomeDashboard {
  const factory HomeDashboard({
    required Vehicle vehicle,
    required HomeSummary summary,
    required Consumption consumption,
    required Maintenance maintenance,
    required Breakdown breakdown,
    required List<RecordItem> records,
    required bool isStale,
    DateTime? cachedAt,
  }) = _HomeDashboard;

  factory HomeDashboard.fromJson(Map<String, dynamic> json) =>
      _$HomeDashboardFromJson(json);
}

@freezed
abstract class HomeSummary with _$HomeSummary {
  const factory HomeSummary({
    required String month,            // yyyy-MM
    required Money totalCost,
    required int distanceKm,
    required double costPerKm,
    required double energyCostPerKm,
    required double? momChangePercent,
    required TrendDirection momTrend,
  }) = _HomeSummary;
}

@freezed
abstract class Consumption with _$Consumption {
  const factory Consumption({
    required String label,      // 平均能耗 / 综合能耗 / 综合油耗
    required String typeLabel,  // 电耗 / 超低油耗 / 双模混动 / 95号汽油
    required ConsumptionValue primary,
    ConsumptionValue? secondary,
    @Default(<double>[]) List<double> primarySparkline,
    @Default(<double>[]) List<double> secondarySparkline,
  }) = _Consumption;
}

@freezed
abstract class ConsumptionValue with _$ConsumptionValue {
  const factory ConsumptionValue({
    required double value,
    required String unit, // kWh/百公里 或 L/百公里
  }) = _ConsumptionValue;
}

@freezed
abstract class Maintenance with _$Maintenance {
  const factory Maintenance({
    required bool enabled,
    required int remainingKm,
    required int? remainingDays,
    required int progressPercent, // 0–100
    required MaintenanceStatus status,
  }) = _Maintenance;
}
```

派生规则（放在 domain getter，便于单测）：

```dart
extension MaintenanceX on Maintenance {
  bool get isWarning => status == MaintenanceStatus.warning || progressPercent > 80;
  bool get isOverdue => status == MaintenanceStatus.overdue || remainingKm < 0;
  String get desc {
    if (!enabled) return '设置保养提醒';
    if (isOverdue) return '已超期 ${remainingKm.abs()} km';
    final days = remainingDays == null ? '' : ' · 约 $remainingDays 天';
    return 'km 后$days${isWarning ? '（即将保养）' : ''}';
  }
}
```

### 5.4 趋势 / 构成 / 记录

```dart
class TrendData {
  const TrendData({
    required this.range,
    required this.total,
    required this.previousTotal,
    required this.direction,
    required this.points,
  });
  final TrendRange range;
  final Money total;
  final Money previousTotal;
  final TrendDirection direction;
  final List<TrendPoint> points;

  Money get diffAmount => Money((total.cents - previousTotal.cents).abs());
}

class TrendPoint {
  const TrendPoint({required this.date, required this.energy, required this.other});
  final DateTime date;
  final Money energy;
  final Money other;
}

class Breakdown {
  const Breakdown({required this.total, required this.count, required this.categories});
  final Money total;
  final int count;
  final List<BreakdownCategory> categories; // 已按金额降序、过滤 0 金额
}

class BreakdownCategory {
  const BreakdownCategory({required this.category, required this.amount, required this.percent});
  final ExpenseCategory category;
  final Money amount;
  final int percent;
}

class RecordItem {
  const RecordItem({
    required this.id,
    required this.category,
    required this.title,
    required this.occurredAt,
    required this.amount,
    this.subLabel,
    this.subValue,
  });
  final String id;
  final ExpenseCategory category;
  final String title;
  final DateTime occurredAt;
  final Money amount;
  final String? subLabel; // ¥0.17/km 或 ¥8.16/L
  final String? subValue;
}
```

> DTO 与领域模型分离：`dto/` 中按接口字段命名，repository 负责转换。接口字段变化只改 DTO 与 mapper。

---

## 6. 网络层

### 6.1 接口

| 方法 | 路径 | 用途 | 时机 |
| --- | --- | --- | --- |
| GET | `/api/v1/vehicles` | 车辆列表、排序、默认车 | 冷启动 / 下拉刷新 |
| GET | `/api/v1/home?vehicleId=&month=` | summary + consumption + maintenance | 选中车辆变化 / 刷新 |
| GET | `/api/v1/home/trend?vehicleId=&range=` | 趋势曲线 | 首次进入 / 切换区间 / 切车 |
| GET | `/api/v1/home/breakdown?vehicleId=&month=` | 开销构成 | 首屏后并行 / 刷新 |
| GET | `/api/v1/home/records?vehicleId=&limit=5` | 最近记录 | 首屏后并行 / 刷新 |
| GET | `/api/v1/notifications/unread-count` | 未读红点 | 冷启动 / 前台恢复 |

首屏请求策略：

- `/home` 为关键路径，先发；`breakdown`、`records`、`trend` 并行发起，各自独立骨架与错误态。
- 车辆切换时，四类请求全部取消并重新发起。
- 若后端最终提供单一聚合接口，仅需替换 repository，UI 与 provider 不变。

### 6.2 Dio 配置

```dart
final dio = Dio(BaseOptions(
  baseUrl: AppConfig.apiBaseUrl,
  connectTimeout: const Duration(seconds: 8),
  receiveTimeout: const Duration(seconds: 10),
  headers: {'Accept': 'application/json'},
));

dio.interceptors.add(AuthInterceptor());   // 注入 token，401 触发登录
dio.interceptors.add(ErrorInterceptor());  // DioException → ApiException
```

异常映射：

| DioException | 领域异常 | UI 表现 |
| --- | --- | --- |
| `connectionTimeout` / `receiveTimeout` | `NetworkTimeout` | 模块重试 + Toast |
| `connectionError` / `unknown` 且无网络 | `NetworkOffline` | 展示缓存 + 离线条 |
| 401 | `Unauthorized` | 跳登录页 |
| 4xx | `BadRequest(message)` | 模块重试 / Toast |
| 5xx | `ServerError` | 模块重试 |
| `cancel` | 忽略（不发状态） | — |

### 6.3 缓存

- key：`home:v1:{vehicleId}:{month}`、`trend:v1:{vehicleId}:{range}`、`breakdown:v1:...`、`records:v1:...`。
- value：成功响应的 JSON + `cachedAt` 时间戳；使用 `shared_preferences`。
- 命中策略：网络成功覆盖缓存；网络失败且存在缓存 → 返回缓存并标记 `isStale = true`。
- 缓存不跨用户：登出时清空所有 `home:*` key。
- 建议缓存 TTL 24 小时；过期仍可作为离线兜底，但必须显示「数据更新于 …」。

---

## 7. 状态管理

### 7.1 Provider 设计

```dart
final preferencesProvider = Provider<AppPreferences>((ref) => ...);

final selectedVehicleIdProvider =
    NotifierProvider<SelectedVehicleIdNotifier, String?>(SelectedVehicleIdNotifier.new);

final vehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  return ref.watch(vehicleRepositoryProvider).fetchVehicles();
});

final homeDashboardProvider =
    FutureProvider.autoDispose.family<HomeDashboard, String>((ref, vehicleId) async {
  final token = CancelToken();
  ref.onDispose(token.cancel);
  return ref.watch(homeRepositoryProvider).fetchHome(vehicleId, token: token);
});

final breakdownProvider =
    FutureProvider.autoDispose.family<Breakdown, String>((ref, vehicleId) async {
  final token = CancelToken();
  ref.onDispose(token.cancel);
  return ref.watch(homeRepositoryProvider).fetchBreakdown(vehicleId, token: token);
});

final recordsProvider =
    FutureProvider.autoDispose.family<List<RecordItem>, String>((ref, vehicleId) async {
  final token = CancelToken();
  ref.onDispose(token.cancel);
  return ref.watch(homeRepositoryProvider).fetchRecords(vehicleId, token: token);
});

final trendRangeProvider = StateProvider<TrendRange>((ref) => TrendRange.d30);

final trendProvider = FutureProvider.autoDispose
    .family<TrendData, ({String vehicleId, TrendRange range})>((ref, key) async {
  final token = CancelToken();
  ref.onDispose(token.cancel);
  return ref.watch(homeRepositoryProvider).fetchTrend(
        key.vehicleId,
        key.range,
        token: token,
      );
});
```

- 选中车辆：`SelectedVehicleIdNotifier` 初始化时读取 `SharedPreferences`，切换时写入；首次进入回退到 `isDefault` 车辆，再回退到列表第一辆。
- 车辆切换：只需更新 `selectedVehicleIdProvider`，所有 family provider 自动切换；旧请求因 provider dispose 被 `CancelToken.cancel()`。
- 趋势区间：`trendRangeProvider` 变化只影响 `trendProvider`，不触发其他请求。
- 下拉刷新：`ref.invalidate` 当前车辆的 home / breakdown / records / trend，并 `await` 刷新完成以结束指示器。

### 7.2 竞态防护

Riverpod family + `ref.onDispose(cancel)` 已能防止大部分串车数据，但仍建议加**请求序号**兜底（防止同一 provider 重建时旧响应迟到）：

```dart
class HomeRepository {
  int _generation = 0;

  Future<HomeDashboard> fetchHome(String vehicleId, {CancelToken? token}) async {
    final gen = ++_generation;
    final data = await _api.fetchHome(vehicleId, token: token);
    if (gen != _generation) throw const StaleResponseIgnored();
    return _mapper.toDomain(data);
  }
}
```

UI 对 `StaleResponseIgnored` 不展示错误。

### 7.3 状态展示

| Provider 状态 | 模块表现 |
| --- | --- |
| `loading` 且无缓存 | 骨架屏 |
| `loading` 且有缓存 | 显示缓存 + 顶部细进度条（可选） |
| `data(isStale: true)` | 显示数据 + 顶部「数据更新于 x 分钟前」条 |
| `error` | 该模块「加载失败，点击重试」 |
| 无车辆 | 车辆区空状态，其余模块不请求 |

---

## 8. UI 实现

### 8.1 页面骨架

- `Scaffold(extendBody: true)`，`body` 为 `Stack`：内容滚动层 + 底部导航层。
- 内容区最大宽度 448，居中：`Center(child: ConstrainedBox(maxWidth: 448, ...))`。
- 顶部栏使用 `SliverPersistentHeader(pinned: true)` 或 `SliverAppBar`，内部 `ClipRect + BackdropFilter(blur 12–20)` 实现毛玻璃。
- 主滚动使用 `CustomScrollView`，各 section 用 `SliverToBoxAdapter`，间距 20px、左右 16px。
- 底部导航固定，内容 `padding.bottom = 112 + MediaQuery.padding.bottom`。
- 下拉刷新：`RefreshIndicator` 包裹 `CustomScrollView`。

```
HomePage
└── Stack
    ├── RefreshIndicator
    │   └── CustomScrollView
    │       ├── HomeHeader (pinned sliver，模糊)
    │       └── SliverList
    │           ├── VehicleSwitcher
    │           ├── HeroCard
    │           ├── Row[ConsumptionCard, MaintenanceCard]
    │           ├── TrendCard
    │           ├── BreakdownCard
    │           └── RecentRecords
    └── HomeBottomNav (含中央 FAB)
```

### 8.2 顶部栏

- 左侧 `CircleAvatar` 40 + 状态点；右侧问候 / 标题。
- 昵称超过 8 字符 `TextOverflow.ellipsis`。
- 操作胶囊 `Container(decoration: BoxDecoration(color: white70, borderRadius: pill))` + 3 个 `IconButton`。
- 通知红点用 `Positioned` 小圆点；未读数来自独立 provider。
- 状态栏图标亮度随主题：`AnnotatedRegion<SystemUiOverlayStyle>`。

### 8.3 车辆区

组件：`VehicleSwitcher` + `VehicleCard`。

- 横向 `ListView.separated(scrollDirection: Axis.horizontal)`，`padding: EdgeInsets.symmetric(horizontal: 16)`，卡宽 192、间距 12，末尾添加卡宽 80。
- 不做 `PageView`：需要同时支持半露卡片、末尾添加卡与自由滚动；用 `ScrollController` + `ScrollEndNotification` 计算最近卡更新指示器。
- 点击卡片：`selectedVehicleIdProvider.notifier.select(id)`；随后 `Scrollable.ensureVisible(context, alignment: 0.5, duration: 250ms)` 居中。
- 选中态用 `AnimatedContainer`（200–300ms）切换边框、阴影、透明度。
- 卡片右上角：选中显示勾选徽标；未选中显示动力 / 油品标签。
- 指示器：`AnimatedContainer` 在 6×6 圆点与 16×6 绿条之间过渡；车辆数 > 5 时显示省略。
- 添加卡：`DottedBorder` 或自绘虚线（避免额外依赖，可用 `CustomPainter`）。
- 骨架：3 个 `SkeletonBox(192×120)` + 80px 占位。

### 8.4 Hero 卡

- 外层 `Container` + `LinearGradient`（`#00C48C → #05B380 → #0A8C66`），`borderRadius 16`，阴影。
- 背景波浪：`CustomPaint` 绘制两条白色曲线，整体 `Opacity(0.2)`；光晕用 2 个 `DecoratedBox` + `ImageFilter.blur`。
- 环形 / 磨砂三列：`Container` 白色 10% + `BackdropFilter` + 1px 白色 20% 边框。
- 环比胶囊：`Row(icon + text)`；上涨时背景 `Color(0xFFF43F5E).withOpacity(0.30)`、边框同色 30%，图标 `trending_up`；下降白色 20%。
- 数字：`¥` 26px、数值 38px/800、`/km` 13px；使用 `RichText` 保证基线对齐。
- 数字动画：`TweenAnimationBuilder<double>`，切车时随整块淡入，不做逐位滚动（避免与切换动效冲突）。

### 8.5 双指标卡

布局：`Row(children: [Expanded(ConsumptionCard), SizedBox(12), Expanded(MaintenanceCard)])`，等高由 `IntrinsicHeight` 或固定内容高度保证；建议两卡都设 `mainAxisSize: min` 并让内部 `Spacer` 控制。

**ConsumptionCard**

```
Column
├── Row[icon 28, label, Spacer, typePill]
├── 主数值 Row[24px value, 10px unit]
├── if (secondary != null) Divider + Row[14px orange value, 10px unit]
└── SizedBox(height: 32, child: CustomPaint(SparklinePainter))
```

- 单位 / 标题完全由 `Consumption` 数据驱动，不在 UI 里 switch 动力类型。
- 副能耗橙色 `#FC9D41`；分隔线 1px 浅灰 60%。
- `SparklinePainter`：
  - 输入 `List<double>`，归一化到画布；
  - 主曲线 `Path` 三次贝塞尔平滑，2.5px 圆头；
  - 面积用 `LinearGradient(#00C48C 15% → 透明)`；
  - 副曲线 `dash 3/3`、1.5px 橙色，无面积；
  - 点数 < 2 时直接返回；
  - `shouldRepaint` 比较数据列表。

**MaintenanceCard**

- 左侧数值 / 描述，右侧 44×44 `CustomPaint(RingProgressPainter)`。
- `RingProgressPainter`：底环 `#E5EEFF` 3.5px，进度环 3.5px 圆头，起始 -90°；`progress` 用 `TweenAnimationBuilder` 从旧值过渡到新值（500ms）。
- 警示态：`progress > 80` 或 `status == warning` → 环与图标底色变 `#BA1A1A`，图标容器 `#FEE2E2`；超期文案「已超期 x km」。
- 未配置：不画环，显示「设置保养提醒」文字按钮，点击跳车辆编辑页。

### 8.6 趋势卡

- 标题区 + 图例 + 自定义分段控件（4 段）。
- 分段控件用 `Container` 托盘 + 每段 `InkWell` + `AnimatedContainer` 白色胶囊，避免 `SegmentedButton` 默认样式差异。
- 图表：`fl_chart` 的 `LineChart`：

```dart
LineChart(
  LineChartData(
    minX: 0,
    maxX: (points.length - 1).toDouble(),
    minY: 0,
    maxY: yMax,
    gridData: FlGridData(show: true, drawVerticalLine: false, ...),
    titlesData: FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: xInterval)),
    ),
    lineBarsData: [
      _bar(points.map((p) => p.other.cents / 100), color: orange),
      _bar(points.map((p) => p.energy.cents / 100), color: green),
    ],
    lineTouchData: LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(getTooltipItems: ...),
    ),
  ),
  duration: const Duration(milliseconds: 300),
)
```

- `LineChartBarData` 配置：`isCurved: true`、`preventCurveOverShooting: true`、`dotData: FlDotData(show: false)`、`belowBarData: BarAreaData(show: true, gradient: ...)`、`barWidth: 2.5`。
- 曲线层级：橙色（其他开销）在下，绿色（能源）在上，避免遮挡。
- 范围切换：`ref.read(trendRangeProvider.notifier).state = range`；卡片内 `AnimatedSwitcher` 淡入新图（200ms）。
- X 轴标签数量按宽度限制为 5–7 个，避免重叠：30 天取 6 个刻度，7 天逐日，半年 / 1 年按月。
- 金额为 0 时 `maxY = 100` 兜底，防止除零；单位刻度取整到 100 / 200 / 500。

### 8.7 开销构成

- `fl_chart` `PieChart`：`startDegreeOffset: -90`（12 点起顺时针），`sectionsSpace: 2`，`centerSpaceRadius: 34`。
- Section 颜色来自 `ExpenseCategory.color`；`showTitle: false`；中心用 `Stack` 叠加「合计 / 金额」。
- 数据已由 repository 过滤 0 金额并按金额降序，UI 不再排序。
- 切换车辆时用 `PieChart(..., duration: 500ms)` 隐式动画；或 `TweenAnimationBuilder<double>` 插值各段 sweep。
- 图例行用 `Wrap`/`Column`；金额加粗、百分比灰色；点击触发账单列表（P1）。

### 8.8 最近记录

- 白色容器 + 内部分隔线，行高自适应，最多 5 条。
- 图标：`Container(40×40, color: category.color.withOpacity(.12), child: Icon(category.icon, color: category.color))`。
- 副值颜色：充电使用绿色，加油使用橙色；由 `RecordItem.subLabel` 的类型或分类决定。
- 标题 / 副标题均 `maxLines: 1` + `ellipsis`；金额固定列宽右对齐，避免长标题挤压。
- 点击行 `context.push('/ledger/detail/${record.id}')`；「全部」`/ledger`。
- 返回首页时 `ref.invalidate` 相关 provider（或监听路由返回）以刷新。

### 8.9 底部导航与 FAB

- 自定义 `HomeBottomNav`（不用默认 `BottomNavigationBar`，需要悬浮与中央凸起）。
- `Container` 白 90% + `BackdropFilter(blur 20)` + 顶部圆角 16 + 上阴影；`SafeArea(top: false)`。
- 4 个 Tab 均分；选中态图标 / 文案绿色 + 顶部 16×4 绿条（用 `AnimatedContainer`）。
- FAB：`Positioned` 居中，`bottom: navHeight - 28`（上移 20px），56×56 渐变 + 环 4px 背景色；点击 `context.push('/entry')`。
- Tab 切换使用 `go_router` 的 `StatefulShellRoute.indexedStack`，保留各 Tab 状态。
- 重复点击当前 Tab：通过 `GoRouterState` 判断，滚动 `ScrollController` 到顶部。

### 8.10 主题与设计 token

```dart
class AppColors {
  static const primary = Color(0xFF00C48C);
  static const primaryText = Color(0xFF006C4B);
  static const fuel = Color(0xFFFC9D41);
  static const background = Color(0xFFF8F9FF);
  static const surface = Colors.white;
  static const onSurface = Color(0xFF0B1C30);
  static const outline = Color(0xFF6C7A72);
  static const error = Color(0xFFBA1A1A);
}

class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.radiusCard,
    required this.radiusPill,
    required this.spaceXs,
    required this.spaceSm,
    required this.spaceMd,
    required this.spaceLg,
    required this.cardShadow,
    required this.pagePadding,
  });
  // light / dark 两套静态实例
}
```

- `ThemeData(useMaterial3: true)`，`ColorScheme.fromSeed(seedColor: AppColors.primary)` 后按设计稿覆盖关键色。
- 字体：`fontFamily: 'Plus Jakarta Sans'`，`fontFamilyFallback: ['PingFang SC', 'Noto Sans SC', 'sans-serif']`；字体文件放入 `assets/fonts/` 并在 `pubspec.yaml` 声明，注意子集化与授权。
- 深色主题：背景 `#0B1C30`、卡片 `#16263D`（待设计深色新版确认），绿色主色保持；图表网格与分类色需提升明度以满足对比度。
- 阴影、圆角、间距统一从 `AppTokens` 读取，禁止散落魔法数。

### 8.11 格式化

```dart
String formatKm(int km) => '${NumberFormat('#,##0', 'zh_CN').format(km)} km';
String formatEnergy(double v, String unit) => '${v.toStringAsFixed(1)} $unit';
String formatPercent(double v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}%';
String formatDateLabel(DateTime dt, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final d = DateUtils.dateOnly(dt);
  final today = DateUtils.dateOnly(n);
  final diff = today.difference(d).inDays;
  if (diff == 0) return '今天 ${DateFormat('HH:mm').format(dt)}';
  if (diff == 1) return '昨天 ${DateFormat('HH:mm').format(dt)}';
  if (diff == 2) return '前天 ${DateFormat('HH:mm').format(dt)}';
  if (dt.year == n.year) return DateFormat('M月d日').format(dt);
  return DateFormat('yyyy年M月d日').format(dt);
}
```

- 聚合金额取整：`Money.yuanCompact`；明细保留两位：`Money.yuanDetail`。
- 负号只用于支出：`'-${money.yuanDetail}'`。
- 空值统一显示「—」，禁止显示 `null` / `NaN`。

### 8.12 无障碍

- Hero、能耗、保养、趋势卡外层包 `Semantics(container: true, label: ...)`，把金额与单位组合成一句中文。
- 车辆卡 `Semantics(selected: isSelected, button: true, label: '${name}，${plate}，${powertrainMeta}')`。
- 图表提供文字摘要（如「近 30 天共花费 1,286 元，能源 900 元，其他 386 元」），供读屏使用。
- 文本缩放 1.3 倍时，金额列可换行或缩字号，不截断。

---

## 9. 性能

| 优化点 | 措施 |
| --- | --- |
| 首屏 | `/home` 优先；breakdown / records / trend 并行，不阻塞首屏 |
| 切换车辆 | 取消旧请求；优先命中内存 provider 缓存，其次本地缓存 |
| 重建范围 | 每个 section 单独 `Consumer` / `ref.watch`，避免整页 rebuild |
| 图表 | 外层 `RepaintBoundary`；点数限制 ≤ 90（30 天日粒度），半年 / 1 年服务端聚合到月 |
| 列表 | 车辆区 `ListView.builder`；记录最多 5 条，无需懒加载 |
| 图片 | 头像使用 `cacheWidth`，网络图带占位与缓存 |
| 字体 | 仅打包必要字重（400/500/600/700/800），中文走系统字体 |
| 启动 | 主题 / 上次车辆从本地同步读取，避免首帧闪变 |

指标：首屏可交互 ≤ 2s；切换车辆渲染 ≤ 400ms（有缓存 ≤ 100ms）；滚动掉帧率 < 1%。

---

## 10. 错误与边界处理

| 场景 | 处理 |
| --- | --- |
| 无车辆 | 车辆区空状态 + 添加按钮；不请求 home 系列接口 |
| 里程为 0 / 缺失 | 每公里成本显示「—」；Hero 三列显示 0 |
| 上月无数据 | 环比显示「较上月 —」 |
| 无能耗数据 | 能耗显示「—」，sparkline 不画线 |
| 保养未配置 | 引导设置，不显示 0 / 负值 |
| 保养超期 | 红色 + 「已超期 x km」，进度环封顶 |
| 分类全为 0 | 构成显示「本月暂无开销」 |
| 最近记录为空 | 空状态 +「记一笔」 |
| 网络失败且有缓存 | 展示缓存 + 离线提示条 |
| 网络失败且无缓存 | 模块级错误 + 重试 |
| 401 | 跳登录，登录后恢复上次车辆 |
| 车辆被删除 | 自动切默认车 + Toast |
| 快速连续切车 | CancelToken + 请求序号，丢弃过期响应 |
| 金额超长 | 千分位 + 必要时缩字号，不换行 |

---

## 11. 测试方案

### 11.1 单元测试

- `Money`：分 → 元、千分位、两位 / 取整、负数。
- `formatDateLabel`：今天 / 昨天 / 前天 / 本年内 / 跨年 / 跨零点。
- 能耗、每公里成本、保养剩余天数、进度、百分比排序与 0 过滤。
- `MaintenanceX.desc`：正常 / 警告 / 超期 / 未配置四种文案。
- `HomeRepository`：网络成功写缓存、失败回退缓存并标记 `isStale`、过期响应被丢弃。
- `SelectedVehicleIdNotifier`：恢复上次车辆、默认车回退、删除车回退。

### 11.2 Widget 测试

- 四类动力数据分别渲染：标题、胶囊、单位、副能耗行、sparkline 数量。
- 点击车辆卡：选中态、指示器、四个模块内容同步替换（用 fake repository 即时返回）。
- 保养 > 80%：红色环 + 文案包含「即将保养」；超期文案。
- 空车辆 / 空记录 / 模块错误 / 离线缓存四种状态的 UI。
- 趋势区间切换：只有趋势卡变化，其他模块不重建（可用 `ProviderScope` 计数或 golden 对比）。

### 11.3 Golden 测试（可选）

- 首页浅色 / 深色各一张（390×844），覆盖四类动力代表数据。
- 图表使用固定数据与关闭动画，保证稳定。

### 11.4 CI

- PR：`flutter analyze` + `flutter test`（与现有 workflow 一致）。
- 覆盖率目标：domain / data 层 ≥ 80%，presentation 关键交互有 Widget 测试。
- 不把视觉回归放进 PR 必过项，避免字体差异导致阻塞。

---

## 12. 实施拆分

| 阶段 | 内容 | 产出 |
| --- | --- | --- |
| M1 基建 | 依赖、目录、主题 token、路由壳、ProviderScope | App 可运行，空首页 |
| M2 数据层 | DTO / 模型 / API / Repository / 缓存 | Mock 与真实接口均可返回数据 |
| M3 静态首页 | 顶部栏、车辆区、Hero、双指标、底部导航 | 视觉对齐设计稿（假数据） |
| M4 图表 | 趋势、环形、sparkline、保养环 | 图表可交互、可动画 |
| M5 联动与状态 | 车辆切换、区间切换、加载 / 空 / 错误 / 离线、持久化 | 全流程可用 |
| M6 打磨 | 深色模式、无障碍、性能、测试补齐 | 达到验收清单 |

建议分支：`feat/home-dashboard`（代码）、`feat/home-charts`（图表可独立拆分支）；每阶段保持 `flutter analyze` / `flutter test` 通过后合入功能分支。

---

## 13. 风险与待确认

| 风险 | 影响 | 应对 |
| --- | --- | --- |
| 接口契约未定稿 | DTO / 聚合字段返工 | DTO 与领域模型隔离；先用 Mock 开发；字段命名集中映射 |
| 插混能耗主单位 `kWh` vs `kWh/百公里` | 双能耗卡展示不一致 | 统一为 `kWh/百公里`，待产品确认 |
| 深色设计稿仍是上一版 | 深色视觉偏差 | 新版深色稿出来前，先按 token 推导，标注待核对 |
| Plus Jakarta Sans 不含中文 | 中文回退字体不一致 | `fontFamilyFallback` + 真机核验；必要时打包思源黑体子集 |
| 图表性能 / 定制限制 | 滑动掉帧、渐变与虚线支持差异 | 优先 `fl_chart` 原生；sparkline / 圆环自绘；`RepaintBoundary` |
| 金额浮点误差 | 汇总不一致 | 全链路整数分；仅展示时转 double |
| 车辆切换竞态 | 旧数据覆盖新车 | CancelToken + 请求序号 + family provider |
| 首屏并发请求过多 | 弱网首屏变慢 | `/home` 关键路径优先；其余并行但独立骨架；可合并接口 |

待确认（与需求文档 §13 同步）：

1. 默认选中车辆规则与上次选择持久化。
2. 插混主能耗单位。
3. 保养警示阈值与超期文案。
4. 车辆卡动力 / 油品标签是否保留。
5. 最近记录展示条数（3 或 5）。
6. 通知中心是否本期实现。
7. 金额精度（建议后端整数分）。
8. 后端是否提供聚合 `/home` 接口及字段最终命名。
9. 深色模式新版设计稿时间点。
10. 车牌、地点等敏感字段的日志脱敏规范。

---

## 14. 附录：需求 → 实现映射

| 需求模块 | Widget | Provider | 测试重点 |
| --- | --- | --- | --- |
| 顶部栏 | `HomeHeader` | `profileProvider` / `unreadCountProvider` | 问候时间、红点、主题切换 |
| 我的车辆 | `VehicleSwitcher` / `VehicleCard` | `vehiclesProvider` / `selectedVehicleIdProvider` | 四类动力、选中态、指示器、持久化 |
| Hero 卡 | `HeroCard` | `homeDashboardProvider(id)` | 金额格式、涨跌配色、零数据 |
| 平均能耗 | `ConsumptionCard` | `homeDashboardProvider(id)` | 单 / 双能耗矩阵、sparkline |
| 下次保养 | `MaintenanceCard` | `homeDashboardProvider(id)` | 正常 / 警示 / 超期 / 未配置 |
| 花费趋势 | `TrendCard` | `trendProvider(vehicleId, range)` | 区间切换、曲线、涨跌文案 |
| 开销构成 | `BreakdownCard` | `breakdownProvider(id)` | 排序、零过滤、合计一致 |
| 最近记录 | `RecentRecords` | `recordsProvider(id)` | 副值规则、时间文案、点击跳转 |
| 底部导航 | `HomeBottomNav` | 路由 | Tab 状态、FAB、重复点击回顶 |
