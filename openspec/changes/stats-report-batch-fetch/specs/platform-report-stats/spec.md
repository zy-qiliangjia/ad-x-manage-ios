## MODIFIED Requirements

### Requirement: Advertiser IDs sourced from local database
系统 SHALL 从本地 `advertisers` 表按 `user_id` 和 `platform` 查询所有有效（status=1）的 `advertiser_id`，用于传入 Report API 请求。

获取到 advertiser_id 列表后，SHALL 按每批最多 5 个分批调用平台 Report API（受平台单次限制约束），各批次结果在服务层累加为最终汇总值。

#### Scenario: Multiple advertisers split into batches and aggregated
- **WHEN** 用户在某平台下绑定了多个广告主
- **THEN** 广告主 ID 列表被切分为每批 ≤ 5 个，逐批调用 Report API，各批次 `total_metrics` 累加后返回全量汇总的 `ReportStats`

#### Scenario: 5 or fewer advertisers use single request
- **WHEN** 用户绑定的广告主数量 ≤ 5
- **THEN** 直接发起 1 次 API 请求，行为与分批前一致

#### Scenario: No advertisers returns zero stats
- **WHEN** 用户在指定平台下没有绑定任何广告主
- **THEN** 返回全零的 `ReportStats{}`，接口正常响应

### Requirement: TikTok GetReportStats returns total_metrics
TikTok `GetReportStats` 实现 SHALL 将 advertiserIDs 列表分批（每批 ≤5）顺序调用 `GET /open_api/v1.3/report/integrated/get`，各批次请求均包含 `data_level=AUCTION_ADVERTISER`、`report_type=BASIC`、`dimensions=["advertiser_id"]`、`metrics=["spend","conversion","clicks","impressions"]`、`enable_total_metrics=true`，解析每批响应的 `data.total_metrics` 并累加，最终返回聚合后的 `ReportStats`。

#### Scenario: TikTok batches all sent with correct parameters
- **WHEN** 调用 TikTok `GetReportStats`，传入有效的 accessToken 和多个 advertiserIDs
- **THEN** 每批请求包含 `enable_total_metrics=true`，`advertiser_ids` 字段为该批次的 ID 数组（≤5 个）

#### Scenario: Batch responses aggregated into single ReportStats
- **WHEN** 多批次调用均成功返回
- **THEN** 所有批次的 `total_metrics` 各字段数值求和，作为 `GetReportStats` 的返回值

#### Scenario: Single batch advertiser IDs within limit
- **WHEN** advertiserIDs 列表共 3 个
- **THEN** 仅发起 1 次 API 请求，参数 `advertiser_ids=["id1","id2","id3"]`

#### Scenario: GetReportStats handles empty advertiserIDs
- **WHEN** 传入空的 advertiserIDs 列表
- **THEN** 直接返回 `ReportStats{}` 零值，不发起 API 请求

#### Scenario: GetReportStats handles platform API error
- **WHEN** 任一批次 API 返回非 0 code 或网络错误
- **THEN** 返回 error，调用方可映射到错误码 1003
