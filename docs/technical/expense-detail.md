# 账单·单笔开销详情页技术方案

| 项目 | 内容 |
| --- | --- |
| 关联需求 | [账单·单笔开销详情页需求文档 v0.3](../requirements/expense-detail.md) |
| 实现基准 | [`../code.html`](../../../code.html)（当前 UI 的 HTML 源码） |
| 设计稿（对应页面） | [Stitch · 账单·通用开销详情页（精炼纯粹版）](https://stitch.google.com/projects/9615374848161425677?node-id=c9b3d2a152944e7f9f3b5c6cce59ba05) |
| 客户端 | Flutter 3.50.0 stable / Dart 3.14 |
| 平台 | Android（arm64 优先）、iOS |
| 文档版本 | v0.3（草案） |
| 状态 | 按 `../code.html` 对齐；未实施；接口未确认，客户端先用 Mock |

> 本文档基于**仓库当前已有实现**（首页、账单页、月度报表、`AppTabShell` 已落地，依赖为 `material_ui`、`flutter_riverpod 3.5`、`fl_chart`、`intl`、`pdf`、`printing`、`share_plus`、`path_provider`）编写。所有新增目录与文件均为拟实施内容，按 `feat/expense-detail-*` 分支推进。
> 需求口径以[需求文档 v0.3](../requirements/expense-detail.md) 的「口径建议（Q1–Q16）」为准；接口契约见需求文档 §8，本文档 §6.4 只描述客户端映射与容错。
> **`../code.html` 是唯一实现基准**：只做 4 张内容卡 + 底栏。该文件 `EXPENSE_DATA` 里的指标 / 对比 / 商户 / 导航 / 票据 / 秒级时间 / 支付尾号 / 双里程 / 组合分类名都是原型残留，当前 DOM 没有对应节点，**不实现**。
> 项目里的 `9839…` 富稿 / `220eed…` 旧稿只作历史对照，不作为验收基线。

---

## 1. 目标与约束

### 1.1 技术目标

- 从账单卡片点击到页面首帧 ≤ 200ms（使用列表已有 `LedgerRecord` 先渲染）；详情补齐 ≤ 800ms；切换 / 返回无白屏。
- **单一数据源**：金额、分类、时间、车辆、里程全部来自 `LedgerRecord` 与现有格式化函数；本页不复制一套金额规则。
- 页面按分类通用，不写 `switch (category)` 分支的页面结构；分类差异集中在图标、分类副标题、语义色映射。
- 备注 / 标签保存为**乐观更新 + 失败回滚**，不整页刷新、不闪骨架。
- 删除为**确认后串行执行**，成功后返回并让账单、首页、报表失效，避免跨页数字不一致。
- 不新增依赖、不新增图片资源；分享复用已引入的 `share_plus`，复制使用 `Clipboard`。
- 深色模式直接复用 `AppPalette.dark` / `AppTokens.dark`，不写死浅色值。

### 1.2 约束

- 不引入 `go_router`：继续用 `Navigator.push(MaterialPageRoute)`，返回即 `pop`。
- 金额全链路整数分（`int cents`），展示统一走 `formatters.dart`。
- 本页只读一条记录 + 局部更新备注 / 标签 + 删除；整笔编辑、再记一笔跳记账页。
- **不实现** `EXPENSE_DATA` 中的指标、对比、商户、导航、票据、支付尾号、秒级时间、双里程、组合分类名与分类切换胶囊。
- 不落盘缓存详情；`autoDispose` 随页面释放，重新进入重新拉取。
- 详情接口未确认前由 `MockExpenseDetailRepository` 提供数据，UI 与 provider 不感知实现。
- 首页「最近记录」入口 P1：`RecordItem` 当前无稳定 id，本期不改首页模型。
- 分享 / 复制默认隐藏车牌；页面展示完整车牌，与账单页一致。
- 文案、图标全部中文 / Material Icons，不引入本地图片。

---

## 2. 现状与复用清单

| 现有能力 | 位置 | 本页用法 |
| --- | --- | --- |
| 色彩 token | `lib/app/theme/app_colors.dart` → `AppPalette` / `AppColors` | 页面、卡片、状态、支付圆点、Hero 光斑 |
| 间距 / 圆角 / 阴影 | `lib/app/theme/app_tokens.dart` → `AppTokens` | 页面边距、卡片阴影、底栏；24 圆角在页面内定义 |
| 字体 | `lib/app/theme/app_typography.dart` | `displayHero`、`headlineLg`、`headlineSm`、`bodyMd`、`bodySm`、`labelMd`、`labelSm` |
| 金额 / 里程 / 时间格式化 | `lib/core/format/formatters.dart` | `formatYuanDetail`、`formatExpense`、`formatKm`、`formatDuration`；新增 `formatDateTimeMinute` |
| 分类语义色与图标 | `lib/core/presentation/category_style.dart` → `ExpenseCategoryVisual` | Hero 图标渐变、徽标、分类色；新增徽标文案与文字色 |
| 动力图标 | 同上 → `PowertrainVisual` | 车辆卡图标 |
| 基础枚举 | `lib/core/domain/enums.dart` | `ExpenseCategory`、`PowertrainType` |
| 记录模型 | `lib/features/ledger/domain/ledger_models.dart` | `LedgerRecord`、`LedgerMetrics` 作为详情的主体 |
| 记录展示推导 | `lib/features/ledger/domain/ledger_presenter.dart` | 列表副标题复用 `note`（`ledger_presenter.dart:85`），备注变更需失效列表 |
| 记录卡点击 | `lib/features/ledger/presentation/ledger_page.dart:322` | 将 `_toast('账单详情待接入')` 替换为推入本页并处理结果 |
| Mock 数据 | `lib/features/ledger/data/mock_ledger_repository.dart` | 详情 Mock 复用同一批记录，保证列表与详情一致 |
| 毛玻璃吸顶栏 | `lib/core/widgets/blurred_header_delegate.dart` | 顶部栏滚动吸顶 |
| 卡片容器 | `lib/core/widgets/app_card.dart` | 车辆 / 结算 / 标签卡片；Hero 需自定义渐变光斑，不复用 |
| 空态 / 错误 / 骨架 | `lib/core/widgets/empty_state.dart`、`section_error.dart`、`skeleton_box.dart` | 不存在、加载失败、加载中 |
| 底栏最大宽度 | `lib/app/tab_shell.dart`（448 居中） | 本页底栏同样最大 448 |
| 分享 API | `lib/features/report/export/report_exporter.dart:116` | `SharePlus.instance.share(ShareParams(...))` |
| Provider 写法 | `lib/features/ledger/domain/providers.dart` | 仓库 Provider + `FutureProvider.autoDispose.family` + `AsyncNotifier` |
| 报表文案 / 隐私口径 | `lib/features/report/domain/report_presenter.dart` | 车牌隐藏、时间格式沿用 |

### 2.1 现有实现与本页的差异

| 项 | 现状 | 本页处理 |
| --- | --- | --- |
| 记录点击 | Toast 占位 | 推入详情页，返回可刷新 |
| `LedgerMetrics.paymentMethod` | 模型已有，Mock 未赋值，CSV 使用 | Mock 补齐；详情只展示渠道名，不展示尾号 |
| 记录备注 | `LedgerRecord.note` 可空，多数 Mock 未赋值 | 详情用 `ExpenseDetail.note`，Mock 按分类生成演示备注 |
| 标签 | 无模型 | 新增 `tags`，仅详情层 |
| 状态 | 无枚举，列表用 `statusText` 自由文案 | 新增 `ExpenseStatus`，列表 `statusText` 不变 |
| 分类副标题文案 | 无 | 新增分类映射（纯文字，不依赖后端） |
| 车辆绑定状态 | 无 | `ExpenseDetail.vehicleBound`，Mock 恒为 `true` |
| 深色模式 | 已有 token，无本页设计 | 按暗色 token 推导 |

---

## 3. 结构调整（M0）

### 3.1 新增目录

```
lib/features/expense_detail/
├── data/
│   ├── expense_detail_repository.dart      # 接口 + 异常类型
│   └── mock_expense_detail_repository.dart # 由 MockLedgerRepository 派生
├── domain/
│   ├── expense_detail_models.dart          # ExpenseDetail / ExpenseStatus / PaymentChannel
│   ├── expense_detail_presenter.dart       # 金额、状态、徽标、支付、分享文本推导
│   └── providers.dart                      # 仓库 + 详情 AsyncNotifier
└── presentation/
    ├── expense_detail_page.dart            # 页面骨架 + 状态分发
    ├── expense_detail_style.dart           # 本页 24 圆角、间距、光斑等局部常量
    └── widgets/
        ├── detail_header.dart
        ├── detail_hero_card.dart
        ├── detail_vehicle_card.dart
        ├── detail_settlement_card.dart
        ├── detail_tags_note_card.dart
        ├── detail_bottom_bar.dart
        ├── detail_more_sheet.dart
        ├── note_editor_sheet.dart
        ├── tag_editor_sheet.dart
        └── delete_expense_sheet.dart
```

设计稿的卡片圆角 24 与现有 `AppTokens.radiusCard = 16`、`radiusSummary = 32` 都不同。为避免影响首页 / 账单 / 报表，本页在 `expense_detail_style.dart` 定义局部常量：

```dart
abstract final class ExpenseDetailStyle {
  static const pagePadding = 16.0;
  static const cardGap = 12.0;
  static const cardRadius = 24.0;
  static const cardPadding = 20.0;
  static const heroPadding = 24.0;
  static const heroIconSize = 56.0;
  static const iconRadius = 16.0;
  static const rowRadius = 16.0;
  static const actionHeight = 50.0;
  static const contentBottomPadding = 144.0;
}
```

若评审确认 24 圆角将用于更多页面，再提升为 `AppTokens.radiusPanel`；本期不扩大公共 token 面。

### 3.2 修改现有文件

| 文件 | 改动 | 影响 |
| --- | --- | --- |
| `lib/features/ledger/presentation/ledger_page.dart` | 新增 `_openExpenseDetail(LedgerRecord)`；记录卡 `onTap` 改为调用；`await` 返回结果并刷新 | 替换 Toast；不改变列表数据流 |
| `lib/features/ledger/data/mock_ledger_repository.dart` | 新增 `LedgerRecord? recordById(String id)`；生成记录时补 `metrics.paymentMethod` | 详情 Mock 取数；CSV 支付列由空变有值 |
| `lib/core/format/formatters.dart` | 新增 `formatDateTimeMinute(DateTime)`、`formatSignedYuan(int cents)` | 本页与后续页面复用 |
| `lib/core/presentation/category_style.dart` | `ExpenseCategoryVisual` 增加 `captionLabel`（纯文字分类副标题） | 首页 / 账单可选用，不改变现有行为 |
| `lib/app/theme/app_colors.dart` | 无需改动 | 复用现有色值 |
| 首页 `recent_records.dart` | 本期不改 | P1 补 id 后接入 |

> 不修改 `LedgerRepository` 接口：详情走独立 `ExpenseDetailRepository`，生产环境由 `HttpExpenseDetailRepository` 替换，列表接口保持不变。

---

## 4. 数据流

```
账单页 LedgerRecordCard.onTap(record)
        │
        ▼
Navigator.push<ExpenseDetailOutcome>(
  ExpenseDetailPage(recordId: record.id, initialRecord: record)
)
        │
        ├── 首帧：ExpenseDetail.fromRecord(record) → 摘要 / 车辆 / 结算立即可见
        │
        ▼
ref.watch(expenseDetailProvider(recordId))
        │
        ▼
ExpenseDetailRepository.fetchDetail(id)
        │            ├── MockExpenseDetailRepository → MockLedgerRepository.recordById
        │            └── HttpExpenseDetailRepository → GET /expenses/{id}
        ▼
AsyncValue<ExpenseDetail>
   ├── data   → 全量内容 + 标签 / 备注
   ├── loading→ 标签 / 备注区域骨架，其余用快照
   └── error  → SectionError（可重试）/ 404 空态
        │
        ├── 保存备注 → controller.saveNote → PATCH → 局部 setState + 失效账单列表
        ├── 保存标签 → controller.saveTags → PUT   → 局部 setState
        └── 删除     → controller.delete    → DELETE → pop(outcome.deleted)
                                                   + 失效账单 / 首页 / 报表
```

### 4.1 进入页面的两种形态

| 形态 | 入参 | 行为 |
| --- | --- | --- |
| 账单页进入（本期唯一） | `recordId` + `initialRecord` | 先用快照渲染，再拉详情补齐 |
| 无快照（P1 深链接 / 通知） | 仅 `recordId` | 全页骨架 → 内容 |

### 4.2 返回结果

```dart
enum ExpenseDetailOutcome { updated, deleted }
```

- 备注 / 标签变更返回 `updated`；账单页只需刷新列表（备注可能影响副标题）与汇总（金额不变，可不刷）。
- 删除返回 `deleted`；账单页刷新汇总 + 列表，并保持当前筛选与滚动位置。
- 用户直接返回返回 `null`，账单页不刷新。

---

## 5. 数据模型

### 5.1 领域模型

```dart
enum ExpenseStatus { completed, refunded }

enum PaymentChannel { wechat, alipay, unionpay, etc, cash, card, other }

@immutable
class ExpensePayment {
  const ExpensePayment({required this.channel, required this.label});

  final PaymentChannel channel;
  final String label;      // 后端展示名，如「微信支付」；不展示尾号 / 卡号
}

@immutable
class ExpenseDetail {
  const ExpenseDetail({
    required this.record,
    required this.status,
    this.payment,
    this.tags = const <String>[],
    this.note,
    this.vehicleBound = true,
    this.updatedAt,
  });

  /// 列表同源记录：金额、分类、时间、车辆快照、里程。
  final LedgerRecord record;
  final ExpenseStatus status;
  final ExpensePayment? payment;
  final List<String> tags;
  final String? note;
  final bool vehicleBound;
  final DateTime? updatedAt;

  ExpenseDetail copyWith({
    ExpenseStatus? status,
    ExpensePayment? payment,
    List<String>? tags,
    String? note,
    bool clearNote = false,
    bool? vehicleBound,
    DateTime? updatedAt,
  }) { /* ... */ }

  /// 无详情时的轻量快照，供首帧与骨架使用。
  factory ExpenseDetail.fromRecord(LedgerRecord record) {
    return ExpenseDetail(
      record: record,
      status: record.amountCents < 0
          ? ExpenseStatus.refunded
          : ExpenseStatus.completed,
      tags: const <String>[],
      note: record.note,
    );
  }
}
```

设计取舍：

- 不把 `tags`、`payment`、`status` 塞进 `LedgerRecord`：列表接口不需要这些字段，避免列表模型与接口膨胀；详情组合 `record` 保持单一金额来源。
- `ExpenseDetail.record` 直接复用 `LedgerRecord`，因此 `record.vehicleName`、`record.metrics.plate`、`record.metrics.odometerKm` 已满足车辆卡；`vehicleBound` 单独放在详情层。
- `note` 在详情层为权威值；`record.note` 只作为快照兜底，避免 Mock 详情反向污染列表对象。
- 不引入 `merchantName`、`telemetry`、`comparison`、`vouchers`、`navigation` 等富字段：当前 UI 没有对应模块。

### 5.2 展示推导（presenter）

```dart
extension ExpenseDetailPresentation on ExpenseDetail {
  String get heroAmountText => formatSignedYuan(record.amountCents);

  String get settledAmountText => record.amountCents < 0
      ? '+${formatYuanDetail(record.amountCents.abs())}'
      : formatYuanDetail(record.amountCents);

  String get settledLabel =>
      status == ExpenseStatus.refunded ? '退款金额' : '实付金额';

  String get statusLabel =>
      status == ExpenseStatus.refunded ? '已退款' : '已完成';

  String get timeText => formatDateTimeMinute(record.occurredAt);

  String get categoryLabel => record.category.label;

  String get categoryCaption => record.category.captionLabel;

  String get odometerText {
    final km = record.metrics.odometerKm;
    return km == null ? '里程未记录' : '记录里程 ${formatKm(km)}';
  }

  String? get paymentLabel => payment?.label;

  String get vehicleName => record.vehicleName ?? record.vehicleShortName;

  String? get plate => record.metrics.plate;

  String get noteText => (note ?? '').trim();

  bool get hasNote => noteText.isNotEmpty;

  String get shareText => buildExpenseShareText(this);
}
```

状态 / 分类副标题 / 支付颜色的视觉映射放在 presenter 或独立 extension，避免 Widget 内散落 `switch`：

| 映射 | 位置 |
| --- | --- |
| 状态图标与颜色 | `ExpenseStatusVisual`（`check_circle` 绿 / `undo` 粉） |
| 分类副标题文案 | `ExpenseCategoryVisual.captionLabel`（`category_style.dart`） |
| 支付圆点色 | `PaymentChannelVisual.color(palette)`（本 feature 内） |

### 5.3 格式化新增

```dart
/// 交易时间：`2025-05-16 13:28`，24 小时制。
String formatDateTimeMinute(DateTime time) {
  final t = time.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} '
      '${two(t.hour)}:${two(t.minute)}';
}

/// 带符号金额：支出 `-¥51.10`，退款 `+¥51.10`，零金额 `¥0.00`。
String formatSignedYuan(int cents) {
  if (cents == 0) return formatYuanDetail(0);
  return cents < 0
      ? '+${formatYuanDetail(cents.abs())}'
      : '-${formatYuanDetail(cents)}';
}
```

> `formatExpense` 已存在但语义是「支出带负号」，退款场景会得到 `-¥51.10` 的反直觉结果；本页新增 `formatSignedYuan`，不改旧函数以免影响报表。

### 5.4 标签与备注规则

```dart
abstract final class ExpenseDetailRules {
  static const maxTags = 8;
  static const maxTagLength = 10;
  static const maxNoteLength = 200;
}

/// trim、去 `#`、去空、去重、限长、限数量。
List<String> sanitizeTags(Iterable<String> input) { ... }

/// trim；空串转 null。
String? normalizeNote(String raw) { ... }
```

- 存储不带 `#`；渲染 `#${tag}`。
- 超长标签在输入阶段限制，不静默截断。
- 备注保留内部换行，首尾空白删除；200 字按字符数（`characters` 包由 Flutter 提供，`String.characters.length`）计数。

---

## 6. 数据层

### 6.1 仓库接口

```dart
abstract class ExpenseDetailRepository {
  Future<ExpenseDetail> fetchDetail(String id);

  Future<ExpenseDetail> updateNote(String id, String? note);

  Future<ExpenseDetail> updateTags(String id, List<String> tags);

  Future<void> deleteExpense(String id);
}

sealed class ExpenseDetailException implements Exception {
  const ExpenseDetailException(this.message, [this.cause]);
  final String message;
  final Object? cause;
}

class ExpenseNotFoundException extends ExpenseDetailException { ... }
class ExpenseDetailNetworkException extends ExpenseDetailException { ... }
class ExpenseDetailConflictException extends ExpenseDetailException { ... }
```

### 6.2 Mock 实现

`MockExpenseDetailRepository(MockLedgerRepository ledger)`：

| 字段 | 生成规则 |
| --- | --- |
| `record` | `ledger.recordById(id)`；未找到抛 `ExpenseNotFoundException` |
| `status` | `amountCents < 0` → `refunded`，否则 `completed` |
| `payment` | 按分类固定映射（见下） |
| `tags` | 按分类固定 2–3 个，确定性，便于截图 / 测试 |
| `note` | 优先 `record.note`；为空时按分类给 1 条演示备注；加油 / 保养等保留原文 |
| `vehicleBound` | `true` |
| `updatedAt` | `occurredAt + 2min` |
| 延迟 | 120ms；构造参数可关闭，供 Widget 测试 |

支付映射：

| 分类 | 渠道 | 展示名 |
| --- | --- | --- |
| charging | wechat | 微信支付 |
| fuel | unionpay | 云闪付加油卡代扣 |
| maintenance | alipay | 支付宝 |
| carWash | wechat | 微信支付（次卡划扣） |
| parking | other | 无感免密支付 |
| toll | etc | 粤通卡 ETC 自动划扣 |
| other | alipay | 支付宝 |

标签映射（示例）：

| 分类 | 标签 |
| --- | --- |
| charging | 日常补能、谷电错峰 |
| fuel | 满箱加注、跨城自驾 |
| maintenance | 官方授权、基础保养 |
| carWash | 精洗内饰、轮胎养护 |
| parking | 商场购物、无感支付 |
| toll | 早高峰、ETC 通行 |
| other | 临时开销 |

更新方法：

- `updateNote`：mock 内部按 id 维护覆盖表 `Map<String, String?>`，返回 `record + note + updatedAt`；不修改 `LedgerRecord`。
- `updateTags`：同样维护覆盖表，先 `sanitizeTags` 再存储；超过上限抛 `ArgumentError`（仅开发期）。
- `deleteExpense`：从覆盖表与 `MockLedgerRepository` 的删除集合中移除；`recordById` 对已删 id 返回 `null`。为演示删除后刷新，Mock 还应在 `fetchRecords` 中过滤掉已删 id（见 §6.3）。

### 6.3 记录查找

`MockLedgerRepository` 目前只在内部按月份生成并缓存记录，没有按 id 查询能力。新增：

```dart
/// 按 id 查找记录：先查索引，再回扫最近 24 个月。
LedgerRecord? recordById(String id) {
  final cached = _idIndex[id];
  if (cached != null) return cached;
  final now = DateTime.now();
  for (var i = 0; i < 24; i++) {
    final month = DateTime(now.year, now.month - i);
    final record = _recordsFor(month).where((r) => r.id == id).firstOrNull;
    if (record != null) {
      _idIndex[id] = record;
      return record;
    }
  }
  return null;
}
```

- `_recordsFor` 已有月度缓存，回扫成本低；首次查询最多生成 24 个月数据，Mock 环境可接受。
- 生产环境由 `GET /expenses/{id}` 直接取，不存在回扫。
- 删除集合 `Set<String> _deletedIds`：`fetchRecords` / `fetchSummary` 过滤；`recordById` 对已删 id 返回 `null`。该集合只在 Mock 生命周期内有效，App 重启恢复，符合「Mock 演示」定位。

### 6.4 接口映射与容错

| JSON 字段 | 模型字段 | 容错 |
| --- | --- | --- |
| `id` | `record.id` | 缺失 → 解析失败，按网络错误处理 |
| `category` | `record.category` | 未知 key → `ExpenseCategory.other`，记录埋点 |
| `title` | `record.title` | 空 → 分类名兜底由 UI 处理 |
| `amountCents` | `record.amountCents` | 必须是整数；负数即退款 |
| `occurredAt` | `record.occurredAt` | ISO 8601，解析失败 → 卡片隐藏时间 |
| `status` | `detail.status` | 缺失 / 未知 → 按金额符号推导 |
| `vehicle.*` | `record.vehicleId` / `vehicleName` / `powertrain` / `metrics.plate` / `metrics.odometerKm` | 车辆可空；`bound` 缺失默认 `true` |
| `payment.channel/label` | `detail.payment` | 未知 channel → `other`，label 兜底「其他」 |
| `tags` | `detail.tags` | 非数组 / 超限 → 客户端 `sanitizeTags` |
| `note` | `detail.note` | 超长 → 客户端截到 200 字并提示 |
| `metrics` | `record.metrics` | 与列表接口同构；缺字段为 null |
| `updatedAt` | `detail.updatedAt` | 仅用于并发提示，P0 不展示 |

HTTP 实现（P1 接入时）：

- `GET /expenses/{id}`：超时 8s，不自动重试；404 → `ExpenseNotFoundException`；其他 → `ExpenseDetailNetworkException`。
- `PATCH /note` / `PUT /tags`：整字段覆盖；409 → `ExpenseDetailConflictException`（页面提示「已有更新，请重新进入」）。
- `DELETE`：204 视为成功；404 也视为成功（幂等）。
- 请求头 `Accept: application/json`、`Content-Type: application/json`；车牌 / 备注不写日志。
- 不支持离线队列：失败即提示，不做后台重试。

### 6.5 Repository Provider

```dart
final expenseDetailRepositoryProvider = Provider<ExpenseDetailRepository>((ref) {
  return MockExpenseDetailRepository(ref.watch(ledgerRepositoryProvider));
});
```

接入接口时只替换此处为 `HttpExpenseDetailRepository(...)`，页面与 controller 不改。

---

## 7. 状态管理

### 7.1 Provider

```dart
final expenseDetailProvider = AsyncNotifierProvider.autoDispose
    .family<ExpenseDetailController, ExpenseDetail, String>(
  ExpenseDetailController.new,
);

class ExpenseDetailController extends AsyncNotifier<ExpenseDetail> {
  ExpenseDetailController(this.recordId);

  final String recordId;
  bool _isMutating = false;

  @override
  Future<ExpenseDetail> build() {
    return ref.watch(expenseDetailRepositoryProvider).fetchDetail(recordId);
  }

  Future<void> saveNote(String? note) async {
    final current = state.valueOrNull;
    if (current == null || _isMutating) return;
    _isMutating = true;
    final normalized = normalizeNote(note ?? '');
    state = AsyncData(current.copyWith(note: normalized));
    try {
      final updated = await ref
          .read(expenseDetailRepositoryProvider)
          .updateNote(recordId, normalized);
      state = AsyncData(updated);
      ref.invalidate(ledgerRecordsProvider); // 备注影响列表副标题
    } catch (_) {
      state = AsyncData(current); // 回滚
      rethrow;
    } finally {
      _isMutating = false;
    }
  }

  Future<void> saveTags(List<String> tags) async { /* 同上，不失效列表 */ }

  Future<void> delete() async {
    if (_isMutating) return;
    _isMutating = true;
    try {
      await ref.read(expenseDetailRepositoryProvider).deleteExpense(recordId);
      _invalidateDependents();
    } finally {
      _isMutating = false;
    }
  }

  void _invalidateDependents() {
    ref.invalidate(ledgerRecordsProvider);
    ref.invalidate(ledgerSummaryProvider);
    ref.invalidate(homeDashboardProvider);
    ref.invalidate(recordsProvider);
    ref.invalidate(monthlyReportProvider);
  }
}
```

说明：

- `AsyncNotifierProvider.autoDispose.family` 为 Riverpod 3.5 现有能力；family 参数通过构造函数注入（与 `riverpod` 3.5 的 family 写法一致）。
- 备注使用乐观更新：先改本地，再请求；失败回滚并让页面 Toast。标签同理。
- 删除不做乐观：成功后再失效 + 返回，避免「已删除但请求失败」。
- `_isMutating` 防止连点；页面按钮同时禁用。

### 7.2 失效矩阵

| 操作 | 详情 | 账单列表 | 账单汇总 | 首页仪表盘 / 最近记录 | 月度报表 |
| --- | --- | --- | --- | --- | --- |
| 保存备注 | 本地更新 | 失效（`ledger_presenter.dart:85` 用 note 作副标题） | 不失效（金额不变） | 不失效 | 不失效 |
| 保存标签 | 本地更新 | 不失效 | 不失效 | 不失效 | 不失效 |
| 删除记录 | 返回上一页 | 失效 | 失效 | 失效 | 失效 |
| 整笔编辑（P2） | 失效 | 失效 | 失效 | 失效 | 失效 |

> 失效 `ledgerSummaryProvider` 时不带 family 参数会失效全部实例，符合「金额变了，所有筛选组合都要重算」的预期；本页只删除，成本可接受。

### 7.3 竞态与生命周期

- 页面销毁后 mutation 回调不再 `setState`；使用 `ref.read` + `mounted` 判断，controller 的 `state` 在 autoDispose 后写入会被忽略。
- 连续保存备注：`_isMutating` 直接忽略第二次点击；输入框在保存中禁用。
- 页面重新进入重新拉取；不依赖 controller 缓存。
- 返回结果由页面在 `Navigator.pop(context, outcome)` 时一次性交付，不通过全局状态。

---

## 8. UI 实现

### 8.1 页面骨架

```dart
class ExpenseDetailPage extends ConsumerWidget {
  const ExpenseDetailPage({
    super.key,
    required this.recordId,
    this.initialRecord,
  });

  final String recordId;
  final LedgerRecord? initialRecord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final asyncDetail = ref.watch(expenseDetailProvider(recordId));
    final snapshot = initialRecord == null
        ? null
        : ExpenseDetail.fromRecord(initialRecord!);
    final detail = asyncDetail.valueOrNull ?? snapshot;

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                const _AmbientBackdrop(),
                CustomScrollView(
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: BlurredHeaderDelegate(
                        height: kToolbarHeight + MediaQuery.paddingOf(context).top,
                        child: DetailHeader(detail: detail),
                      ),
                    ),
                    if (detail == null)
                      SliverFillRemaining(child: _DetailSkeleton(...))
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 144),
                        sliver: SliverList.list(children: [
                          DetailHeroCard(detail: detail),
                          const SizedBox(height: 12),
                          DetailVehicleCard(detail: detail, ...),
                          const SizedBox(height: 12),
                          DetailSettlementCard(detail: detail),
                          const SizedBox(height: 12),
                          DetailTagsNoteCard(
                            detail: detail,
                            isSyncing: asyncDetail.isLoading,
                            onEditNote: ...,
                            onAddTag: ...,
                            onRemoveTag: ...,
                          ),
                        ]),
                      ),
                  ],
                ),
              ],
            ),
          ),
          DetailBottomBar(
            enabled: detail != null,
            onReAdd: ...,
            onEdit: ...,
          ),
        ],
      ),
    );
  }
}
```

- `_AmbientBackdrop`：顶部 384 高、页面色到透明的渐变 + 两个分类色 15% 模糊圆（`IgnorePointer`），对应设计稿的环境光斑。
- 错误态：`SliverFillRemaining` 内放 `EmptyState` / `SectionError`；404 用空态，网络错误用 `SectionError`。
- 页面使用 `Column` + `Expanded` 而不是 `Scaffold.bottomNavigationBar`，便于底栏做毛玻璃与顶部圆角；键盘弹出时底栏用 `MediaQuery.viewInsetsOf` 隐藏（本页无输入，浮层单独处理）。

### 8.2 顶部栏 `DetailHeader`

- 高度 56 + 顶部安全区；内部左右 16、上下 8。
- 左返回 40 圆 + `surface` 白底 + `AppTokens.cardShadow`；图标 `Icons.arrow_back` 20。
- 中间两行：标题 `AppTypography.headlineSm`；副标题 `AppTypography.labelSm.copyWith(color: palette.outline, letterSpacing: 0.2)`。
- 右侧 40 圆按钮两个：分享 `Icons.ios_share`（19）、更多 `Icons.more_horiz`（20）。
- 按钮统一 `IconButton` + `styleFrom`，`minimumSize: Size(40, 40)`，外层 `Semantics(button: true, label: '分享凭证'/'更多操作')`。
- `detail == null` 时分享 / 更多 `onPressed: null`，透明度 0.4。
- 点击更多弹出 `DetailMoreSheet`；点击分享调用 `shareExpense`。

### 8.3 开销摘要卡 `DetailHeroCard`

```dart
Container(
  padding: const EdgeInsets.all(24),
  decoration: BoxDecoration(
    color: palette.surface,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
    boxShadow: tokens.cardShadow,
  ),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: Stack(
      children: [
        Positioned(
          right: -40, top: -40,
          child: _HeroGlow(), // 160x160, 主色 15% 模糊，固定不随分类变化
        ),
        Column(children: [
          _HeroIcon(category: record.category),
          const SizedBox(height: 12),
          Text(title, style: AppTypography.headlineSm, maxLines: 2, ...),
          const SizedBox(height: 4),
          Text(
            detail.categoryCaption,
            style: AppTypography.labelSm.copyWith(color: palette.outline),
          ),
          const SizedBox(height: 16),
          _HeroAmount(detail: detail),
          const SizedBox(height: 8),
          _StatusLine(detail: detail),
        ]),
      ],
    ),
  ),
)
```

- `_HeroIcon`：`Container(56, 56)`，`LinearGradient(colors: [category.color, Color.lerp(category.color, Colors.white, 0.45)!])`，`borderRadius: 16`，图标白 / 深色按对比度；阴影 `category.color.withValues(alpha: 0.3)`。
- `_HeroAmount`：`Row(mainAxisSize: min, crossAxisAlignment: baseline)`，符号 `AppTypography.headlineLg`，数字 `AppTypography.displayHero`；整体包 `FittedBox(fit: BoxFit.scaleDown)` 并限制最大宽度，避免长金额溢出。
- `_StatusLine` 用 `Wrap` 或 `Row` + `Flexible`，11/14，状态文字与时间不被截断；状态图标 15。
- 摘要卡**不渲染**地址副标题、右上「单笔核销」、指标格、对比条或波浪装饰；这些不在 `code.html` 的 DOM 中。
- 标题兜底 `record.title.trim().isEmpty ? record.category.label : record.title`。

### 8.4 车辆卡 `DetailVehicleCard`

- 外层 `AppCard`（圆角 16）不足以表达 24 圆角，使用与 Hero 相同的 `Container` 装饰常量，抽 `_DetailCard` 组件。
- 卡头：`Icon(Icons.directions_car_rounded, size: 18, color: palette.primary)` + 标题 + `Spacer` + 胶囊。
- 胶囊：`已绑定`（`primary` 20% 底 + `primaryText`）/ `已解绑`（`surfaceContainer` 底 + `onSurfaceVariant`）。
- 信息行：`Material` + `InkWell`，`color: palette.surfaceContainer.withValues(alpha: 0.6)`，`borderRadius: 16`，`padding: 14`。
- 车辆名 + 车牌用 `Wrap`，窄屏时车牌换行而不是截断；车牌胶囊 `surfaceContainerHigh`。
- 里程行：`Text(detail.odometerText, bodySm, color: palette.outline)`。
- 箭头仅 `vehicleBound == true` 时显示；点击进入车辆管理占位（`_toast('车辆管理待接入')`），P1 换成路由。

### 8.5 结算卡 `DetailSettlementCard`

- 复用 `_DetailCard`；卡头 `receipt_long_rounded` 20（`palette.tertiary`）+ `结算明细` + 右侧 `电子记账`。
- 字段行组件 `_SettlementRow(label, child)`：`Row` + `padding vertical 10` + 底部 `Divider(height: 1, color: outlineVariant.withValues(alpha: 0.6))`。
- 支付行：`Row(children: [if (payment != null) _Dot(color), Text(label)])`；`未记录` 时无圆点。
- 金额行：顶部 `SizedBox(height: 12)`，标题 `headlineSm`，金额 `headlineLg.copyWith(color: palette.primaryText)`；退款时标题 `退款金额`，金额 `+`。
- 所有字段值 `textAlign: TextAlign.right`，最多 1 行省略（支付渠道最多 2 行）。
- 不渲染商户网点、权益文案、支付尾号或秒级时间。

### 8.6 标签与备注卡 `DetailTagsNoteCard`

- 卡头：`label_rounded` 18（`palette.secondary`）+ 标题 + 右侧 `TextButton.icon`（`edit_rounded` 14，「编辑备注」）。
- 标签区：`Wrap(spacing: 8, runSpacing: 8)`；标签胶囊 `GestureDetector` 打开移除确认；末尾 `添加标签` 虚线胶囊（`CustomPaint` 或 `DottedBorder` 不引入依赖：用 `DecoratedBox` + `Border.all(style: BorderStyle.none)` 无法画虚线，改用 `CustomPainter` 绘制虚线边框，或使用 0.5px 实线 + `outlineVariant` 降低视觉权重；本页建议实现一个 20 行 `DashedBorderPainter`）。
- 备注块：`Container` + `surfaceContainer` 50% + 圆角 16 + padding 14；`Row(crossAxisAlignment: start)`：`format_quote_rounded` 18 + `Expanded(Text)`。
- 折叠：`LayoutBuilder` + `TextPainter` 计算 4 行高度；超出时 `maxLines: 4` + 底部 `展开` 文本按钮；展开状态用 `StatefulWidget` 局部维护。
- 空备注：显示占位文案 + 点击打开编辑浮层；不显示引号图标（或保留低透明度）。
- 标签 / 备注在 `isSyncing` 时降低不透明度 0.6，并禁止点击。

### 8.7 底部操作栏 `DetailBottomBar`

- `Container`：`padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset)`，`decoration` 顶部圆角 24、`palette.surface.withValues(alpha: 0.9)`、顶部白色 60% 1px、`tokens.navShadow`。
- 内部 `Row(children: [Expanded(flex: 1, _SecondaryButton), SizedBox(8), Expanded(flex: 2, _PrimaryButton)])`。
- 高度 50；`_SecondaryButton`：`palette.surfaceContainer` 底 + `add_circle_outline_rounded`；`_PrimaryButton`：`LinearGradient([palette.primary, Color(0xFF00C48C)])`，白色文字，`edit_note_rounded`，阴影 40%。
- 按压：`GestureDetector` + `AnimatedScale`（0.98，100ms）；或 `InkWell` + `Material`，按设计稿使用缩放。
- 命中区覆盖整个按钮；`Semantics(button: true)`。
- 禁用：`enabled == false` 时 `onTap: null`，整体透明度 0.5。

### 8.8 浮层

**备注编辑 `NoteEditorSheet`**

```dart
showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: palette.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: NoteEditorSheet(initialNote: detail.note, onSave: ...),
  ),
);
```

- 标题「编辑备注」；`TextField(maxLines: 5, minLines: 4, maxLength: 200)`，`counterText` 默认；
- 取消 / 保存；保存中禁用；失败时保留浮层并显示错误文案（`SectionError` 或红字）。
- 清空后保存 → `note = null`，卡片回到空备注占位。

**标签编辑 `TagEditorSheet`**

- 标题「添加标签」；输入框前置固定 `#`，`maxLength: 10`；重复 / 空值禁用保存。
- 已有标签列表带 `移除` 图标；保存调用 `controller.saveTags`。
- 标签达到 8 个时输入框禁用，顶部提示「最多添加 8 个标签」。

**更多菜单 `DetailMoreSheet`**

- 三个 `ListTile`：复制账单信息、分享为图片（禁用 + 「暂不支持」）、删除此笔账单（`palette.error`）。
- 复制：`Clipboard.setData(ClipboardData(text: buildExpenseShareText(detail, includePlate: false)))`，Toast「已复制」。
- 删除：先关闭菜单，再打开 `DeleteExpenseSheet`。

**删除确认 `DeleteExpenseSheet`**

- 标题「删除这笔开销？」；正文两行说明；`TextButton` 取消 + `FilledButton` 删除（`palette.error`）。
- 确认后调用 `controller.delete()`，按钮转圈；成功 `Navigator.pop(context, ExpenseDetailOutcome.deleted)`；失败关闭 loading、Toast。
- 系统返回 / 点击遮罩在提交中不关闭（`isDismissible: false` 动态切换）。

### 8.9 深色模式

- 所有颜色来自 `context.palette` 与 `context.tokens`；Hero 图标渐变用分类色 + 向白色混合，在暗色下改为向背景色混合，避免过亮。
- 卡片背景 `palette.surface`，内描边用 `palette.cardBorder`（暗色为 8% 白）。
- 分类副标题固定用 `palette.outline` 文字，无底色 / 边框。
- 支付圆点在暗色下使用高亮变体（`tertiary` / `secondaryText`）。
- 光斑透明度暗色降到 10%，避免灰雾。

### 8.10 无障碍

- 摘要卡 `Semantics(container: true, label: '${category}，$title，${amount}，$status，$time')`。
- 车辆行 `Semantics(button: vehicleBound, label: '车辆 $name，车牌 $plate，$odometer')`。
- 标签胶囊 `Semantics(label: '标签 ${tag}', button: true)`。
- 返回 / 分享 / 更多 / 底部按钮提供 `tooltip` 与 `semanticLabel`。
- 焦点顺序：顶部栏 → 摘要 → 车辆 → 结算 → 标签 → 备注 → 底栏。
- 系统「减少动态效果」时移除 `AnimatedScale` 与淡入。

---

## 9. 交互与跳转

### 9.1 从账单页进入

```dart
Future<void> _openExpenseDetail(LedgerRecord record) async {
  final outcome = await Navigator.of(context).push<ExpenseDetailOutcome>(
    MaterialPageRoute(
      builder: (_) => ExpenseDetailPage(
        recordId: record.id,
        initialRecord: record,
      ),
    ),
  );
  if (!mounted || outcome == null) return;
  switch (outcome) {
    case ExpenseDetailOutcome.deleted:
      _refresh();
    case ExpenseDetailOutcome.updated:
      ref.read(ledgerRecordsProvider.notifier).refresh();
  }
}
```

- `_refresh` 复用现有下拉刷新逻辑（失效汇总 + 刷新列表），保持筛选与滚动位置。
- 备注变更后列表刷新会重建行；使用 `id` 去重 / 游标稳定，不跳位。

### 9.2 分享

```dart
String buildExpenseShareText(ExpenseDetail detail, {bool includePlate = false}) {
  final buffer = StringBuffer()
    ..writeln('车小记 · 开销详情')
    ..writeln('${detail.categoryLabel} · ${detail.record.title}')
    ..writeln(detail.heroAmountText)
    ..writeln('${detail.timeText} · ${detail.statusLabel}')
    ..write('车辆：${detail.vehicleName}');
  if (includePlate && detail.plate != null) buffer.write('（${detail.plate}）');
  if (detail.hasNote) {
    final note = detail.noteText;
    buffer
      ..writeln()
      ..write('备注：${note.length > 80 ? '${note.substring(0, 80)}……' : note}');
  }
  return buffer.toString();
}
```

```dart
await SharePlus.instance.share(ShareParams(text: buildExpenseShareText(detail)));
```

- 分享失败（平台异常）Toast；取消不提示。
- 复制使用同一文本，`includePlate: false`。

### 9.3 删除

```
点击更多 → 删除此笔账单 → 删除确认浮层 → 确认
  → controller.delete()
      ├── 成功：invalidate 依赖 → pop(outcome.deleted) → 账单 Toast「已删除」
      └── 失败：留在本页 → Toast「删除失败，请重试」
```

- 404 视为成功。
- 删除期间禁用底部两个按钮与顶部更多，防止重复提交。
- 返回时若详情页由深链接打开（P1），无上一页可回，则 `Navigator.popUntil(first)`。

### 9.4 编辑 / 再记一笔

- 两者在当前仓库尚无记账页，统一点击 Toast：
  - `编辑此笔账单` → `记账页待接入`
  - `再记一笔` → `记账页待接入`
- 预填契约先固定为：
  - 再记：`vehicleId = record.vehicleId`、`category = record.category`、`occurredAt = now`
  - 编辑：整条 `record.id`
- 记账页落地后，将两个回调替换为 `Navigator.push`，页面其余部分不改。

### 9.5 系统返回

- 备注 / 标签 / 更多 / 删除浮层打开时，系统返回先关闭浮层。
- 删除提交中拦截返回，避免半完成状态。
- 无浮层时直接返回账单，不弹确认。

---

## 10. 性能

| 项 | 措施 |
| --- | --- |
| 首帧 | 用 `initialRecord` 构造 `ExpenseDetail.fromRecord`，不等待网络 |
| 详情请求 | 120ms Mock / 生产 ≤ 800ms；`autoDispose.family` 避免重复请求 |
| 重建范围 | 页面拆成独立 Widget；备注 / 标签更新只重建对应卡片（`select` 或局部 `setState`） |
| 布局 | 4 个卡片，无需懒加载；滚动使用 `CustomScrollView` + `SliverList` |
| 阴影 / 模糊 | 阴影为静态 `BoxShadow`；Hero 光斑用单层 `Container` + `BoxShadow`，不使用 `BackdropFilter`（成本高） |
| 图片 | 无图片资源；图标为字体图标 |
| 动画 | 仅页面转场、浮层、按钮缩放；无持续动画 |
| 长文本 | 备注折叠用 `TextPainter` 只算一次；避免每帧测量 |
| 内存 | 不缓存全量详情；退出即释放 |

---

## 11. 错误与边界

| 场景 | 处理 |
| --- | --- |
| 详情 404 | 全页空态「记录不存在或已被删除」+「返回账单」；隐藏分享 / 更多 |
| 详情网络失败 | 内容区 `SectionError(onRetry: () => ref.invalidate(expenseDetailProvider(id)))`；顶部返回可用 |
| 详情字段缺失 | 逐项兜底：标题→分类名、支付→未记录、里程→里程未记录、时间→隐藏 |
| 未知分类 key | 映射为 `other`，图标 / 颜色用中性色，记录埋点 |
| 未知支付渠道 | `PaymentChannel.other`，label 用后端值或「其他」 |
| 金额超长 | `FittedBox` 最小缩到 28 号；仍溢出时省略号（极端情况） |
| 备注超长 / 含换行 | 输入限制 200 字；展示折叠；分享截断 80 字 |
| 标签超限 / 重复 / 全空 | 保存前 `sanitizeTags`；UI 禁用 + 提示 |
| 车辆已删除 / 解绑 | 用快照渲染，徽标「已解绑」，隐藏箭头 |
| 删除时网络失败 | 保留页面，Toast；不本地移除 |
| 删除时 404 | 视为成功，返回并刷新 |
| 保存备注时 409 | 提示「记录已更新，请重新进入」并刷新详情 |
| 保存备注时 404 | 关闭浮层，Toast「记录已被删除」，返回账单刷新 |
| 连续点击保存 / 删除 | `_isMutating` + 按钮禁用 |
| 页面销毁后回调 | `mounted` 判断；controller autoDispose 忽略写入 |
| 分享平台不可用 | 捕获异常，Toast「分享失败，请重试」 |
| 系统字号放大 | 卡片自然增高；金额 `FittedBox`；按钮文字不截断 |
| 深色切换 | 依赖 `Theme` 重建；无硬编码颜色 |
| 时区变化 | 时间按接口本地时间展示，不重算 |

---

## 12. 测试方案

### 12.1 单元测试

| 文件 | 覆盖 |
| --- | --- |
| `test/features/expense_detail/expense_detail_presenter_test.dart` | 支出 / 退款金额文本、状态文案、结算标签、时间格式、里程兜底、分类副标题、分享文本（车牌隐藏、备注截断） |
| `test/features/expense_detail/expense_detail_models_test.dart` | `ExpenseDetail.fromRecord` 状态推导、`copyWith`、`sanitizeTags`（trim / `#` / 去重 / 限长 / 限数量）、`normalizeNote` |
| `test/features/expense_detail/mock_expense_detail_repository_test.dart` | 按 id 取详情、未找到抛 `ExpenseNotFoundException`、支付 / 标签确定性、备注更新、标签更新、删除后取不到 |
| `test/features/ledger/mock_ledger_repository_record_by_id_test.dart` | 跨月查找、缓存命中、删除过滤 |

### 12.2 Widget 测试

| 文件 | 覆盖 |
| --- | --- |
| `expense_detail_page_test.dart` | 有快照首帧渲染、加载中骨架、404 空态、网络错误重试、暗色主题 |
| `detail_hero_card_test.dart` | 支出 / 退款 / 超长金额 / 标题为空 / 分类副标题为纯文字 |
| `detail_vehicle_card_test.dart` | 已绑定 / 已解绑、里程缺失、车牌缺失、点击箭头 |
| `detail_settlement_card_test.dart` | 支付渠道有 / 无、退款标签、字段缺失隐藏、不出现尾号 / 商户 |
| `detail_tags_note_card_test.dart` | 标签渲染、8 个上限、空备注占位、长备注展开 / 收起、移除标签 |
| `note_editor_sheet_test.dart` | 字数计数、保存成功关闭、保存失败保留、清空备注 |
| `delete_expense_sheet_test.dart` | 取消不调用、确认调用、提交中禁用、404 视为成功 |
| `ledger_detail_navigation_test.dart` | 点击记录卡推入详情、删除返回后列表刷新、普通返回不刷新 |

- Widget 测试通过 `ProviderScope(overrides: [expenseDetailRepositoryProvider.overrideWithValue(FakeRepo())])` 注入假仓库，避免延时。
- 深色 / 浅色各跑一组关键断言；不强制 golden（字体与平台差异大），P1 再加截图比对。

### 12.3 手工验收

1. 账单页任意分类进入详情，核对金额、状态、时间、车辆、里程与卡片一致。
2. 编辑备注：保存中、成功、失败、清空、200 字上限。
3. 标签：添加第 9 个被阻止、重复提示、移除。
4. 删除：取消、确认、断网、已删除后重试。
5. 车辆删除（Mock 关闭绑定）：显示快照与「已解绑」。
6. 分享：系统面板内容、车牌隐藏、备注截断。
7. 深色模式、系统字号 1.3、横屏滚动、返回手势。

### 12.4 CI

- PR 跑 `flutter analyze` + `flutter test`，与本页无关的既有用例不得回归。
- 新增测试全部使用 Mock，不依赖网络与平台通道。

---

## 13. 实施拆分

| 阶段 | 分支 | 内容 | 产出 |
| --- | --- | --- | --- |
| M0 数据与模型 | `feat/expense-detail-data` | `ExpenseDetail` / 枚举 / presenter / 格式化 / 仓库接口 / Mock / `recordById` / 单元测试 | 数据层可测，UI 未接 |
| M1 静态页面 | `feat/expense-detail-ui` | 页面骨架、顶部栏、4 个卡片、底部栏、浅色视觉对齐；账单卡接入导航 | 设计稿还原，可来回跳转 |
| M2 交互闭环 | `feat/expense-detail-actions` | 备注 / 标签浮层、更多菜单、分享、复制、删除确认、controller、失效矩阵、返回结果刷新 | 备注 / 标签 / 删除 / 分享可用 |
| M3 状态与打磨 | `feat/expense-detail-polish` | 骨架、错误、404、深色、无障碍、长文本、性能、Widget 测试、文档回填 | 达到验收清单 |

> 指标 / 对比 / 商户 / 导航 / 票据 / 分类胶囊不在本期，也不拆 M4；如产品后续要加，需重新出稿与评审。

每个阶段保持 `flutter analyze` / `flutter test` 通过后合入功能分支，按仓库规范通过 PR 合并到 `main`。

---

## 14. 风险与待确认

| 风险 | 影响 | 应对 |
| --- | --- | --- |
| 详情接口未确认（标签、支付渠道、状态、绑定态） | 模型返工 | 模型字段全部可空；Mock 先跑通；接口按需求 §8 推进 |
| `code.html` 脚本与渲染画面不一致 | 开发误做未渲染模块 | 以 DOM + 需求文档 §3.3 为准；脚本残留一律不实现 |
| 设计稿分类占位色与项目语义色冲突（保养蓝 vs 琥珀） | 视觉不一致 | 统一用 `AppColors` 分类色；设计走查时确认 |
| 备注影响账单列表副标题 | 列表数据过期 | 保存备注后失效 `ledgerRecordsProvider`（已写入失效矩阵） |
| 删除后首页 / 报表未刷新 | 跨页数字不一致 | 删除统一失效首页与报表 provider；验收覆盖 |
| 记账 / 编辑页未上线 | 底部按钮像死路 | Toast 明确「待接入」；P1 接线只改回调 |
| 删除与备注并发（其他端已删） | 404 / 409 | 404 视为成功；409 提示刷新 |
| 长备注 / 长标签 | 布局溢出 | 备注折叠 + 分享截断；标签限长限数量 |
| 车牌隐私（页面展示 vs 分享隐藏） | 用户困惑 | 分享文案明确「车牌已隐藏」；文案评审确认 |
| 深色稿缺失 | 视觉偏差 | 按 token 推导；设计提供后统一复核 |
| 其他 Stitch 稿（富稿 / 旧稿）被误当基线 | 返工 | 以 `../code.html` 为准；验收前对照 DOM |
| 无快照深链接（P1） | 首帧骨架 | 页面已支持仅 `recordId`，自动走骨架 |
| `recordById` 首次回扫 24 个月 | Mock 首次进入慢 | 月度缓存 + id 索引；生产走接口，不受影响 |
| 退款状态与金额符号冲突 | 展示矛盾 | `status` 显式优先；冲突时埋点并按后端渲染 |

待确认（与需求文档 §13 同步）：

1. 详情接口是否提供 `tags`、`payment.channel` / `label`、`status`、`vehicle.bound`。
2. 首页「最近记录」入口与 `RecordItem.id` 补齐时间。
3. 备注上限 200 字是否满足。
4. 删除是否需要撤销（影响是否引入软删除）。
5. 分享是否允许显示车牌（默认隐藏）。
6. 分类副标题文案由客户端映射（不新增后端字段）。
7. 退款记录的展示与状态口径。
8. 深色设计稿时间点。
9. 编辑 / 再记一笔的记账页路由与预填参数契约。
10. 其他 Stitch 稿（富稿 / 旧稿）是否彻底废弃，只保留 `code.html` 作为验收基线。

---

## 15. 附录：需求 → 实现映射

| 需求 | 实现 |
| --- | --- |
| §6.1 顶部栏 | `presentation/widgets/detail_header.dart` + `BlurredHeaderDelegate` |
| §6.2 开销摘要卡 | `detail_hero_card.dart` + `ExpenseDetailPresentation.heroAmountText` / `statusLabel` |
| §6.3 关联爱车资产卡 | `detail_vehicle_card.dart` + `ExpenseDetail.vehicleBound` |
| §6.4 结算明细卡 | `detail_settlement_card.dart` + `ExpensePayment` / `PaymentChannelVisual` |
| §6.5 标签与用车备注 | `detail_tags_note_card.dart` + `ExpenseDetailRules` |
| §6.6 底部操作栏 | `detail_bottom_bar.dart` |
| §6.7 分享 / 更多 / 删除 | `detail_more_sheet.dart`、`delete_expense_sheet.dart`、`buildExpenseShareText` |
| §6.8 状态与反馈 | `expense_detail_page.dart` 的 `AsyncValue` 分发 + `SkeletonBox` / `EmptyState` / `SectionError` |
| §7 数据口径 | `expense_detail_presenter.dart`、`formatters.dart`、`category_style.dart` |
| §8 接口契约 | `ExpenseDetailRepository` + `HttpExpenseDetailRepository`（P1） |
| §9 异常 | `ExpenseDetailException` + §11 表格 |
| §10 非功能 | §8.9 / §8.10 / §10 |
| §12 验收 | §12 测试 + 手工验收 |

---

## 16. 实施记录（v0.3）

| 层 | 落地文件 |
| --- | --- |
| 模型 / 规则 | `expense_detail_models.dart`、`expense_detail_presenter.dart` |
| 数据 | `expense_detail_repository.dart`、`mock_expense_detail_repository.dart`、`MockLedgerRepository.recordById / markDeleted` |
| 状态 | `providers.dart`（`AsyncNotifierProvider.autoDispose.family` + 备注 / 标签乐观更新 + 删除失效） |
| 页面 / 组件 | `expense_detail_page.dart`、`detail_header.dart`、`detail_hero_card.dart`、`detail_vehicle_card.dart`、`detail_settlement_card.dart`、`detail_tags_note_card.dart`、`detail_bottom_bar.dart` |
| 浮层 | `detail_more_sheet.dart`、`note_editor_sheet.dart`、`tag_editor_sheet.dart`、`delete_expense_sheet.dart` |
| 入口 | `ledger_page.dart` 记录卡点击 → `ExpenseDetailPage`，返回后刷新 |

测试：

- `test/expense_detail/expense_detail_models_test.dart`
- `test/expense_detail/expense_detail_presenter_test.dart`
- `test/expense_detail/mock_expense_detail_repository_test.dart`
- `test/expense_detail/expense_detail_page_test.dart`
- `test/ledger/mock_ledger_repository_record_by_id_test.dart`

与方案的差异：

- 详情接口未接，`expenseDetailRepositoryProvider` 仍返回 `MockExpenseDetailRepository`。
- 支付渠道在详情未加载完时显示骨架，不显示「未记录」。
- 「车辆管理」「记账页」仍为 Toast 占位，等待对应页面落地。
- 未做富稿中的指标 / 对比 / 商户 / 导航 / 票据。

---

## 17. 变更记录

| 版本 | 日期 | 说明 |
| --- | --- | --- |
| v0.3 | 2026-11-14 | 按 `../code.html` 收敛：4 张卡 + 底栏；移除富字段模型（指标 / 对比 / 商户 / 票据 / 导航 / 支付尾号 / 双里程）；分类副标题改为纯文字 |
| v0.2 | 2026-11-14 | 曾按 Stitch `9839…` 富稿扩展，与当前 UI 不符，已撤回 |
| v0.1 | 2026-11-14 | 首版技术方案 |
