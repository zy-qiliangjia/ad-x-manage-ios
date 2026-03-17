## Why

账号 Tab 有三个小体验问题：同步时间显示为"相对倒计时"（每秒跳动导致页面抖动），广告主 ID 完整展示过长，以及 `AdvertiserListViewModel.load()` 在首次进入时触发后台 `syncAll()` 导致列表数据刷新抖动。

## What Changes

- 去除卡片右上角的相对时间倒计时（`Text(syncedAt, style: .relative)`），改为固定的"已同步"文案或不显示
- 广告主 ID 只显示后 6 位（加 `…` 前缀），避免长 ID 占用卡片空间
- 去除 `AdvertiserListViewModel.load()` 中首次触发 `syncAll()` 的逻辑，消除页面自动刷新抖动

## Capabilities

### New Capabilities

（无新能力，均为 UI 细节调整）

### Modified Capabilities

- `account-list-ui`：卡片同步时间显示、ID 截断、自动同步副作用移除

## Impact

- **iOS 文件**：`AdvertiserListView.swift`（AdvertiserCardView）、`AdvertiserListViewModel.swift`
- **后端/数据库**：无变更
