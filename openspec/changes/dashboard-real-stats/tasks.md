## 1. 后端 Platform 接口扩展

- [x] 1.1 在 `platform.go` 中新增 `ReportResult` 结构体（字段：`Spend float64`、`Clicks float64`、`Impressions float64`、`Conversions float64`），并在 `Client` 接口中新增 `GetReport(ctx context.Context, accessToken, advertiserID, startDate, endDate string) (*ReportResult, error)` 方法

## 2. TikTok 报表实现

- [x] 2.1 在 `tiktok/client.go` 中实现 `GetReport()`：调用 `POST /open_api/v1.3/report/advertiser/get/`，请求体包含 `advertiser_id`、`data_level=AUCTION_ADVERTISER`、`dimensions=["advertiser_id","stat_time_day"]`、`metrics=["spend","show","click","conversion"]`、`start_date`、`end_date`，对返回的 `data.list` 各行的指标求和后返回 `ReportResult`

## 3. Kwai 报表占位实现

- [x] 3.1 在 `kwai/client.go` 中实现 `GetReport()`：直接返回 `&platform.ReportResult{}`（全零），不报错

## 4. 后端 Stats 服务重构

- [x] 4.1 更新 `stats/service.go` 中的 `OverviewResult` 结构体，新增 `TotalClicks float64 json:"total_clicks"`、`TotalImpressions float64 json:"total_impressions"`、`TotalConversions float64 json:"total_conversions"` 字段
- [x] 4.2 更新 `stats/service.go` 中 `service` 结构体，添加 `clients map[string]platform.Client`、`tokenRepo tokenrepo.Repository`、`encryptKey string` 依赖；更新 `New()` 构造函数签名以接收这三个参数
- [x] 4.3 在 `stats/service.go` 的 `Overview()` 方法中新增 `startDate`、`endDate string` 参数；对查出的每个广告主并发调用 `GetReport()`（复用 `SyncService.getValidAccessToken()` 类似的 token 获取逻辑）；将各广告主报表结果累加到 `TotalClicks`、`TotalImpressions`、`TotalConversions`；`TotalSpend` 改为来自报表（替换原 DB 查询的 spend 汇总）
- [x] 4.4 更新 `stats/service.go` 中 `Service` 接口，将 `Overview` 方法签名改为 `Overview(ctx context.Context, userID uint64, platform, startDate, endDate string) (*OverviewResult, error)`

## 5. 后端 Handler 与路由更新

- [x] 5.1 更新 `handler/stats/handler.go`：从 query string 读取 `start_date` 和 `end_date`（若空则默认近7天，格式 `2006-01-02`），将其传给 `svc.Overview()`
- [x] 5.2 更新 `router/router.go`：`statssvc.New()` 调用传入 `clients`（已有 map）、`tokenRepo`（从已有依赖中取）、`encryptKey`（从 `cfg.AppEncryptKey` 取）

## 6. iOS 模型扩展

- [x] 6.1 更新 `Models/StatsModels.swift` 中 `StatsOverview`：新增 `totalClicks: Double`、`totalImpressions: Double`、`totalConversions: Double` 字段（`CodingKeys` 对应 `total_clicks`、`total_impressions`、`total_conversions`），使用 `decodeIfPresent ?? 0` 保持向后兼容

## 7. iOS 网络层扩展

- [x] 7.1 更新 `StatsService.swift` 中 `overview()` 方法：新增 `startDate`、`endDate` 参数（默认值为近7天，用 `Calendar.current` 计算，格式 `yyyy-MM-dd`），将 `start_date` / `end_date` 加入 query params 传给 API

## 8. iOS Dashboard 视图更新

- [x] 8.1 更新 `DashboardView.swift` 中 `DashboardViewModel.load()`：调用 `service.overview()` 时传入 `startDate`、`endDate`（今天往前7天）
- [x] 8.2 更新 `DashboardView.swift` 中 `statsGrid()` 展示4张真实指标卡片：总消耗（`ov.totalSpend`，保留原逻辑）、总点击（`ov.totalClicks`，icon `cursorarrow.click.2`，色 `.blue`）、总展示（`ov.totalImpressions`，icon `eye.fill`，色 `.indigo`）、总转化（`ov.totalConversions`，icon `star.fill`，色 `.orange`），将原活跃广告主卡片和系列/广告组计数卡片替换为新指标（或扩展为6卡片网格，按实际设计决定）
