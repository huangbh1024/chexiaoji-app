# 账单·单笔开销详情页技术方案

| 项目 | 内容 |
| --- | --- |
| 关联需求 | [账单·单笔开销详情页需求文档 v0.2](../requirements/expense-detail.md) |
| 设计稿 | [Stitch · 账单·通用开销详情页](https://stitch.google.com/projects/9615374848161425677?node-id=9839d8f96a9440dcaf869d7eac418170) |
| 客户端 | Flutter 3.50.0 stable / Dart 3.14 |
| 平台 | Android（arm64 优先）、iOS |
| 文档版本 | v0.2（草案） |
| 状态 | 设计完成，未实施；接口未确认，客户端先用 Mock |

> 本文档基于**仓库当前已有实现**（首页、账单页、月度报表、`AppTabShell` 已落地，依赖为 `material_ui`、`flutter_riverpod 3.5`、`fl_chart`、`intl`、`pdf`、`printing`、`share_plus`、`path_provider`）编写。所有新增目录与文件均为拟实施内容，按 `feat/expense-detail-*` 分支推进。
> 需求口径以[需求文档 v0.2](../requirements/expense-detail.md) 的「口径建议（Q1–Q19）」为准；接口契约见需求文档 §8，本文档 §6.4 描述客户端映射、容错与 Mock。
> 设计稿顶部的分类胶囊是原型控件，**不进入产品 UI**；本文档不为其设计交互（见需求 §3.1）。设计稿 HTML 的 `EXPENSE_DATA` 作为各分类 Mock 与验收样例。

---

## 1. 目标与约束

### 1.1 技术目标

- 从账单卡片点击到页面首帧 ≤ 200ms（用列表已有 `LedgerRecord` 先渲染）；详情补齐 ≤ 800ms。
- **单一数据源**：金额、分类、时间、车辆、里程来自 `LedgerRecord`；指标、对比、票据、导航由详情接口补充，客户端不重复计算业务口径。
- 页面通用：不为 6 个分类写 6 套页面；分类差异由图标 / 徽标 / `telemetry` / `comparison` / `navigation` 数据驱动。
- 备注 / 标签乐观更新 + 失败回滚；票据预览按需加载；导航调起系统能力。
- 删除串行执行，成功后失效账单、首页、报表缓存，避免跨页数字不一致。
- 不新增图片资源；分享复用 `share_plus`，PDF 预览复用 `printing`，导航新增 `url_launcher`。
- 深色模式复用 `AppPalette.dark` / `AppTokens.dark`。

### 1.2 约束

- 不引入 `go_router`：继续用 `Navigator.push(MaterialPageRoute)`。
- 金额全链路整数分（`int cents`）；指标值是**后端下发的展示字符串**，客户端不做二次计算。
- 本页只读一条记录 + 局部更新备注 / 标签 + 删除 + 票据读取；整笔编辑、再记一笔跳记账页。
- 不落盘缓存详情与凭证；凭证 URL 为短期签名地址，过期重新拉详情。
- 详情接口未确认前由 `MockExpenseDetailRepository` 提供数据，UI 与 provider 不感知实现。
- 票据上传、OCR、验真为 P1，本期不引入文件选择依赖；「补充凭证」只做入口提示。
- 导航 P0 只调起系统地图 / 外部链接，不做站内路线规划、实时车位、轨迹回放。
- 分享 / 复制隐藏车牌与支付尾号；页面展示完整车牌，与账单页一致。
- 首页「最近记录」入口 P1：`RecordItem` 当前没有稳定 id。

### 1.3 新增依赖

| 依赖 | 用途 | 说明 |
| --- | --- | --- |
| `url_launcher` | 调起系统地图 / 外部链接 | 新增，需在 PR 中说明；版本锁最新稳定版；Android 11+ 如需 `canLaunchUrl`，在 `AndroidManifest.xml` 增加 `geo` / `https` 的 `<queries>` |
| `printing` | PDF 凭证预览 | 已有（月度报表使用） |
| `share_plus` | 文本分享 | 已有 |
| `dart:io` `HttpClient` | 拉取签名凭证字节 | 不新增依赖；仅移动端 |

P1 上传凭证时再评估 `image_picker` / `file_picker`，本期不引入。

---

## 2. 现状与复用清单

| 现有能力 | 位置 | 本页用法 |
| --- | --- | --- |
| 色彩 token | `lib/app/theme/app_colors.dart` → `AppPalette` / `AppColors` | 页面、卡片、状态、支付圆点、指标色调、Hero 光斑 |
| 间距 / 圆角 / 阴影 | `lib/app/theme/app_tokens.dart` → `AppTokens` | 页面边距、普通卡片阴影、底栏；24 圆角在页面内定义 |
| 字体 | `lib/app/theme/app_typography.dart` | `displayHero`、`headlineLg`、`headlineSm`、`bodyMd`、`bodySm`、`labelMd`、`labelSm` |
| 金额 / 里程 / 时间格式化 | `lib/core/format/formatters.dart` | `formatYuanDetail`、`formatKm`、`formatDuration`；新增 `formatDateTimeMinute`、`formatDateTimeFullCn`、`formatSignedYuan` |
| 分类语义色与图标 | `lib/core/presentation/category_style.dart` → `ExpenseCategoryVisual` | Hero 图标渐变、徽标、分类色；新增徽标文案与文字色 |
| 动力图标 | 同上 → `PowertrainVisual` | 车辆卡图标 |
| 基础枚举 | `lib/core/domain/enums.dart` | `ExpenseCategory`、`PowertrainType` |
| 记录模型 | `lib/features/ledger/domain/ledger_models.dart` | `LedgerRecord`、`LedgerMetrics` 作为详情主体 |
| 记录展示推导 | `lib/features/ledger/domain/ledger_presenter.dart` | 列表副标题复用 `note`，备注变更需失效列表 |
| 记录卡点击 | `lib/features/ledger/presentation/ledger_page.dart:322` | 替换 Toast，推入本页并处理结果 |
| Mock 数据 | `lib/features/ledger/data/mock_ledger_repository.dart` | 详情 Mock 复用同一批记录，保证列表与详情一致 |
| 毛玻璃吸顶栏 | `lib/core/widgets/blurred_header_delegate.dart` | 顶部栏滚动吸顶 |
| 空态 / 错误 / 骨架 | `lib/core/widgets/empty_state.dart`、`section_error.dart`、`skeleton_box.dart` | 不存在、加载失败、加载中 |
| PDF 预览 | `lib/features/report/export/report_pdf_builder.dart`、`printing` | 票据 PDF 全屏预览（`PdfPreview`） |
| 分享 API | `lib/features/report/export/report_exporter.dart:116` | `SharePlus.instance.share(ShareParams(...))` |
| 底栏最大宽度 | `lib/app/tab_shell.dart`（448 居中） | 本页底栏同样最大 448 |

### 2.1 现有实现与本页的差异

| 项 | 现状 | 本页处理 |
| --- | --- | --- |
| 记录点击 | Toast 占位 | 推入详情页，返回可刷新 |
| `LedgerMetrics.paymentMethod` | 模型已有，Mock 未赋值 | Mock 补齐；详情支付渠道 + 尾号由详情接口提供 |
| 记录备注 | `LedgerRecord.note` 可空 | 详情用 `ExpenseDetail.note`；备注变更失效列表 |
| 标签 | 无模型 | 新增 `tags`，仅详情层 |
| 状态 | 列表用 `statusText` 自由文案 | 详情新增 `ExpenseStatusInfo`；列表字段不变 |
| 指标 | 无 | 新增 `telemetry`，后端下发 4 条展示值 |
| 对比 | 无 | 新增 `comparison`，可空 |
| 票据 | 无 | 新增 `vouchers` + 预览；上传 P1 |
| 导航 | 无 | 新增 `navigation` + `url_launcher` |
| 深色模式 | 已有 token，无本页设计 | 按暗色 token 推导 |

---

## 3. 结构调整

### 3.1 新增目录

```
lib/features/expense_detail/
├── data/
│   ├── expense_detail_repository.dart      # 接口 + 异常类型
│   ├── mock_expense_detail_repository.dart # 由 MockLedgerRepository 派生
│   ├── voucher_loader.dart                 # 凭证字节加载（签名 URL）
│   └── map_launcher.dart                   # 系统地图 / 链接调起
├── domain/
│   ├── expense_detail_models.dart          # Detail / Telemetry / Comparison / Voucher / Navigation
│   ├── expense_detail_presenter.dart       # 金额、状态、时间、支付、里程、分享文本
│   └── providers.dart                      # 仓库 / 详情 / 地图 / 凭证加载
└── presentation/
    ├── expense_detail_page.dart
    ├── expense_detail_style.dart
    └── widgets/
        ├── detail_header.dart
        ├── detail_hero_card.dart
        ├── detail_telemetry_grid.dart
        ├── detail_vehicle_card.dart
        ├── detail_comparison_banner.dart
        ├── detail_settlement_card.dart
        ├── detail_tags_note_card.dart
        ├── detail_voucher_card.dart
        ├── detail_nav_button.dart
        ├── detail_bottom_bar.dart
        ├── detail_more_sheet.dart
        ├── note_editor_sheet.dart
        ├── tag_editor_sheet.dart
        ├── delete_expense_sheet.dart
        └── voucher_preview_sheet.dart
```

局部常量：

```dart
abstract final class ExpenseDetailStyle {
  static const pagePadding = 16.0;
  static const cardGap = 12.0;
  static const cardRadius = 24.0;
  static const heroPadding = 20.0;
  static const heroIconSize = 48.0;
  static const iconRadius = 16.0;
  static const rowRadius = 16.0;
  static const actionHeight = 50.0;
  static const contentBottomPadding = 144.0;
}
```

若 24 圆角后续复用到多个页面，再提升为 `AppTokens.radiusPanel`；本期不扩大公共 token 面。

### 3.2 修改现有文件

| 文件 | 改动 | 影响 |
| --- | --- | --- |
| `lib/features/ledger/presentation/ledger_page.dart` | 新增 `_openExpenseDetail(LedgerRecord)`；记录卡 `onTap` 改为调用；`await` 返回结果并刷新 | 替换 Toast |
| `lib/features/ledger/data/mock_ledger_repository.dart` | 新增 `recordById(String id)`；生成记录时补 `metrics.paymentMethod` | 详情 Mock 取数；CSV 支付列由空变有值 |
| `lib/core/format/formatters.dart` | 新增 `formatDateTimeMinute`、`formatDateTimeFullCn`、`formatSignedYuan` | 本页与后续页面复用 |
| `lib/core/presentation/category_style.dart` | `ExpenseCategoryVisual` 增加 `badgeLabel`、`badgeTextColor(AppPalette)` | 首页 / 账单可选用 |
| `pubspec.yaml` | 新增 `url_launcher` | 地图调起 |

> 不修改 `LedgerRepository` 接口：详情走独立 `ExpenseDetailRepository`。

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
   ├── data   → 指标 / 对比 / 票据 / 导航 / 标签 / 备注
   ├── loading→ 标签 / 票据区域骨架，其余用快照
   └── error  → SectionError（可重试）/ 404 空态
        │
        ├── 保存备注 → controller.saveNote → PATCH → 局部更新 + 失效账单列表
        ├── 保存标签 → controller.saveTags → PUT   → 局部更新
        ├── 预览票据 → VoucherLoader → 预览浮层
        ├── 点击导航 → MapLauncher → 系统地图 / 链接
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

- 备注 / 标签变更返回 `updated`；账单页刷新列表（备注可能影响副标题）。
- 删除返回 `deleted`；账单页刷新汇总 + 列表，并保持筛选与滚动位置。
- 未做改动直接返回 `null`，账单页不刷新。

---

## 5. 数据模型

### 5.1 枚举

```dart
enum ExpenseStatus { completed, refunded }

enum PaymentChannel { wechat, alipay, unionpay, etc, cash, card, other }

enum TelemetryTone { primary, tertiary, warning, neutral, unknown }

enum ExpenseVoucherKind { pdf, image, unknown }

enum NavigationType { navigate, parkingStatus, route, external, unknown }
```

### 5.2 子模型

```dart
@immutable
class ExpensePayment {
  const ExpensePayment({
    required this.channel,
    required this.label,
    this.detail,
  });

  final PaymentChannel channel;
  final String label;      // 「微信支付」
  final String? detail;    // 「尾号8812」
}

@immutable
class ExpenseMerchant {
  const ExpenseMerchant({required this.name, this.address, this.lat, this.lng});

  final String name;
  final String? address;
  final double? lat;
  final double? lng;
}

@immutable
class ExpenseTelemetry {
  const ExpenseTelemetry({
    required this.key,
    required this.label,
    required this.value,
    this.unit,
    this.tone = TelemetryTone.neutral,
  });

  final String key;
  final String label;
  final String value;
  final String? unit;
  final TelemetryTone tone;
}

@immutable
class ExpenseComparison {
  const ExpenseComparison({
    required this.label,
    required this.value,
    this.iconKey,
    this.tone = TelemetryTone.primary,
  });

  final String label;
  final String value;
  final String? iconKey;
  final TelemetryTone tone;
}

@immutable
class ExpenseVoucher {
  const ExpenseVoucher({
    required this.id,
    required this.kind,
    required this.name,
    this.statusLabel,
    required this.url,
    this.thumbnailUrl,
  });

  final String id;
  final ExpenseVoucherKind kind;
  final String name;
  final String? statusLabel;
  final String url;
  final String? thumbnailUrl;
}

@immutable
class ExpenseNavigation {
  const ExpenseNavigation({
    required this.type,
    required this.label,
    this.lat,
    this.lng,
    this.url,
  });

  final NavigationType type;
  final String label;
  final double? lat;
  final double? lng;
  final String? url;

  bool get hasTarget => url != null || (lat != null && lng != null);
}

@immutable
class ExpenseStatusInfo {
  const ExpenseStatusInfo({required this.code, required this.text});

  final ExpenseStatus code;
  final String text;
}
```

### 5.3 详情模型

```dart
@immutable
class ExpenseDetail {
  const ExpenseDetail({
    required this.record,
    required this.status,
    required this.settlementTypeLabel,
    required this.categoryLabel,
    required this.categoryBadgeLabel,
    this.subtitle,
    this.payment,
    this.merchant,
    this.telemetry = const <ExpenseTelemetry>[],
    this.comparison,
    this.discountNote,
    this.tags = const <String>[],
    this.note,
    this.vouchers = const <ExpenseVoucher>[],
    this.verificationVerified,
    this.verificationText,
    this.navigation,
    this.vehicleBound = true,
    this.totalOdometerKm,
    this.updatedAt,
  });

  final LedgerRecord record;
  final ExpenseStatusInfo status;
  final String settlementTypeLabel;
  final String categoryLabel;
  final String categoryBadgeLabel;
  final String? subtitle;
  final ExpensePayment? payment;
  final ExpenseMerchant? merchant;
  final List<ExpenseTelemetry> telemetry;
  final ExpenseComparison? comparison;
  final String? discountNote;
  final List<String> tags;
  final String? note;
  final List<ExpenseVoucher> vouchers;
  final bool? verificationVerified;
  final String? verificationText;
  final ExpenseNavigation? navigation;
  final bool vehicleBound;
  final int? totalOdometerKm;
  final DateTime? updatedAt;

  ExpenseDetail copyWith({ /* status, tags, note, updatedAt ... */ });

  /// 无详情时的轻量快照，供首帧与骨架使用。
  /// 支付、商户、指标、票据、导航留空，由详情接口补齐；
  /// UI 在加载中对这些字段显示骨架，而不是「未记录」。
  factory ExpenseDetail.fromRecord(LedgerRecord record) {
    final refunded = record.amountCents < 0;
    return ExpenseDetail(
      record: record,
      status: ExpenseStatusInfo(
        code: refunded ? ExpenseStatus.refunded : ExpenseStatus.completed,
        text: '',
      ),
      settlementTypeLabel: refunded ? '退款入账' : '单笔核销',
      categoryLabel: record.category.label,
      categoryBadgeLabel: record.category.badgeLabel,
      note: record.note,
    );
  }
}
```

设计取舍：

- 不把 `tags`、`telemetry`、`vouchers` 塞进 `LedgerRecord`：列表接口不需要这些字段，避免列表模型与接口膨胀。
- `record` 直接复用 `LedgerRecord`，金额、分类、时间、车辆快照、`metrics` 保持单一来源。
- `totalOdometerKm` 单独放详情层：列表只需要记账时里程。
- 指标 / 对比的值是**展示字符串**，客户端不再用 `amount / distance` 推导，避免与报表口径冲突。
- `vouchers` 只存元数据与签名 URL，不缓存字节。

### 5.4 展示推导（presenter）

```dart
extension ExpenseDetailPresentation on ExpenseDetail {
  String get heroAmountText => formatSignedYuan(record.amountCents);

  String get settledAmountText => record.amountCents < 0
      ? '+${formatYuanDetail(record.amountCents.abs())}'
      : formatYuanDetail(record.amountCents);

  String get settledLabel =>
      status.code == ExpenseStatus.refunded ? '退款金额' : '实付金额';

  String get summaryTimeText => formatDateTimeMinute(record.occurredAt);

  String get settlementTimeText => formatDateTimeFullCn(record.occurredAt);

  String get titleText =>
      record.title.trim().isEmpty ? record.category.label : record.title;

  String get statusText => status.text.trim().isEmpty
      ? (status.code == ExpenseStatus.refunded
          ? '已退款 · 账单已冲正'
          : '已完成扣款 · 账单已入账')
      : status.text;

  String get categoryText => categoryLabel.trim().isEmpty
      ? record.category.label
      : categoryLabel;

  String get badgeText => categoryBadgeLabel.trim().isEmpty
      ? record.category.badgeLabel
      : categoryBadgeLabel;

  String get paymentText {
    final p = payment;
    if (p == null || p.label.trim().isEmpty) return '未记录';
    final detail = p.detail?.trim();
    return detail == null || detail.isEmpty ? p.label : '${p.label} ($detail)';
  }

  String get odometerText {
    final recordKm = record.metrics.odometerKm;
    final totalKm = totalOdometerKm;
    if (recordKm == null && totalKm == null) return '里程未记录';
    if (recordKm != null && totalKm != null) {
      return '记账时里程 ${formatKm(recordKm)} · 累计总里程 ${formatKm(totalKm)}';
    }
    return recordKm != null
        ? '记账时里程 ${formatKm(recordKm)}'
        : '累计总里程 ${formatKm(totalKm!)}';
  }

  String get merchantText => merchant?.name.trim() ?? '';

  bool get hasNote => (note ?? '').trim().isNotEmpty;

  String get shareText => buildExpenseShareText(this);
}
```

状态 / 徽标 / 支付 / 指标色调映射放在 presenter 或独立 extension，避免 Widget 内散落 `switch`：

| 映射 | 位置 |
| --- | --- |
| 状态图标与颜色 | `ExpenseStatusVisual`（`check_circle` 主绿 / `undo` 玫粉） |
| 分类徽标文案 | `ExpenseCategoryVisual.badgeLabel`（`category_style.dart`） |
| 分类徽标文字色 | `ExpenseCategoryVisual.badgeTextColor(palette)` |
| 支付圆点色 | `PaymentChannelVisual.color(palette)`（本 feature 内） |
| 指标 / 对比色调 | `TelemetryToneVisual.color(palette)`（`primary` → `primaryText`，`tertiary` → `tertiary`，`warning` → `secondaryText`，其余 `onSurface`） |

### 5.5 格式化新增

```dart
/// 摘要时间：`2025-05-16 13:28`。
String formatDateTimeMinute(DateTime time) { ... }

/// 结算时间：`2025年05月16日 13:28:44`。
String formatDateTimeFullCn(DateTime time) { ... }

/// 带符号金额：支出 `-¥51.10`，退款 `+¥51.10`，零金额 `¥0.00`。
String formatSignedYuan(int cents) { ... }
```

- `formatExpense` 已存在但语义是「支出带负号」，退款场景会得到反直觉结果；新增 `formatSignedYuan`，不改旧函数。
- 时间统一 `toLocal()` 后格式化；接口返回带偏移量的 ISO 8601。

### 5.6 标签与备注规则

```dart
abstract final class ExpenseDetailRules {
  static const maxTags = 8;
  static const maxTagLength = 10;
  static const maxNoteLength = 200;
}

List<String> sanitizeTags(Iterable<String> input) { ... }
String? normalizeNote(String raw) { ... }
```

- 存储不带 `#`；渲染 `#${tag}`。
- 超长标签在输入阶段限制，不静默截断。
- 备注保留内部换行，首尾空白删除；按 `characters.length` 计数。
- `TelemetryTone` 解析未知值 → `TelemetryTone.unknown`，渲染时按 `neutral`。

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

sealed class ExpenseDetailException implements Exception { ... }
class ExpenseNotFoundException extends ExpenseDetailException { ... }
class ExpenseDetailNetworkException extends ExpenseDetailException { ... }
class ExpenseDetailConflictException extends ExpenseDetailException { ... }
```

凭证加载与地图调起独立抽象：

```dart
abstract class VoucherLoader {
  Future<Uint8List> loadBytes(ExpenseVoucher voucher);
}

abstract class MapLauncher {
  Future<bool> open(ExpenseNavigation navigation);
}
```

### 6.2 Mock 实现

`MockExpenseDetailRepository(MockLedgerRepository ledger)`：

| 字段 | 生成规则 |
| --- | --- |
| `record` | `ledger.recordById(id)`；未找到抛 `ExpenseNotFoundException` |
| `status` | `amountCents < 0` → `refunded`，否则 `completed`；文案按分类固定 |
| `settlementTypeLabel` | 已完成「单笔核销」，退款「退款入账」 |
| `categoryLabel` | 按分类固定组合名（见下表） |
| `categoryBadgeLabel` | 按分类固定（新能源补能 / 燃油加注 / …） |
| `subtitle` | 按分类固定地址 / 服务描述；保养 / 洗车可用记录 `description` |
| `payment` | 按分类固定渠道 + 尾号（Mock） |
| `merchant` | 按分类固定商户名 + 地址 + 坐标 |
| `telemetry` | 按分类固定 4 条（见下表） |
| `comparison` | 按分类固定 1 条 |
| `discountNote` | 充电 / 保养给「已享专属车友权益减免」，其他可空 |
| `tags` | 按分类固定 2–3 个 |
| `note` | 优先 `record.note`；为空按分类给演示备注 |
| `vouchers` | 充电 2 个（PDF + 图片），加油 / 保养 1 个，其他 0–1 个 |
| `verification` | 有凭证时 `verified=true`，文案「已核验」 |
| `navigation` | 按分类固定 label + 坐标；`type=navigate` |
| `totalOdometerKm` | `record.metrics.odometerKm`（Mock 无当前总里程，同值） |
| `vehicleBound` | `true` |
| `updatedAt` | `occurredAt + 2min` |
| 延迟 | 120ms；构造参数可关闭，供 Widget 测试 |

分类固定数据：

| 分类 | categoryLabel | 支付 | 商户 | 对比 |
| --- | --- | --- | --- | --- |
| 充电 | 能源补给 · 充电 | 微信支付 (尾号8812) | 特来电新能源科技股份有限公司 | 相比同里程 92# 汽油节省约 ¥98.50 |
| 加油 | 能源补给 · 加油 | 云闪付加油卡代扣 | 中国石化销售股份有限公司深圳分公司 | 本次百公里综合油耗测算约 6.8 L/100km |
| 保养 | 日常维保 · 常规大保养 | 支付宝企业结算 (尾号3302) | 深圳中升汽车服务实业发展有限公司 | 三电健康状态及底盘检查评分 99.2 分 优 |
| 洗车 | 车辆美容 · 标准洗车 | 微信支付（次卡划扣） | 极客汽车养护连锁管理有限公司 | 距上一次全车深度精洗已有 21 天 |
| 停车 | 行程停放 · 临时停车 | 无感免密快捷支付 | 华润万象生活商业物业管理系统 | 已使用会员积分抵扣停车费 -¥15.00 |
| 过路费 | 行程通行 · 高速过路费 | 粤通卡 ETC 自动划扣 | 广东广深沿江高速公路有限公司 | 走沿江高速相比普通地面道路节省 约 32 分钟 |
| 其他 | 其他开销 | 支付宝 | 商户（按记录标题） | 不展示 |

`telemetry` 固定样例见需求文档 §7.2；Mock 直接按表生成，保证 6 类都能截图 / 测试。

### 6.3 记录查找

`MockLedgerRepository` 新增：

```dart
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

- `_recordsFor` 已有月度缓存，回扫成本低；首次最多生成 24 个月数据，Mock 环境可接受。
- 新增 `Set<String> _deletedIds`：`fetchRecords` / `fetchSummary` 过滤；`recordById` 对已删 id 返回 `null`。
- 生产环境由 `GET /expenses/{id}` 直接取，不回扫。

### 6.4 接口映射与容错

| JSON 字段 | 模型字段 | 容错 |
| --- | --- | --- |
| `id` | `record.id` | 缺失 → 解析失败，按网络错误处理 |
| `category` | `record.category` | 未知 key → `ExpenseCategory.other`，记录埋点 |
| `categoryLabel` | `detail.categoryLabel` | 空 → 分类短名 |
| `categoryBadgeLabel` | `detail.categoryBadgeLabel` | 空 → 客户端映射 |
| `title` / `subtitle` | `record.title` / `detail.subtitle` | 空标题 → 分类名；空副标题隐藏 |
| `amountCents` | `record.amountCents` | 整数分；负数即退款 |
| `occurredAt` | `record.occurredAt` | 解析失败 → 隐藏时间 |
| `status.code/text` | `detail.status` | 未知 code → 按金额符号推导；空 text → 兜底文案 |
| `settlementTypeLabel` | `detail.settlementTypeLabel` | 空 → 按状态兜底 |
| `vehicle.*` | `record.vehicleId` / `vehicleName` / `powertrain` / `metrics.plate` / `metrics.odometerKm` / `detail.totalOdometerKm` / `vehicleBound` | 车辆可空；`bound` 缺失默认 `true` |
| `payment.*` | `detail.payment` | 未知 channel → `other`；label 空 → 「其他」；detail 空 → 只显示 label |
| `merchant.name/address/lat/lng` | `detail.merchant` | 整块缺失 → 隐藏商户行与导航坐标 |
| `telemetry[]` | `detail.telemetry` | 非数组 / 空 → 隐藏指标格；单条缺 label/value → 跳过；最多 4 条 |
| `comparison` | `detail.comparison` | 缺 label 或 value → 隐藏 |
| `settlement.discountNote` | `detail.discountNote` | 空 → 隐藏 |
| `tags` | `detail.tags` | `sanitizeTags` 兜底 |
| `note` | `detail.note` | 超长截到 200 字并提示 |
| `vouchers[]` | `detail.vouchers` | 非法 URL / 缺 name → 跳过；最多展示 2 个 |
| `verification` | `detail.verificationVerified/Text` | 缺失 → 隐藏徽标 |
| `navigation` | `detail.navigation` | 无 url 且无坐标 → 不渲染按钮 |
| `metrics` | `record.metrics` | 与列表接口同构；缺字段为 null |
| `updatedAt` | `detail.updatedAt` | 仅用于并发提示，P0 不展示 |

HTTP 实现（P1 接入时）：

- `GET /expenses/{id}`：超时 8s，不自动重试；404 → `ExpenseNotFoundException`；其他 → `ExpenseDetailNetworkException`。
- `PATCH /note` / `PUT /tags`：整字段覆盖；409 → `ExpenseDetailConflictException`（提示「已有更新，请重新进入」）。
- `DELETE`：204 成功；404 也视为成功（幂等）。
- 请求头 `Accept: application/json`、`Content-Type: application/json`；不记录车牌、备注全文、凭证 URL。
- 不支持离线队列：失败即提示。

### 6.5 凭证加载

```dart
class HttpVoucherLoader implements VoucherLoader {
  @override
  Future<Uint8List> loadBytes(ExpenseVoucher voucher) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(voucher.url));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw const VoucherExpiredException();
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    } finally {
      client.close();
    }
  }
}
```

- 只按需加载，单文件 ≤ 20MB；超过直接提示。
- 图片缩略图走 `Image.network(voucher.thumbnailUrl ?? voucher.url)`，`errorBuilder` 显示占位。
- 不写磁盘缓存；离开页面释放内存。
- URL 过期 → 抛出 `VoucherExpiredException`，页面提示并允许重新拉详情。

### 6.6 地图调起

```dart
class SystemMapLauncher implements MapLauncher {
  @override
  Future<bool> open(ExpenseNavigation navigation) async {
    final uri = _resolve(navigation);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Uri? _resolve(ExpenseNavigation nav) {
    if (nav.url != null && nav.url!.isNotEmpty) return Uri.parse(nav.url!);
    final lat = nav.lat, lng = nav.lng;
    if (lat == null || lng == null) return null;
    final label = Uri.encodeComponent(nav.label);
    if (Platform.isIOS) {
      return Uri.parse('https://maps.apple.com/?ll=$lat,$lng&q=$label');
    }
    if (Platform.isAndroid) {
      return Uri.parse('geo:$lat,$lng?q=$lat,$lng($label)');
    }
    return Uri.parse('https://uri.amap.com/marker?position=$lng,$lat&name=$label');
  }
}
```

- `MapLauncher` 通过 provider 注入，Widget 测试使用 Fake。
- `launchUrl` 返回 `false`（无地图应用）时回退高德 Web；仍失败由页面 Toast。
- 非 `navigate` 类型（停车 / 轨迹）优先使用 `navigation.url`；无 URL 则 Toast「功能待接入」。

### 6.7 Repository Provider

```dart
final expenseDetailRepositoryProvider = Provider<ExpenseDetailRepository>((ref) {
  return MockExpenseDetailRepository(ref.watch(ledgerRepositoryProvider));
});

final voucherLoaderProvider = Provider<VoucherLoader>((ref) {
  return HttpVoucherLoader();
});

final mapLauncherProvider = Provider<MapLauncher>((ref) {
  return SystemMapLauncher();
});
```

接入接口时只替换仓库实现，页面与 controller 不改。

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

- `AsyncNotifierProvider.autoDispose.family` 为 Riverpod 3.5 现有能力；family 参数通过构造函数注入。
- 备注 / 标签乐观更新；失败回滚并 Toast。
- 删除成功后再失效 + 返回，避免「已删除但请求失败」。

### 7.2 失效矩阵

| 操作 | 详情 | 账单列表 | 账单汇总 | 首页仪表盘 / 最近记录 | 月度报表 |
| --- | --- | --- | --- | --- | --- |
| 保存备注 | 本地更新 | 失效（列表副标题用 note） | 不失效 | 不失效 | 不失效 |
| 保存标签 | 本地更新 | 不失效 | 不失效 | 不失效 | 不失效 |
| 删除记录 | 返回上一页 | 失效 | 失效 | 失效 | 失效 |
| 整笔编辑（P2） | 失效 | 失效 | 失效 | 失效 | 失效 |

### 7.3 竞态与生命周期

- 页面销毁后 mutation 回调不再 `setState`；controller autoDispose 后写入被忽略。
- 连续保存：`_isMutating` 忽略第二次；输入框禁用。
- 凭证预览与导航为一次性动作，不进 controller。
- 返回结果只在 `Navigator.pop` 交付，不用全局状态。

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
                          DetailTagsNoteCard(detail: detail, ...),
                          const SizedBox(height: 12),
                          DetailVoucherCard(detail: detail, ...),
                          const SizedBox(height: 12),
                          DetailNavButton(detail: detail, ...),
                        ]),
                      ),
                  ],
                ),
              ],
            ),
          ),
          DetailBottomBar(...),
        ],
      ),
    );
  }
}
```

- `_AmbientBackdrop`：顶部 384 高、页面色到透明的渐变 + 两个分类色 15% 模糊圆（`IgnorePointer`）。
- 错误态：`SliverFillRemaining` 内放 `EmptyState` / `SectionError`。
- 页面使用 `Column` + `Expanded`，便于底栏毛玻璃与顶部圆角。

### 8.2 顶部栏 `DetailHeader`

- 高度 56 + 顶部安全区；左右 16、上下 8。
- 左返回 40 圆 + `surface` 白底 + `AppTokens.cardShadow`；`Icons.arrow_back` 20。
- 中间两行：标题 `headlineSm`；副标题 `labelSm`（`outline`，字距 0.2）。
- 右侧 40 圆按钮：分享 `Icons.ios_share` 19、更多 `Icons.more_horiz` 20。
- `detail == null` 时分享 / 更多禁用，透明度 0.4。
- 更多 → `DetailMoreSheet`；分享 → `shareExpense`。

### 8.3 摘要卡 `DetailHeroCard`

```dart
Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: palette.surface,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
    boxShadow: const [
      BoxShadow(color: Color(0x1F00C48C), blurRadius: 32, offset: Offset(0, 12), spreadRadius: -6),
      BoxShadow(color: Color(0x080F172A), blurRadius: 16, offset: Offset(0, 4)),
    ],
  ),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: Stack(
      children: [
        Positioned(right: -40, top: -40, child: _CategoryGlow(...)),
        Positioned(right: 0, bottom: 0, child: _WaveDecoration(...)),
        Column(children: [
          _HeroHeader(detail: detail),
          const SizedBox(height: 20),
          _HeroAmount(detail: detail),
          const SizedBox(height: 4),
          _StatusLine(detail: detail),
          if (detail.telemetry.isNotEmpty) ...[
            const SizedBox(height: 16),
            DetailTelemetryGrid(items: detail.telemetry),
          ],
        ]),
      ],
    ),
  ),
)
```

- `_HeroHeader`：`Row(crossAxisAlignment: start)`：
  - 左：48 图标 + `Expanded(Column(title Row + subtitle))`；标题与徽标用 `Wrap(spacing: 8)`，窄屏自动换行。
  - 右：`settlementTypeLabel` 胶囊，`labelSm` 11/14，`surfaceContainerLow` 底。
- `_HeroAmount`：`Row(mainAxisSize: min, crossAxisAlignment: baseline)` + `FittedBox(scaleDown)`；符号 `headlineLg`，数字 `displayHero`。
- `_StatusLine`：`Wrap` 居中，状态图标 14 + `statusText` + `·` + `summaryTimeText`；状态文案过长时换到下一行，不截断。
- `DetailTelemetryGrid`：
  ```dart
  Row(children: [
    for (var i = 0; i < items.length; i++) ...[
      if (i > 0) const SizedBox(width: 8),
      Expanded(child: _TelemetryTile(item: items[i])),
    ],
  ])
  ```
  `_TelemetryTile`：`Container(padding: 10, decoration: surfaceContainerLow 70%, radius 16)`，`label` 11/16 `outline`，值 16/22 700 + 单位 11/16；`FittedBox` 防溢出。
- 指标格与摘要内容之间加 1px 顶部分隔线（`outlineVariant` 40%），对应设计稿 `border-t`。

### 8.4 车辆卡与对比条

`DetailVehicleCard` 包含两个部分：

1. 车辆卡：外卡 `_DetailCard(padding: 16)`；卡头 13/16 + 「主驾绑定」胶囊；信息行 `InkWell` + `surfaceContainer` 60% + 圆角 16 + 内边距 14；车辆名 + 车牌用 `Wrap`；里程 `odometerText`；箭头仅在 `vehicleBound` 时显示。
2. `DetailComparisonBanner`：`Container` + `LinearGradient(primary 10% → transparent)` + `border primary 20%` + 圆角 16 + 内边距 14×10；`Row(icon 18 + label Expanded + value)`；`comparison == null` 时不渲染。

- 对比图标按 `comparison.iconKey` 映射：`savings` / `local_fire_department` / `verified_user` / `clean_hands` / `schedule` / `speed` / 默认 `trending_up`。
- 对比值用 `FittedBox`，避免长文案挤压。

### 8.5 结算卡 `DetailSettlementCard`

- 复用 `_DetailCard`；卡头 `receipt_long_rounded` 20（`tertiary`）+ 标题 + 右侧「电子单据」。
- 字段行 `_SettlementRow(label, value)`：上下 8，底部 1px 分隔线；值右对齐，商户行单行省略。
- 支付行：`Row(children: [if (payment != null) _Dot(color), Text(paymentText)])`；`未记录` 无圆点。
- 详情未就绪（`isSyncing && payment == null`）时，支付值显示 60 宽骨架，**不显示「未记录」**，避免首帧误导；商户行同样处理。
- 金额行：顶部 10；左侧标题 + `discountNote` 11/16；右侧金额 `headlineLg` 主绿；退款标题「退款金额」、金额带 `+`。
- 时间使用 `settlementTimeText`（含秒）。

### 8.6 标签与备注卡 `DetailTagsNoteCard`

- 卡头：`label_rounded` 18（`secondary`）+ 「标签与用车备忘」+ `TextButton.icon`（`edit_rounded` 14，「编辑备注」）。
- 标签区：`Wrap(spacing: 8, runSpacing: 8)`；标签胶囊 `GestureDetector` 打开移除确认；末尾虚线「添加标签」胶囊（`DashedBorderPainter`，不引入依赖）。
- 备注块：`surfaceContainer` 50% + 圆角 16 + 内边距 14；`format_quote_rounded` 18 + `Expanded(Text)`。
- 折叠：`LayoutBuilder` + `TextPainter` 计算 4 行；超出时 `maxLines: 4` + 「展开」；展开后「收起」。
- 空备注：占位文案 + 点击编辑；不显示引号图标（或低透明度）。
- `isSyncing` 时降低不透明度 0.6，禁止点击。

### 8.7 票据卡 `DetailVoucherCard`

```dart
Row(children: [
  Expanded(child: _VoucherTile(voucher: first)),
  const SizedBox(width: 10),
  Expanded(child: _VoucherTile(voucher: secondOrCount)),
  const SizedBox(width: 10),
  Expanded(child: _AddVoucherTile(onTap: onAdd)),
])
```

- 外卡 `_DetailCard(padding: 20)`；卡头 `attachment` 18（`tertiary`）+ 标题 + 核验胶囊。
- 核验胶囊：`verified == true` → 「已核验」主绿；`false` → 「待核验」中性；`null` → 不显示。
- 单元格：`AspectRatio(aspectRatio: 1)` + 圆角 16 + 浅灰底 + 1px 描边 + 居中 `Column`；图标 30，名称 10/12 700，状态 9/16 `outline`；`InkWell` 缩放 0.95。
- 最多展示 2 个已有凭证；更多时第二格显示 `+N`（点击打开凭证列表 P1）。
- 空凭证：只显示「补充凭证」格（仍保留卡片）。
- 点击 PDF → `VoucherPreviewSheet` 用 `PdfPreview`；点击图片 → `InteractiveViewer` + `Image.network`。
- 点击补充凭证 → P0 Toast「凭证上传待接入」；P1 接文件选择与上传。

`VoucherPreviewSheet`：

- `showModalBottomSheet(isScrollControlled: true, useSafeArea: true)`，高度 90%。
- 标题栏：文件名 + 关闭；正文加载中骨架 / 错误重试 / 内容。
- PDF：`PdfPreview(build: (format) async => bytes, allowPrinting: false, allowSharing: false)`。
- 图片：`InteractiveViewer(minScale: 1, maxScale: 4)` + `Image.memory`（先 `loadBytes`）。
- 内存：预览关闭后释放 bytes；单文件 ≤ 20MB。

### 8.8 导航按钮 `DetailNavButton`

- `navigation == null` 或 `!hasTarget && merchant?.address == null` → 不渲染。
- `Container` 白卡 + 圆角 16 + 内边距 12×16 + `InkWell`。
- 图标 `near_me_rounded` 18 主绿 + 文案 13/16 600，居中。
- 点击：
  1. `nav.url != null` → `MapLauncher.open` 打开外部链接；
  2. 坐标存在 → 系统地图；
  3. 仅地址 → 复制地址 + Toast「地址已复制」；
  4. 全无 → 不渲染。
- 打开失败 → Toast「无法打开地图，请稍后重试」。

### 8.9 底部操作栏 `DetailBottomBar`

- `Container`：左右 16、上下 12 + 底部安全区；顶部圆角 24、`surface` 90%、顶部白色 60% 1px、`tokens.navShadow`。
- `Row`：`Expanded(flex: 1)` 次按钮、8 间距、`Expanded(flex: 2)` 主按钮。
- 高 50；次按钮 `surfaceContainer` + `add_circle_outline_rounded`；主按钮 `LinearGradient([primary, 0xFF00C48C])` + `edit_note_rounded` + 40% 阴影。
- 文案「再记一笔」「编辑此笔开销」；禁用时透明度 0.5。
- 点击回调由页面注入，便于后续接记账页。

### 8.10 浮层

**备注编辑 `NoteEditorSheet`**

- `showModalBottomSheet(isScrollControlled: true)` + `viewInsets` 底部内边距。
- 标题「编辑备注」；`TextField(maxLines: 5, minLines: 4, maxLength: 200)`。
- 取消 / 保存；保存中禁用；失败保留输入并显示错误。
- 清空保存 → `note = null`，回到空备注占位。

**标签编辑 `TagEditorSheet`**

- 标题「添加标签」；输入框前置固定 `#`，`maxLength: 10`；重复 / 空值禁用保存。
- 已有标签列表带移除图标；达到 8 个时禁用输入并提示。

**更多菜单 `DetailMoreSheet`**

- 「复制账单信息」→ `Clipboard.setData`（隐藏车牌与支付尾号）+ Toast。
- 「分享为图片」→ P1，禁用 + 「暂不支持」。
- 「删除此笔开销」→ 警示色，先关闭菜单再打开删除确认。

**删除确认 `DeleteExpenseSheet`**

- 标题「删除这笔开销？」+ 两行说明；取消 / 删除（`error`）。
- 提交中禁用返回与遮罩关闭；成功 `pop(outcome.deleted)`；失败 Toast。

### 8.11 深色模式

- 所有颜色来自 `context.palette` / `context.tokens`。
- Hero 图标渐变在暗色下向背景色混合，避免过亮。
- 卡片内描边用 `palette.cardBorder`；对比条渐变透明度暗色降到 8%。
- 指标格 `surfaceContainer` 在暗色下用 `surfaceContainer` token，不写死浅灰。
- 票据占位与虚线边框使用 `outlineVariant`。

### 8.12 无障碍

- 摘要卡 `Semantics(container: true, label: '${category}，$title，${amount}，${statusText}，$summaryTime')`。
- 指标逐项 `Semantics(label: '${label} ${value}${unit}')`，合并为一行朗读。
- 对比条 `Semantics(label: '${comparison.label} ${comparison.value}')`。
- 车辆行 `Semantics(button: vehicleBound, label: '车辆 $name，车牌 $plate，$odometerText')`。
- 票据格 `Semantics(button: true, label: '凭证 ${name}，${statusLabel}')`。
- 导航按钮 `Semantics(button: true, label: navigation.label)`。
- 焦点顺序：顶部栏 → 摘要 → 指标 → 车辆 / 对比 → 结算 → 标签 → 备注 → 票据 → 导航 → 底栏。
- 系统「减少动态效果」时移除缩放与淡入。

---

## 9. 交互与导航

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

- `_refresh` 复用现有下拉刷新逻辑，保持筛选与滚动位置。

### 9.2 分享

```dart
String buildExpenseShareText(ExpenseDetail detail) {
  final buffer = StringBuffer()
    ..writeln('车小记 · 开销详情')
    ..writeln('${detail.categoryText} · ${detail.titleText}')
    ..writeln(detail.heroAmountText)
    ..writeln('${detail.summaryTimeText} · ${detail.statusText}')
    ..write('车辆：${detail.vehicleName}（车牌已隐藏）');
  if (detail.hasNote) {
    final note = detail.noteText;
    buffer
      ..writeln()
      ..write('备注：${note.length > 80 ? '${note.substring(0, 80)}……' : note}');
  }
  return buffer.toString();
}
```

- 不包含支付尾号、商户完整地址、凭证链接。
- 失败 Toast；取消不提示。

### 9.3 删除

```
更多 → 删除此笔开销 → 确认
  → controller.delete()
      ├── 成功：invalidate 依赖 → pop(outcome.deleted) → 账单 Toast
      └── 失败：留在本页 → Toast
```

- 404 视为成功。
- 删除期间禁用底部按钮与顶部更多。

### 9.4 凭证预览与导航

- 凭证点击：先显示预览浮层骨架，再加载；失败在浮层内重试。
- 导航点击：调用 `MapLauncher`；返回 `false` 时回退高德 Web；仍失败 Toast。
- 两者都不修改记录数据。

### 9.5 编辑 / 再记一笔

- 当前仓库尚无记账页，统一点击 Toast「记账页待接入」。
- 预填契约：
  - 再记：`vehicleId = record.vehicleId`、`category = record.category`、`occurredAt = now`；
  - 编辑：整条 `record.id`。
- 记账页落地后替换回调，页面其余部分不改。

### 9.6 系统返回

- 浮层打开时先关闭浮层；删除提交中拦截返回；无浮层直接返回。

---

## 10. 性能

| 项 | 措施 |
| --- | --- |
| 首帧 | `initialRecord` 构造 `ExpenseDetail.fromRecord`，不等待网络 |
| 详情请求 | 120ms Mock / 生产 ≤ 800ms；`autoDispose.family` 避免重复请求 |
| 重建范围 | 页面拆成独立 Widget；备注 / 标签更新只重建对应卡片 |
| 指标格 | 固定 4 列，`Row` + `Expanded`，无滚动、无动画 |
| 票据 | 缩略图按需加载；原图只在预览时拉取；PDF 不预加载 |
| 图片 | `Image.network` 默认内存缓存；不写磁盘；离开页面释放 |
| 阴影 / 模糊 | 静态 `BoxShadow`；Hero 光斑单层模糊，不用 `BackdropFilter` |
| 长文本 | 备注折叠用 `TextPainter` 只算一次 |
| 内存 | 详情不落盘；凭证 bytes 仅预览期间持有 |

---

## 11. 错误与边界

| 场景 | 处理 |
| --- | --- |
| 详情 404 | 全页空态 + 返回；隐藏分享 / 更多 |
| 详情网络失败 | `SectionError` 重试；顶部返回可用 |
| 指标缺失 / 不足 4 条 | 按实际条数等宽；整条为空隐藏 |
| 对比缺失 | 隐藏对比条 |
| 商户缺失 | 隐藏商户行；导航仍可用坐标 / 链接 |
| 支付渠道缺失 | 显示「未记录」，无圆点 |
| 车辆解绑 / 删除 | 快照 + 「已解绑」，隐藏箭头 |
| 凭证 URL 过期 | 预览浮层提示 + 重试；重新拉详情可刷新签名 URL |
| 凭证超过 20MB | 拒绝预览，提示文件过大 |
| 无地图应用 | 回退浏览器；仍失败 Toast |
| 导航无目标 | 不渲染按钮 |
| 金额超长 | `FittedBox` 最小 28 号 |
| 备注超长 / 换行 | 200 字限制；折叠；分享截断 |
| 标签超限 / 重复 | `sanitizeTags`；UI 禁用 + 提示 |
| 删除时 404 | 视为成功 |
| 保存备注 409 | 提示「记录已更新，请重新进入」并刷新 |
| 保存备注 404 | 关闭浮层，Toast「记录已被删除」，返回账单刷新 |
| 连点保存 / 删除 | `_isMutating` + 按钮禁用 |
| 页面销毁后回调 | `mounted` + autoDispose |
| 系统字号放大 | 卡片增高；指标值 `FittedBox`；按钮不截断 |
| 深色切换 | 依赖 `Theme` 重建，无硬编码颜色 |

---

## 12. 测试方案

### 12.1 单元测试

| 文件 | 覆盖 |
| --- | --- |
| `expense_detail_presenter_test.dart` | 支出 / 退款金额、状态文案兜底、摘要 / 结算时间、分类展示名兜底、支付渠道拼接（有 / 无尾号）、双里程兜底、分享文本（隐藏车牌、截断备注） |
| `expense_detail_models_test.dart` | `ExpenseDetail.fromRecord`、`copyWith`、`sanitizeTags`、`normalizeNote`、`TelemetryTone` 解析、`ExpenseNavigation.hasTarget` |
| `mock_expense_detail_repository_test.dart` | 6 类 telemetry / comparison / merchant / navigation 生成；凭证数量；未找到抛异常；备注 / 标签更新；删除后取不到 |
| `voucher_loader_test.dart` | 200 返回 bytes；404 抛 `VoucherExpiredException`；超限拒绝 |
| `map_launcher_test.dart` | URL 优先；iOS / Android URI 生成；无坐标返回 null |
| `ledger_record_by_id_test.dart` | 跨月查找、缓存命中、删除过滤 |

### 12.2 Widget 测试

| 文件 | 覆盖 |
| --- | --- |
| `expense_detail_page_test.dart` | 有快照首帧、骨架、404 空态、网络错误重试、暗色 |
| `detail_hero_card_test.dart` | 支出 / 退款、超长金额、标题为空、徽标、核销标识、状态文案换行 |
| `detail_telemetry_grid_test.dart` | 4 条 / 3 条 / 0 条、tone 颜色、长值缩放 |
| `detail_vehicle_card_test.dart` | 双里程、缺一项、已解绑、对比条缺失 |
| `detail_settlement_card_test.dart` | 支付尾号、商户省略、权益文案、退款金额 |
| `detail_tags_note_card_test.dart` | 标签上限、空备注、长备注展开 / 收起、移除标签 |
| `detail_voucher_card_test.dart` | 2 个 + 补充、1 个、0 个、核验徽标、点击预览 |
| `detail_nav_button_test.dart` | 有坐标 / 链接 / 仅地址 / 无目标 |
| `note_editor_sheet_test.dart` | 计数、保存、失败保留、清空 |
| `delete_expense_sheet_test.dart` | 取消、确认、提交中禁用、404 成功 |
| `ledger_detail_navigation_test.dart` | 点击记录卡推入、删除返回刷新 |

- 通过 `ProviderScope(overrides: [...])` 注入 Fake 仓库 / Fake VoucherLoader / Fake MapLauncher，避免延时与平台通道。
- 深色 / 浅色各跑关键断言；golden 可选。

### 12.3 手工验收

1. 账单页 6 类记录分别进入详情，核对图标、徽标、指标、对比、导航文案。
2. 指标 4 / 3 / 0 条与长值；对比缺失。
3. 双里程的三种组合。
4. 票据 0 / 1 / 2 / 3 个；PDF 与图片预览；过期 URL。
5. 导航：坐标、外部链接、仅地址、无目标四种。
6. 备注 / 标签的保存、失败、清空、上限。
7. 删除：取消、确认、断网、404。
8. 分享内容与车牌 / 尾号隐藏。
9. 深色、字号 1.3、横屏滚动、返回手势。

### 12.4 CI

- PR 跑 `flutter analyze` + `flutter test`，既有用例不得回归。
- 新增测试全部使用 Fake，不依赖网络、地图、文件系统与平台通道。

---

## 13. 实施拆分

| 阶段 | 分支 | 内容 | 产出 |
| --- | --- | --- | --- |
| M0 数据与模型 | `feat/expense-detail-data` | `ExpenseDetail` + 子模型 / presenter / 格式化 / 仓库 / Mock / `recordById` / 单元测试 | 数据层可测 |
| M1 静态页面 | `feat/expense-detail-ui` | 页面骨架、顶部栏、摘要 + 指标、车辆 + 对比、结算、标签、票据、导航、底部栏；账单卡接入 | 设计稿还原 |
| M2 交互闭环 | `feat/expense-detail-actions` | 备注 / 标签浮层、更多、分享、复制、删除、票据预览、导航调起、返回结果刷新 | 交互可用 |
| M3 状态与打磨 | `feat/expense-detail-polish` | 骨架、错误、404、缺失模块、深色、无障碍、长文本、性能、Widget 测试、文档回填 | 达到验收清单 |
| M4（P1） | `feat/expense-detail-voucher` | 凭证上传 / 删除、OCR / 验真、分享长图、首页入口 | 按需排期 |

每个阶段保持 `flutter analyze` / `flutter test` 通过后合入功能分支，按仓库规范通过 PR 合并到 `main`。

---

## 14. 风险与待确认

| 风险 | 影响 | 应对 |
| --- | --- | --- |
| 详情接口字段多且未确认（telemetry / comparison / vouchers / navigation） | 模型返工 | 全部可空；Mock 先跑通；按需求 §8 推进 |
| 「单笔核销」「已核验」「权益减免」缺少真实业务数据 | 虚假背书 | 仅在后端返回时展示；缺失隐藏或中性文案 |
| 指标由后端下发，客户端不做校验 | 后端错误直接可见 | 客户端跳过空项；加数据质量埋点 |
| 凭证签名 URL 过期 / 存储权限 | 预览失败 | 过期提示 + 重拉详情；P1 上传方案单独评审 |
| PDF 预览内存与包体 | 大文件卡顿 | 20MB 上限；按需加载；预览关闭释放 |
| `url_launcher` 平台差异 | 地图打不开 | 三级回退：坐标 → 高德 Web → Toast |
| 设计稿分类胶囊被误实现 | 交互返工 | 文档明确为原型控件；评审确认 |
| 分类占位色与项目语义色冲突（保养蓝 vs 琥珀） | 视觉不一致 | 统一用 `AppColors`；设计走查确认 |
| 状态文案过长 | 摘要行换行 | `Wrap` + 两行；必要时缩小字号 |
| 备注影响账单列表副标题 | 列表数据过期 | 保存备注后失效 `ledgerRecordsProvider` |
| 删除后首页 / 报表未刷新 | 跨页不一致 | 删除统一失效首页与报表 provider |
| 记账 / 编辑页未上线 | 底部按钮像死路 | Toast 明确「待接入」；接线只改回调 |
| 退款记录的指标 / 票据口径 | 展示矛盾 | 后端返回什么展示什么；状态与符号优先 |
| 首页入口缺 id | 入口不完整 | P1 补 `RecordItem.id` 后再接 |
| 深色稿缺失 | 视觉偏差 | 按 token 推导；设计提供后复核 |

待确认（与需求文档 §13 同步）：

1. `telemetry` / `comparison` 由后端计算并下发，客户端不推导。
2. 票据上传的存储、鉴权、大小限制与验真来源。
3. 导航使用 `geo:` / Apple Maps / 高德的优先级与回退。
4. 「已核验」「权益减免」是否真实存在，缺失时是否隐藏。
5. 退款记录的指标、对比、票据如何返回。
6. 备注上限 200 字、标签上限 8 个是否满足。
7. 删除是否需要撤销。
8. 深色设计稿时间点。
9. 编辑 / 再记一笔的记账页路由与预填参数。
10. 设计稿分类胶囊是否确认不进入产品。

---

## 15. 附录：需求 → 实现映射

| 需求 | 实现 |
| --- | --- |
| §6.1 顶部栏 | `detail_header.dart` + `BlurredHeaderDelegate` |
| §6.2 摘要卡 | `detail_hero_card.dart` + `ExpenseDetailPresentation` |
| §6.2 指标格 | `detail_telemetry_grid.dart` + `ExpenseTelemetry` |
| §6.3 车辆 / 对比 | `detail_vehicle_card.dart` + `detail_comparison_banner.dart` |
| §6.4 结算明细 | `detail_settlement_card.dart` + `ExpensePayment` / `ExpenseMerchant` |
| §6.5 标签 / 备注 | `detail_tags_note_card.dart` + `ExpenseDetailRules` |
| §6.6 票据凭证 | `detail_voucher_card.dart` + `VoucherLoader` + `VoucherPreviewSheet` |
| §6.7 导航 | `detail_nav_button.dart` + `MapLauncher` |
| §6.8 底部操作栏 | `detail_bottom_bar.dart` |
| §6.9 分享 / 删除 / 浮层 | `detail_more_sheet.dart`、`delete_expense_sheet.dart`、`note_editor_sheet.dart`、`tag_editor_sheet.dart` |
| §7 数据口径 | `expense_detail_presenter.dart`、`formatters.dart`、`category_style.dart` |
| §8 接口契约 | `ExpenseDetailRepository` + `HttpExpenseDetailRepository`（P1） |
| §9 异常 | `ExpenseDetailException` + §11 表格 |
| §10 非功能 | §8.11 / §8.12 / §10 |
| §12 验收 | §12 测试 + 手工验收 |
