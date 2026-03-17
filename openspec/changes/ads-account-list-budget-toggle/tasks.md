## 1. 数据模型扩展

- [x] 1.1 在 `AdvertiserListItem` 中新增 `spend: Double`、`budget: Double`、`budgetMode: String` 字段，CodingKeys 映射 `spend`、`budget`、`budget_mode`，默认值均为 0 / ""
- [x] 1.2 在 `APIEndpoint` 中新增 `.advertiserBudget(id: Int)` 和 `.advertiserStatus(id: Int)` 端点（PATCH 方法）

## 2. 网络层扩展

- [x] 2.1 在 `AdvertiserService` 中新增 `updateBudget(id:budget:)` 方法，调用 `PATCH /advertisers/:id/budget`
- [x] 2.2 在 `AdvertiserService` 中新增 `updateStatus(id:action:)` 方法，调用 `PATCH /advertisers/:id/status`

## 3. ViewModel 扩展

- [x] 3.1 在 `AdsManageListViewModel` 中新增 `@Published var budgetTarget: AdvertiserListItem?`、`@Published var statusConfirmTarget: AdvertiserListItem?`、`@Published var updatingStatusID: UInt64?`
- [x] 3.2 实现 `updateBudget(item:budget:)` async 方法：调用 service，成功后刷新 items 中对应条目
- [x] 3.3 实现 `updateStatus(item:action:)` async 方法：设置 `updatingStatusID`，调用 service，完成后清空，失败时展示错误并回滚

## 4. 账号卡片 UI 重设计

- [x] 4.1 将 `AdsAccountCardView` 改为三段式富卡片：顶部（平台 avatar + 账号名/ID + 状态 loading/toggle）、中部（消耗 + 预算指标行）、底部（调整预算按钮 + 进入推广系列按钮）
- [x] 4.2 卡片接收 `isUpdating: Bool`、`onBudget: () -> Void`、`onToggle: () -> Void`、`onDrill: () -> Void` 四个回调参数

## 5. 账号列表视图接线

- [x] 5.1 在 `AdsManageView` 的 `ForEach` 中将 `AdsAccountCardView` 调用更新为新签名，传入对应回调（onBudget / onToggle / onDrill = navPath.append）
- [x] 5.2 在 `AdsManageView` 中添加 `.sheet(item: $vm.budgetTarget)` 绑定，展示 `BudgetEditSheet`
- [x] 5.3 在 `AdsManageView` 中添加 `.confirmationDialog(...)` 绑定 `vm.statusConfirmTarget`，确认后调用 `vm.updateStatus`
