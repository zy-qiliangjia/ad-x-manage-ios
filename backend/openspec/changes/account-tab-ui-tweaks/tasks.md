## 1. AdvertiserCardView UI 调整

- [x] 1.1 将卡片右上角 `Text(syncedAt, style: .relative)` 相对时间改为静态「已同步」文案（图标 `clock.arrow.circlepath` + 文字「已同步」）
- [x] 1.2 将卡片中 `"ID: \(advertiser.advertiserID)"` 改为截断展示：末 6 位加 `…` 前缀，6 位及以下完整显示

## 2. AdvertiserListViewModel 副作用清理

- [x] 2.1 删除 `hasSyncedOnce` 属性及 `load()` 中触发 `syncAll()` 的 Task 代码块
