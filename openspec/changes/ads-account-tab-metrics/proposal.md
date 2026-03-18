## Why

账号管理列表目前只展示账号基本信息，用户无法在列表层面快速了解各广告主的投放表现（消耗、点击、展示、转化、CPA、日预算），需要逐个进入详情才能查看数据，操作效率低。增加指标展示和日期筛选功能，可让用户一目了然地对比多个账号的投放效果，提升管理效率。

## What Changes

- 账号列表每行新增指标展示：消耗（spend）、点击（clicks）、展示（impressions）、转化（conversion）、CPA（cost_per_conversion / skan_click_time_cost_per_conversion）、日预算（daily_budget）
- 新增自定义日期筛选器，默认近7天，日期跨度最多30天
- 新增汇总行，展示当前筛选范围内所有广告主的指标合计
- 后端新增广告主报表批量拉取接口（每次最多5个广告主），支持 TikTok 平台
- 接口结果 Redis 缓存（按 platform + advertiser_ids + date_range 作为 key），缓存5分钟
- 未拉取到数据的广告主指标默认显示0
- iOS 客户端在账号列表拉取数据时按批次（每批5个）并发请求，合并结果后展示

## Capabilities

### New Capabilities

- `advertiser-stats-report`: 按广告主批量拉取报表指标（消耗/点击/展示/转化/CPA），支持日期区间，每批最多5个广告主，带缓存；对应后端新接口 `GET /stats/report`
- `account-list-metrics-ui`: iOS 账号列表页新增指标卡片展示、日期筛选器、汇总行

### Modified Capabilities

## Impact

- **后端**：`internal/handler/stats/`、`internal/service/stats/`、`internal/service/platform/tiktok/` 新增报表查询逻辑；`internal/router/router.go` 新增路由
- **iOS**：`AdvertiserListView`、对应 ViewModel 更新；新增日期选择器组件；网络层新增报表批量请求方法
- **缓存**：新增 Redis key 规则 `stats:report:{platform}:{date_range}:{sorted_advertiser_ids}`
- **无破坏性变更**（Kwai 平台暂不实现，预留接口扩展点）
