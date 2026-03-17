## Why

登录后首页仅展示本地数据库汇总的静态指标（消耗/广告主数/系列数/广告组数），缺少真实平台报表数据，用户无法在首页直观看到近7天的实际消耗、点击、展示和转化汇总，决策价值有限。

## What Changes

- 后端新增 Platform 接口方法 `GetReport()`，支持按广告主 ID + 日期范围拉取指定指标
- 后端实现 TikTok `GET /open_api/v1.3/report/advertiser/get/` 基础报表调用（`data_level=AUCTION_ADVERTISER`，metrics：`spend`、`show`、`click`、`conversion`）
- 后端 `GET /stats` 接口新增 `start_date` / `end_date` 查询参数，并并发调用各广告主的报表 API，聚合返回真实指标
- 后端响应新增字段：`total_clicks`、`total_impressions`、`total_conversions`
- iOS `StatsOverview` 模型新增 `totalClicks`、`totalImpressions`、`totalConversions` 字段
- iOS `StatsService.overview()` 默认传入近7天日期范围（`start_date` / `end_date`）
- iOS `DashboardView` 展示4个真实指标卡片：总消耗、总点击、总展示、总转化

## Capabilities

### New Capabilities

- `platform-reporting`: 平台报表接口封装——Platform 接口新增 `GetReport()` 方法，TikTok 实现调用 v1.3 基础报表 API，聚合各广告主近7天核心指标

### Modified Capabilities

（无现有 spec 需要变更）

## Impact

- **后端**：`platform_interface.go`、`tiktok/client.go`（新增报表调用）、`stats/service.go`（聚合逻辑）、`stats/handler.go`（接口参数）、`model/dto/`（响应结构体）
- **iOS**：`Models/StatsModels.swift`、`Features/Dashboard/DashboardView.swift`、`Features/Dashboard/StatsService.swift`（或等价网络层）
- **API 接口**：`GET /stats` 新增 `start_date`、`end_date` 可选参数，响应 data 新增3个指标字段（向后兼容）
- **外部依赖**：TikTok Business Marketing API v1.3（需有效 access_token）
