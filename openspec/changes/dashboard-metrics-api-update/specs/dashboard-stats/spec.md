## MODIFIED Requirements

### Requirement: GET /stats returns platform report metrics
`GET /stats` 接口 SHALL 返回从平台 Report API 汇总的 4 项指标：spend（总消耗）、conversion（转化）、clicks（点击）、impressions（展示）。

原有字段 `active_advertisers`、`campaign_count`、`adgroup_count` SHALL 被移除。

#### Scenario: All platforms stats
- **WHEN** 请求 `GET /stats`（不传 platform 参数或 `platform=all`）
- **THEN** 分别调用 TikTok 和 Kwai 的 `GetReportStats`，将两个平台的结果数值相加，返回合并汇总

#### Scenario: Single platform stats
- **WHEN** 请求 `GET /stats?platform=tiktok`
- **THEN** 仅调用 TikTok `GetReportStats`，返回该平台的汇总数据

#### Scenario: Stats response structure
- **WHEN** 请求 `GET /stats` 成功
- **THEN** 响应 `data` 字段包含：
  ```json
  {
    "spend": 5.57,
    "conversion": 0,
    "clicks": 68,
    "impressions": 1017
  }
  ```
  spend 为 float64，其余为 int64

#### Scenario: Platform API unavailable falls back to cached data
- **WHEN** 平台 Report API 调用失败但 Redis 有缓存
- **THEN** 返回缓存数据，HTTP 200，不暴露平台错误给客户端

#### Scenario: No data returns zero values
- **WHEN** 用户无绑定广告主或平台 API 返回空数据
- **THEN** 返回 `{"spend":0,"conversion":0,"clicks":0,"impressions":0}`，HTTP 200

## ADDED Requirements

### Requirement: iOS Dashboard displays new 4 metric cards
iOS DashboardView SHALL 展示 4 个指标卡片：总消耗（spend）、转化（conversion）、点击（clicks）、展示（impressions），替换原有的活跃广告主/推广系列数/广告组数卡片。

#### Scenario: Dashboard shows correct metric labels
- **WHEN** Dashboard 页面加载完成
- **THEN** 显示 4 张卡片，标题分别为"总消耗"、"转化"、"点击"、"展示"，数值从 `/stats` 接口读取

#### Scenario: Dashboard respects platform filter
- **WHEN** 用户切换平台筛选（全部 / TikTok / Kwai）
- **THEN** 重新请求 `/stats?platform=<selected>`，更新 4 个卡片数值

#### Scenario: Spend displayed with decimal formatting
- **WHEN** spend 为浮点数（如 5.57）
- **THEN** 显示时保留 2 位小数，其余整数指标显示整数
