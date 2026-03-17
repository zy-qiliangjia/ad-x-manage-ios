## MODIFIED Requirements

### Requirement: 推广系列列表响应包含广告主上下文字段
后端推广系列列表接口（`GET /api/v1/advertisers/:id/campaigns` 和全量接口）的 `CampaignItem` 响应体 SHALL 包含以下字段：
- `advertiser_id`（uint64）：所属广告主数据库 ID
- `advertiser_name`（string）：广告主名称
- `platform`（string）：平台标识 `tiktok` | `kwai`
- `clicks`（int64）：点击数，默认 0
- `impressions`（int64）：展示数，默认 0
- `conversions`（int64）：转化数，默认 0

#### Scenario: 单广告主下推广系列列表包含广告主字段
- **WHEN** 客户端请求 `GET /api/v1/advertisers/1/campaigns`
- **THEN** 响应中每个 campaign 对象包含 `advertiser_id=1`、`advertiser_name` 和 `platform` 字段

#### Scenario: 全量推广系列列表包含广告主字段
- **WHEN** 客户端请求全量推广系列接口（`GET /api/v1/campaigns`）
- **THEN** 每个 campaign 对象包含 `advertiser_id`、`advertiser_name`、`platform`，iOS 可据此构造正确的 AdvertiserListItem 用于下钻导航

#### Scenario: 推广系列列表包含指标字段
- **WHEN** 客户端请求任意推广系列列表接口
- **THEN** 每个 campaign 对象包含 `clicks`、`impressions`、`conversions` 字段（未同步时值为 0）

---

### Requirement: 广告组列表响应包含广告主上下文字段
后端广告组列表接口的 `AdGroupItem` 响应体 SHALL 同样包含：
- `advertiser_id`（uint64）
- `advertiser_name`（string）
- `platform`（string）
- `clicks`（int64）
- `impressions`（int64）
- `conversions`（int64）

#### Scenario: 全量广告组列表包含广告主字段
- **WHEN** 客户端请求全量广告组接口（`GET /api/v1/adgroups`）
- **THEN** 每个 adgroup 对象包含 `advertiser_id`、`advertiser_name`、`platform`，iOS 可据此下钻到广告列表

#### Scenario: 广告组列表包含指标字段
- **WHEN** 客户端请求任意广告组列表接口
- **THEN** 每个 adgroup 对象包含 `clicks`、`impressions`、`conversions` 字段

---

### Requirement: iOS CampaignItem / AdGroupItem 模型解码新字段
iOS `CampaignItem` 和 `AdGroupItem` 模型 SHALL 解码 `clicks`、`impressions`、`conversions` 字段（缺失时默认 0）。

#### Scenario: 模型解码兼容旧响应
- **WHEN** 后端返回的 JSON 中不包含 `clicks` 字段（旧版本兼容）
- **THEN** iOS 模型解码时 `clicks` 默认为 0，不报错

#### Scenario: 模型解码新字段
- **WHEN** 后端返回包含 `clicks`, `impressions`, `conversions` 的 JSON
- **THEN** iOS 模型正确解码这些值，传递给 AdsSummaryCardView 展示
