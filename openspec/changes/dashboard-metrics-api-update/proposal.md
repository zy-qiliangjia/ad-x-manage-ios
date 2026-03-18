## Why

当前首页数据概览（Dashboard）的 4 个统计指标（总消耗、活跃广告主数、推广系列数、广告组数）来自本地数据库聚合，无法反映广告平台的真实报表数据（如点击数、转化数、曝光数）。需要改为直接调用平台 Report API 拉取真实指标，提升数据准确性与实时性。

## What Changes

- 新增平台 Report API 调用能力（TikTok `integrated/get`，Kwai 对应报表接口）
- `/stats` 接口返回的 4 个指标从本地 DB 聚合改为调用平台 Report API 获取：
  - **spend**（总消耗）
  - **conversion**（转化）
  - **clicks**（点击）
  - **impressions**（展示）
- 数据来源：对当前平台下所有 advertiser_id 发起报表请求，取 `total_metrics` 汇总值
- 结果缓存 15 分钟（Redis），减少平台 API 调用频率
- iOS Dashboard 指标卡片标签更新为新的 4 项指标（去掉"活跃广告主数/推广系列数/广告组数"，加入 conversion / clicks / impressions）

## Capabilities

### New Capabilities

- `platform-report-stats`: 通过平台 Report API 拉取指定广告主的汇总指标（spend、conversion、clicks、impressions），支持 TikTok 和 Kwai，结果 Redis 缓存 15 分钟

### Modified Capabilities

- `dashboard-stats`: 首页统计概览接口 `/stats` 的返回指标由本地 DB 聚合（活跃广告主/系列数/广告组数）改为平台 Report API 实时汇总（spend/conversion/clicks/impressions）

## Impact

- **后端**
  - `internal/service/stats/`: 重写统计聚合逻辑，改为调用平台 Report API
  - `internal/service/platform/tiktok/`: 新增 `GetReportStats` 方法
  - `internal/service/platform/kwai/`: 新增 `GetReportStats` 方法
  - `internal/service/platform_interface.go`: 在 Platform 接口新增 `GetReportStats` 方法
  - `internal/model/dto/`: 更新 stats response 结构体（新增 conversion、clicks、impressions，移除 active_advertisers、campaign_count、adgroup_count）
  - Redis 缓存 key: `stats:{platform}:{date_range}` TTL 15 分钟
- **iOS**
  - `DashboardView`: 指标卡片更新为 spend / conversion / clicks / impressions
  - 网络层 `StatsResponse` DTO 对应字段更新
- **API 兼容性**：`/stats` 接口响应字段变更，**BREAKING**（旧字段移除）
