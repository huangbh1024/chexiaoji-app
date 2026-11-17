# 车小记 · 客户端接口契约（v1）

> 状态：草案，供后端评审；客户端当前由 `Mock*Repository` 实现。
>
> 目标：**同一笔流水在首页、账单、统计、月度报表与「我的」页必须得到同一组数字。**
> 因此本契约把「聚合口径」写进接口，而不是让各页面各自请求原始数据再本地计算。

---

## 0. 页面 → 接口映射

| 页面 / 模块 | 客户端仓库 | 主要接口 |
| --- | --- | --- |
| 首页 · 车辆切换 | `HomeRepository.fetchVehicles` | `GET /vehicles` |
| 首页 · Hero / 能耗 / 保养 | `HomeRepository.fetchDashboard` | `GET /home/dashboard` |
| 首页 · 分类构成 | `HomeRepository.fetchBreakdown` | `GET /home/breakdown` |
| 首页 · 最近记录 | `HomeRepository.fetchRecords` | `GET /home/records` |
| 首页 · 花费趋势 | `HomeRepository.fetchTrend` | `GET /home/trend` |
| 账单页 · 汇总 / 日柱 | `LedgerRepository.fetchSummary` | `GET /ledger/summary` |
| 账单页 · 流水列表 | `LedgerRepository.fetchRecords` | `GET /expenses` |
| 记账页 · 默认值 / 基线 | `ExpenseEntryRepository.fetchDefaults` / `fetchOdometerBaseline` | `GET /expenses/defaults`、`GET /ledger/odometer-baseline` |
| 记账页 · 保存 | `createExpense` / `updateExpense` | `POST /expenses`、`PUT /expenses/{id}` |
| 详情页 · 单笔 | `ExpenseDetailRepository.fetchDetail` | `GET /expenses/{id}` |
| 详情页 · 备注 / 标签 / 删除 | `updateNote` / `updateTags` / `deleteExpense` | `PATCH /expenses/{id}/note`、`PUT /expenses/{id}/tags`、`DELETE /expenses/{id}` |
| 统计页 | `StatsRepository` | `GET /stats/overview`、`/breakdown`、`/trend`、`/recent` |
| 月度报表 | `ReportRepository.fetchReport` / `fetchAllRecords` | `GET /reports/monthly`、`GET /reports/monthly/records` |
| 车辆管理 / 归档页 | `VehicleRepository` | `GET /garage/overview`、`GET /vehicles/archived`、`POST /vehicles/{id}/*` |
| 我的页 · 资料 | `ProfileRepository.fetchOverview` | `GET /profile/overview` |
| 我的页 · 车库卡 | `ProfileRepository.fetchGarage` | `GET /profile/garage` |

---

## 1. 通用约定

### 1.1 基础

- Base URL：`https://api.chexiaoji.app/api/v1`
- 认证：`Authorization: Bearer <access_token>`（当前本地账号阶段可省略，接口需预留）
- 所有请求带 `Accept: application/json`；写操作带 `Content-Type: application/json`
- 时区：客户端固定传 `timezone=Asia/Shanghai`；服务端按该时区计算「月 / 日 / 周」边界
- 幂等：`POST /expenses`、`POST /vehicles`、`POST /receipts` 支持 `Idempotency-Key` 头
- 追踪：响应头 `X-Request-Id`，客户端错误上报时带上

### 1.2 数值与时间

| 类型 | 约定 |
| --- | --- |
| 金额 | **整数分**（`amountCents`、`totalCents`、`costPerKmCents`），前端负责格式化 |
| 电量 | `double`，单位 kWh，保留 1 位 |
| 油量 | `double`，单位 L，保留 2 位 |
| 里程 | `int`，单位 km |
| 时长 | `int`，单位分钟 |
| 日期 | `YYYY-MM-DD` |
| 时间 | ISO-8601 带时区，如 `2026-11-16T08:42:00+08:00` |
| 月份 | `YYYY-MM` |
| ID | 字符串；车辆 `veh_*`，流水 `rec_*`，凭证 `rcpt_*` |

### 1.3 分页

游标分页，禁止 offset 分页（月度数据会变化）：

```json
{
  "items": [ ... ],
  "hasMore": true,
  "nextCursor": "eyJvY2N1cnJlZEF0IjoiMjAyNi0xMS0xNiIsImlkIjoicmVjXzEifQ"
}
```

- `limit` 默认 30，最大 100；报表导出允许 `limit=500`。
- 排序固定「发生时间倒序 + id 倒序」作为游标稳定键。

### 1.4 错误

```json
{
  "error": {
    "code": "ODOMETER_CONFLICT",
    "message": "里程读数已更新",
    "field": "odometerKm",
    "details": { "lastReadingKm": 18409, "recordedAt": "2026-11-15T18:20:00+08:00" }
  }
}
```

| HTTP | code | 客户端处理 |
| --- | --- | --- |
| 400 | `INVALID_FIELD` | 定位到 `field` 提示 |
| 401 | `UNAUTHORIZED` | 跳登录 |
| 403 | `FORBIDDEN` | Toast |
| 404 | `NOT_FOUND` | 返回并刷新列表 |
| 409 | `VEHICLE_HAS_RECORDS` / `VEHICLE_IS_PRIMARY` / `DUPLICATE_PLATE` / `CONFLICT` | 弹对应引导 |
| 409 | `ODOMETER_CONFLICT` | 刷新基线，提示用户重新确认 |
| 422 | `PLATE_TAIL_MISMATCH` | 保留弹层，提示重输 |
| 429 | `RATE_LIMITED` | 指数退避 |
| 5xx | `SERVER_ERROR` | 模块级重试 + Toast |

### 1.5 聚合口径（所有接口必须一致）

1. **范围**：`month + vehicleId`（`vehicleId` 缺省 = 全部车辆）。月份按 `timezone` 的自然月。
2. **总额**：范围内所有未删除流水的 `amountCents` 之和，**退款为负数**。
3. **笔数**：范围内未删除流水的条数，退款也计入。
4. **能源金额**：`charging + fuel`。
5. **服务金额**：`maintenance + carWash`。
6. **里程**：每辆车优先取「月内里程表读数最大值 − 最小值」；不足 2 条读数时用 `distanceKm` 求和；仍无法计算返回 0，并给出 `distanceSource`：
   - `odometer`：至少一辆车用了读数极差；
   - `records`：只用了单笔距离；
   - `none`：无法计算（此时 `costPerKmCents`、`kwhPer100km`、`litersPer100km` 为 `null`）。
7. **每公里成本**：`totalCents / distanceKm`（分/km，四舍五入）。
8. **百公里能耗**：`Σ kWh / distanceKm × 100`、`Σ L / distanceKm × 100`。
9. **百分比**：
   - 首页 / 统计「开销构成」：金额降序、最多 6 类、`<2%` 并入「其他」、最大余数法保证合计 **恰好 100**；「其他」只出现一次。
   - 月度报表：固定 6 个分组（`charging / fuel / maintenance / parking / toll / carWashOther`），金额含退款（可负），存在负组时 `percent = null`。
10. **环比**：当前范围总额 vs 上一等长范围总额；上期为 0 或不存在 → `null` + `none`；`|percent| < 0.05` 视为 `flat`。
11. **首页 / 统计 / 报表 / 我的必须复用上述字段**，不允许各接口重新定义一套口径。

---

## 2. 车辆与车库

### 2.1 `GET /vehicles`

返回在库车辆（归档车辆不在内），默认主驾置顶。

```json
{
  "items": [
    {
      "id": "veh_han_ev",
      "name": "比亚迪 汉 EV",
      "plate": "粤B·D82K6",
      "powertrain": "ev",
      "powertrainLabel": "纯电",
      "odometerKm": 18426,
      "badge": null,
      "batteryCapacityKwh": 85.4,
      "tankCapacityL": null,
      "defaultFuelGrade": null,
      "specLabel": "2023款 创世旗舰型 · 纯电",
      "nickname": null,
      "isPrimary": true,
      "sortOrder": 0,
      "insuranceExpiry": "2027-06-04",
      "inspectionExpiry": "2027-09-12",
      "batteryHealthPercent": 98,
      "officialConsumption": 13.2,
      "electricRangeKm": null,
      "purchaseDate": "2023-06-18",
      "purchasePriceCents": 26800000,
      "nextMaintenanceKm": 20000
    }
  ]
}
```

- `powertrain`：`ev | hev | phev | ice`
- `odometerKm`：**当前表显里程** = `max(档案里程, 最近一条带读数流水)`，与首页 Hero、记账基线一致。

### 2.2 `GET /vehicles/{id}` / `GET /vehicles/{id}/editor`

`/editor` 额外返回保存所需元信息：

```json
{
  "vehicle": { ... },
  "latestOdometerKm": 18426,
  "isPrimary": true,
  "activeVehicleCount": 4,
  "maxActiveVehicles": 10,
  "isOnlyActiveVehicle": false,
  "successorName": "丰田 凯美瑞 双擎",
  "version": 3
}
```

- `version` 用于 `PUT` 的乐观并发校验。

### 2.3 `POST /vehicles` / `PUT /vehicles/{id}`

请求体（对应 `VehicleEditorDraft`）：

```json
{
  "name": "比亚迪 汉 EV",
  "specLabel": "2023款 创世旗舰型 · 纯电",
  "nickname": "小汉",
  "province": "粤",
  "plateBody": "BD82K6",
  "isGreenPlate": false,
  "odometerKm": 18426,
  "powertrain": "ev",
  "batteryCapacityKwh": 85.4,
  "officialConsumption": 13.2,
  "electricRangeKm": null,
  "tankCapacityL": null,
  "defaultFuelGrade": null,
  "purchaseDate": "2023-06-18",
  "purchasePriceCents": 26800000,
  "nextMaintenanceKm": 20000,
  "insuranceExpiry": "2027-06-04",
  "makePrimary": false
}
```

响应：

```json
{ "vehicleId": "veh_han_ev", "created": true, "isPrimary": true, "version": 1 }
```

校验（与客户端一致）：

- `name` 2–40 字；`specLabel` ≤30；`nickname` ≤12
- 新能源车牌：城市字母 + 6 位（共 8 位）；燃油车牌：城市字母 + 5 位（共 7 位）
- 车牌唯一（含归档车辆），冲突返回 `DUPLICATE_PLATE`
- `odometerKm` 不能小于最近记账里程
- 在库车辆上限 10 辆

### 2.4 车库命令

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| POST | `/vehicles/{id}/primary` | 设为主驾；仅归档车不可操作 |
| POST | `/vehicles/{id}/archive` | 归档；主驾归档后由继任车辆接管 |
| POST | `/vehicles/{id}/restore` | 恢复；无主驾时成为主驾 |
| DELETE | `/vehicles/{id}` | 删除在库车辆；有流水 → `VEHICLE_HAS_RECORDS`，主驾且多车 → `VEHICLE_IS_PRIMARY` |
| DELETE | `/vehicles/{id}/purge` | 彻底删除归档车辆；请求体 `{ "plateTail": "D82K6" }` |

**彻底删除语义**：只销毁车辆档案；历史流水保留，但不再归属任何车辆（详情页显示「已解绑」）；账单「全部车辆」合计不变。

### 2.5 `GET /garage/overview`

车辆管理页一次拿全，避免客户端逐车请求 dashboard：

```json
{
  "vehicles": [
    {
      "id": "veh_han_ev",
      "vehicle": { ... },
      "specLabel": "2023款 创世旗舰型 · 纯电",
      "sortOrder": 0,
      "isPrimary": true,
      "monthSpendCents": 128600,
      "recordCount": 37,
      "consumption": {
        "label": "平均能耗",
        "typeLabel": "纯电电耗",
        "primary": { "value": 14.8, "unit": "kWh/百公里" },
        "secondary": null,
        "primarySparkline": [15.8, 15.3, 14.9, 14.4],
        "secondarySparkline": [],
        "hasData": true
      },
      "maintenance": {
        "enabled": true,
        "remainingKm": 1574,
        "remainingDays": 39,
        "progressPercent": 21,
        "status": "normal",
        "hasProgress": true
      },
      "batteryHealthPercent": 98,
      "insuranceExpiry": "2027-06-04",
      "inspectionExpiry": "2027-09-12"
    }
  ],
  "archivedVehicles": [],
  "primaryVehicleId": "veh_han_ev",
  "summary": {
    "vehicleCount": 4,
    "totalOdometerKm": 155096,
    "monthSpendCents": 623000,
    "powertrainCounts": { "ev": 1, "hev": 1, "phev": 1, "ice": 1 },
    "pendingIssueCount": 2,
    "hasReminderData": true
  },
  "fetchedAt": "2026-11-16T10:00:00+08:00"
}
```

- `monthSpendCents` 必须等于同车 `GET /ledger/summary?month=current` 的 `totalCents`。
- `recordCount` 是全历史（未删除）笔数。
- `consumption` / `maintenance` 必须与 `GET /home/dashboard` 同车同月一致。

### 2.6 `GET /vehicles/archived`

```json
{
  "vehicles": [
    {
      "id": "veh_camry",
      "vehicle": { ... },
      "specLabel": "2.5L 豪华版 · 92号汽油",
      "archivedAt": "2026-08-15T20:10:00+08:00",
      "lifetimeSpendCents": 964000,
      "recordCount": 38,
      "energyRecordCount": 21,
      "averageConsumption": { "value": 4.5, "unit": "L/百公里" },
      "latestRecordAt": "2026-08-14T18:20:00+08:00"
    }
  ],
  "fetchedAt": "2026-11-16T10:00:00+08:00"
}
```

- 无能耗读数时 `averageConsumption = null`，客户端显示「未录入」，**不得填 0**。
- `lifetimeSpendCents` 为该车全部未删除流水合计；生产环境返回全生命周期（Mock 为 36 个月）。

---

## 3. 流水（账单）

### 3.1 `GET /expenses`

查询参数：

| 参数 | 必填 | 说明 |
| --- | --- | --- |
| `month` | 是 | `YYYY-MM` |
| `vehicleId` | 否 | 缺省 = 全部车辆 |
| `category` | 否 | `charging / fuel / maintenance / parking / toll / carWash / other` |
| `sort` | 否 | `timeDesc`（默认）/ `amountDesc` / `category` |
| `cursor` / `limit` | 否 | 游标分页 |

单条流水：

```json
{
  "id": "rec_20261116_12",
  "vehicleId": "veh_han_ev",
  "vehicleShortName": "汉 EV",
  "vehicleName": "比亚迪 汉 EV",
  "powertrain": "ev",
  "category": "charging",
  "title": "特来电快充 · 科技园站",
  "amountCents": 5110,
  "occurredAt": "2026-11-16T08:42:00+08:00",
  "badgeText": "汉 EV",
  "badgeKind": "vehicle",
  "description": "充入 38.5 kWh",
  "statusText": null,
  "note": "夜间谷电",
  "metrics": {
    "kwh": 38.5,
    "liters": null,
    "odometerKm": 18426,
    "distanceKm": null,
    "durationMinutes": null,
    "plate": "粤B·D82K6",
    "paymentMethod": "微信"
  }
}
```

- `amountCents`：支出为正、退款为负；客户端展示时给支出加 `-`。
- `metrics.odometerKm`：**该笔记录发生时的表显里程**，不是当前里程。
- `metrics.distanceKm`：该笔记录对应的单笔行驶距离，仅在无法用读数极差时兜底。
- `statusText`：右侧辅助文案（如 `19:45 离场`、`工单已归档`），**不是支付方式**。
- `paymentMethod`：支付方式展示名，详情页与编辑页都以此为准。
- `tags`：详情页标签；生成流水可为空。

### 3.2 `GET /expenses/{id}`

返回单笔详情：

```json
{
  "record": { ... },
  "status": "completed",
  "payment": { "channel": "wechat", "label": "微信支付" },
  "tags": ["日常补能"],
  "note": "夜间谷电",
  "vehicleBound": true,
  "updatedAt": "2026-11-16T08:45:00+08:00"
}
```

- `status`：`completed`（正数）/ `refunded`（负数）。
- `vehicleBound=false` 表示车辆已彻底删除，客户端显示快照 + 「已解绑」。
- `note` / `tags` 为空时返回 `null` / `[]`，**不要返回演示文案**。

### 3.3 保存流水

`POST /expenses` 请求体（对应 `ExpenseEntryDraft`）：

```json
{
  "vehicleId": "veh_han_ev",
  "category": "charging",
  "amountCents": 5110,
  "occurredAt": "2026-11-16T08:42:00+08:00",
  "place": "特来电科技园站",
  "payment": { "channel": "wechat", "label": "微信支付" },
  "odometerKm": 18426,
  "lastOdometerKm": 18000,
  "note": "夜间谷电",
  "receiptIds": ["rcpt_1"],
  "detail": {
    "type": "charging",
    "kwh": 38.5,
    "unitPriceCentsPerKwh": 133,
    "socStart": 20,
    "socEnd": 100
  }
}
```

`detail.type` 与字段：

| type | 字段 |
| --- | --- |
| `charging` | `kwh`、`unitPriceCentsPerKwh`、`socStart`、`socEnd` |
| `fuel` | `liters`、`unitPriceCentsPerLiter`、`fuelGrade` |
| `parking` | `durationMinutes`、`rateCentsPerHour`、`lotName` |
| `toll` | `entryStation`、`exitStation`、`roadName`、`distanceKm` |
| `maintenance` | `item`、`shopName`、`odometerKm` |
| `carWash` | `serviceType`、`shopName` |
| `insurance` | `coverageType`、`policyNo`、`periodStart`、`periodEnd` |

服务端校验：

- `amountCents > 0`（录入页只记支出）
- `occurredAt` 不晚于当前时间，且不早于「账本可回看窗口」（Mock 36 个月）
- `odometerKm ≥ lastOdometerKm`；跨度 > 5000 km 需要客户端二次确认后带 `forceOdometer=true`
- 充电单价 0.10–20.00 元/kWh；加油单价 3.00–15.00 元/L；停车时租 0–100 元/h
- 凭证 ≤ 4 张

`PUT /expenses/{id}` 同请求体；带 `If-Match` / `version` 做并发校验，冲突返回 `CONFLICT` 或 `ODOMETER_CONFLICT`。

### 3.4 备注 / 标签 / 删除

| 方法 | 路径 | 请求体 | 响应 |
| --- | --- | --- | --- |
| PATCH | `/expenses/{id}/note` | `{ "note": "..." }`（空串清除） | 最新 `ExpenseDetail` |
| PUT | `/expenses/{id}/tags` | `{ "tags": ["日常补能"] }`（≤8 个、每个 ≤10 字） | 最新 `ExpenseDetail` |
| DELETE | `/expenses/{id}` | — | `204` |

删除后账单、统计、报表、首页、我的页的合计都必须同步减少（客户端负责失效对应查询）。

### 3.5 凭证上传

`POST /receipts`（multipart 或预签名 URL）：

```json
{ "receiptId": "rcpt_1", "url": "https://cdn.../1.jpg", "uploadedAt": "..." }
```

客户端在保存流水前完成上传，把 `receiptId` 放进 `receiptIds`。

### 3.6 `GET /ledger/summary`

| 参数 | 必填 | 说明 |
| --- | --- | --- |
| `month` | 是 | `YYYY-MM` |
| `vehicleId` | 否 | 缺省 = 全部车辆 |

```json
{
  "month": "2026-11",
  "totalCents": 428600,
  "count": 31,
  "energyCents": 156800,
  "serviceCents": 48000,
  "dailyAverageCents": 14287,
  "daily": [
    { "date": "2026-11-01", "amountCents": 5110, "dominantCategory": "charging" }
  ],
  "momPercent": -8.2,
  "momTrend": "down"
}
```

约束：

- `totalCents` 必须等于 `daily[].amountCents` 之和。
- `dailyAverageCents = totalCents / 当月自然日天数`（当前月也按整月天数，产品已确认）。
- 与 `/stats/overview`（同 month+vehicle）、`/reports/monthly`（同 scope）的 `totalCents`、`count` 一致。

### 3.7 生命周期与里程辅助

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/ledger/lifetime-stats` | `{ recordCount, firstRecordAt }`；全部车辆、全部历史、未删除 |
| GET | `/ledger/record-count?vehicleId=` | 单车未删除笔数（删除拦截） |
| GET | `/vehicles/{id}/ledger-stats` | `{ totalSpendCents, recordCount, energyRecordCount, firstRecordAt, latestRecordAt }` |
| GET | `/ledger/odometer-baseline?vehicleId=&before=&excludeRecordId=` | `{ lastReadingKm, recordedAt, recordId, currentOdometerKm }` |
| GET | `/ledger/latest-odometer?vehicleId=` | 最近一条带读数流水的表显里程 |
| GET | `/ledger/latest-maintenance-odometer?vehicleId=` | 最近一次保养流水的表显里程（保养进度用） |

### 3.8 `GET /expenses/defaults?vehicleId=`

```json
{
  "defaultCategory": "charging",
  "paymentChannel": "wechat",
  "paymentLabel": "微信支付",
  "lastPlace": "特来电科技园站",
  "recentPlaces": ["特来电科技园站", "万象城 B2"],
  "unitPrices": {
    "chargingCentsPerKwh": 120,
    "fuelCentsPerLiter": 785,
    "parkingCentsPerHour": 800
  },
  "fuelGrade": 92,
  "batteryCapacityKwh": 85.4,
  "tankCapacityL": null,
  "lastSoc": 38,
  "lastOdometerKm": 18426,
  "lastCategory": "charging"
}
```

- `lastSoc` 为 P1（从最近一条充电记录读取），当前可为 `null`。
- `lastCategory` 供后续「按上次分类预选」使用，客户端当前未消费。

---

## 4. 首页

> 首页四个接口返回的数字必须与第 3 节的账本接口完全一致（同 month+vehicle），
> 不允许首页单独维护一套「演示值」。

### 4.1 `GET /home/dashboard?vehicleId=&month=`

```json
{
  "vehicle": { ... },
  "summary": {
    "costPerKm": 0.47,
    "monthSpendCents": 128600,
    "monthMileageKm": 2741,
    "energyCostPerKm": 0.18,
    "momChangePercent": -8.2,
    "momTrend": "down"
  },
  "consumption": {
    "label": "平均能耗",
    "typeLabel": "纯电电耗",
    "primary": { "value": 14.8, "unit": "kWh/百公里" },
    "secondary": null,
    "primarySparkline": [15.8, 15.3, 14.9, 14.4],
    "secondarySparkline": [],
    "hasData": true
  },
  "maintenance": {
    "enabled": true,
    "remainingKm": 1574,
    "remainingDays": 39,
    "progressPercent": 21,
    "status": "normal",
    "hasProgress": true
  }
}
```

口径：

- `summary` 与 `GET /ledger/summary`（同 month+vehicle）一致：`monthSpendCents = totalCents`、`monthMileageKm = distance`。
- `costPerKm = monthSpendCents / 100 / monthMileageKm`。
- `energyCostPerKm = energyCents / 100 / monthMileageKm`。
- `momChangePercent` 对比上月。
- `consumption`：周期内充电 kWh 与加油 L 按里程折算；无读数时 `hasData=false`、`primary.value=0`。
- `maintenance`：`nextMaintenanceKm` 有值才 `enabled=true`；`remainingDays = remainingKm / 近 30 日日均里程`；`hasProgress` 需要同时存在保养流水与下次保养里程。

### 4.2 `GET /home/breakdown?vehicleId=&month=`

字段与 `StatsBreakdown` 相同（`totalCents`、`count`、`categories[]`、`otherMerged`）。
必须与 `GET /stats/breakdown`（同 month+vehicle）**逐项相等**。

### 4.3 `GET /home/records?vehicleId=&month=&limit=5`

返回该月最新 N 条（默认 5），字段同流水列表。

### 4.4 `GET /home/trend?vehicleId=&range=`

`range`：`7d | 30d | 6m | 1y`；窗口固定为「含今天的近 N 天 / 近 N 月」，由服务端按当前时间计算。

```json
{
  "range": "30d",
  "points": [
    { "date": "2026-10-18", "energyCents": 4200, "otherCents": 1200 }
  ],
  "totalCents": 128600,
  "previousTotalCents": 140200
}
```

- 7d / 30d：按天分桶（含今天）；6m / 1y：按月分桶（含本月）。
- `points` 的 `energyCents + otherCents` 之和必须等于 `totalCents`。
- `previousTotalCents`：上一个等长窗口的总额；无数据为 0。
- **日期由服务端按当前时间生成**，客户端只负责渲染。

---

## 5. 统计

### 5.1 `GET /stats/overview`

| 参数 | 必填 | 说明 |
| --- | --- | --- |
| `vehicleId` | 否 | 缺省 = 全部车辆 |
| `period` | 是 | `week / month / half_year / year / all` |
| `anchor` | 是 | 锚点日期；`all` 时忽略 |
| `timezone` | 是 | `Asia/Shanghai` |

```json
{
  "scope": { "vehicleId": null, "period": "month", "anchor": "2026-11-16" },
  "range": {
    "start": "2026-11-01T00:00:00+08:00",
    "end": "2026-11-30T23:59:59+08:00",
    "label": "2026年11月",
    "shortLabel": "本月",
    "comparisonLabel": "较上月"
  },
  "powertrain": null,
  "summary": {
    "totalCents": 428600,
    "distanceKm": 2741,
    "distanceSource": "odometer",
    "costPerKmCents": 156,
    "energyCents": 156800,
    "energyCostPerKmCents": 57,
    "previousTotalCents": 467000,
    "changePercent": -8.21,
    "changeTrend": "down",
    "changeText": null,
    "cumulativeYears": null,
    "cumulativeDays": null
  },
  "consumption": {
    "rating": "good",
    "primary": { "value": 14.8, "unit": "kWh/100km" },
    "secondary": null,
    "sparkline": [15.8, 15.3, 14.9]
  },
  "maintenance": {
    "enabled": true,
    "vehicleId": "veh_han_ev",
    "vehicleName": "汉 EV",
    "tag": "小保养",
    "remainingKm": 1574,
    "progressPercent": 21,
    "status": "normal",
    "remainingDays": 39
  },
  "dataUpdatedAt": "2026-11-16T10:00:00+08:00"
}
```

- 与 `GET /ledger/summary`（month 范围）同 scope 时总额 / 笔数一致。
- `distanceSource` 必须下发（客户端当前未展示，后续用于口径说明）。
- 全部车辆时 `consumption.primary.unit = CNY/km`、`rating = fleet`。

### 5.2 `GET /stats/breakdown` / `/stats/trend` / `/stats/recent`

- `breakdown`：同 `GET /home/breakdown`。
- `trend`：参数 `vehicleId / range / anchor / timezone`，返回 `buckets[]`、`axis`、`peakIndex`、`previousTotalCents`、`changePercent`、`changeTrend`。
- `recent`：参数 `vehicleId / period / anchor / limit / timezone`；`showVehicle` 由 `vehicleId == null` 推导。

---

## 6. 月度报表

### 6.1 `GET /reports/monthly?month=&vehicleId=&timezone=`

```json
{
  "scope": { "month": "2026-11", "vehicleId": null },
  "reportNo": "RP-202611-0427",
  "status": "recording",
  "generatedAt": "2026-11-16T10:00:00+08:00",
  "updatedAt": "2026-11-16T09:58:00+08:00",
  "settledAt": null,
  "totalCents": 428600,
  "recordCount": 31,
  "distanceKm": 2741,
  "distanceSource": "odometer",
  "days": 30,
  "costPerKmCents": 156,
  "energyKwh": 405.2,
  "fuelLiters": 0,
  "kwhPer100km": 14.8,
  "litersPer100km": null,
  "momPercent": -8.2,
  "momTrend": "down",
  "vehicles": [
    {
      "id": "veh_han_ev",
      "name": "比亚迪 汉 EV",
      "shortName": "汉 EV",
      "plate": "粤B·D82K6",
      "powertrain": "ev",
      "powertrainLabel": "纯电",
      "odometerKm": 18426,
      "recordCount": 12
    }
  ],
  "categories": [
    { "key": "charging", "label": "充电动能", "amountCents": 38600, "count": 6, "percent": 30 }
  ],
  "daily": [
    {
      "date": "2026-11-01",
      "chargingCents": 5110,
      "otherCents": 0,
      "recordCount": 1,
      "dominantCategory": "charging"
    }
  ],
  "verified": false,
  "verificationText": "数据由车小记本地账本汇总 · 请核对后使用",
  "isOffline": false
}
```

约束：

- 与 `GET /ledger/summary` 同 scope 的 `totalCents`、`count` 一致。
- `categories[].amountCents` 之和 = `totalCents`（含退款时需要支持负数；存在负数时 `percent = null`）。
- `daily` 覆盖 1 日至月末（当前月截止今天）；`daily[].totalCents` 之和 = `totalCents`。
- `vehicles[]`：全部车辆口径下包含所有有流水的车辆（含已归档车辆的快照），`recordCount` 为范围内笔数。

### 6.2 `GET /reports/monthly/records?month=&vehicleId=&cursor=&limit=500`

报表 CSV 导出用：分页返回原始流水，字段同 `/expenses`。

### 6.3 `GET /reports/monthly/export`

| 参数 | 说明 |
| --- | --- |
| `month` / `vehicleId` | 范围 |
| `format` | `pdf / csv / poster` |
| `includeEnergy` | 是否包含每公里 / 能耗走势 |
| `maskPlate` | 车牌脱敏 |
| `includeInvoices` | 凭证附件（当前恒 false） |

返回 `application/pdf` / `text/csv` / `image/png` 文件流，或预签名下载 URL。

---

## 7. 我的

### 7.1 `GET /profile/overview`

```json
{
  "user": {
    "id": "local-user",
    "nickname": "林漪",
    "avatarUrl": null,
    "verifiedOwner": true,
    "tagline": "车小记 · 驱动每公里透明",
    "phoneMasked": "138 **** 9208"
  },
  "stats": {
    "accountDays": 486,
    "recordCount": 312,
    "firstRecordAt": "2025-07-18T08:42:00+08:00"
  },
  "dataUpdatedAt": "2026-11-16T10:00:00+08:00"
}
```

### 7.2 `GET /profile/garage?vehicleId=&month=`

```json
{
  "vehicles": [
    {
      "id": "veh_han_ev",
      "name": "比亚迪 汉 EV",
      "shortName": "汉 EV",
      "plate": "粤B·D82K6",
      "powertrain": "ev",
      "powertrainLabel": "纯电",
      "odometerKm": 18426,
      "energyCostPerKmCents": 18
    }
  ],
  "snapshot": {
    "vehicleId": "veh_han_ev",
    "badge": "纯电",
    "plateText": "粤B·D82K6",
    "title": "比亚迪 汉 EV",
    "subtitle": "本月能耗 ¥0.18/km",
    "powertrain": "ev",
    "odometerKm": 18426,
    "monthEnergy": {
      "amountCents": 38600,
      "count": 6,
      "kwh": 405.2,
      "liters": null
    },
    "maintenance": {
      "enabled": true,
      "status": "normal",
      "vehicleId": "veh_han_ev",
      "vehicleName": "汉 EV",
      "remainingKm": 1574,
      "remainingDays": 39
    },
    "tip": { "kind": "charging", "text": "本月充电 6 次 · 平均 ¥1.20/kWh" }
  },
  "dataUpdatedAt": "2026-11-16T10:00:00+08:00"
}
```

- `monthEnergy.amountCents` 必须等于 `GET /ledger/summary` 的 `energyCents`。
- `energyCostPerKmCents` 必须等于 `GET /home/dashboard` 的 `summary.energyCostPerKm × 100`。
- 全部资产：`vehicleId = null`，`monthEnergy.kwh/liters` 仅在单一能源类型时可比较，否则 `null`。

### 7.3 工具与偏好

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/profile/services` | 报表 / 票夹 / 同步 / 离线的可用状态；不可用不得伪造数量 |
| GET | `/profile/preferences` | `unitSystem / currency / notificationsEnabled / maskSensitive` |
| PUT | `/profile/preferences` | P1；当前客户端抛 `UnimplementedError` |
| POST | `/auth/logout` | P1 |

---

## 8. 跨接口一致性验收（后端联调必测）

| # | 场景 | 断言 |
| --- | --- | --- |
| 1 | 同月同车：账单汇总 vs 统计概览 vs 月报 | `totalCents`、`count` 完全相等 |
| 2 | 同月同车：首页构成 vs 统计构成 | 分类、金额、百分比逐项相等 |
| 3 | 同月同车：账单汇总 | `totalCents == Σ daily[].amountCents` |
| 4 | 同月同车：首页汇总 vs 账单汇总 | `monthSpendCents == totalCents` |
| 5 | 同月同车：首页每公里能源成本 vs 我的页 | `round(energyCostPerKm × 100) == energyCostPerKmCents` |
| 6 | 车库总览本月支出 vs 账单全部车辆 | `Σ monthSpendCents == ledger totalCents` |
| 7 | 编辑流水跨月 | 从原月消失、出现在新月；两月总额都等于日柱之和；统计/报表都能查到 |
| 8 | 删除流水 | 账单、统计、月报、首页、我的页合计同时减少 |
| 9 | 归档车辆 | 首页/记账/统计选择器不再出现；历史流水仍计入「全部车辆」 |
| 10 | 彻底删除车辆 | 流水保留、车辆归属解除、总额不变、详情显示「已解绑」 |
| 11 | 退款 | 总额按负数计入；分类构成规则需与服务端一致（存在负组时 `percent = null`） |
| 12 | 里程 | `distanceSource=none` 时每公里成本与百公里能耗必须为 `null`，而不是 0 |
| 13 | 无数据车辆 | 首页汇总为 0、构成为空、趋势为空、保养 `enabled=false`，不得伪造演示值 |

---

## 9. 客户端仓库方法对照

| 仓库方法 | 建议接口 |
| --- | --- |
| `HomeRepository.fetchVehicles` | `GET /vehicles` |
| `HomeRepository.fetchDashboard` | `GET /home/dashboard` |
| `HomeRepository.fetchBreakdown` | `GET /home/breakdown` |
| `HomeRepository.fetchRecords` | `GET /home/records` |
| `HomeRepository.fetchTrend` | `GET /home/trend` |
| `LedgerRepository.fetchSummary` | `GET /ledger/summary` |
| `LedgerRepository.fetchRecords` | `GET /expenses` |
| `LedgerRepository.fetchLifetimeStats` | `GET /ledger/lifetime-stats` |
| `LedgerRepository.countRecords` | `GET /ledger/record-count` |
| `LedgerRepository.fetchVehicleStats` | `GET /vehicles/{id}/ledger-stats` |
| `LedgerRepository.latestOdometerForVehicle` | `GET /ledger/latest-odometer` |
| `LedgerRepository.latestMaintenanceOdometer` | `GET /ledger/latest-maintenance-odometer` |
| `ExpenseEntryRepository.fetchDefaults` | `GET /expenses/defaults` |
| `ExpenseEntryRepository.fetchOdometerBaseline` | `GET /ledger/odometer-baseline` |
| `ExpenseEntryRepository.fetchDraft` | `GET /expenses/{id}`（转成草稿） |
| `ExpenseEntryRepository.createExpense` | `POST /expenses` |
| `ExpenseEntryRepository.updateExpense` | `PUT /expenses/{id}` |
| `ExpenseEntryRepository.uploadReceipts` | `POST /receipts` |
| `ExpenseDetailRepository.fetchDetail` | `GET /expenses/{id}` |
| `ExpenseDetailRepository.updateNote` | `PATCH /expenses/{id}/note` |
| `ExpenseDetailRepository.updateTags` | `PUT /expenses/{id}/tags` |
| `ExpenseDetailRepository.deleteExpense` | `DELETE /expenses/{id}` |
| `StatsRepository.fetchOverview` | `GET /stats/overview` |
| `StatsRepository.fetchBreakdown` | `GET /stats/breakdown` |
| `StatsRepository.fetchTrend` | `GET /stats/trend` |
| `StatsRepository.fetchRecent` | `GET /stats/recent` |
| `ReportRepository.fetchReport` | `GET /reports/monthly` |
| `ReportRepository.fetchAllRecords` | `GET /reports/monthly/records` |
| `VehicleRepository.fetchGarage` | `GET /garage/overview` |
| `VehicleRepository.fetchArchivedGarage` | `GET /vehicles/archived` |
| `VehicleRepository.fetchVehicleEditor` | `GET /vehicles/{id}/editor` |
| `VehicleRepository.createVehicle` | `POST /vehicles` |
| `VehicleRepository.updateVehicle` | `PUT /vehicles/{id}` |
| `VehicleRepository.setPrimary` | `POST /vehicles/{id}/primary` |
| `VehicleRepository.archive` | `POST /vehicles/{id}/archive` |
| `VehicleRepository.restore` | `POST /vehicles/{id}/restore` |
| `VehicleRepository.delete` | `DELETE /vehicles/{id}` |
| `VehicleRepository.purgeArchivedVehicle` | `DELETE /vehicles/{id}/purge` |
| `ProfileRepository.fetchOverview` | `GET /profile/overview` |
| `ProfileRepository.fetchGarage` | `GET /profile/garage` |
| `ProfileRepository.fetchServices` | `GET /profile/services` |
| `ProfileRepository.fetchPreferences` | `GET /profile/preferences` |
| `ProfileRepository.updatePreferences` | `PUT /profile/preferences` |
| `ProfileRepository.logout` | `POST /auth/logout` |

---

## 10. 缓存与刷新

- 聚合类接口（`/home/*`、`/stats/*`、`/reports/monthly`、`/profile/*`）响应带 `ETag` 与 `dataUpdatedAt`；
  客户端命中缓存时必须展示「数据更新于 …」。
- 流水写操作成功后，客户端会失效以下查询（实现见 `invalidateLedgerDependents`）：
  账单列表 / 汇总、首页 dashboard / 构成 / 最近记录 / 趋势、统计 overview / 构成 / 趋势 / 最近、
  月报、我的概览 / 车库卡、车库总览 / 归档快照、车辆列表。
- 车辆写操作成功后，客户端会失效车库与所有按车维度的查询，并把当前筛选从被删车辆上迁走。
- 建议服务端提供 `GET /sync/version`（可选）：返回账本最后变更时间，客户端可据此跳过无变化刷新。

## 11. Mock 与生产的差异

| 项 | Mock 当前 | 生产接口 |
| --- | --- | --- |
| 历史窗口 | 最近 36 个月 | 全生命周期 |
| 延迟 | 模拟 120–160ms | 网络 |
| 存储 | 内存（重启丢失） | 服务端持久化 |
| 里程读数 | 以当前里程为锚点按日均里程倒推 | 用户录入的真实读数 |
| 备注 / 标签 | 演示流水自带示例内容 | 仅返回用户实际写入 |
| 并发 | 无 | `version` / `If-Match` 乐观锁 |
| 退款 | 不生成负数流水 | 支持负数退款，口径见 §1.5 |
