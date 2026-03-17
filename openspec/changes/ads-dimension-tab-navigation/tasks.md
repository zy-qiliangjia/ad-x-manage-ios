## 1. DimensionTabRow 交互化

- [x] 1.1 给 `DimensionTabRow` 添加 `onSelect: (AdsDimension) -> Void` 参数，每个维度 tab 改为 `Button`，点击触发 `onSelect(dim)`
- [x] 1.2 更新所有调用 `DimensionTabRow` 的地方（`AdsManageView`、`AdsCampaignView`、`AdsAdGroupView`），传入 `onSelect` 闭包（暂时为空 `{}` 占位，后续步骤填充逻辑）

## 2. AdsNav 枚举扩展

- [x] 2.1 在 `AdsNav` 中新增 `.allCampaigns`、`.allAdGroups`、`.allAds`、`.adGroupsForAccount(AdvertiserListItem)`、`.adsForAccount(AdvertiserListItem)` 五个 case
- [x] 2.2 在 `AdsManageView` 的 `.navigationDestination(for: AdsNav.self)` 中为新 case 添加占位（返回 `EmptyView()`，后续替换为真实视图）

## 3. 后端及网络层（全量接口）

- [x] 3.1 在 `APIEndpoint` 中新增 `.allCampaigns`、`.allAdGroups`、`.allAds` case（GET 方法）
- [x] 3.2 在 `AdDetailService` 中新增 `allCampaigns(platform:keyword:page:pageSize:)`、`allAdGroups(platform:keyword:page:pageSize:)`、`allAds(platform:keyword:page:pageSize:)` 方法

## 4. 全量列表视图

- [x] 4.1 创建 `AdsAllCampaignsView`（读取 `allCampaigns` 接口，平台筛选 + 分页 + 下拉刷新，点击进入 `.adGroups(advertiser:campaign:)`，从 `CampaignItem.advertiserID` 查找对应 `AdvertiserListItem`）
- [x] 4.2 创建 `AdsAllAdGroupsView`（读取 `allAdGroups` 接口，平台筛选 + 分页 + 下拉刷新，点击进入 `.ads(advertiser:adgroup:)`）
- [x] 4.3 创建 `AdsAllAdsView`（读取 `allAds` 接口，关键词搜索 + 平台筛选 + 分页 + 下拉刷新，只读行展示）
- [x] 4.4 将步骤 2.2 中的占位 `EmptyView` 替换为真实视图（`.allCampaigns → AdsAllCampaignsView`，`.allAdGroups → AdsAllAdGroupsView`，`.allAds → AdsAllAdsView`）

## 5. 账号作用域跨层级视图

- [x] 5.1 创建 `AdsAdGroupsForAccountView`：调用 `AdDetailService.adGroups(advertiserID:campaignID:0:page:)` 不传 campaignID，支持预算编辑和状态开关，点击进入 `.ads(advertiser:adgroup:)`
- [x] 5.2 创建 `AdsAdsForAccountView`：调用 `AdDetailService.ads(advertiserID:adgroupID:0:keyword:page:)` 不传 adgroupID，支持关键词搜索，只读行
- [x] 5.3 在 `.navigationDestination` 中为 `.adGroupsForAccount → AdsAdGroupsForAccountView` 和 `.adsForAccount → AdsAdsForAccountView` 绑定真实视图

## 6. 各层 Tab 导航逻辑接线

- [x] 6.1 `AdsManageView`（账号层）`onSelect`：账号 → no-op，其他三个 → `navPath = [对应全量 case]`
- [x] 6.2 `AdsCampaignView`（推广系列层）`onSelect`：账号 → `navPath.removeAll()`，推广系列 → no-op，广告组 → `navPath.append(.adGroupsForAccount(advertiser))`，广告 → `navPath.append(.adsForAccount(advertiser))`
- [x] 6.3 `AdsAdGroupView`（广告组层）`onSelect`：账号 → `navPath.removeAll()`，推广系列 → `navPath.removeLast()`，广告组 → no-op，广告 → `navPath.append(.adsForAccount(advertiser))`
- [x] 6.4 全量视图（`AdsAllCampaignsView` 等）中的 `DimensionTabRow` `onSelect`：账号 → `navPath.removeAll()`，其他全量 → `navPath = [对应 case]`，同层 → no-op
