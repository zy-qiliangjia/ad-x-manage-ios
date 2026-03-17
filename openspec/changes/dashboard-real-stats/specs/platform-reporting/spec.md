## ADDED Requirements

### Requirement: Platform 接口支持报表查询
Platform 接口 SHALL 新增 `GetReport(ctx, accessToken, advertiserID, startDate, endDate string) (*ReportResult, error)` 方法。`ReportResult` 包含 `Spend`、`Clicks`、`Impressions`、`Conversions` 四个 float64 字段，代表指定日期范围内的聚合汇总值。

#### Scenario: TikTok 报表查询成功
- **WHEN** 调用 `TikTokClient.GetReport()` 并传入有效 token、advertiserID 及日期范围
- **THEN** 调用 TikTok `POST /open_api/v1.3/report/advertiser/get/`，data_level=AUCTION_ADVERTISER，汇总多天数据，返回 spend/click/show/conversion 合计值

#### Scenario: Kwai 报表查询（占位）
- **WHEN** 调用 `KwaiClient.GetReport()` 传入任意参数
- **THEN** 返回 `ReportResult{Spend:0, Clicks:0, Impressions:0, Conversions:0}`，不返回 error

### Requirement: /stats 接口支持日期范围参数
`GET /stats` SHALL 接受可选查询参数 `start_date`（YYYY-MM-DD）和 `end_date`（YYYY-MM-DD）。若未传，默认值为近7天（today-6 至 today）。

#### Scenario: 传入日期范围
- **WHEN** 请求 `GET /stats?start_date=2025-03-01&end_date=2025-03-07`
- **THEN** 报表聚合仅覆盖该日期区间内的数据

#### Scenario: 不传日期参数
- **WHEN** 请求 `GET /stats`（不含日期参数）
- **THEN** 后端默认使用近7天（今天往前推6天到今天）

### Requirement: /stats 接口聚合真实报表指标
`GET /stats` SHALL 并发调用当前用户下所有活跃广告主的 `GetReport()`，将结果聚合到响应中。响应 data 字段 SHALL 包含 `total_spend`（实时）、`total_clicks`、`total_impressions`、`total_conversions`。

#### Scenario: 多广告主聚合
- **WHEN** 用户有3个活跃广告主（2个 TikTok，1个 Kwai）
- **THEN** 并发调用3次 GetReport，将 spend/clicks/impressions/conversions 分别求和后返回

#### Scenario: 部分广告主报表失败
- **WHEN** 某个广告主的 GetReport 调用因 token 过期失败
- **THEN** 跳过该广告主，返回其余广告主的聚合数据；不因单个失败导致整个接口报错

#### Scenario: Redis 缓存命中
- **WHEN** 同一用户在5分钟内重复请求相同日期范围的 /stats
- **THEN** 直接返回 Redis 缓存数据，不重复调用平台 API

### Requirement: iOS StatsOverview 模型扩展
iOS `StatsOverview` SHALL 新增 `totalClicks`、`totalImpressions`、`totalConversions` 字段（Int 或 Double），并能正常解码后端响应中新增的字段。

#### Scenario: 接收新指标字段
- **WHEN** 后端返回包含 `total_clicks`、`total_impressions`、`total_conversions` 的 JSON
- **THEN** iOS 解码后 `StatsOverview` 对应字段不为0或nil

#### Scenario: 向后兼容
- **WHEN** 后端响应不包含新字段（旧版本）
- **THEN** iOS 解码不崩溃，新字段使用默认值0

### Requirement: iOS DashboardView 展示4个真实指标
`DashboardView` SHALL 在数据加载后展示4个统计卡片：总消耗（spend）、总点击（clicks）、总展示（impressions）、总转化（conversions）。数据来源为后端 `/stats` 接口，加载时显示加载状态，失败时展示错误提示。

#### Scenario: 首页加载真实数据
- **WHEN** 用户登录后进入 Tab1（数据概览），或下拉刷新
- **THEN** 调用 `/stats?start_date=<7天前>&end_date=<今天>`，加载完成后4张卡片显示真实数值

#### Scenario: 平台筛选
- **WHEN** 用户选择 "TikTok" 平台筛选
- **THEN** 请求 `/stats?platform=tiktok&start_date=...&end_date=...`，仅展示 TikTok 广告主的聚合数据
