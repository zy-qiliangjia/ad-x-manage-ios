## Context

### 现状

- `campaigns` / `ad_groups` 表只存储 `spend`，无 `clicks`、`impressions`、`conversions` 字段
- 后端 `CampaignItem` / `AdGroupItem` DTO 不包含 `advertiser_id`、`advertiser_name`、`platform`，导致 iOS 全量列表视图（allCampaigns / allAdGroups）下钻时构造 `AdvertiserListItem` 时 `id = 0`，后续 API 请求报错
- `AdsSummaryCardView` 调用处硬编码 `clicks: 0, impressions: 0, conversions: 0`
- 统计接口 `GET /api/v1/stats` 不支持日期过滤，也不返回更新时间
- 无专门的"分层级聚合统计"接口

### 约束

- 数据库迁移须向后兼容（新增列 DEFAULT 0，不破坏现有数据）
- iOS 最低版本 iOS 16，使用 SwiftUI + MVVM + async/await
- 点击/展示/转化数据来源于平台同步时写入，不实时调用平台 API

---

## Goals / Non-Goals

**Goals:**
- 修复全量视图（推广系列/广告组）点击下钻 API 报错
- `AdsSummaryCardView` 在各层级展示真实的点击/展示/转化数据
- 各层级列表支持日期快捷筛选（今天/昨天/近7天/近30天）
- 导航栏右上角显示数据最后更新时间
- `docs/db-migrations.md` 记录所有 SQL 变更

**Non-Goals:**
- 实时调用平台报表 API（保持离线数据模型）
- 自定义任意日期区间（仅预设快捷选项）
- 广告（ad）层级的点击/展示/转化指标（平台广告层无聚合报表）
- Dashboard Tab1 的趋势图改造

---

## Decisions

### D1：新增指标列放在现有表 vs 独立报表表

**决策**：在 `campaigns` 和 `ad_groups` 现有表中新增 `clicks BIGINT DEFAULT 0`、`impressions BIGINT DEFAULT 0`、`conversions BIGINT DEFAULT 0` 列。

**理由**：项目当前数据规模小、无需历史时序数据；离线同步模型只需保留最近一次的汇总值；独立报表表会增加 JOIN 复杂度。若未来需要按日期分时序报表，可届时拆分。

**替代方案**：独立 `campaign_stats(date, campaign_id, clicks, ...)` 表 → 过度设计，暂不采用。

---

### D2：日期筛选实现方式

**决策**：日期筛选**仅作用于后端统计聚合接口**（stats 和 stats/summary）的 `date_from`/`date_to` 参数，用于过滤 `updated_at` 所在日期范围的记录汇总；列表接口（campaigns/adgroups）**不加日期过滤**。

**理由**：列表接口展示的是广告投放状态和预算，日期无意义；汇总卡片数据才需日期维度。iOS 选择日期 → 请求 summary 接口刷新汇总卡片，列表本身不变。

**替代方案**：在 DB 中冗余存日期维度 → 超出当前同步策略范围。

---

### D3：汇总统计接口设计

**决策**：新增 `GET /api/v1/stats/summary` 接口，参数：
```
scope       = advertiser | campaign | adgroup   (必填)
scope_id    = {db_id}                            (必填)
date_from   = YYYY-MM-DD                         (可选)
date_to     = YYYY-MM-DD                         (可选)
```
返回：
```json
{
  "spend": 0.0,
  "clicks": 0,
  "impressions": 0,
  "conversions": 0,
  "last_updated_at": "2025-01-01T10:00:00Z"
}
```

- `scope=advertiser`：聚合该广告主下所有 campaigns 的指标总和
- `scope=campaign`：聚合该推广系列下所有 adgroups 的指标总和
- `scope=adgroup`：直接读取 adgroup 的指标值

**理由**：单一接口覆盖所有层级，iOS 只需传不同 scope 参数，统一处理逻辑。

---

### D4：iOS 日期选择 UI 方案

**决策**：在 `AdsSummaryCardView` 内嵌日期快捷选项 Tab（今天/昨天/近7天/近30天），选中后触发重新加载汇总数据。日期状态由各层级 ViewModel 持有，传入 summary API 请求。

**理由**：快捷选项比日期选择器 (DatePicker) 操作更快，覆盖 90% 使用场景；避免引入复杂的 sheet。

---

### D5：更新时间来源

**决策**：`last_updated_at` 取 summary 查询范围内 `MAX(updated_at)`，由后端 stats/summary 接口返回，iOS 在导航栏 ToolbarItem 中展示"更新于 HH:mm"。

**理由**：不需要额外字段，直接利用已有 `updated_at` 即可。

---

## Risks / Trade-offs

- **数据库迁移风险**：ALTER TABLE 在大表时会锁表 → 当前数据量小，可接受；生产环境可使用 `pt-online-schema-change` 或 MySQL 8.0 Instant DDL（`ALGORITHM=INSTANT`）
- **同步覆盖**：新增指标字段在已有数据同步中需更新 UPSERT 语句，否则旧数据 clicks/impressions/conversions 将为 0 → 可通过触发手动同步填充
- **date_from/date_to 过滤精度**：按 `updated_at` 过滤不等于真实"投放日期"的消耗，有统计误差 → 满足当前"最近同步数据"的业务需求，暂接受
- **iOS 汇总卡片加载时序**：summary 接口比列表接口多一次请求，可能导致卡片骨架显示时间略长 → 乐观展示 0 值占位，加载完成后更新

---

## Migration Plan

1. 执行 `ALTER TABLE campaigns ADD COLUMN clicks BIGINT NOT NULL DEFAULT 0, ADD COLUMN impressions BIGINT NOT NULL DEFAULT 0, ADD COLUMN conversions BIGINT NOT NULL DEFAULT 0;`
2. 执行 `ALTER TABLE ad_groups ADD COLUMN clicks BIGINT NOT NULL DEFAULT 0, ADD COLUMN impressions BIGINT NOT NULL DEFAULT 0, ADD COLUMN conversions BIGINT NOT NULL DEFAULT 0;`
3. 部署后端新版本（含新字段写入 + stats/summary 接口）
4. 部署 iOS 新版本（含新字段解码 + summary 接口调用）
5. 用户可通过"手动同步"按钮触发数据回填
6. `docs/db-migrations.md` 记录完整 SQL 语句和回滚方案（DROP COLUMN）

---

## Open Questions

- 平台 API（TikTok / Kwai）同步时是否能获取到 `clicks`、`impressions`、`conversions`？需确认平台 campaign/adgroup 列表接口字段，若不支持则汇总数据仍为 0，需调用报告接口单独拉取（留作后续迭代）
