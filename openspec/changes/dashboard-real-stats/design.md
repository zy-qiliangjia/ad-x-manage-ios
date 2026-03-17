## Context

当前 `GET /stats` 接口由 `stats/service.go` 从本地 MySQL 汇总 `total_spend`、`active_advertisers`、`campaign_count`、`adgroup_count`，不涉及平台 API 调用。iOS 侧 `StatsOverview` 模型对应4个字段，`DashboardView` 展示4张卡片。

要引入的4个新指标（消耗、点击、展示、转化）来自平台报表 API：
- TikTok：`POST /open_api/v1.3/report/advertiser/get/`（`data_level=AUCTION_ADVERTISER`）
- Kwai：对应商业化报表接口（结构类似，本期一并预留接口，TikTok 优先实现）

## Goals / Non-Goals

**Goals:**
- 后端新增 `Platform.GetReport()` 统一报表接口，TikTok 实现调用 v1.3 报表 API
- `/stats` 接口支持 `start_date` / `end_date` 参数（默认近7天）
- 并发调用当前用户下所有活跃广告主的报表 API，聚合汇总后返回
- 响应新增 `total_clicks`、`total_impressions`、`total_conversions` 字段
- iOS 端展示4个真实指标：总消耗、总点击、总展示、总转化

**Non-Goals:**
- 不实现每日趋势折线图（Dashboard 图表仍用 mock 数据，下个 change 处理）
- 不实现 Kwai 报表（预留接口，返回0值占位）
- 不做历史报表缓存的持久化（仅 Redis 短缓存）

## Decisions

### 决策1：报表调用在后端聚合，不透传到 iOS

**选择**：后端并发调用各广告主报表 API，聚合后通过 `/stats` 接口一次性返回。

**理由**：iOS 无需管理多个广告主的 token；聚合逻辑集中在后端方便缓存和限流；iOS 只需单次请求。

**备选**：iOS 逐个调用 → 复杂度高、token 管理麻烦，不选。

---

### 决策2：TikTok 报表 API 使用 `data_level=AUCTION_ADVERTISER`

**选择**：按广告主粒度聚合，一次请求得到该广告主在指定日期范围内的总消耗/点击/展示/转化。

**指标字段**：`spend`、`show`（展示）、`click`、`conversion`

**日期维度**：`dimensions: ["advertiser_id", "stat_time_day"]`，后端对返回的多天数据求和。

**备选**：不传日期维度只传广告主维度 → 部分平台不支持跨天聚合，不选。

---

### 决策3：Redis 缓存报表结果，TTL = 5分钟

**选择**：`stats:{userID}:{platform}:{startDate}:{endDate}` 作为 cache key，5分钟过期。

**理由**：平台报表 API 有速率限制；同一用户短时间内多次刷新首页不需要重复调用。

---

### 决策4：iOS 默认近7天 = 今天往前推6天

**选择**：`start_date = today-6`，`end_date = today`，格式 `YYYY-MM-DD`，通过 query string 传给 `/stats`。

**理由**：与 TikTok 报表 API 日期参数格式一致，后端直接透传。

---

### 决策5：Kwai 报表接口返回0值占位

**选择**：`KwaiClient.GetReport()` 实现返回全0的 `ReportResult`，不报错。

**理由**：不阻塞 TikTok 功能上线；保持 Platform 接口统一性。

## Risks / Trade-offs

- [TikTok API 速率限制] → 通过 Redis 缓存降低调用频次；并发数控制在 `sync.WaitGroup` + 信号量（最多10个并发）
- [广告主数量大时响应慢] → 增加 context timeout（10s）；超时时返回已聚合的部分数据 + 标记 `partial: true`
- [Token 过期] → 沿用现有 token 自动刷新逻辑；刷新失败的广告主跳过，不影响其他广告主

## Migration Plan

1. 后端先部署（`/stats` 响应新增字段，旧字段保留，向后兼容）
2. iOS 更新 `StatsOverview` 模型接收新字段，更新 DashboardView
3. 无需数据库迁移

## Open Questions

- Kwai 报表接口文档未提供，Kwai 实现暂时返回0值，后续单独接入
