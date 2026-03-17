## Context

Tab3 的 `DimensionTabRow` 是一个纯展示组件，只标注当前层级，不接受任何点击事件。导航完全靠 `NavigationStack` + `AdsNav` push/pop 实现。

```
当前 AdsNav:
  .campaigns(AdvertiserListItem)
  .adGroups(advertiser:, campaign:)
  .ads(advertiser:, adgroup:)
```

现有 API 均要求 `advertiser_id`，无跨账号全量接口。

## Goals / Non-Goals

**Goals:**
- `DimensionTabRow` 变为可点击（新增 `onSelect` 回调）
- 从顶部 Tab 点击 → 全量模式（新增 3 个全量视图）
- 从账号钻入后 Tab 切换 → 账号作用域模式（不限 campaign 的广告组/广告）
- 后端新增 3 个全量接口，按 JWT user_id 过滤权限

**Non-Goals:**
- 不修改 Tab2 账号管理页的任何逻辑
- 全量视图中不支持修改预算/状态（只读列表 + 钻取）
- 不做跨账号批量操作

## Decisions

### 决策 1：`DimensionTabRow` 保持纯 UI，通过 `onSelect` 回调驱动导航

`DimensionTabRow` 只负责渲染，每个 Tab 点击触发 `onSelect(dim)`，由父视图决定如何导航。避免在通用组件里耦合路由逻辑。

### 决策 2：扩展 `AdsNav` 枚举而不是增加新的 NavigationStack

新增 `AdsNav` case：
```swift
case allCampaigns                           // 全量推广系列
case allAdGroups                            // 全量广告组
case allAds                                 // 全量广告
case adGroupsForAccount(AdvertiserListItem) // 账号作用域广告组
case adsForAccount(AdvertiserListItem)      // 账号作用域广告
```

这样复用现有的 `NavigationStack(path: $navPath)` 和 `.navigationDestination`，无需引入新的 NavStack 层级。

### 决策 3：Tab 点击时重置 navPath，再 push 目标 case

从账号层点击"推广系列"：`navPath = [.allCampaigns]`
从推广系列层（已在账号内）点击"广告组"：`navPath = [.campaigns(adv), .adGroupsForAccount(adv)]`（弹出 campaign，保留账号上下文）

实际实现更简单：各层的 `DimensionTabRow.onSelect` 根据当前所处层级和是否有账号上下文来决定 push 什么。

### 决策 4：后端全量接口返回结构与现有分页接口完全相同

`GET /campaigns?platform=&keyword=&page=&page_size=`
`GET /adgroups?platform=&keyword=&page=&page_size=`
`GET /ads?platform=&keyword=&page=&page_size=`

响应复用现有 `campaigns` / `adgroups` / `ads` 的 JSON 结构和分页格式，iOS 侧只需新 `APIEndpoint` case，ViewModel 复用现有 model。

### 决策 5：全量视图为只读，不展示预算编辑和状态开关

全量视图跨账号，预算/状态操作需要账号上下文（access token）。只读列表 + 点击钻入到该条目所属账号的子层级，从而复用现有操作入口。

## Risks / Trade-offs

- [风险] 全量接口在账号多时数据量大 → 后端强制分页（page_size 最大 50），iOS 保持下拉加载更多
- [风险] `navPath` 重置会丢失返回上下文 → 面包屑不再完整；但这是全量视图的预期行为，有"返回" chevron 可回到账号列表
- [取舍] 账号作用域跨层跳转（`.adGroupsForAccount`）需要后端支持不带 `campaign_id` 的广告组查询 → 现有 `GET /advertisers/:id/adgroups` 已支持（`campaign_id` 可选）
