## ADDED Requirements

### Requirement: Advertiser IDs split into batches of at most 5
`GetReportStats` 实现 SHALL 将传入的 advertiserIDs 列表按每批最多 5 个切分，逐批顺序调用 TikTok Report API。

#### Scenario: Exactly 5 or fewer IDs sent in one request
- **WHEN** advertiserIDs 列表共 5 个或以下
- **THEN** 只发起 1 次 API 请求，所有 ID 包含在该请求的 `advertiser_ids` 参数中

#### Scenario: More than 5 IDs split into multiple batches
- **WHEN** advertiserIDs 列表共 13 个
- **THEN** 发起 3 次 API 请求：第 1 批 5 个、第 2 批 5 个、第 3 批 3 个

#### Scenario: Batch size constant is 5
- **WHEN** 平台限制变更需要调整批次大小
- **THEN** 只需修改 tiktok 实现层的 `batchSize = 5` 常量，无需改动其他逻辑

### Requirement: Request rate limited to at most 10 calls per second
批次调用之间 SHALL 间隔至少 100ms，确保调用频率不超过 10 次/秒。首批调用无需等待。

#### Scenario: Rate limit delay applied between batches
- **WHEN** 发起第 2 批及后续批次请求前
- **THEN** 等待 100ms 后再发出请求

#### Scenario: Single batch requires no delay
- **WHEN** 所有 advertiserIDs ≤ 5 个，只有 1 个批次
- **THEN** 直接发出请求，不插入任何 sleep

### Requirement: Metrics accumulated across all batches
各批次响应的 `total_metrics` SHALL 在服务层逐字段累加，得到全量汇总的 `ReportStats`。

#### Scenario: Spend accumulated correctly
- **WHEN** 第 1 批 total_metrics.spend = "3.00"，第 2 批 = "2.57"
- **THEN** 最终 ReportStats.Spend = 5.57（float64 累加）

#### Scenario: Integer metrics accumulated correctly
- **WHEN** 第 1 批 total_metrics.clicks = "40"，第 2 批 = "28"
- **THEN** 最终 ReportStats.Clicks = 68（int64 累加）

#### Scenario: Any batch error stops accumulation
- **WHEN** 第 2 批 API 调用返回错误
- **THEN** 立即返回 error，丢弃已累加的第 1 批数据，不返回部分汇总

### Requirement: Batch intermediate results cached per batch
每批请求的 `total_metrics` 结果 SHALL 单独缓存到 Redis，TTL 15 分钟，key 格式：`stats:report:batch:{platform}:{start_date}:{end_date}:{sorted_ids}`，其中 `sorted_ids` 为该批次 advertiser_id 升序排列后以逗号拼接的字符串。

#### Scenario: Batch cache hit skips API call
- **WHEN** 同一批次（相同 platform + date range + sorted_ids）在 15 分钟内已有缓存
- **THEN** 直接读取缓存数据，不调用 TikTok API，将缓存值加入累加器继续处理下一批

#### Scenario: Batch cache miss stores result after API call
- **WHEN** 某批次无缓存
- **THEN** 调用 TikTok API 成功后，将该批次 total_metrics 写入 Redis（TTL 15 分钟），再加入累加器

#### Scenario: Batch cache key is user-independent
- **WHEN** 两个不同用户的请求中包含相同的广告主 ID 批次及相同日期范围
- **THEN** 共享同一批次缓存 key，均可命中缓存，避免重复调用平台 API
