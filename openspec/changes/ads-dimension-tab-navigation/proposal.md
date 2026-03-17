## Why

Tab3 广告管理页的顶部维度标签栏（账号 / 推广系列 / 广告组 / 广告）目前仅起标记当前层级的作用，无法直接点击跳转，用户必须逐层钻取才能查看推广系列/广告组/广告的全量数据，操作路径过长。

## What Changes

- **`DimensionTabRow` 变为可交互组件**：新增 `onSelect: (AdsDimension) -> Void` 回调，每个 Tab 可点击
- **双模式数据范围**：
  - 从顶部 Tab 点击进入 → **全量模式**：展示所有账号下的推广系列 / 广告组 / 广告
  - 从账号卡片钻入后点击 Tab → **账号作用域模式**：展示当前账号下的数据
- **新增全量列表视图**：`AdsAllCampaignsView`、`AdsAllAdGroupsView`、`AdsAllAdsView`
- **新增账号作用域跨层级跳转**：从推广系列层直接跳到"该账号的全部广告组"（不限定 campaign），或"该账号的全部广告"
- **后端新增全量查询接口**：`GET /campaigns`、`GET /adgroups`、`GET /ads`（支持 `platform` 和 `keyword` 过滤 + 分页）
- **`AdsNav` 枚举新增全量 case**：`.allCampaigns`、`.allAdGroups`、`.allAds`、`.adGroupsForAccount(AdvertiserListItem)`、`.adsForAccount(AdvertiserListItem)`

## Capabilities

### New Capabilities

- `dimension-tab-interactive`: `DimensionTabRow` 变为可点击的交互组件，支持回调
- `global-dimension-views`: 三个全量列表视图（推广系列/广告组/广告的跨账号全量查询）
- `account-scoped-cross-level`: 在账号作用域内跨层级切换（不限定 campaign 的广告组 / 广告列表）

### Modified Capabilities

无

## Impact

- iOS：`BreadcrumbView.swift`（`DimensionTabRow`）、`AdsManageView.swift`（导航逻辑 + 新视图）、`APIEndpoint.swift`、`AdDetailService.swift`
- 后端：新增 `GET /campaigns`、`GET /adgroups`、`GET /ads` 全量接口（无 advertiser_id 限定，按 JWT user_id 过滤）
