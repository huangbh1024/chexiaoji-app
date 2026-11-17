# 车小记（chexiaoji_app）全项目数据一致性审查报告

- 审查日期：2026-11-16
- 代码基线：`main` @ `dcf7074`（Merge PR #36）
- 审查范围：`lib/` 下 248 个 Dart 文件（约 4.2 万行）的 domain / data / provider 层，重点是**页面之间的数据来源、字段映射与聚合口径**
- 审查方式：静态阅读代码；修复完成后用本地 Flutter 3.50.0 执行 `flutter analyze`（无问题）与 `flutter test`（321 项通过）
- 不涉及：视觉还原、动画、性能、CI 配置

---

## 修复状态（2026-11-17 本次 PR）

> 下列条目已在本次 PR 修复并验证：`flutter analyze` 无问题，`flutter test` 338 项全部通过。
>
> 配套接口契约见 [docs/technical/api-contract.md](../technical/api-contract.md)。

| 编号 | 状态 | 处理 |
| --- | --- | --- |
| H1 首页看板静态数据 | ✅ 已修复 | `MockHomeRepository` 重写：Hero / 能耗 / 保养 / 构成 / 趋势全部从 `MockLedgerRepository` 聚合 |
| H2 趋势日期硬编码 | ✅ 已修复 | 趋势窗口改为基于当前时间动态生成 |
| H3 跨月编辑数据错位 | ✅ 已修复 | `_recordsFor` 按 override 的 `occurredAt` 重新分桶；汇总 / 列表增加月份过滤 |
| H4 36 / 24 个月窗口 | ✅ 已修复 | 账本查找、累计统计、记账日期下限统一为 `ledgerHistoryMonths = 36` |
| H5 里程读数随机 | ✅ 已修复 | 以当前里程为锚点按日均里程倒推，读数随时间单调；保养流水补里程读数 |
| H6 编辑支付方式取错字段 | ✅ 已修复 | 改用 `metrics.paymentMethod`，`statusText` 不再参与支付方式 |
| H7 详情页伪造支付 / 备注 / 标签 | ✅ 已修复 | 支付取记录字段；用户手动记账不再补默认备注与标签（演示流水保留示例内容） |
| H8 归档车能耗 0.0 | ✅ 已修复 | 无读数返回 `null`；历史平均改由全周期账本统计计算 |
| M1 重复「其他」 | ✅ 已修复 | 抽出公共 `buildCategoryBreakdown`，合并时复用同一个 other 切片 |
| M2 退款口径 | ⚠️ 待定 | 当前无退款入口；规则已写入 API 契约（§1.5、§6.1），接入退款时统一 |
| M3 种子数据 | ◐ 部分修复 | 凯美瑞默认油号改为 92；新能源车牌格式与绿牌推断仍保持原状（改动会影响较多历史测试，需单独评审） |
| M4 停车锚点时间 | ✅ 已修复 | 离场时间按 `occurredAt + 210min` 计算 |
| M5 保养当前里程未取 max | ✅ 已修复 | `max(最近流水读数, 车辆表显里程)` |
| M6 缓存失效不完整 | ✅ 已修复 | 抽出 `invalidateLedgerDependents`，新增 / 编辑 / 删除流水统一失效账单、首页、统计、报表、我的、车库 |
| M7 环比阈值不一致 | ✅ 已修复 | 报表改用公共 `compareTotals` |
| M8 首页百分比 99% | ✅ 已修复 | 百分比改为动态最大余数法 |
| 死字段 / shortName / 徽标重写 | ⏳ 未处理 | 不影响当前数据链路，保留给后续清理 |

新增回归测试：

- `test/home/home_ledger_consistency_test.dart`：首页 ↔ 账单 ↔ 统计 ↔ 月报 ↔ 我的 ↔ 车辆管理同月一致；新增流水后首页同步增加。
- `test/ledger/mock_ledger_repository_cross_month_test.dart`：跨月编辑后月份迁移、总额 = 日柱之和、统计窗口可查。
- `test/stats/stats_aggregation_test.dart`：7 类且「其他」靠前时只出现一个「其他」。
- `test/expense_detail/mock_expense_detail_repository_test.dart`：支付方式取记录字段；手动记账不补演示备注 / 标签。
- `test/vehicles/mock_vehicle_repository_test.dart`：归档无能耗时返回 `null`。

---

## 0. 结论先说：各页面的数据能串联起来吗？

**部分能。**

目前是「一条链路通 + 三块数据独立」：

| 链路 | 数据来源 | 是否互相对得上 |
| --- | --- | --- |
| 账单页 ↔ 统计页 ↔ 月度报表 ↔ 我的页「本月能耗」 | 同一个 `MockLedgerRepository` 生成的流水 | ✅ 基本一致（有 1 个跨月编辑的例外，见 H3） |
| 首页 Hero / 构成 / 趋势 / 能耗 / 保养 | `MockHomeRepository._cars` 里写死的演示值 | ❌ 与账单、统计、报表全部对不上 |
| 车辆管理页「本月支出」「车队总开销」 | 首页 dashboard 的静态 `monthSpendCents` | ❌ 与账单对不上；新建车辆恒为 ¥0 |
| 我的页「累计能耗 ¥x/km」 | 首页 dashboard 的静态 `energyCostPerKm` | ❌ 与统计页能耗、报表每公里成本对不上 |

举个最直观的例子：比亚迪 汉 EV 的首页写死「本月支出 ¥1,286 / 本月里程 2,140 km / 每公里 ¥0.60 / 平均能耗 14.8 kWh/100km」，而账单页、统计页、报表页的本月数字是从生成流水实时聚合的，二者没有任何关联。用户从首页点进账单，金额必然不同。

> 这不是「视觉上差不多」的问题，而是**同一指标在不同页面由两套数据源分别计算**。上线接后端时，首页需要单独一个聚合接口（技术文档里也是这么设计的），但当前 Mock 阶段没有做这层贯通。

---

## 1. 页面数据来源地图（实测代码）

| 页面 / 指标 | 数据来源 | 代码位置 | 与账单一致 |
| --- | --- | --- | --- |
| 首页 · 本月支出/本月里程/每公里成本 | 写死的 `_CarMock.summary` | `mock_home_repository.dart:247`、`:381`、`:505`、`:631` | ❌ |
| 首页 · 能耗（kWh/100km） | 写死的 `Consumption` | 同上 | ❌（统计页按流水重算） |
| 首页 · 保养剩余 | 写死的 `Maintenance`（有 `nextMaintenanceKm` 时才重算） | `mock_home_repository.dart:260` | ❌ |
| 首页 · 分类构成 | 写死的 `Breakdown` | `mock_home_repository.dart:265` | ❌ |
| 首页 · 花费趋势 | 写死的权重 + **硬编码 2026-06 日期** | `mock_home_repository.dart:762-830` | ❌ |
| 首页 · 最近记录 | 账单流水 | `mock_home_repository.dart:91-113` | ✅ |
| 账单页 · 月度汇总/日柱 | `MockLedgerRepository` 流水 | `mock_ledger_repository.dart:22-100` | ✅（基准） |
| 账单页 · 列表 | 同上 | `mock_ledger_repository.dart:103-166` | ✅ |
| 统计页 · 总览/构成/趋势/最近 | 同上（`recordsBetween`） | `stats_aggregation.dart` | ✅ |
| 月度报表 · 全部指标 | 同上（`fetchRecords`） | `report_aggregation.dart` | ✅ |
| 我的页 · 本月能耗金额 | 同上 | `garage_aggregation.dart:52-95` | ✅ |
| 我的页 · 每公里能耗 | 首页 dashboard 静态值 | `mock_profile_repository.dart:59,72` | ❌ |
| 车辆管理 · 本月支出/车队总开销 | 首页 dashboard 静态值 | `mock_vehicle_repository.dart:73` | ❌ |
| 车辆管理 · 流水笔数 | 账单统计 | `mock_vehicle_repository.dart:70` | ✅ |
| 归档页 · 累计花费/笔数 | 账单统计（24 个月窗口） | `mock_ledger_repository.dart:171-196` | ⚠️ 窗口限制见 H4 |

---

## 2. 高优先级问题（会直接看到「数据对不上」）

### H1. 首页看板整体是演示数据，不随记账变化

- `mock_home_repository.dart:236-367`（汉 EV）、`:368-491`（凯美瑞）、`:492-617`（宋PLUS）、`:618-755`（宝马）
- `fetchDashboard` / `fetchBreakdown` / `fetchTrend` 只在车辆 id 命中 `_cars` 时返回写死数据；只有 `fetchRecords` 走了账单。
- 影响：
  1. 任意新增/删除流水后，首页 Hero、构成、趋势、能耗**不变**；
  2. 首页「本月支出」与账单页「本月总额」、报表「总开销」、统计「本月总开销」是四个不同的数；
  3. 用户新建的车辆不在 `_cars` 里，首页只有「最近记录」是真的，Hero/构成/能耗/趋势全是 0（`_emptyDashboard`）。

**建议**：Mock 阶段让 `MockHomeRepository` 复用 `stats_aggregation.dart` 的 `totalCentsOf` / `distanceOf` / `consumptionOf` / `buildStatsBreakdown`，按「本月 + 该车」从账单聚合，首页数字自然和账单一致；或者至少在首页标注「演示数据」，避免验收时被当成 bug 反复排查。

### H2. 首页趋势图的日期是硬编码的 2026 年 6 月

- `mock_home_repository.dart:769` 30 天：`DateTime(2026, 6, 1 + i)`
- `:783` 7 天：`DateTime(2026, 6, 24 + i)`
- `:797` 半年：`2026-01-28 ... 2026-06-28`
- `:811` 1 年：`2025-07-28 ... 2026-06-28`

首页趋势卡的 X 轴直接取 `TrendPoint.date`（`trend_card.dart:327,414-418`），所以今天（2026-11-16）打开首页，选择「30天」看到的刻度是 `6/1 … 6/30`，而不是 `10/18 … 11/16`。这不是时区或格式问题，是数据本身写死了。

**建议**：`_buildTrend` 的 `dates` 改为基于 `DateTime.now()` 倒推；如果想保留设计稿曲线形状，可以保留权重，只改日期。

### H3. 编辑已有流水、把发生时间改到别的月份后，账单与统计/报表互相矛盾

这是本次审查发现的最隐蔽、也最像「账对不上」的问题。

- 编辑保存走 `MockExpenseEntryRepository.updateExpense` → `ledger.updateRecord`
  （`mock_expense_entry_repository.dart:105-119`）
- 生成出来的流水用 `_overrides[id]` 覆盖，**覆盖项仍挂在其原始月份**：
  `mock_ledger_repository.dart:383-404`（`_recordsFor` 只按「该月生成的基础记录 + overrides」合并，不再按 `occurredAt` 归档）
- 而 `fetchSummary`（`:22-30`）与 `fetchRecords`（`:108-119`）**都没有按 `occurredAt` 过滤月份**

后果，以「把 11 月的一条流水改到 10 月」为例：

| 页面 / 指标 | 表现 |
| --- | --- |
| 11 月账单列表 | 仍然显示这条流水（日期是 10 月） |
| 11 月账单汇总 | 总额包含它 |
| 11 月日柱状图 | 不包含它（`isSameDay` 过滤）→ **总额 ≠ 日柱之和** |
| 10 月账单列表 | 不显示它 |
| 统计页（任意周期） | 完全看不到它（`recordsBetween` 按 `occurredAt` 过滤，两边都排除） |
| 月度报表 | 10 月报表总额不含它；11 月报表总额含它但日走势不含它 |
| 我的页本月能耗 | 不含它（`aggregateMonthEnergy` 按月份过滤） |
| 首页最近记录 | 查询的是 11 月，却展示一条 10 月日期的记录 |

对照组：手动新增的流水（`_manualRecords`）在 `_recordsFor` 里是按 `occurredAt` 重新分桶的，所以**只有编辑「生成流水」时才会踩到**。

**建议**：`_recordsFor` 合并时按 `overrides` 的 `occurredAt` 重新分桶（或 `updateRecord` 时同步迁移）；`fetchSummary` / `fetchRecords` 增加 `occurredAt` 月份过滤，双保险。

### H4. 「能翻到的月份」和「能查到的记录」范围不一致（36 个月 vs 24 个月）

- 账单月份选择器给最近 **3 年**：`ledger_month_picker_sheet.dart:38-40`（`now.year - offset`，`offset < 3`）
- 但 `recordById` 只回扫 **24 个月**：`mock_ledger_repository.dart:232-249`
- 累计类统计同样只算 24 个月：`countRecords`（`:219-229`）、`fetchVehicleStats`（`:171-196`）、`fetchLifetimeStats`（`:154-169`）、`firstRecordAt`（`:277-300`）

以今天 2026-11 为例，月份选择器可以选到 2024-01，而 `_generate` 对**任意月份**都会生成数据（没有 24 个月限制），于是：

1. 2024-01 ~ 2024-11 的账单列表有数据，点进任何一条详情都会提示「记录不存在或已被删除」（`MockExpenseDetailRepository.fetchDetail` → `recordById` 返回 null）；
2. 这些月份的数据不计入「累计记账」「归档累计花费」「统计-全部」；
3. 但月度报表切到 2024-06 时又能正常展示这些流水 → 报表总额与统计口径不一致。

另外，记账页发生时间允许选到 **2000 年**（`entry_meta_card.dart:229`、`expense_entry_validation.dart:65`），但月份选择器最多回看 3 年。用户在 2023 年补记一笔后，**账单页没有任何入口能看到它**，累计统计也不算 —— 从用户视角就是「存了但丢了」。

**建议**：统一窗口常量（例如都按 36 个月，或都按 24 个月）；`recordById` 至少覆盖月份选择器的范围；记账页的 `firstDate` 与账本可回看范围保持一致。

### H5. 记账 Mock 的里程表读数随机生成、不随时间单调递增

- 充电记录：`odometerKm: vehicle.odometerKm - id.hashCode.abs() % 4000`
  （`mock_ledger_repository.dart:710`）
- 加油记录：`odometerKm: vehicle.odometerKm - time.day * 37`
  （`:738`）

也就是说，**每条记录的里程读数都是以「当前表显里程」为基准随机减一个数**，23 个月前的记录可能显示 18,000 km，昨天的记录可能显示 15,000 km。带来的连锁反应：

- `computeDistance`（`core/domain/distance.dart:29-88`）的「同一辆车取 max−min 读数」会得到任意值（0~4000 km），很少等于真实月行驶里程；
- 统计页「本月行驶」、报表「行驶里程」、每公里成本、百公里能耗都建立在这个里程上；
- `latestOdometerRecord` 按发生时间取最新一条，读数可能低于车辆当前里程，导致录入页基线、首页保养进度被低估（见 M5）。

**建议**：生成时按「车辆当前里程 − 时间衰减」构造单调递增序列（越早的月份读数越小），或直接把读数从生成流水里去掉、只依赖 `distanceKm`，避免两种口径混用。

### H6. 编辑流水时支付方式取错字段（停车记录会显示「19:45 离场」）

- `mock_expense_entry_repository.dart:84-85`：

```dart
paymentChannel: _channelFromLabel(record.statusText),
paymentLabel: record.statusText ?? '微信支付',
```

`statusText` 在账单里是「右侧辅助文案」，和支付方式不是一回事：

| 记录类型 | `statusText` 实际值 | 编辑页显示的支付方式 |
| --- | --- | --- |
| 停车（锚点） | `19:45 离场` | **19:45 离场** |
| 停车（生成） | `21:15 离场` | **21:15 离场** |
| 过路费 | `粤通卡ETC` | 粤通卡ETC |
| 充电/加油 | `null` | 微信支付（但真实 `metrics.paymentMethod` 是「微信」/「云闪付」） |

而记账页直接展示 `draft.paymentLabel`（`entry_meta_card.dart:79`），用户会看到支付方式是「19:45 离场」。之后不改支付方式直接保存，这条记录写回的 `statusText` / `metrics.paymentMethod` 都会变成「19:45 离场」。

**建议**：`fetchDraft` 用 `record.metrics.paymentMethod` 反查渠道与展示名（该字段本来就是为这个准备的），`statusText` 不要参与支付方式。

### H7. 详情页的支付方式、备注、标签是按分类写死的，会和记账输入不一致

- 支付方式：`mock_expense_detail_repository.dart:71,91-122`（`_paymentFor(record.category)`）
  → 记账时选「现金」的充电记录，详情页仍显示「微信支付」。
- 备注：`:75,136-...`。若记录没有备注，会用 `_defaultNote(category)` 填一段**用户从未写过的演示备注**（燃油固定文案还写着「95# 汽油」）。
- 标签：`:72,124-134`，同样按分类塞默认标签。

新记一笔账、备注留空，打开详情页会看到「周末出省自驾前加满一箱 95# 汽油……」这类不存在的备注，属于**伪造用户数据**，比显示空更糟。

**建议**：支付方式改用 `record.metrics.paymentMethod`；备注/标签为空就展示空态，默认演示文案只能存在于纯演示数据里。

### H8. 归档车辆无能耗读数时显示 0.0，而不是「未录入」

- `mock_vehicle_repository.dart:109-112`：直接把 `dashboard.consumption.primary` 作为 `averageConsumption`，不看 `Consumption.hasData`
- 新建车辆没有流水时 `_emptyDashboard` 返回 `primary.value = 0, hasData = false`（`mock_home_repository.dart:173-199`）
- 归档卡 `ArchivedVehiclePresenter.metricsOf`（`vehicle_presenter.dart:246-266`）见非 null 就渲染 `0.0 kWh/百公里`

需求文档明确写了「缺失数据显示「—」，**不得填 0 或伪造演示值**」（`docs/requirements/archived-vehicles.md:305`）。这里违反了。

**建议**：`hasData == false` 时传 null。

---

## 3. 中优先级问题（口径 / 边界）

### M1. 统计「开销构成」可能生成两个「其他」分类

`stats_aggregation.dart:169-206`：

1. 分类数 > 6 时先保留前 5 类，把剩余合并成一个 `ExpenseCategory.other` 切片；
2. 若原始 `other` 本身就在前 5 类里，此时列表里已经有**两个 other**；
3. 后面「<2% 并入其他」时 `small` 明确排除了 `other`，再 `add` 一个新的 other → 可能出现 **2~3 个「其他」行**。

Mock 每月都由 `_ensureAllCategories` 保证 7 类齐全（`mock_ledger_repository.dart:447-...`），选择「全部车辆 + 全部」时触发概率不低。现有单测 `test/stats/stats_aggregation_test.dart:165` 只覆盖了 other 金额最小的场景，没覆盖 other 位于前 5 的场景。

**建议**：合并前先检查 `entries` 中是否已有 other，有就加到已有的那个上。

### M2. 退款口径：统计构成与总额、报表构成不一致

- `totalCentsOf`（`stats_aggregation.dart:14`）包含负数退款；
- `buildStatsBreakdown`（`:143-215`）的分组合计**跳过** `amountCents <= 0`；
- 报表 `buildCategoryGroups`（`report_aggregation.dart:145-177`）则把负数计入分组。

目前 App 内没有创建退款的入口，Mock 也不会生成负数，所以暂时看不到；一旦接入退款（`LedgerRecord` 注释、`formatSignedYuan`、详情页「已退款」都已支持），统计页会出现「分类合计 ≠ 总额」，报表与统计页也会给出不同的构成和百分比。建议现在就统一规则（要么都含退款，要么都把退款单列）。

### M3. 种子数据自相矛盾

1. **油号**：凯美瑞 `specLabel: '2.5L 豪华版 · 92号汽油'`，但 `defaultFuelGrade: 95`
   （`vehicle_seed_data.dart:40-42`）；Mock 生成的加油流水标题是随机的 92#/95#/98#（`mock_ledger_repository.dart:731`），与该车默认油号无关。记账页默认油号也会是 95，和配置名、流水都不一致。
2. **车牌格式**：汉 EV `粤B·D82K6`、宋PLUS `粤B·9X521` 都是 7 位蓝牌格式；而编辑器要求新能源车牌是「城市字母 + 6 位」（共 8 位）
   （`vehicle_editor_presenter.dart:62,169-176`）。
3. 由此带来一个实际故障：编辑这两辆车时，`draftOf` 用「车身长度 ≥ 7 位」推断 `isGreenPlate`
   （`vehicle_editor_presenter.dart:278`），会把它们当成蓝牌；一旦用户切换动力类型（`setPowertrain` 按动力类型设置 `isGreenPlate`，`vehicle_editor_providers.dart:219`），车牌校验必然失败，除非重填一个 8 位车牌。

**建议**：种子数据改成真实绿牌格式（如 `粤B·D82K6` → `粤B·D82K66` 形式）；`isGreenPlate` 的初始值优先取动力类型（EV/PHEV → 绿牌），长度只作为兜底。

### M4. 停车锚点的「离场时间」与时长不一致

`mock_ledger_repository.dart:498-518`：停车时间 16:45，`durationMinutes: 210`（3.5 小时），但文案是

```dart
statusText: '${(parkingTime.hour + 3) % 24}:45 离场'
```

16:45 + 210 分钟 = 20:15，文案写 19:45；而且 `(hour + 3) % 24` 在跨午夜时会回绕成「00:45 离场」。生成流水的停车记录是对的（`time.add(Duration(minutes: duration))`，`:625-631`），只有这个锚点写错了。

### M5. 首页保养覆盖没有取「当前里程」的最大值

`mock_home_repository.dart:138-171`：

```dart
final current = odometerResolver?.call(record.id) ?? record.vehicle.odometerKm;
```

`odometerResolver` 是「最新一条流水的读数」，而 H5 的生成方式让这个读数经常**小于**车辆真实表显里程。首页 Hero 的 `_withOdometer`（`:46-62`）用 `max(latest, vehicle.odometerKm)`，这里没有，导致同一页面的「当前里程」和「保养剩余里程」基于两个不同的当前值。建议 `current = max(latest, vehicle.odometerKm)`。

### M6. 写操作后的缓存失效不完整

**新增/编辑流水**：`expense_entry/domain/providers.dart:741-756` 失效了 13 个 provider，但漏了：

- `profileGarageProvider`：我的页车库卡「本月能耗」不会更新（`ProfilePage` 在 `IndexedStack` 里常驻，autoDispose 不会被回收）；
- `garageProvider`：车辆管理页「本月支出」/「车队总开销」不会更新（且该 provider 不是 autoDispose，会一直缓存旧值）。

**删除流水**：`expense_detail/domain/providers.dart:116-125` 只失效账单、首页、报表，漏了：

- `statsOverview/Breakdown/Recent/Trend`：从账单页删除后切到统计 Tab，统计仍是删除前的数字；
- `profileOverviewProvider`：我的页「累计记录/记账天数」不变；
- `profileGarageProvider` / `garageProvider`。

从「统计页最近记录」或「首页最近记录」进入详情时，各自会在返回后补失效一部分；但**从账单页进入详情**不会，这是最容易复现的路径。

**建议**：把失效清单收敛到一处（vehicle 侧已经有 `VehicleScopeInvalidator`，流水侧同样应该有一个 `LedgerScopeInvalidator`），避免新增页面时再漏。

### M7. 环比「持平」的阈值在统计与报表里不一致

- 统计：`compareTotals` 把 `|percent| < 0.05` 视为持平（`stats_aggregation.dart:90-102`）
- 报表：`trendFor` 只有完全相等才算持平（`report_aggregation.dart:292-306`）

同一个月、同一辆车，统计显示「持平」、报表显示「↑ 0.0%」是可能的。建议统一。

### M8. 首页汉 EV 的分类百分比合计 99%

`mock_home_repository.dart:265-300`：30+37+13+10+7+2 = 99。若构成卡的环形图或进度条用百分比合计做校验，会出现 1% 缺口。统计页/报表用了最大余数法保证 100（`largestRemainder`），首页这组写死数据没有。

---

## 4. 低优先级 / 字段完整性（不影响当前功能，但属于「字段不完整/死字段」）

| 字段 | 位置 | 说明 |
| --- | --- | --- |
| `ReportVehicleBrief.shortName` | `report_aggregation.dart:83` | 赋值为 `vehicle.name`（全名），语义错误；且该字段在报表 UI/CSV/PDF 中**完全没被读取** |
| `StatsSummary.distanceSource` / `MonthlyReport.distanceSource` | 模型定义 | 计算了但 UI 从未展示，也没有「按读数/按单笔」的说明 |
| `ExpenseEntryDefaults.lastCategory` | `mock_expense_entry_repository.dart:46` | 赋值后无人读取 |
| `HomeRepository.defaultVehicleId` | `home_repository.dart:6` | 接口 + Mock 实现了，但无人调用 |
| `OdometerBaseline.recordedAt` | `expense_entry_models.dart:329` | 赋值后无人读取 |
| `ExpenseEntryDraft.toJson` / `EntryCategoryDetail.toJson` | 各模型 | 目前无调用方（为接后端预留可以保留） |
| `monthStart` | `ledger_models.dart:386` 与 `report_models.dart:308` 各定义一份 | 重复函数，建议收敛到 `core` |
| `formatYuanCompact/OneDecimal/...` | `formatters.dart` | `formatKm` 等用法正常；未发现格式化不一致 |

另外两个小观察：

- `MockVehicleRepository._badgeOf`（`mock_vehicle_repository.dart:358-366`）只要车辆有 `defaultFuelGrade` 就把徽标改成「X号汽油」。编辑凯美瑞/宋PLUS 后，首页车辆卡徽标会从「油电双模」「绿牌插混」变成「95号汽油」「92号汽油」——保存一次没改过的字段，徽标却被重写。
- `VehicleStore.add` 不复制 `batteryHealthPercent`（`vehicle_store.dart:182-207`），新建车 SOH 为 null；这是合理的（新车无 SOH），但要注意从归档恢复走的是 `restore`，不受影响。

---

## 5. 已经做得不错、建议保持的部分

1. **流水是账单/统计/报表/我的-本月能耗的唯一来源**，聚合函数集中（`computeDistance`、`totalCentsOf`、`consumptionOf`），没有各页面各写一套公式。
2. 车辆选择器（首页、账单、统计、报表、记账、我的）**全部读同一个 `vehiclesProvider`（store.active）**，归档车辆在所有入口同时消失，没有「某页还能选到归档车」的问题。
3. 归档/恢复/彻底删除后走 `VehicleScopeInvalidator.normalizeScopes`（`vehicles/domain/providers.dart:64-89`），会把账单/统计/我的的车筛选从被删车辆上挪走，避免筛选到不存在的车。
4. 彻底删除按需求「档案销毁 + 流水保留」实现，详情页通过 `vehicleExists` 判断「已解绑」（`expense_detail/domain/providers.dart:17-25`），与文档一致。
5. 报表单号用 FNV-1a（`report_aggregation.dart:308-324`），跨平台稳定；CSV 有 BOM、RFC 4180 转义和公式注入防护（`report_csv_builder.dart:3-9,91-104`）。
6. 百分比用最大余数法保证合计 100（统计/报表），比简单四舍五入稳。

---

## 6. 建议修复顺序

| 顺序 | 事项 | 理由 |
| --- | --- | --- |
| 1 | H3 跨月编辑（`_recordsFor` 重新分桶 + 月份过滤） | 直接造成账单总额≠日柱之和、账单≠统计，是最像「账错了」的问题 |
| 2 | H6 + H7 支付方式/备注/标签字段串错 | 用户能直接看到「19:45 离场」当支付方式，且会写回数据 |
| 3 | H1 + H2 首页改用流水聚合、趋势日期改为动态 | 解决「跨页数字对不上」的根因；改动集中在 `mock_home_repository` |
| 4 | H4 统一 24/36 个月窗口 | 避免「列表有、详情打不开」和补记流水丢失 |
| 5 | H5 里程读数单调化 | 让统计/报表的里程与每公里成本可信 |
| 6 | H8、M1、M2 | 边界与口径修正 |
| 7 | M3 种子数据、M4 文案、M5 取 max | 演示数据自洽 |
| 8 | M6 收敛失效清单 | 防止后续新增页面继续漏 |
| 9 | M7、M8、第 4 节死字段 | 收尾 |

每项都可独立提 PR；建议按上面的顺序做，前 2 项改完后「同一笔流水在各页面数字一致」的体验会立刻正确。

---

## 7. 验证情况与未覆盖部分

- 修复完成后已用本地 Flutter 3.50.0（与 CI 一致）执行 `flutter analyze`（无问题）与 `flutter test`（338 项通过）。
- 未执行 `flutter build apk`，也未在真机 / 模拟器上走完整交互；Widget 测试覆盖了首页、账单、统计、记账、详情、车库与归档页。
- 未覆盖 `report_pdf_builder.dart` / `report_paper_preview.dart` 的排版细节（只核对了取数来源）。
- 未覆盖深色主题、动画、无障碍（非本次目标）。

## 8. 复现与自查建议（给后续接手的人）

1. **H3**：账单页选本月 → 打开任意一条记录 → 编辑 → 把发生时间改到上个月 → 保存；回到账单页观察总额与日柱，再切统计/报表对比。
2. **H4**：账单页月份胶囊选到两年前 1 月 → 打开任意记录 → 观察「记录不存在或已被删除」。
3. **H6**：账单页找到一条停车记录 → 编辑 → 看支付方式是不是「xx:xx 离场」。
4. **H1**：记一笔 100 元 → 首页 Hero 金额不变；账单页总额 +100。
5. **M1**：统计页选「全部车辆 + 全部」，观察构成卡是否出现两个「其他」。
6. **H8**：新建一辆车 → 记一笔 → 归档 → 在已归档页看「历史平均电耗/油耗」是否为 `0.0` 而不是 `—`。
7. **M6**：账单页删一条记录 → 直接切统计 Tab（不刷新）→ 观察总额是否仍包含已删除流水。

---

*报告随本次 PR 提交。*
