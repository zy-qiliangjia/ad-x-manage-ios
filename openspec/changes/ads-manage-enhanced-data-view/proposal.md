## Why

广告管理页（Tab3）的维度切换（账号/推广系列/广告组/广告）后，汇总卡片的点击/展示/转化数据始终为 0，因为后端列表接口缺少这些指标字段，且跨账号全量视图切换时会因 `advertiser_id = 0` 导致下钻导航报错。同时 Dashboard 和广告管理页均缺少日期筛选和数据更新时间展示，影响数据可读性。

## What Changes

- **修复跨层级导航报错**：后端推广系列/广告组列表响应中补充 `advertiser_id`、`advertiser_name`、`platform` 字段，确保全量视图（allCampaigns / allAdGroups）点击下钻时能构造正确的广告主对象
- **补充展示指标字段**：数据库 `campaigns` 和 `ad_groups` 表新增 `clicks`、`impressions`、`conversions` 列；后端 DTO 和列表 API 响应中暴露这些字段；同步逻辑中写入平台返回的真实数据
- **新增汇总统计接口**：`GET /api/v1/stats/summary` 支持按广告主/推广系列/广告组维度聚合消耗、点击、展示、转化，供各层级汇总卡片使用
- **日期筛选支持**：`/api/v1/stats` 和 `/api/v1/stats/summary` 接口支持 `date_from` / `date_to` 参数；iOS 各层级页面顶部/导航栏提供日期快捷选择（今天/昨天/近7天/近30天）
- **更新时间展示**：统计接口返回 `last_updated_at` 字段（取该范围内最近一条记录的 `updated_at`）；iOS 导航栏右上角显示"更新于 HH:mm"
- **SQL 变更文档**：所有数据库结构变更记录到 `docs/db-migrations.md`

## Capabilities

### New Capabilities
- `ads-stats-summary`: 按层级聚合广告指标的汇总统计 API（消耗/点击/展示/转化），支持日期过滤
- `ads-date-filter`: iOS 广告管理页各层级的日期范围快捷筛选 UI 及参数传递
- `ads-update-time`: 各层级页面右上角展示数据最后更新时间

### Modified Capabilities
- `ads-manage-list-data`: 推广系列和广告组列表响应增加 `advertiser_id`、`advertiser_name`、`platform`、`clicks`、`impressions`、`conversions` 字段，修复全量视图下钻报错

## Impact

- **后端**：`campaigns`、`ad_groups` 表结构变更（需数据库迁移）；campaign/adgroup DTO 扩展字段；新增 stats/summary handler+service；同步服务写入指标数据
- **iOS**：`CampaignItem`、`AdGroupItem` 模型补充新字段；`AdsSummaryCardView` 接入真实数据；各 View 添加日期选择器和更新时间组件
- **数据库迁移**：`docs/db-migrations.md` 记录 ALTER TABLE 语句
- **接口兼容性**：列表接口仅新增字段，向后兼容；stats/summary 为全新接口，无破坏性
