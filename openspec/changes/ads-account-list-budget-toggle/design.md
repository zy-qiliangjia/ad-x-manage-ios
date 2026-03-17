## Context

Tab3 广告管理的账号层（`AdsManageView`）使用 `AdsAccountCardView` 展示账号列表。目前该卡片仅有导航功能（点击进入推广系列）。推广系列层（`CampaignManageCard`）和广告组层（`AdGroupManageCard`）已有完整的预算编辑和状态开关功能，设计和实现可直接复用。

后端现有 `PATCH /campaigns/:id/budget`、`PATCH /campaigns/:id/status` 接口，需新增结构相同的广告主层级接口。

## Goals / Non-Goals

**Goals:**
- 账号卡片展示消耗金额、当前预算、状态开关
- 点击"调整预算"弹出 `BudgetEditSheet` 并调用新后端接口
- 状态切换弹出二次确认后调用新后端接口
- 后端新增 `PATCH /advertisers/:id/budget` 和 `PATCH /advertisers/:id/status`
- `AdvertiserListItem` 新增 `spend`、`budget`、`budgetMode` 字段

**Non-Goals:**
- 不聚合展示推广系列/广告组的子级指标（仅展示广告主自身字段）
- 不修改账号列表的分页或搜索逻辑
- 不修改账号详情（`AccountDetailView`）内的任何页面

## Decisions

### 决策 1：复用 CampaignManageCard 的卡片布局结构

`AdsAccountCardView` 改为与 `CampaignManageCard` 相同的三段式卡片：顶部（名称 + 状态开关）、中部（消耗 + 预算指标行）、底部（调整预算按钮 + 进入推广系列按钮）。不另起一套设计，保持 Tab3 各层级视觉一致性。

### 决策 2：budgetMode 统一沿用现有字符串约定

`budget_mode` 使用与 campaign/adgroup 相同的 `BUDGET_MODE_INFINITE` / `BUDGET_MODE_DAY` 字符串，便于复用 `budgetModeLabel` extension 和 `BudgetEditSheet`。

### 决策 3：状态开关使用 confirmationDialog 二次确认，与 campaign 层保持一致

避免误触。确认后乐观更新 UI 并调用接口，失败时回滚并展示错误提示。

### 决策 4：ViewModel 内 updateStatus / updateBudget 方法直接内联在 AdsManageListViewModel

不新建独立 ViewModel，与现有 `CampaignListViewModel` 中的模式保持一致，减少层级。

## Risks / Trade-offs

- [风险] 后端广告主层级的 budget/status 接口实际含义需与平台 API 对齐（TikTok/Kwai 是否支持广告主级别的预算设置）→ 后端团队确认后再联调；iOS 侧可先完成 UI，接口调用用 stub 占位
- [取舍] `AdvertiserListItem` 新增字段后，如果后端旧接口不返回这些字段，模型解码会得到默认值（0 / ""），UI 降级展示为"--"或不限，不会崩溃
