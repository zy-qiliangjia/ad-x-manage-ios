## ADDED Requirements

### Requirement: Platform interface exposes GetReportStats method
Platform 接口 SHALL 新增 `GetReportStats` 方法，接受 accessToken、advertiserID 列表、start_date、end_date，返回汇总的报表指标（spend、conversion、clicks、impressions）。

#### Scenario: TikTok GetReportStats returns total_metrics
- **WHEN** 调用 TikTok `GetReportStats`，传入有效的 accessToken 和非空的 advertiserIDs 列表
- **THEN** 系统向 TikTok `GET /open_api/v1.3/report/integrated/get` 发起请求，参数包含 `data_level=AUCTION_ADVERTISER`、`report_type=BASIC`、`dimensions=["advertiser_id"]`、`metrics=["spend","conversion","clicks","impressions"]`、`enable_total_metrics=true`
- **THEN** 解析响应 `data.total_metrics`，返回 `ReportStats{Spend, Conversion, Clicks, Impressions}`

#### Scenario: Kwai GetReportStats returns zero placeholder
- **WHEN** 调用 Kwai `GetReportStats`
- **THEN** 返回 `ReportStats{}` 零值（接口预留，不报错），待 Kwai API 完整适配后实现

#### Scenario: GetReportStats handles empty advertiserIDs
- **WHEN** 传入空的 advertiserIDs 列表
- **THEN** 直接返回 `ReportStats{}` 零值，不发起 API 请求

#### Scenario: GetReportStats handles platform API error
- **WHEN** 平台 API 返回非 0 code 或网络错误
- **THEN** 返回 error，调用方可映射到错误码 1003

### Requirement: Report API date range defaults to last 30 days
服务层 SHALL 在调用 `GetReportStats` 时，以当前 UTC 日期为 end_date，往前 30 天为 start_date（格式 `YYYY-MM-DD`）。

#### Scenario: Date range computed correctly
- **WHEN** stats 服务调用 GetReportStats
- **THEN** start_date = today(UTC) - 30 days，end_date = today(UTC)，均格式化为 `YYYY-MM-DD`

### Requirement: Report stats results cached in Redis
系统 SHALL 将 `GetReportStats` 的结果缓存到 Redis，TTL 15 分钟，key 格式：`stats:report:{user_id}:{platform}:{start_date}:{end_date}`。

#### Scenario: Cache hit returns cached value
- **WHEN** 相同 user_id + platform + date_range 在 15 分钟内已有缓存
- **THEN** 直接返回缓存数据，不调用平台 API

#### Scenario: Cache miss triggers API call and stores result
- **WHEN** 缓存不存在或已过期
- **THEN** 调用平台 API，将结果写入 Redis（TTL 15 分钟），再返回数据

### Requirement: Advertiser IDs sourced from local database
系统 SHALL 从本地 `advertisers` 表按 `user_id` 和 `platform` 查询所有有效（status=1）的 `advertiser_id`，用于传入 Report API 请求。

#### Scenario: Multiple advertisers aggregated
- **WHEN** 用户在某平台下绑定了多个广告主
- **THEN** 所有广告主 ID 批量传入 Report API，`total_metrics` 返回所有广告主汇总值

#### Scenario: No advertisers returns zero stats
- **WHEN** 用户在指定平台下没有绑定任何广告主
- **THEN** 返回全零的 `ReportStats{}`，接口正常响应

### Requirement: Platform supports access token lookup for report calls
系统 SHALL 在调用平台 Report API 前，从 `platform_tokens` 表取当前用户对应平台的有效 access_token（已解密）。

#### Scenario: Valid token found and used
- **WHEN** 用户有对应平台的有效 token（status=1，未过期）
- **THEN** 使用该 token 调用 Report API

#### Scenario: No valid token returns error
- **WHEN** 用户没有对应平台的有效 token
- **THEN** 返回错误，接口返回错误码 1005（需重新授权）
