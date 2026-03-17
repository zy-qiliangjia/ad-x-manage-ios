## Why

广告管理 Tab3 的账号层级卡片（`AdsAccountCardView`）目前仅展示账号名称、ID 和状态徽章，用户必须先钻取进入推广系列层才能操作预算和开关。对于只需要快速调整某个账号整体投放状态或预算上限的场景，需要额外的操作步骤，体验不如推广系列/广告组层级一致。

## What Changes

- **`AdsAccountCardView` 重设计**：从简单行卡片改为与 `CampaignManageCard` 风格一致的富卡片，展示消耗指标、预算、状态开关和预算编辑按钮
- **`AdvertiserListItem` 模型扩展**：新增 `spend`、`budget`、`budgetMode` 字段（后端需同步返回）
- **后端新增广告主预算接口**：`PATCH /advertisers/:id/budget`
- **后端新增广告主状态接口**：`PATCH /advertisers/:id/status`
- **`AdsManageListViewModel` 扩展**：新增 `budgetTarget`、`statusConfirmTarget`、`updatingStatusID` 状态，以及 `updateBudget` / `updateStatus` 方法
- **`AdvertiserService` 扩展**：新增 `updateBudget` / `updateStatus` 方法

## Capabilities

### New Capabilities

- `advertiser-budget-update`: 广告主层级的预算修改接口及 iOS 调用链
- `advertiser-status-toggle`: 广告主层级的状态开启/暂停接口及 iOS 调用链

### Modified Capabilities

无（账号卡片 UI 是纯新增功能，无现有 spec 需要 delta）

## Impact

- iOS：`AdsManageView.swift`（`AdsAccountCardView` + ViewModel）、`AdvertiserModels.swift`、`AdvertiserService.swift`
- 后端：需新增两个 PATCH 路由（与现有 campaign/adgroup 接口结构相同）
