## Context

当前 `/stats` 接口通过本地 MySQL 聚合计算（COUNT 广告主/推广系列/广告组，SUM spend），数据仅反映本地同步结果，无法提供真实的广告效果指标（点击、转化、曝光）。平台 Report API 提供的 `total_metrics` 可以在单次请求中汇总所有广告主的核心指标，适合作为首页概览数据源。

技术约束：
- TikTok: `GET /open_api/v1.3/report/integrated/get`，`enable_total_metrics=true`，`data_level=AUCTION_ADVERTISER`
- Kwai: 对应报表接口（结构相似）
- Redis 已有完整封装，可直接使用
- Platform 接口已定义，需新增 `GetReportStats` 方法

## Goals / Non-Goals

**Goals:**
- `/stats` 接口返回 spend、conversion、clicks、impressions 四项由平台 Report API 实时汇总的指标
- 调用前从本地 DB 取当前用户+平台的所有 advertiser_id，批量传入 Report API
- 结果 Redis 缓存 15 分钟，key 包含 user_id + platform + date range
- 默认时间范围：近 30 天（`today-30d` 至 `today`）
- iOS Dashboard 展示新的 4 项指标卡片

**Non-Goals:**
- 不提供自定义日期区间选择（固定近 30 天）
- 不提供单个广告主的明细拆分（仅 total_metrics 汇总）
- 不实现 Kwai Report API 的完整适配（本次以 TikTok 为主，Kwai 接口预留）
- 不修改广告主/推广系列/广告组列表相关接口

## Decisions

### 1. 使用 `enable_total_metrics=true` 获取汇总值

**选择**: 在单次 API 请求中传入所有 advertiser_id 并设置 `enable_total_metrics=true`，直接读取响应中的 `total_metrics` 字段。

**理由**: 避免客户端/服务端手动求和多条 list 记录，TikTok 官方支持此参数，语义清晰。

**备选**: 遍历 `list` 中每条记录求和 → 逻辑复杂且易出错，不选。

### 2. 广告主 ID 来源：本地 DB 而非平台 API

**选择**: 从本地 `advertisers` 表按 `user_id` + `platform` 查询所有有效 advertiser_id，组装到 Report API 请求中。

**理由**: 避免额外一次平台 API 调用（获取广告主列表），本地数据已通过同步保持最新，且 Report API 对无数据的 advertiser_id 不报错。

**备选**: 每次先调用平台 API 获取最新广告主列表 → 增加延迟和平台 API 配额消耗，不选。

### 3. 缓存粒度：user_id + platform + date_range

**选择**: Redis key 格式：`stats:report:{user_id}:{platform}:{start_date}:{end_date}`，TTL 15 分钟。

**理由**: 不同用户拥有不同广告主集合，缓存必须隔离。platform 区分 TikTok/Kwai/all。

**备选**: 全局 platform 维度缓存（忽略 user_id）→ 多用户场景下数据串用，安全风险，不选。

### 4. Platform 接口新增 `GetReportStats` 方法

**选择**: 在 `Platform` 接口新增方法签名：
```go
GetReportStats(accessToken string, advertiserIDs []string, startDate, endDate string) (*ReportStats, error)
```
其中 `ReportStats` 包含 `Spend`, `Conversion`, `Clicks`, `Impressions` float64 字段。

**理由**: 保持平台能力的统一抽象，后续 Kwai 实现相同接口即可切换。

### 5. 日期范围：固定近 30 天

**选择**: 服务端计算 `today-30` 至 `today`（UTC）并传入 API。

**理由**: 简单可预期，与 iOS Dashboard 的"近期概览"定位匹配。无需前端传参，减少接口复杂度。

## Risks / Trade-offs

- **[风险] 平台 API 限流** → 通过 15 分钟缓存降低调用频率；若命中限流则返回缓存数据或降级返回空值+错误码 1003
- **[风险] Kwai Report API 接口结构差异** → 本次 Kwai 实现可返回零值占位（`GetReportStats` 返回空 `ReportStats{}`），不影响 TikTok 数据展示
- **[Trade-off] 近 30 天固定范围** → 不能反映当日实时数据；可接受，Dashboard 定位为趋势概览而非实时监控
- **[风险] advertiser_id 数量过多导致 URL 过长** → TikTok API 支持 `page_size=1000`，广告主数量超过时需分页调用并合并 `total_metrics`（本次若超过 1000 按分页处理）

## Migration Plan

1. 后端部署新版本（接口字段变更为 BREAKING，旧字段移除）
2. iOS 同步更新 `StatsResponse` DTO 及 Dashboard 卡片
3. 两端同时发布，无数据库迁移

## Open Questions

- Kwai Report API 的具体端点和参数格式（需查阅快手商业化文档，本次预留接口，返回零值）
- 是否需要在 iOS 上展示日期范围标注（如"近 30 天"）？当前方案不传该参数，可后续加
