## 1. 数据库迁移与文档

- [x] 1.1 创建 `docs/` 目录并新建 `docs/db-migrations.md`，记录 campaigns / ad_groups 表新增 clicks / impressions / conversions 列的 ALTER TABLE SQL 语句及回滚方案
- [x] 1.2 更新后端 entity：`entity.Campaign` 和 `entity.AdGroup` 添加 `Clicks`、`Impressions`、`Conversions` 字段（GORM 标签 `bigint not null default 0`）

## 2. 后端：列表 DTO 补充字段

- [x] 2.1 更新 `dto.CampaignItem`：添加 `AdvertiserID`、`AdvertiserName`、`Platform`、`Clicks`、`Impressions`、`Conversions` 字段
- [x] 2.2 更新 `dto.AdGroupItem`：添加 `AdvertiserID`、`AdvertiserName`、`Platform`、`Clicks`、`Impressions`、`Conversions` 字段
- [x] 2.3 更新 campaign service 的 `toCampaignItem()` 函数，JOIN advertisers 表填充 `AdvertiserID`、`AdvertiserName`、`Platform`，并映射 `Clicks`/`Impressions`/`Conversions`
- [x] 2.4 更新 adgroup service 的 `toAdGroupItem()` 函数，同上补充广告主上下文字段和指标字段
- [x] 2.5 更新 campaign/adgroup repository 全量查询方法，确保 AdvertiserName / Platform 有值（service 层关联广告主）

## 3. 后端：stats/summary 接口

- [x] 3.1 在 `internal/handler/stats/handler.go` 中新增 `Summary` 方法，解析 `scope`、`scope_id`、`date_from`、`date_to` 参数，调用 service
- [x] 3.2 在 `internal/service/stats/service.go` 新增 `Summary` 方法和 `SummaryResult` 结构体（含 Spend/Clicks/Impressions/Conversions/LastUpdatedAt）
- [x] 3.3 实现三种 scope 聚合逻辑：advertiser（SUM campaigns）、campaign（SUM adgroups）、adgroup（读取单行），支持 date_from/date_to 过滤（WHERE updated_at BETWEEN）
- [x] 3.4 在 router 注册路由 `GET /api/v1/stats/summary`（需 JWT 鉴权）

## 4. 后端：stats 接口支持日期过滤

- [x] 4.1 `GET /api/v1/stats` 的 `Overview` 已支持 `start_date` / `end_date` query 参数

## 5. iOS：模型更新

- [x] 5.1 更新 `CampaignModels.swift` 中的 `CampaignItem`：添加 `clicks`、`impressions`、`conversions` 字段（`Int`，`decodeIfPresent` 默认 0）
- [x] 5.2 更新 `CampaignModels.swift` 中的 `AdGroupItem`：同上添加三个指标字段
- [x] 5.3 `StatsModels.swift` 添加 `StatsSummary` 结构体：`spend`, `clicks`, `impressions`, `conversions`, `lastUpdatedAt`（可选 String）

## 6. iOS：StatsService 新增 summary 方法

- [x] 6.1 在 `StatsService.swift` 新增 `summary(scope:scopeID:dateFrom:dateTo:)` 方法，调用 `GET /api/v1/stats/summary`
- [x] 6.2 在 `APIEndpoint.swift` 新增 `.statsSummary` case
- [x] 6.3 `StatsService.overview()` 已支持 `startDate`、`endDate` 参数

## 7. iOS：日期筛选 UI 组件

- [x] 7.1 新建 `DateRangeFilter` 枚举（today / yesterday / last7days / last30days）和对应的 `dateFrom`/`dateTo` 计算属性
- [x] 7.2 新建 `DateRangeTabView` SwiftUI 组件：水平横排4个胶囊按钮，选中高亮

## 8. iOS：AdsSummaryCardView 接入真实数据

- [x] 8.1 修改 `AdsSummaryCardView`，在汇总卡片顶部嵌入 `DateRangeTabView`，接受 `dateFilter: Binding<DateRangeFilter>` 和 `isLoadingSummary: Bool` 参数
- [x] 8.2 修改 `AdsManageListViewModel`：新增 `dateFilter`、`overview`、`summaryLoading`；`dateFilter` 变化时重新拉取 overview 数据
- [x] 8.3 修改 `CampaignListViewModel`：新增 `dateFilter`、`summary`、`summaryLoading`；scope=advertiser
- [x] 8.4 修改 `AdGroupListViewModel`：新增 `dateFilter`、`summary`、`summaryLoading`；scope=campaign（有 campaignID 时）
- [x] 8.5 修改 `AdListViewModel` + `AdsAdView`：新增汇总卡片，scope=adgroup
- [x] 8.6 将各层级真实的 spend/clicks/impressions/conversions 传入 `AdsSummaryCardView` 替换原来的硬编码 0

## 9. iOS：导航栏更新时间展示

- [x] 9.1 在各层级 ViewModel 中新增 `lastUpdatedLabel: String?` 属性，从 summary 接口 `last_updated_at` 解析为 HH:mm
- [x] 9.2 在 `AdsCampaignView`、`AdsAdGroupView`、`AdsAdView` 导航栏右上角 ToolbarItem 展示"更新于 HH:mm"，加载中时显示 ProgressView
- [x] 9.3 在 `DashboardView` header 展示"更新于 HH:mm"（客户端侧时间戳）

## 10. iOS：修复全量视图下钻报错

- [x] 10.1 `AdsAllCampaignsView` 中构造 `AdvertiserListItem` 时使用后端返回的 `item.advertiserID`、`item.advertiserName`、`item.platform`（后端现已返回这些字段）
- [x] 10.2 `AdsAllAdGroupsView` 中构造 `AdvertiserListItem` 时同上

## 11. 验证与文档

- [x] 11.1 `docs/db-migrations.md` 包含完整 ALTER TABLE 语句、执行说明和回滚 SQL
- [ ] 11.2 测试全量视图（推广系列/广告组维度）点击下钻不再报错
- [ ] 11.3 测试 AdsSummaryCardView 切换日期选项后数据刷新
- [ ] 11.4 测试导航栏更新时间在加载/空数据/有数据三种状态下显示正确
