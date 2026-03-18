## MODIFIED Requirements

### Requirement: GET /stats returns platform report metrics
`GET /stats` 接口 SHALL 返回从平台 Report API 汇总的 4 项指标：spend（总消耗）、conversion（转化）、clicks（点击）、impressions（展示）。

原有字段 `active_advertisers`、`campaign_count`、`adgroup_count` SHALL 被移除。

接口 SHALL 接受可选查询参数 `start_date` 和 `end_date`（`YYYY-MM-DD`）；缺省时默认近 30 天。

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

#### Scenario: Custom date range applied
- **WHEN** 请求 `GET /stats?start_date=2026-03-01&end_date=2026-03-10`
- **THEN** 使用指定日期范围调用平台 Report API，返回对应时段的指标汇总

#### Scenario: Default date range when params absent
- **WHEN** 请求 `GET /stats` 未传 start_date / end_date
- **THEN** 使用近 30 天作为日期范围，行为与调整前完全一致

#### Scenario: Platform API unavailable falls back to cached data
- **WHEN** 平台 Report API 调用失败但 Redis 有缓存
- **THEN** 返回缓存数据，HTTP 200，不暴露平台错误给客户端

#### Scenario: No data returns zero values
- **WHEN** 用户无绑定广告主或平台 API 返回空数据
- **THEN** 返回 `{"spend":0,"conversion":0,"clicks":0,"impressions":0}`，HTTP 200

### Requirement: iOS Dashboard displays new 4 metric cards
iOS DashboardView SHALL 展示 4 个指标卡片：总消耗（spend）、转化（conversion）、点击（clicks）、展示（impressions），替换原有的活跃广告主/推广系列数/广告组数卡片。

DashboardView SHALL 在卡片区域上方提供日期区间选择器，支持快捷选项和自定义范围。

#### Scenario: Dashboard shows correct metric labels
- **WHEN** Dashboard 页面加载完成
- **THEN** 显示 4 张卡片，标题分别为"总消耗"、"转化"、"点击"、"展示"，数值从 `/stats` 接口读取

#### Scenario: Dashboard respects platform filter
- **WHEN** 用户切换平台筛选（全部 / TikTok / Kwai）
- **THEN** 重新请求 `/stats?platform=<selected>`，更新 4 个卡片数值

#### Scenario: Spend displayed with decimal formatting
- **WHEN** spend 为浮点数（如 5.57）
- **THEN** 显示时保留 2 位小数，其余整数指标显示整数

## ADDED Requirements

### Requirement: iOS Dashboard provides date range selector
DashboardView SHALL 在平台筛选器旁/下方提供日期区间选择控件，包含以下选项：
- 最近 7 天（快捷）
- 最近 14 天（快捷）
- 最近 30 天（快捷，默认选中）
- 自定义（触发双 DatePicker Sheet）

选择后 SHALL 立即以新日期参数重新请求 `/stats`。

#### Scenario: Quick option triggers stats reload
- **WHEN** 用户点击"最近 7 天"快捷选项
- **THEN** 计算 start_date = today-7、end_date = today，发起 `GET /stats?start_date=...&end_date=...`，更新卡片数据

#### Scenario: Custom date picker opens on selection
- **WHEN** 用户点击"自定义"
- **THEN** 弹出包含开始日期 / 结束日期两个 DatePicker 的 Sheet

#### Scenario: Default quick option selected on load
- **WHEN** Dashboard 页面首次加载
- **THEN** 日期选择器默认选中"最近 30 天"

### Requirement: iOS validates custom date range before request
iOS DashboardView 的自定义日期 Sheet SHALL 在用户选择日期时实时计算跨度，若超过 30 天则禁用"确认"按钮并展示 inline 提示"日期范围不能超过 30 天"。

#### Scenario: Valid custom range enables confirm
- **WHEN** 用户在 Sheet 内选择 start_date = 2026-03-01、end_date = 2026-03-20（19 天）
- **THEN** 确认按钮可点击，无提示文字

#### Scenario: Excessive range disables confirm
- **WHEN** 用户在 Sheet 内选择跨度超过 30 天的日期
- **THEN** 确认按钮置灰，显示 inline 提示"日期范围不能超过 30 天"

#### Scenario: Confirming custom range closes sheet and reloads
- **WHEN** 用户点击确认按钮（日期合法）
- **THEN** Sheet 关闭，以自定义日期参数发起 `/stats` 请求，更新卡片
