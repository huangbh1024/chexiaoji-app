# 月度报表与导出页技术方案

| 项目 | 内容 |
| --- | --- |
| 关联需求 | [月度报表与导出页需求文档 v0.1](../requirements/monthly-report.md) |
| 设计稿 | [Stitch · 账单导出与月度报表预览页](https://stitch.google.com/projects/9615374848161425677?node-id=6e6486f813ee4d1d87708cf7fab49890) |
| 客户端 | Flutter 3.50.0 stable / Dart 3.14 |
| 平台 | Android（arm64 优先）、iOS |
| 文档版本 | v0.1（待评审） |
| 状态 | 设计完成，未实施；导出依赖与后端契约待确认 |

> 本文档基于**仓库当前已有实现**（首页、账单页、`AppTabShell` 已落地，依赖为 `material_ui`、`flutter_riverpod`、`fl_chart`、`intl`）编写。所有新增目录、文件与依赖均为拟实施内容，按 `feat/monthly-report` 分支推进。

---

## 1. 目标与约束

### 1.1 技术目标

- 进入页面 ≤ 800ms 可交互，有缓存 ≤ 200ms；切换月份 / 车辆 ≤ 500ms。
- 预览与导出**同源**：同一份 `MonthlyReport` 模型、同一套格式化函数、同一套隐私规则，避免「预览一个数、PDF 另一个数」。
- 报表聚合结果与账单页汇总**严格一致**：同一 `month + vehicleId` 的总额、笔数、分类金额必须相等。
- PDF 单页 A4，中文可选中、字体嵌入、矢量图表，体积 < 2MB（字体子集后争取 < 800KB），生成 ≤ 800ms。
- CSV 3000 条 ≤ 1.5s，UTF-8 BOM，Excel / WPS 不乱码，公式注入安全。
- 导出任务串行、可失败重试、不产生半成品文件；离开页面可安全取消。
- 复用现有 token、组件、Mock 仓库、格式化与分类语义色，不引入第二套视觉规范。

### 1.2 约束

- **新增依赖**（本页无法避免，需在 PR 中单独说明）：
  - `pdf`：PDF 文档构建（纯 Dart）；
  - `printing`：系统打印与 PDF 预览；
  - `share_plus`：系统分享面板；
  - `path_provider`：临时目录。
  - 版本以 pub 最新稳定版为准，锁定后写入 `pubspec.yaml` 并更新 `pubspec.lock`。
- 金额全链路使用 **整数分**（`int cents`），与 `formatters.dart` 一致。
- 不引入 `go_router`：本页用 `Navigator.push` 打开，返回即 `pop`。
- PDF 固定浅色纸张，不随 App 主题变化；屏幕预览在深色模式下仍使用白纸（纸的隐喻），页面外框跟随主题。
- 报表数据由后端聚合接口提供；接入前由 `MockReportRepository` 基于账单 Mock 计算，保证两页一致。
- 不把报表文件上传服务端；生成、分享、清理全部在客户端完成。

---

## 2. 现状与复用清单

| 现有能力 | 位置 | 本页用法 |
| --- | --- | --- |
| 色彩 token | `lib/app/theme/app_colors.dart` → `AppPalette` / `AppColors` | 页面与预览纸全部颜色；新增 `paper` 等常量按需补充 |
| 间距 / 圆角 / 阴影 | `lib/app/theme/app_tokens.dart` → `AppTokens` | 页面边距、卡片圆角、底栏阴影 |
| 字体 | `lib/app/theme/app_typography.dart` | `headlineSm`、`bodySm`、`labelMd`、`labelSm` 等 |
| 金额 / 日期 / 里程格式化 | `lib/core/format/formatters.dart` | `formatYuanCompact`、`formatYuanDetail`、`formatSignedPercent`、`formatKm`、`formatMonthLabel` 等 |
| 分类 / 动力语义色与图标 | `lib/core/presentation/category_style.dart` | 车辆圆点、动力图标、分类条色值 |
| 基础枚举 | `lib/core/domain/enums.dart` | `ExpenseCategory`、`PowertrainType`、`TrendDirection` |
| 车辆模型与数据 | `lib/core/domain/vehicle.dart`、`vehiclesProvider` | 车辆 chips、报表车辆条；Mock 报表复用 `HomeRepository` |
| 报表入口 | `lib/features/ledger/presentation/widgets/ledger_header.dart` | 导出按钮由 Toast 改为 `Navigator.push` 本页 |
| 月份选择器 | `lib/features/ledger/presentation/widgets/ledger_month_picker_sheet.dart` | 直接复用 `showLedgerMonthPicker` |
| 车辆 chips 样式 | `lib/features/ledger/presentation/widgets/ledger_vehicle_chips.dart` | 复用胶囊形状与动力圆点；选中态改为设计稿的绿色 |
| 账单汇总 / 记录模型 | `lib/features/ledger/domain/ledger_models.dart` | Mock 报表聚合的输入；CSV 明细来源 |
| 账单仓库 | `lib/features/ledger/data/ledger_repository.dart` | `MockReportRepository` 通过它拉取全月记录 |
| 顶部毛玻璃 | `lib/core/widgets/blurred_header_delegate.dart` | 本页 sticky 顶栏 |
| 卡片 / 骨架 / 错误 / 空态 | `lib/core/widgets/app_card.dart`、`skeleton_box.dart`、`section_error.dart`、`empty_state.dart` | 页面外框与状态 |
| 图表库 | `fl_chart`（首页 `trend_card.dart` 已使用） | 预览走势图；PDF 使用 `pdf` 自绘 |
| Riverpod | `flutter_riverpod` | 报表数据、导出控制器 |
| Tab 壳 | `lib/app/tab_shell.dart` | 本页作为二级路由覆盖在 Tab 之上，不参与 `IndexedStack` |

---

## 3. 目录结构

```
lib/
├── core/
│   └── format/formatters.dart              # 追加：formatReportNo / maskPlate / formatReportDate
└── features/
    └── report/
        ├── data/
        │   ├── report_repository.dart       # 抽象接口
        │   ├── mock_report_repository.dart  # 基于 LedgerRepository + HomeRepository 聚合
        │   └── report_api.dart              # 接口契约与 DTO（暂不实现）
        ├── domain/
        │   ├── report_models.dart           # ReportScope / MonthlyReport / 分组 / 日点 / 选项
        │   ├── report_aggregation.dart      # 纯函数：聚合、里程、百分比、单号、脱敏
        │   ├── report_presenter.dart        # 展示文案：能耗行、环比、图例、文件名
        │   ├── report_chart_geometry.dart   # 预览与 PDF 共用的曲线几何
        │   └── providers.dart               # 仓库、报表 FutureProvider
        ├── export/
        │   ├── report_exporter.dart          # 抽象：PDF / CSV / 长图 / 分享 / 打印
        │   ├── report_pdf_builder.dart      # pdf 包构建 A4 单页
        │   ├── report_csv_builder.dart      # UTF-8 BOM + RFC 4180
        │   ├── report_image_builder.dart    # 长图（P1）
        │   └── report_file_service.dart     # 临时目录、命名、清理
        └── presentation/
            ├── monthly_report_page.dart      # 页面入口与路由
            ├── report_style.dart            # 报表内专用样式 / 布局预算
            ├── report_export_controller.dart # 导出状态机（ChangeNotifier）
            └── widgets/
                ├── report_header.dart
                ├── report_scope_bar.dart
                ├── report_month_pill.dart
                ├── report_vehicle_chips.dart
                ├── report_paper_preview.dart
                ├── report_paper_header.dart
                ├── report_vehicle_strip.dart
                ├── report_kpi_row.dart
                ├── report_trend_chart.dart
                ├── report_category_bar.dart
                ├── report_paper_footer.dart
                ├── report_format_cards.dart
                ├── report_option_toggles.dart
                ├── report_bottom_dock.dart
                └── report_fullscreen_preview.dart
```

`assets/` 新增：

```
assets/fonts/NotoSansSC-Regular.ttf   # PDF 中文字体（子集，见 §11）
assets/fonts/NotoSansSC-Bold.ttf
```

---

## 4. 数据流

```
LedgerHeader(onExport)
        │ Navigator.push(initialScope: ledgerFilter)
        ▼
MonthlyReportPage (route-local state: _scope / _options)
        │
        ├── ref.watch(monthlyReportProvider(_scope))
        │        │
        │        ▼
        │   ReportRepository ──> ReportApi（未来） / MockReportRepository
        │        │                       │
        │        │                       ├── LedgerRepository.fetchRecords（分页拉全月）
        │        │                       └── HomeRepository.fetchVehicles
        │        ▼
        │   MonthlyReport（不可变聚合结果，按 scope 缓存）
        │
        ├── ReportPaperPreview(report, options)   # 屏幕 A4 预览
        └── ReportExportController
                 ├── ReportPdfBuilder(report, options)  → File → share / print
                 ├── ReportCsvBuilder(scope, options)   → File → share
                 └── ReportImageBuilder(previewKey)      → File → share（P1）
```

- `_scope` 与 `_options` 是页面局部状态，不写入全局 provider：离开页面即销毁，避免污染账单页筛选。
- `monthlyReportProvider` 为 `FutureProvider.autoDispose.family`，key 为值相等的 `ReportScope`。
- 导出控制器由页面持有（`ChangeNotifier`），通过 `reportExporterProvider` 注入真实 / Fake 实现，便于测试。
- 报表缓存 key = `month|vehicleId`，Mock 与未来 HTTP 实现都在仓库内部缓存；切换回来时先显示缓存再后台刷新（P1）。

---

## 5. 数据模型

### 5.1 范围与选项

```dart
@immutable
class ReportScope {
  const ReportScope({required this.month, this.vehicleId});

  /// 归一化到当月 1 日 00:00（本地时区）。
  final DateTime month;

  /// null = 全部车辆。
  final String? vehicleId;

  String get monthKey =>
      '${month.year.toString().padLeft(4, '0')}-'
      '${month.month.toString().padLeft(2, '0')}';

  ReportScope copyWith({DateTime? month, String? vehicleId, bool clearVehicle = false}) => ...;

  @override
  bool operator ==(Object other) =>
      other is ReportScope &&
      other.month.year == month.year &&
      other.month.month == month.month &&
      other.vehicleId == vehicleId;

  @override
  int get hashCode => Object.hash(month.year, month.month, vehicleId);
}

enum ReportFormat { pdf, csv, poster }

@immutable
class ReportOptions {
  const ReportOptions({
    this.format = ReportFormat.pdf,
    this.includeEnergy = true,
    this.includeInvoices = false,
    this.maskPlate = false,
  });

  final ReportFormat format;
  final bool includeEnergy;

  /// 本期恒为 false（无附件能力），保留字段供 P1。
  final bool includeInvoices;
  final bool maskPlate;

  ReportOptions copyWith({...}) => ...;
}
```

> `ReportScope` 与账单的 `LedgerScope` 结构相似但**不复用**：报表范围不含分类与排序，语义更窄；复用会导致 `runtimeType` 相等判断与未来字段分叉。入口处做一次显式转换即可。

### 5.2 报表模型

```dart
enum ReportStatus { recording, issued }

enum ReportCategoryKey { charging, fuel, maintenance, parking, toll, carWashOther }

class ReportCategoryGroup {
  const ReportCategoryGroup({
    required this.key,
    required this.label,
    required this.amountCents,
    required this.count,
    required this.percent,   // 0–100，已做最大余数修正；总额 ≤ 0 时为 null
  });
  ...
}

class ReportDailyPoint {
  const ReportDailyPoint({
    required this.date,
    required this.chargingCents,
    required this.otherCents,
    this.dominantCategory,
  });

  final DateTime date;
  final int chargingCents;
  final int otherCents;
  final ExpenseCategory? dominantCategory;

  int get totalCents => chargingCents + otherCents;
}

class ReportVehicleBrief {
  const ReportVehicleBrief({
    required this.id,
    required this.name,
    required this.plate,
    required this.powertrain,
    required this.powertrainLabel,
    required this.odometerKm,
  });
  ...
}

class MonthlyReport {
  const MonthlyReport({
    required this.scope,
    required this.reportNo,
    required this.status,
    required this.generatedAt,
    required this.totalCents,
    required this.recordCount,
    required this.distanceKm,
    required this.days,
    required this.costPerKmCents,
    required this.energyKwh,
    required this.fuelLiters,
    required this.kwhPer100km,
    required this.litersPer100km,
    required this.momPercent,
    required this.momTrend,
    required this.vehicles,
    required this.categories,
    required this.daily,
    required this.verified,
    required this.verificationText,
    this.settledAt,
    this.updatedAt,
    this.isOffline = false,
  });
  ...
}
```

- 金额、笔数、里程、能耗均为服务端 / 仓库聚合结果；客户端不拿 `LedgerMonthSummary` 直接展示（它缺少里程、能耗与分类分组）。
- `categories` 固定按 §7.3 的 6 组顺序排列，金额为 0 的组可以保留在模型里，由 UI 过滤；`percent` 为 null 表示总额 ≤ 0。
- `daily` 覆盖当月 1 日至最后一天；当前月只到今天。缺失日期由聚合函数补齐为 0，保证曲线连续。
- `verified` / `verificationText` 由后端下发；Mock 阶段固定 `verified = false`，文案使用本地汇总版本。

### 5.3 导出状态

```dart
enum ReportExportPhase { idle, preparing, generating, sharing, done, failed }

class ReportExportState {
  const ReportExportState({
    this.phase = ReportExportPhase.idle,
    this.progress = 0,
    this.format = ReportFormat.pdf,
    this.message,
    this.error,
  });

  final ReportExportPhase phase;
  final double progress;      // 0–1，仅用于文案
  final ReportFormat format;
  final String? message;      // 「正在生成 PDF…」
  final Object? error;

  bool get isBusy =>
      phase == ReportExportPhase.preparing ||
      phase == ReportExportPhase.generating ||
      phase == ReportExportPhase.sharing;
}
```

`ReportExportController` 负责：

```dart
Future<void> export({
  required MonthlyReport report,
  required ReportOptions options,
  required ReportScope scope,
  required ExportAction action, // export / print / share
});
```

- 串行执行：`isBusy` 时忽略重复调用。
- `preparing`：CSV 需拉取全月流水；PDF 直接使用报表模型。
- `generating`：写临时文件。
- `sharing`：调用系统分享 / 打印。
- `done`：Toast「报表已生成」，1.5s 后回到 `idle`。
- `failed`：保留错误，页面弹窗重试。
- 页面 `dispose` 时 `cancel()`：标记 cancelled，生成完成后立即删除临时文件，不再调起分享。

---

## 6. 聚合口径与纯函数

放在 `domain/report_aggregation.dart`，全部纯函数，便于单测。

### 6.1 由记录构建报表

```dart
MonthlyReport buildMonthlyReport({
  required ReportScope scope,
  required List<LedgerRecord> records,
  required List<Vehicle> vehicles,
  required DateTime now,
  int? previousTotalCents,
}) {
  final month = DateTime(scope.month.year, scope.month.month);
  final days = DateTime(month.year, month.month + 1, 0).day;
  final isCurrent = month.year == now.year && month.month == now.month;
  final lastDay = isCurrent ? now.day : days;

  final total = records.fold(0, (sum, r) => sum + r.amountCents);
  final distance = computeDistanceKmByVehicle(records);
  final kwh = records
      .where((r) => r.category == ExpenseCategory.charging)
      .fold(0.0, (sum, r) => sum + (r.metrics.kwh ?? 0));
  final liters = records
      .where((r) => r.category == ExpenseCategory.fuel)
      .fold(0.0, (sum, r) => sum + (r.metrics.liters ?? 0));
  final previousTotal = previousTotalCents; // 由仓库传入（上月同范围）

  return MonthlyReport(
    scope: scope,
    reportNo: reportNoFor(scope),
    status: isCurrent ? ReportStatus.recording : ReportStatus.issued,
    generatedAt: now,
    updatedAt: isCurrent ? now : DateTime(month.year, month.month, days, 23, 59),
    settledAt: isCurrent ? null : DateTime(month.year, month.month, days),
    totalCents: total,
    recordCount: records.length,
    distanceKm: distance,
    days: days,
    costPerKmCents: distance <= 0 ? 0 : (total / distance).round(),
    energyKwh: kwh,
    fuelLiters: liters,
    kwhPer100km: distance <= 0 ? null : kwh / distance * 100,
    litersPer100km: distance <= 0 ? null : liters / distance * 100,
    momPercent: momPercentFor(total, previousTotal),
    momTrend: trendFor(total, previousTotal),
    vehicles: briefsFor(scope, vehicles),
    categories: buildCategoryGroups(records, total),
    daily: buildDailyPoints(records, month, lastDay),
    verified: false,
    verificationText: '数据由车小记本地账本汇总 · 请核对后使用',
    isOffline: false,
  );
}
```

- `momPercent` 由仓库用上月同范围记录计算后 `copyWith`，或聚合函数额外接收 `previousTotalCents`：
  ```dart
  double? momPercentFor(int total, int? previousTotal) =>
      previousTotal == null || previousTotal == 0
          ? null
          : (total - previousTotal) / previousTotal * 100;
  ```
- `days` 使用当月自然日天数，与账单页 Q11 口径一致。
- 当前月 `lastDay = now.day`，但 `days` 仍是整月天数（KPI 第三列显示「公里 · 30天」）。

### 6.2 行驶里程

```dart
int computeDistanceKm(List<LedgerRecord> records) {
  final readings = records
      .map((r) => r.metrics.odometerKm)
      .whereType<int>()
      .where((km) => km > 0)
      .toList()
    ..sort();

  if (readings.length >= 2) {
    final delta = readings.last - readings.first;
    if (delta > 0) return delta;
  }

  // 单车记录可能带 distanceKm（后续模型扩展）；没有则 0。
  final sum = records.fold(0, (total, r) => total + (r.metrics.distanceKm ?? 0));
  return sum > 0 ? sum : 0;
}
```

> 当前 `LedgerMetrics` 没有 `distanceKm` 字段。实现本页时给 `LedgerMetrics` 增加可空 `distanceKm`，并让 Mock 在充电 / 加油记录上生成合理值，作为里程读数不足时的兜底。该字段也可供账单详情页使用。

边界：

- 月内只有 1 条里程读数 → 用单笔距离求和；仍为 0 → `distanceKm = 0`，每公里成本与百公里能耗显示 `—`。
- 全部车辆时里程读数可能来自不同车，直接取极差会串车。**全部车辆改为按车分组后各自求极差再求和**：
  ```dart
  int computeDistanceKmByVehicle(List<LedgerRecord> records) {
    final byVehicle = <String, List<int>>{};
    for (final r in records) {
      final km = r.metrics.odometerKm;
      if (km != null && km > 0) {
        byVehicle.putIfAbsent(r.vehicleId, () => []).add(km);
      }
    }
    return byVehicle.values.fold(0, (sum, list) {
      list.sort();
      return sum + (list.length >= 2 ? (list.last - list.first) : 0);
    });
  }
  ```
  实现时统一使用按车分组版本，单车是其特例。

### 6.3 分类分组与百分比

```dart
const _categoryOrder = [
  ReportCategoryKey.charging,
  ReportCategoryKey.fuel,
  ReportCategoryKey.maintenance,
  ReportCategoryKey.parking,
  ReportCategoryKey.toll,
  ReportCategoryKey.carWashOther,
];

ReportCategoryKey keyFor(ExpenseCategory category) => switch (category) {
  ExpenseCategory.charging => ReportCategoryKey.charging,
  ExpenseCategory.fuel => ReportCategoryKey.fuel,
  ExpenseCategory.maintenance => ReportCategoryKey.maintenance,
  ExpenseCategory.parking => ReportCategoryKey.parking,
  ExpenseCategory.toll => ReportCategoryKey.toll,
  ExpenseCategory.carWash || ExpenseCategory.other => ReportCategoryKey.carWashOther,
};
```

百分比使用**最大余数法**，保证整数之和为 100：

```dart
List<int> largestRemainderPercents(List<int> amounts) {
  final total = amounts.fold(0, (a, b) => a + b);
  if (total <= 0) return List.filled(amounts.length, 0);

  final raw = amounts.map((a) => a / total * 100).toList();
  final floors = raw.map((v) => v.floor()).toList();
  var remainder = 100 - floors.fold(0, (a, b) => a + b);

  final order = List.generate(amounts.length, (i) => i)
    ..sort((a, b) => (raw[b] - floors[b]).compareTo(raw[a] - floors[a]));
  for (var i = 0; i < remainder && i < order.length; i++) {
    floors[order[i]] += 1;
  }
  return floors;
}
```

- 条形段宽度按 `amount / total`，负金额按 0；图例仍显示负数金额与「退款」，百分比为 `—`。
- 金额为 0 的组不渲染图例行；`categories` 模型可保留 0 值，UI 过滤。
- 设计稿「共 6 项收支」按记录笔数展示，文案改为「共 N 笔收支」。

### 6.4 单号

```dart
/// FNV-1a，跨平台、跨版本稳定，便于测试。
int _fnv1a(String input) {
  var hash = 0x811C9DC5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7FFFFFFF;
  }
  return hash;
}

String reportNoFor(ReportScope scope) {
  final seed = '${scope.monthKey}|${scope.vehicleId ?? 'all'}';
  final seq = _fnv1a(seed) % 10000;
  return 'RP-${scope.monthKey.replaceAll('-', '')}-'
      '${seq.toString().padLeft(4, '0')}';
}
```

- 服务端返回 `reportNo` 时直接使用；Mock 用上述稳定值。
- 单号只做展示与归档识别，不承担唯一凭证职责。

### 6.5 车牌脱敏

```dart
String maskPlate(String plate) {
  // `characters` 是 Flutter 的传递依赖；如 lint 报缺失，在 pubspec 中显式声明。
  final chars = plate.characters.toList();
  if (chars.length <= 3) return '***';

  final dot = chars.indexOf('·');
  final keep = dot >= 0
      ? math.min(dot + 2, chars.length)   // 粤B·D82K6 → 保留「粤B·D」
      : 2;                                 // 无分隔点保留前 2 位
  return '${chars.take(keep).join()}${'*' * (chars.length - keep)}';
}
```

- `粤B·D82K6` → `粤B·D****`；`粤B·88K32` → `粤B·8****`。
- 只处理结构化车牌字段；不动备注自由文本。

### 6.6 图表几何

预览（fl_chart）与 PDF（`pdf` 自绘）共用同一套归一化坐标：

```dart
class ReportChartGeometry {
  ReportChartGeometry({
    required this.points,
    required this.maxY,
  });

  final List<ReportDailyPoint> points;
  final int maxY;

  double x(int index) => points.length <= 1 ? 0 : index / (points.length - 1);
  double y(int cents) => maxY <= 0 ? 1 : 1 - (cents / maxY).clamp(0, 1);

  /// Catmull-Rom 转三次贝塞尔的控制点，供 fl_chart 与 pdf 共用。
  List<Offset> splineFor(bool Function(ReportDailyPoint) pick) { ... }
}
```

- `maxY = max(每日金额) * 1.2`，向上取整到 10 元；全 0 时 `maxY = 100`，曲线贴底。
- X 轴刻度选择：`[0, n~/4, peakIndex, n*3~/4, n-1]` 去重后最多 5 个。
- 峰值标注文本 = 峰值日 `dominantCategory` 的报表分组名；无主导分类则不标注。

---

## 7. 数据层

### 7.1 仓库接口

```dart
abstract class ReportRepository {
  Future<MonthlyReport> fetchReport(ReportScope scope);

  /// CSV 导出用：拉取该范围全月记录（自动翻页）。
  Future<List<LedgerRecord>> fetchAllRecords(ReportScope scope);
}
```

`MockReportRepository`：

```dart
class MockReportRepository implements ReportRepository {
  MockReportRepository({
    required LedgerRepository ledger,
    required HomeRepository home,
    this.delay = const Duration(milliseconds: 180),
  });

  final Map<String, ({MonthlyReport report, DateTime cachedAt})> _cache = {};
  static const _ttl = Duration(minutes: 2);

  @override
  Future<MonthlyReport> fetchReport(ReportScope scope) async {
    final key = '${scope.monthKey}|${scope.vehicleId ?? 'all'}';
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.cachedAt) < _ttl) {
      return cached.report;
    }

    await Future<void>.delayed(delay);
    final records = await fetchAllRecords(scope);
    final vehicles = await home.fetchVehicles();
    final previous = await _fetchPreviousTotal(scope);

    final report = buildMonthlyReport(
      scope: scope,
      records: records,
      vehicles: vehicles,
      now: DateTime.now(),
      previousTotalCents: previous,
    );
    _cache[key] = (report: report, cachedAt: DateTime.now());
    return report;
  }

  @override
  Future<List<LedgerRecord>> fetchAllRecords(ReportScope scope) async {
    final query = LedgerQuery(month: scope.month, vehicleId: scope.vehicleId);
    final all = <LedgerRecord>[];
    String? cursor;
    for (var pageIndex = 0; pageIndex < 200; pageIndex++) {
      final page = await ledger.fetchRecords(query, cursor: cursor, limit: 100);
      all.addAll(page.items);
      cursor = page.nextCursor;
      if (!page.hasMore || cursor == null) break;
    }
    return all;
  }
}
```

- 与账单页使用同一个 `MockLedgerRepository` 实例（通过 `ledgerRepositoryProvider`），保证同月同车数据一致。
- 上月总额：查询 `month - 1` 的全部记录求和；为 0 或无数据时 `momPercent = null`。
- 缓存 TTL 2 分钟；本期不做主动失效，页面重新进入时 `autoDispose` 已销毁 Future，仓库缓存仍可命中。记录变更后返回本页应重新拉取（P1 增加 `invalidateReportCache()`）。

### 7.2 接口

| 方法 | 路径 | 用途 | 时机 |
| --- | --- | --- | --- |
| GET | `/api/v1/reports/monthly?month=&vehicleIds=` | 报表聚合 | 进入 / 切月 / 切车 |
| GET | `/api/v1/ledger/records?month=&vehicleIds=&limit=100&cursor=` | CSV 明细 | 导出 CSV / 长图明细（P1） |

- `vehicleIds=all` 表示全部车辆，否则逗号分隔；本期单选，传单个 id 或 `all`。
- `ReportApi` 只定义签名与 DTO mapper；接入后端时新增 `HttpReportApi`，`reportRepositoryProvider` 换实现即可。
- 聚合失败时抛 `ReportLoadException(message)`；UI 展示可重试错误，不影响顶栏与范围条。
- 缓存：`Map<String, MonthlyReport>`，key = `month|vehicleId`，TTL 2 分钟；本期不落盘。
- 报表与流水是两个独立请求；CSV 拉取失败不回滚报表。

### 7.3 竞态

- `FutureProvider.autoDispose.family` 在 scope 变化时会销毁旧 future，旧响应不会渲染；仓库内部仍用 generation 兜底：

```dart
int _generation = 0;

Future<MonthlyReport> fetchReport(ReportScope scope) async {
  final gen = ++_generation;
  final json = await _api.fetchMonthly(...);
  if (gen != _generation) throw const StaleReportResponse();
  return ReportMapper.fromJson(json);
}
```

- UI 对 `StaleReportResponse` 静默忽略，不展示错误。

---

## 8. 状态管理

### 8.1 Provider

```dart
final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return MockReportRepository(
    ledger: ref.watch(ledgerRepositoryProvider),
    home: ref.watch(homeRepositoryProvider),
  );
});

final reportExporterProvider = Provider<ReportExporter>((ref) {
  return DefaultReportExporter(
    files: ReportFileService(),
    ledger: ref.watch(ledgerRepositoryProvider),
  );
});

final monthlyReportProvider = FutureProvider.autoDispose
    .family<MonthlyReport, ReportScope>((ref, scope) {
      return ref.watch(reportRepositoryProvider).fetchReport(scope);
    });
```

### 8.2 页面状态

```dart
class MonthlyReportPage extends ConsumerStatefulWidget {
  const MonthlyReportPage({super.key, required this.initialScope});

  final ReportScope initialScope;

  @override
  ConsumerState<MonthlyReportPage> createState() => _MonthlyReportPageState();
}

class _MonthlyReportPageState extends ConsumerState<MonthlyReportPage> {
  late ReportScope _scope = widget.initialScope;
  ReportOptions _options = const ReportOptions();
  late final ReportExportController _export;

  @override
  void initState() {
    super.initState();
    _export = ReportExportController(
      exporter: ref.read(reportExporterProvider),
      onChanged: () => setState(() {}),
    );
  }

  @override
  void dispose() {
    _export.dispose();
    super.dispose();
  }
  ...
}
```

- 不使用全局 provider 保存范围与选项：本页是二级路由，局部状态不会污染账单页；测试也更直接。
- `_scope` 变化时刷新 `monthlyReportProvider(_scope)`，同时重置缩放与滚动位置。
- `_options` 变化只重建预览，不重新请求报表。
- 进入页面时把账单位置的月份、车辆转成 `ReportScope`：

```dart
ReportScope scopeFromLedger(LedgerQuery query) =>
    ReportScope(month: query.month, vehicleId: query.vehicleId);
```

### 8.3 状态展示

| 状态 | 预览区 | 底栏 |
| --- | --- | --- |
| `loading` | 纸张骨架 | CTA 禁用 + 骨架 |
| `data` | 完整预览 | 可点 |
| `data` 且 `recordCount == 0` | 0 值预览 + 空态提示 | 禁用 + 原因文案 |
| `error` | `SectionError(message, onRetry)` | 禁用 |
| `isOffline` | 顶部离线条 + 预览 | 可点，文件页脚标注 |
| 导出 `preparing / generating` | 不变 | loading + 禁用 |
| 导出 `failed` | 不变 | 恢复 + 弹窗 |

---

## 9. UI 实现

### 9.1 页面骨架

```dart
Scaffold(
  backgroundColor: palette.background,
  body: SafeArea(
    bottom: false,
    child: Stack(
      children: [
        CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: BlurredHeaderDelegate(
                height: tokens.headerHeight,
                child: ReportHeader(
                  onBack: () => Navigator.of(context).pop(),
                  onPrint: _print,
                  onShare: _share,
                  busy: _export.state.isBusy,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverList(delegate: SliverChildListDelegate([
                ReportScopeBar(scope: _scope, onChanged: _onScopeChanged),
                const SizedBox(height: 20),
                ReportPaperPreview(report: report, options: _options, ...),
                const SizedBox(height: 28),
                ReportFormatCards(value: _options.format, onChanged: _onFormatChanged),
                const SizedBox(height: 12),
                ReportOptionToggles(options: _options, onChanged: _onOptionsChanged),
                const SizedBox(height: 24),
              ])),
            ),
          ],
        ),
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: ReportBottomDock(...),
        ),
      ],
    ),
  ),
)
```

- 页面最大宽度 448px 居中：外层 `Center` + `ConstrainedBox`。
- 内容底部留白 `tokens.contentBottomPadding + 16 + bottomInset`，避免被底栏遮挡。
- 本页不使用 `RefreshIndicator`：下拉刷新会与预览缩放、A4 纸张阅读手势冲突；需要刷新时重新进入页面，或 P1 在顶栏加刷新按钮。

### 9.2 顶部栏 `ReportHeader`

- 40×40 白色圆形容器 + `tokens.cardShadow`；返回图标 `arrow_back_rounded` 20px。
- 标题 `headlineSm`；副标题 `bodySm` + `palette.outline`；标题与副标题左对齐，作为整体与返回按钮垂直居中。
- 右侧两个 40×40 圆形按钮（打印 / 分享），`busy` 时替换为 18px `CircularProgressIndicator(strokeWidth: 2)` 并禁用。
- 背景 `palette.background.withValues(alpha: 0.86)` + `BackdropFilter(blur 16)`，由 `BlurredHeaderDelegate` 提供。

### 9.3 范围条

- `ReportMonthPill`：
  - `Container(height: 40, radius: 999, color: palette.surface, boxShadow: tokens.cardShadow, border: white)`；
  - 左：`Icons.calendar_month_rounded` 18px `palette.primary` + 月份文案 `labelLg`；
  - 状态徽标：`_StatusBadge(status)`，`issued` 用 `#DCE9FF` / `#006591`，`recording` 用 `secondary` 20% / `secondaryText`；
  - 右：`InkWell`「切换月份」`labelMd` + `expand_more`；点击 `showLedgerMonthPicker(context, _scope.month)`。
- 车辆 chips：参考 `ledger_vehicle_chips.dart` 的 `_PillChip`，但把选中色改为 `primaryContainer` / `onPrimaryContainer`，并加呼吸圆点：
  ```dart
  class _PulseDot extends StatefulWidget { ... } // AnimationController 2s repeat(reverse)
  ```
  - 减少动态效果：`MediaQuery.disableAnimationsOf(context)` 为 true 时渲染静态 8px 圆点。
  - 选中文案后追加「(当前)」；`全部车辆 (N)` 不带「台」。
- 水平滚动使用 `ListView.separated(scrollDirection: Axis.horizontal)`，避免与外层 `CustomScrollView` 抢手势。

### 9.4 A4 预览

#### 布局预算

预览纸在**固定设计画布 358 × 506**（A4 比例）内布局，再通过 `FittedBox` 缩放到实际宽度：

```dart
LayoutBuilder(builder: (context, constraints) {
  const designWidth = 358.0;
  const designHeight = designWidth * 297 / 210; // 506.2
  final scale = constraints.maxWidth / designWidth;

  return SizedBox(
    width: constraints.maxWidth,
    height: designHeight * scale,
    child: FittedBox(
      fit: BoxFit.fill,
      child: SizedBox(
        width: designWidth,
        height: designHeight,
        child: _PaperContent(report: report, options: options),
      ),
    ),
  );
});
```

设计画布内高度分配（合计 ≤ 506）：

| 区块 | 高度 |
| --- | --- |
| 内边距（上下各 16） | 32 |
| 品牌头 + 分隔线 | 40 + 10 |
| 车辆信息条 | 54 + 10 |
| 三项 KPI | 68 + 10 |
| 走势图卡 | 110 + 10 |
| 分类核算 | 96 + 8 |
| 校验行 + 戳记 | 28 |
| 余量 | ≈ 30 |

- 所有文本 `maxLines: 1` + `TextOverflow.ellipsis`；车辆名、文件名等长文本用 `Flexible`。
- 关闭能耗分析时，KPI 行变为两列，走势图卡整块移除，剩余空间用 `Spacer` 吸收；不得让纸张高度变化（保持 A4 比例）。
- 字体缩放不改变画布逻辑尺寸；系统字号放大通过整体 `FittedBox` 消化（文字设置 `textScaler: TextScaler.noScaling` 仅限纸内，避免布局溢出；页面其余部分正常响应系统字号）。

> 纸内禁用系统字号缩放是为了保证 A4 版式稳定，符合「纸张」隐喻；无障碍摘要通过 `Semantics` 提供完整朗读。

#### 组件拆分

```
ReportPaperPreview
├── ReportPaperHeader        # 品牌、单号、结算 / 截止时间
├── ReportVehicleStrip       # 车辆信息条（单车 / 全部车辆）
├── ReportKpiRow             # 三项 KPI（依 includeEnergy 变两列）
├── ReportTrendChart         # fl_chart 双序列
├── ReportCategoryBar        # 多段条 + 两列图例
├── ReportPaperFooter        # 校验行 + 戳记
└── 装饰：RepaintBoundary    # 供长图截取（P1）
```

- 纸张外框 `ClipRRect(radius: 24)` + `DecoratedBox`（白底、白描边、`sheetShadow`）。
- 预览纸包 `RepaintBoundary(key: _paperKey)`，P1 长图直接截取；PDF 不依赖截屏。
- 缩放：`InteractiveViewer(minScale: 1, maxScale: 2.5, panEnabled: true, scaleEnabled: true)` 包住纸张。为避免与外层纵向滚动冲突：
  - 未缩放时 `panEnabled: false`；
  - 监听 `TransformationController`，当 scale > 1.01 时开启平移；
  - `onInteractionEnd` 若 scale < 1 回弹到 1。
- 双击：`GestureDetector(onDoubleTapDown: ...)` 记录锚点，`onDoubleTap` 在 1× / 2× 间动画切换。
- 切换 `_scope` / `_options` 时重置 `TransformationController.value = Matrix4.identity()`。

### 9.5 走势图 `ReportTrendChart`

- 使用 `fl_chart` 的 `LineChart`，与首页 `trend_card.dart` 保持同一图表库：
  - 两条 `LineChartBarData`：充电（`palette.primary`）、其他（`palette.secondary`）；
  - `isCurved: true`，`curveSmoothness: 0.25`；
  - `belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: top, end: bottom, colors: [color 30%, color 0%]))`；
  - `dotData` 默认隐藏，峰值点手动绘制（`FlDotData(checkToShowDot: ...)`）；
  - `gridData`：仅 2 条水平虚线，颜色 `palette.surfaceContainer`，无垂直网格；
  - `titlesData`：仅底部，5 个刻度，9px 等宽，颜色 `palette.outline`；
  - `borderData`：无边框；
  - `lineTouchData` P1 开启 tooltip，P0 设为 `enabled: false`。
- 高度 110（设计画布内），外层 `RepaintBoundary`。
- 数据为空 / 全 0：不渲染 `LineChart`，渲染贴底 1px 基线 + 居中 `bodySm` 文案「本月暂无开支数据」。

### 9.6 分类核算 `ReportCategoryBar`

```dart
Column(
  children: [
    Row(
      children: [
        Text('分类支出核算明细', style: labelSm.w700),
        Spacer(),
        Text('共 ${report.recordCount} 笔收支', style: labelSm.outline),
      ],
    ),
    SizedBox(height: 6),
    ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            for (final group in visibleGroups)
              Expanded(
                flex: group.amountCents.clamp(0, 1 << 30),
                child: ColoredBox(color: group.color),
              ),
          ],
        ),
      ),
    ),
    SizedBox(height: 6),
    GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 6,
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: [...],
    ),
  ],
)
```

- `Expanded(flex:)` 的 flex 必须是正整数，金额为 0 的组已过滤；大金额直接用分值做 flex，Flutter 内部会归一化。
- 色值映射放在 `report_style.dart`：`ReportCategoryKey → (Color, String label)`，不在 Widget 里写 `switch (category)` 之外的业务。
- 图例行：`Row(dot, label, Spacer, amount + percent)`；金额用 `formatYuanCompact`，百分比 `formatPercentInt`。
- 图例最多 6 项，2 列 × 3 行；若某组为 0 则行数减少，使用 `Wrap` 或过滤后的 `GridView`。

### 9.7 导出格式卡与开关

- `ReportFormatCards`：`Row` + 3 个 `Expanded`，间距 10。
  - 卡片 `InkWell` + `AnimatedContainer`；选中 `border: Border.all(color: palette.primary, width: 2)`，未选中 `Border.all(color: Colors.transparent, width: 2)`，避免选中时尺寸跳动。
  - 勾选徽标 `Positioned(top: -6, right: -6)`，20×20 主色圆 + 白色 `check` 14。
  - 长图卡 `enabled: false`，整体 `Opacity(0.55)`，点击 Toast「长图海报即将支持」。
- `ReportOptionToggles`：三行自定义 `_ToggleRow`：
  - 整行 `InkWell`（热区 ≥ 44）；
  - 右侧 20×20 `AnimatedContainer`，选中主色 + 白色勾，未选中白底 + 1px 描边；
  - 禁用行 `IgnorePointer` + 0.55 透明度 + 说明追加「（暂不支持）」。
- 开关变化调用 `_onOptionsChanged`，只 `setState`，不重新请求。

### 9.8 底部操作栏 `ReportBottomDock`

```dart
Container(
  padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottomInset),
  decoration: BoxDecoration(
    color: palette.surface.withValues(alpha: 0.9),
    boxShadow: tokens.navShadow,
  ),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          _SecondaryButton(onTap: _openFullscreen),
          SizedBox(width: 12),
          Expanded(child: _PrimaryButton(...)),
        ]),
        SizedBox(height: 8),
        Text('支持 AirDrop隔空投送 · 微信文件传输 · 邮件发送与本地留存', ...),
      ],
    ),
  ),
)
```

- 主按钮 `FilledButton` 自定义主题：高 48、全圆角、主色底、`onPrimaryContainer` 文字、`heroShadow`。
- `busy` 时 `onPressed: null` + 转圈；空月时 `onPressed: null` + 40% 透明度 + 上方原因文案。
- 底栏放在 `Stack` 的 `Positioned(bottom: 0)`，不参与滚动。

### 9.9 全屏预览

- `Navigator.push(PageRouteBuilder(opaque: false, ...))`，250ms 淡入。
- 背景 `palette.onSurface.withValues(alpha: 0.94)`，`SafeArea`，顶部一行「2024年6月 · 全部车辆」+ 关闭按钮。
- 纸张使用同一 `_PaperContent`，外层 `InteractiveViewer(minScale: 0.8, maxScale: 3)` + `FittedBox` 按可用宽高等比缩放。
- 全屏页不加载新数据；若原页面报表刷新，全屏页保持打开时的快照（传入不可变 `MonthlyReport`）。

### 9.10 主题与无障碍

- 页面颜色全部走 `context.palette` / `AppColors`；纸内固定浅色 token（`AppPalette.light`），在深色模式下显式传入，不读 `context.palette`。
- 新增 `AppTokens.paperRadius = 24`、`reportShadow`；若不想扩展 token，可在 `report_style.dart` 定义常量。
- 语义：
  - 预览纸整体：`Semantics(container: true, label: '2024年6月，全部车辆，总开销1286元，行驶2140公里，6笔记录，综合每公里0.60元')`；
  - 金额读「元」，百分比读「百分之」；
  - 格式卡 `Semantics(selected: ...)`；
  - 开关 `Semantics(checked: ..., enabled: ...)`；
  - 图表 `Semantics(label: '每日开销走势，峰值6月15日480元')`；
  - 呼吸圆点 `ExcludeSemantics`。
- 系统字号放大：纸内 `TextScaler.noScaling`；页面其余部分正常缩放，允许换行。
- 减少动态效果：关闭脉冲、双击缩放动画改为瞬时。

---

## 10. 导出实现

### 10.1 导出服务接口

```dart
enum ExportAction { export, print, share }

abstract class ReportExporter {
  Future<File> buildPdf(MonthlyReport report, ReportOptions options);
  Future<File> buildCsv(ReportScope scope, ReportOptions options);
  Future<File> buildImage(MonthlyReport report, ReportOptions options); // P1
  Future<void> share(List<File> files, {String? subject, String? text});
  Future<void> print(File pdf);
}
```

`DefaultReportExporter` 组合 `ReportFileService`（临时目录、命名、清理）与 `LedgerRepository`（CSV 明细）。

### 10.2 PDF

```dart
Future<Uint8List> buildReportPdfBytes({
  required MonthlyReport report,
  required ReportOptions options,
  required ReportFonts fonts,
}) async {
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: fonts.regular,
      bold: fonts.bold,
      fontFallback: [fonts.cjkRegular, fonts.cjkBold],
    ),
  );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(14 * PdfPageFormat.mm, 14 * PdfPageFormat.mm,
          14 * PdfPageFormat.mm, 12 * PdfPageFormat.mm),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _pdfBrandHeader(report, fonts),
          _pdfVehicleStrip(report, options),
          if (options.includeEnergy) _pdfKpiRow(report),
          if (options.includeEnergy) _pdfTrendChart(report),
          _pdfCategoryBreakdown(report),
          pw.Spacer(),
          _pdfFooter(report, options),
        ],
      ),
    ),
  );

  return doc.save();
}
```

关键点：

- **单页 A4**：所有区块用固定高度 / `pw.Expanded` 分配，保证不溢出；若内容超出，`pw.Page` 会抛异常，构建前用 `pw.Flexible` 与最小字号兜底。
- **矢量图表**：`pw.CustomPaint` + `ReportChartGeometry` 绘制两条三次贝塞尔曲线、半透明面积、峰值点与虚线网格；坐标按 `pw.Size` 计算，与屏幕比例一致。
- **多段条**：`pw.Row` + `pw.Expanded(flex: amount)` + `pw.Container(color:)`，与 Flutter 端同构。
- **字体**：正文 9–10pt，标题 14–18pt；中文使用 Noto Sans SC，数字优先 Plus Jakarta Sans；`fontFallback` 处理混排。
- **隐私**：`options.maskPlate` 为 true 时，车辆条车牌与页脚说明使用脱敏值。
- **当前月**：页脚「数据截至 2026-11-14 18:30 · 记录中」；历史月「2026-10-31 结算」。
- **离线**：页脚追加「离线数据 · 更新于 x 分钟前」。
- **戳记**：`pw.Container` 虚线边框（`pw.Border.all` 不支持虚线时用 `pw.CustomPaint` 画短线段）+ 文字；文案取需求 §6.3(f) 的最终版。
- **文件体积**：子集字体 + 矢量图，目标 < 2MB（子集生效后争取 < 800KB）；生成后用 `bytes.length` 打点。若 `pdf` 版本未做字形子集，完整 CJK 字重会导致体积明显上升，需在 M3 实测后再决定是否强制子集。

### 10.3 CSV

```dart
String buildReportCsv({
  required List<LedgerRecord> records,
  required ReportOptions options,
}) {
  final buffer = StringBuffer('﻿');
  buffer.write(_header.join(','));
  buffer.write('\r\n');

  for (final record in records) {
    final plate = record.metrics.plate ?? '';
    final row = <String>[
      _date(record.occurredAt),
      _time(record.occurredAt),
      record.category.label,
      record.vehicleName,          // 实现时给 LedgerRecord 补 vehicleName；当前只有 vehicleShortName
      options.maskPlate ? maskPlate(plate) : plate,
      record.title,
      _amount(record.amountCents), // 数值列，不加引号
      _number(record.metrics.kwh),
      _number(record.metrics.liters),
      _int(record.metrics.odometerKm),
      _int(record.metrics.durationMinutes),
      record.metrics.paymentMethod ?? '',
      record.note ?? '',
    ];
    buffer.write(row.map(_escapeText).join(','));
    buffer.write('\r\n');
  }
  return buffer.toString();
}
```

- **只对文本列做转义与公式注入防护**，数值列（金额、电量、升数、里程、时长）直接输出，避免负数被加 `'` 后无法计算。
- `_escapeText`：
  ```dart
  String _escapeText(String value) {
    var text = value;
    if (RegExp(r'^[=+\-@]').hasMatch(text)) {
      text = "'$text";
    }
    if (text.contains(RegExp(r'[",\r\n]'))) {
      text = '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }
  ```
- 日期 / 时间使用本地时区；无时刻的记录时间列留空。
- 记录按 `occurredAt` 正序；导出前按 id 去重。
- 3000 条以上使用 `Isolate.run(() => buildReportCsv(...))`，避免阻塞 UI。
- 文件名：`车小记_账单明细_YYYY-MM_车辆名.csv`。

### 10.4 临时文件与分享

```dart
class ReportFileService {
  Future<Directory> _dir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/reports');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> write(String filename, List<int> bytes) async {
    final dir = await _dir();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> cleanOlderThan(Duration age) async { ... }
}
```

- 文件名过滤：`/ \ : * ? " < > |` → `_`；车辆名去空格。
- 应用启动时（`main()` 或 `AppTabShell.initState`）调用 `cleanOlderThan(const Duration(hours: 24))`。
- 分享：
  ```dart
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf')],
      subject: '车小记 2026年11月用车开销报表',
      text: '由车小记生成的月度报表',
    ),
  );
  ```
  > `share_plus` 的 API 随版本变化；实现时以锁定版本的官方示例为准，保持调用集中在本类。
- 打印：
  ```dart
  await Printing.layoutPdf(
    onLayout: (format) async => buildReportPdfBytes(...),
    name: filename,
  );
  ```
- Android / iOS 均不申请存储权限：分享面板由系统接管，用户选择「存储到文件」时由系统写入。
- 生成失败：删除已写入的临时文件，抛 `ReportExportException`。

### 10.5 长图（P1）

- 使用预览纸的 `RepaintBoundary`，`toImage(pixelRatio: 3)`；屏幕宽度 358 → 约 1074px，满足社交分享。
- 若需要 1080px 以上，使用离屏 `OverlayEntry` 以 360 逻辑宽度渲染后截取；本期先用屏幕内边界。
- 背景补白 + 底部品牌行（「车小记 · 2026年11月」）在截取前临时显示，截取后移除。
- PNG 体积目标 < 2MB；生成后走同一分享面板。

### 10.6 导出流程

```dart
Future<void> export({...}) async {
  if (state.isBusy) return;
  _set(ReportExportState(phase: preparing, format: options.format));

  try {
    final File file = switch (options.format) {
      ReportFormat.pdf => await exporter.buildPdf(report, options),
      ReportFormat.csv => await exporter.buildCsv(scope, options),
      ReportFormat.poster => await exporter.buildImage(report, options),
    };
    if (_cancelled) { await file.delete(); return; }

    _set(state.copyWith(phase: sharing, progress: 0.9));
    switch (action) {
      case ExportAction.export || ExportAction.share:
        await exporter.share([file]);
      case ExportAction.print:
        await exporter.print(file);
    }
    _set(state.copyWith(phase: done, progress: 1));
  } catch (error) {
    _set(state.copyWith(phase: failed, error: error));
  }
}
```

- 进度文案：准备中「正在汇总数据…」、生成中「正在生成 PDF…」、分享中「正在打开分享…」。
- 导出中返回页面：`cancel()` 置位；文件生成完成后删除，不再调起系统面板。
- 失败弹窗由页面监听 `ReportExportController` 的 phase 触发，避免在 controller 里持有 `BuildContext`。

---

## 11. 中文字体与资源

PDF 不依赖设备字体，必须自带中文：

| 文件 | 用途 | 体积目标 |
| --- | --- | --- |
| `NotoSansSC-Regular.ttf` | 正文 / 中文 | ≤ 3MB（子集） |
| `NotoSansSC-Bold.ttf` | 标题 / 金额 | ≤ 3MB（子集） |

- 完整 Noto Sans SC 约 10MB/字重，直接打包会显著增大 APK。建议用 `fonttools` 按 GB2312 + 产品词表做子集：
  ```bash
  pyftsubset NotoSansSC-Regular.ttf \
    --unicodes="U+0020-007E,U+00A5,U+3000-303F,U+4E00-9FFF,U+FF00-FFEF" \
    --output-file=assets/fonts/NotoSansSC-Regular.ttf
  ```
  若 CI 不便引入字体子集步骤，可先使用完整字体并评估 APK 体积增量（Android arm64 release +6–8MB），或改用 `printing` 的 `PdfGoogleFonts.notoSansSCRegular()`（首次联网下载并缓存，离线不可用）。
- 数字 / 拉丁优先 Plus Jakarta Sans（已有 400/500/600/700/800），中文回退 Noto Sans SC；`pw.ThemeData.withFont` 的 `fontFallback` 参数在锁定版本中若不存在，则对所有中文 `pw.Text` 显式指定 `style: pw.TextStyle(font: fonts.cjkRegular)`。
- 字体许可证：Noto Sans SC 为 OFL-1.1，随 `assets/fonts/OFL.txt` 一并入库。
- `pubspec.yaml` 增加：
  ```yaml
  flutter:
    assets:
      - assets/fonts/NotoSansSC-Regular.ttf
      - assets/fonts/NotoSansSC-Bold.ttf
      - assets/fonts/OFL.txt
  ```
  PDF 字体的加载走 `rootBundle.load`，不注册为 Flutter 全局字体（避免与中文系统字体叠加）。

---

## 12. 性能

| 优化点 | 措施 |
| --- | --- |
| 首屏 | 报表仓库缓存命中直接渲染；无缓存显示骨架，不阻塞顶栏与范围条 |
| 聚合 | 纯函数一次遍历完成金额 / 分组 / 日点；上月总额单独请求或缓存 |
| 切换范围 | `FutureProvider.autoDispose.family` 自动取消旧请求；旧响应不渲染 |
| 预览 | 纸张内容 `const` 化；图例 / KPI 拆成独立 StatelessWidget；避免在 build 中排序或格式化大列表 |
| 图表 | 仅 31 个日点，`fl_chart` 成本可忽略；外层 `RepaintBoundary` |
| 缩放 | `InteractiveViewer` 只做矩阵变换，不触发布局；缩放时关闭阴影模糊 |
| PDF | 单页矢量；字体只加载一次并缓存 `pw.Font`；生成放主 isolate（< 800ms），后续多页再评估 isolate |
| CSV | 3000 条以上 `Isolate.run`；分页拉取 limit=100；按 id 去重 |
| 文件 | 临时文件大小上限 10MB；启动清理 24 小时前文件 |
| 内存 | 报表缓存最多 10 份；CSV 全量记录导出后释放 |

指标：进入页面首帧 ≤ 800ms；范围切换 ≤ 500ms；PDF ≤ 800ms（P90）；CSV 3000 条 ≤ 1.5s；预览滚动 60fps。

---

## 13. 错误与边界

| 场景 | 处理 |
| --- | --- |
| 无车辆 | 范围条仅「全部车辆 (0)」；报表空态提示先添加车辆 |
| 当月无记录 | 预览 0 值；CTA 禁用；打印 / 分享提示「本月暂无可导出的记录」 |
| 车辆被删除 | 自动回退全部车辆 + Toast |
| 里程读数不足 | 每公里成本与百公里能耗显示 `—`；PDF 用 `—` 占位，不留空 |
| 全部车辆混合动力 | 能耗辅助行显示充电 kWh + 加油 L；不强行合成百公里单一指标 |
| 退款 / 负金额 | 总额正常抵扣；分类组显示负数 + 「退款」；条形按 0；百分比 `—` |
| 上月无数据 | 环比「较上月 —」，不显示箭头 |
| 报表接口失败 | 预览区错误 + 重试；范围条可用 |
| CSV 拉取失败 | 弹窗重试；不生成文件；报表预览不受影响 |
| PDF 生成失败 | 弹窗「生成失败，请重试」；删除半成品；按钮恢复 |
| 分享取消 | 静默回到页面，不提示失败 |
| 导出中返回 | 取消并清理临时文件；P1 支持后台完成提示 |
| 字体加载失败 | 使用内置 fallback；若中文仍缺字，PDF 显示 `?` 并打点告警（不阻塞） |
| 文件写入失败（磁盘满） | 弹窗「存储空间不足」+ 重试 |
| 隐私开关 | 预览 / PDF / CSV 三处同步；备注自由文本不自动脱敏 |
| 时区变化 / 跨零点 | 重新进入或切换范围时重算「今天」、数据截止时间与状态 |
| 快速连续切月 / 切车 | 丢弃过期响应；骨架不叠加；缩放重置 |
| 单号冲突 | 仅展示用；服务端返回时以服务端为准 |
| 系统字号 1.3× | 纸内不缩放；页面其余部分换行；CTA 文案不截断 |
| 深色模式 | 页面跟随；纸张固定浅色；PDF 固定浅色 |

---

## 14. 测试方案

### 14.1 单元测试

- `buildMonthlyReport`：
  - 空月：总额 0、笔数 0、里程 0、每公里 `—`、分类全 0；
  - 单车：总额 = 记录之和；里程 = 读数极差；能耗与百公里计算正确；
  - 全部车辆：里程按车分组求和，不串车；
  - 退款：总额抵扣、分组负数、百分比为 `—`；
  - 当前月：`status = recording`、`settledAt = null`、日点只到今天；
  - 历史月：`status = issued`、`settledAt = 月末`、日点覆盖整月。
- `computeDistanceKmByVehicle`：0 / 1 / 2 条读数、跨车读数、异常大值。
- `largestRemainderPercents`：和为 100、全 0、单组、负值输入被过滤。
- `reportNoFor`：同 scope 稳定、不同 scope 不同、格式 `RP-YYYYMM-XXXX`。
- `maskPlate`：带分隔点、无分隔点、短车牌、全角字符。
- `buildCategoryGroups`：6 组顺序、洗车 + 其他合并、0 金额过滤。
- `ReportOptions.copyWith` / `ReportScope` 的 `==` / `hashCode`。
- CSV：
  - 表头顺序、BOM、CRLF；
  - 文本转义（逗号、引号、换行）；
  - 公式注入（`=SUM`、`+1`、`-1`、`@x`）只在文本列生效；
  - 金额符号（支出正、退款负）、无千分位；
  - 隐私开关前后车牌列；
  - 3000 条性能（停止 watch，仅断言长度）。
- PDF：
  - `buildReportPdfBytes` 返回非空、以 `%PDF-` 开头；
  - 关闭能耗分析后页数仍为 1；
  - 当前月页脚包含「记录中」；隐私开启时字节流中的车牌为脱敏值（可用 `pdf` 文本提取或构建前参数断言）。
- `ReportExportController`：串行、失败重试、取消后删除文件（注入 FakeExporter 断言调用次数）。

### 14.2 Widget 测试

- 页面骨架：进入时显示骨架，数据到达后显示纸张。
- 范围：默认从账单带入；切换月份 / 车辆后重新请求（FakeRepository 计数）；分类筛选不带入。
- 状态徽标：历史月「已出账」、当前月「记录中」、未来月不可选。
- 预览：品牌头、单号、KPI、图表、分类条、校验行存在；`includeEnergy = false` 时第 2 列与图表消失。
- 隐私：开启后预览车牌文本变化；CSV / PDF 参数收到 `maskPlate = true`（通过 FakeExporter）。
- 格式卡：默认 PDF；点击 CSV 后 CTA 文案变化；长图卡禁用并提示。
- 开关：第三项默认关闭；第二项不可点；点击第一项只重建预览，不触发仓库请求。
- 底栏：空月禁用 + 原因文案；导出中 loading；失败弹窗。
- 缩放 / 全屏：双击后 `TransformationController` scale ≈ 2；全屏路由打开 / 关闭。
- 状态：加载失败重试、离线提示、车辆删除回退。
- 导航：从账单页导出按钮进入；返回后账单页筛选不变。

### 14.3 集成与手工

- Android 真机：分享到微信 / 邮件 / 文件、系统打印、深色模式、1.3× 字号。
- iOS 真机：AirDrop、存储到文件、打印（AirPrint）。
- 文件校验：用 Excel / WPS 打开 CSV；用系统 PDF 阅读器检查中文、选中、缩放。
- 性能：3000 条 CSV 导出、PDF 生成耗时、连续切换 20 次范围无内存增长。

### 14.4 CI

- PR 阶段沿用现有 workflow：`flutter pub get` + `flutter analyze` + `flutter test`。
- 覆盖率目标：`features/report/domain` ≥ 85%，`features/report/export` ≥ 75%；关键交互有 Widget 测试。
- Golden 可选：358×506 纸面浅色一张、页面浅色 / 深色各一张，固定 Mock 数据、关闭动画；不作为必过项。

---

## 15. 实施拆分

| 阶段 | 内容 | 产出 |
| --- | --- | --- |
| M0 数据与入口 | `ReportScope` / `MonthlyReport` / 聚合纯函数 / `MockReportRepository`；账单页导出按钮跳转；单测 | 报表数据与账单页一致，页面可打开 |
| M1 静态页面 | 顶栏、范围条、A4 预览（品牌头 / 车辆条 / KPI / 图表 / 分类条 / 页脚）、格式卡、开关、底栏 | 视觉对齐设计稿，交互由 Mock 驱动 |
| M2 范围与状态 | 月份选择、车辆切换、加载骨架、错误重试、空态、离线条、缩放 / 全屏 | 页面完整可操作 |
| M3 导出 | `pdf` / `share_plus` / `path_provider` / `printing` 接入；PDF + CSV；分享、打印、失败重试、临时文件清理 | 可实际导出报销文件 |
| M4 打磨 | 隐私开关全链路、能耗开关、无障碍、性能、字体子集、长图（P1） | 达到验收清单 |

分支建议：

- `feat/monthly-report-models`（M0）
- `feat/monthly-report-page`（M1–M2）
- `feat/monthly-report-export`（M3）
- `feat/monthly-report-poster`（P1 长图）

每个阶段保持 `flutter analyze` / `flutter test` 通过；依赖新增单独在 M3 的 PR 中说明，并同步更新 `CONTRIBUTING.md` / `docs/CI.md`（若影响构建）。

---

## 16. 风险与待确认

| 风险 | 影响 | 应对 |
| --- | --- | --- |
| PDF 中文字体体积 | APK 增大 6–8MB | 字体子集；或在体积敏感时改为在线字体（牺牲离线） |
| `pdf` / `printing` / `share_plus` 版本差异 | API 不一致、iOS 最低版本 | 锁定版本，集中在 `ReportExporter` 适配；CI 跑 analyze |
| A4 预览在 375pt 溢出 | 纸张内容裁切 | 固定 358×506 画布 + `FittedBox`；纸内禁用系统字号；布局预算表约束 |
| 预览与 PDF 视觉偏差 | 用户不信任 | 共用模型、格式化、几何；字体与色值同一套；导出前人工比对 |
| fl_chart 与 PDF 曲线差异 | 形状不一致 | 共用 `ReportChartGeometry`；PDF 用同一组贝塞尔控制点 |
| 报表与账单数字不一致 | 严重信任问题 | 同一 Mock 仓库 / 同一聚合口径；M0 单测断言总额、笔数、分类金额相等 |
| 当前月数据变化 | 导出文件过期 | PDF 标注数据截止时间与「记录中」 |
| 「云端对账」「财务专用戳记」误导 | 合规风险 | 无真实校验时使用本地汇总文案；戳记改中性文案（需求 Q4） |
| CSV 公式注入 | 安全风险 | 文本列前缀 `'`；数值列不加；单测覆盖 |
| 临时文件残留 | 占用存储 / 隐私 | 启动清理 24 小时前文件；取消时删除 |
| 分享取消被当成失败 | 体验 | `ShareResult` 判断 dismissed，不报错 |
| 车辆里程读数不足 | 每公里成本缺失 | 单笔距离兜底；仍无则显示 `—`，不猜测 |
| 全部车辆混合动力 | 能耗指标混合 | 分别展示充电 kWh 与加油 L，不合成单一百公里指标 |
| 长图截屏清晰度 | 分享质量 | P1 离屏 1080px 渲染；本期不阻塞 |
| 设计稿品牌 / 戳记 / 图例文案不一致 | 返工 | §13 Q1/Q4/Q6 评审确认后再实现 |

待确认（与需求文档 §13 同步）：

1. 品牌文案「里程账本」是否改为「车小记」。
2. 「云端对账校验」「财务专用戳记」的真实性与合规文案。
3. 发票 / 凭证附件能力与开关开放时间。
4. 保养分类色统一为琥珀还是沿用设计稿橙色。
5. 图表标题是否改为「每日开销走势」。
6. 当前月「记录中」是否允许导出（本文档按允许设计）。
7. 报表单号是否由服务端生成并长期稳定。
8. 长图海报的尺寸与模板。
9. 后端是否提供月度报表聚合接口，或先由客户端基于流水聚合。

---

## 17. 附录：需求 → 实现映射

| 需求模块 | Widget / 类 | 数据 / Provider | 测试重点 |
| --- | --- | --- | --- |
| 顶部栏 | `ReportHeader` | `ReportExportController` | 返回、打印 / 分享 loading、sticky |
| 月份与状态 | `ReportMonthPill` + `showLedgerMonthPicker` | `_scope` | 状态徽标、未来月禁用、结算 / 截止时间 |
| 车辆筛选 | `ReportVehicleChips` | `vehiclesProvider` + `_scope` | 单选、动力圆点、`(当前)`、全部车辆 |
| A4 预览 | `ReportPaperPreview` | `MonthlyReport` | 比例、圆角、缩放、布局预算 |
| 品牌头 / 单号 | `ReportPaperHeader` | `report.reportNo` | 单号格式、状态日期 |
| 车辆信息条 | `ReportVehicleStrip` | `report.vehicles` + `maskPlate` | 单车 / 全部、里程合计、脱敏 |
| 三项 KPI | `ReportKpiRow` | `report.*` + `includeEnergy` | 数值、颜色、环比、能耗单位 |
| 走势图 | `ReportTrendChart` + `ReportChartGeometry` | `report.daily` | 双序列、峰值、刻度、空数据 |
| 分类核算 | `ReportCategoryBar` | `report.categories` | 6 组、百分比 100%、退款 |
| 页脚 | `ReportPaperFooter` | `report.verified` | 校验文案、戳记、当前月截止时间 |
| 格式选择 | `ReportFormatCards` | `ReportOptions.format` | 默认 PDF、CTA 联动、长图禁用 |
| 配置开关 | `ReportOptionToggles` | `ReportOptions` | 显隐、禁用、隐私全链路 |
| 底部操作栏 | `ReportBottomDock` | `ReportExportController` | 状态、空月禁用、分享 / 打印 |
| PDF 导出 | `ReportPdfBuilder` + `ReportExporter` | `MonthlyReport` | 单页、中文、矢量、体积 |
| CSV 导出 | `ReportCsvBuilder` | `LedgerRepository` | 编码、列序、转义、注入 |
| 长图（P1） | `ReportImageBuilder` | `RepaintBoundary` | 尺寸、清晰度、分享 |
| 加载 / 错误 / 空态 | `SkeletonBox` / `SectionError` / `EmptyState` | `AsyncValue` | 骨架、重试、空月 |
| 全屏缩放 | `ReportFullscreenPreview` | 页面快照 | 手势、关闭、状态保持 |

---

## 18. 与现有页面的一致性

| 项 | 账单页 | 本页 | 说明 |
| --- | --- | --- | --- |
| 月份选择 | `showLedgerMonthPicker` | 复用同一函数 | 最近 36 个月、未来禁用 |
| 车辆来源 | `vehiclesProvider` | 同源 | 顺序、名称、动力色一致 |
| 总额口径 | 月度汇总 | 报表总额 | 同月同车必须相等 |
| 分类语义色 | `ExpenseCategoryVisual` | 复用 + 6 组归并 | 保养色需与账单页一致 |
| 单价 / 每公里 | 列表用单价胶囊 | 报表用综合每公里 | 口径不同但不冲突：列表看单笔，报表看月度 |
| 导出入口 | 顶部导出按钮 | 由 Toast 改为进入本页 | 账单页不再保留 CSV 快导（或 P1 增加快捷入口） |
| 分类筛选 | 影响列表 | 不带入报表 | 报表始终全分类 |
| 占比 / 百分比 | 无 | 最大余数法 | 保证图例合计 100% |
| 金额符号 | 支出 `-`、退款 `+` | 净额、退款负 | 报表为汇总净额，不显示单笔符号 |

> 实施本页时，账单页顶部导出按钮的行为从「Toast 导出功能开发中」改为 `Navigator.push`。账单需求文档 §6.1 与 §6.6 的导出描述由本页承接；后续更新账单文档时补充交叉引用即可。
