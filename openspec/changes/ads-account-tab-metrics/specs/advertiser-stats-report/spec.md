## ADDED Requirements

### Requirement: 批量广告主报表查询接口
后端 SHALL 提供 `GET /api/v1/stats/report` 接口，接收 `platform`、`advertiser_ids`（逗号分隔）、`start_date`、`end_date` 参数，返回每个广告主的指标数据（spend、clicks、impressions、conversion、cost_per_conversion、skan_click_time_cost_per_conversion）及汇总（total_metrics）。

#### Scenario: 正常批量查询
- **WHEN** 客户端传入 platform=tiktok、10个 advertiser_id、合法日期区间
- **THEN** 服务端将广告主拆分为2批（每批≤5个），并发调用 TikTok 报表接口，合并结果，返回 code=0 及每个广告主的指标 JSON

#### Scenario: 部分广告主无数据
- **WHEN** 某广告主在指定日期范围内无投放记录，TikTok 接口未返回该广告主数据
- **THEN** 该广告主的所有指标字段返回 "0"，不影响其他广告主数据返回

#### Scenario: 日期区间超过30天
- **WHEN** end_date - start_date > 30天
- **THEN** 接口返回 code=1002（参数校验失败），message 说明最大跨度限制

### Requirement: 报表结果 Redis 缓存
服务端 SHALL 对每个广告主的报表结果按 `stats:report:{platform}:{advertiser_id}:{start_date}:{end_date}` 为 key 进行 Redis 缓存，TTL 为5分钟（加随机抖动 ±30秒）。

#### Scenario: 缓存命中
- **WHEN** 同一广告主、同一日期区间在5分钟内被第二次查询
- **THEN** 直接返回 Redis 缓存数据，不调用 TikTok 平台接口

#### Scenario: 部分缓存命中
- **WHEN** 10个广告主中6个已有缓存，4个无缓存
- **THEN** 仅对4个未缓存的广告主发起平台 API 请求，缓存命中的6个直接取缓存，最终合并返回

### Requirement: Kwai 平台报表预留扩展
当 platform=kwai 时，接口 SHALL 返回所有广告主指标全为 "0" 的占位数据，不报错，不调用 Kwai 平台接口。

#### Scenario: Kwai 平台请求
- **WHEN** 客户端传入 platform=kwai 及广告主列表
- **THEN** 接口返回 code=0，每个广告主指标均为 "0"，total_metrics 同为 "0"

### Requirement: TikTok 报表接口适配
服务端 TikTok platform 服务 SHALL 实现 `GetAdvertiserReport(accessToken, advertiserIDs []string, startDate, endDate string)` 方法，调用 TikTok `/open_api/v1.3/report/integrated/get` 接口（data_level=AUCTION_ADVERTISER，report_type=BASIC），并映射返回字段到统一 DTO。

#### Scenario: TikTok 接口调用成功
- **WHEN** 传入有效 access_token 和 ≤5个 advertiser_id
- **THEN** 解析返回 JSON，将 list 中每条记录按 dimensions.advertiser_id 匹配，返回对应指标 DTO

#### Scenario: TikTok 接口返回错误
- **WHEN** TikTok 接口返回非0 code（如 token 失效）
- **THEN** 服务返回 code=1003（平台 API 调用失败），iOS 显示错误提示，指标显示 "0"
