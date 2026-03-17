## Context

账号卡片（AdvertiserCardView）右上角使用 SwiftUI 的 `Text(date, style: .relative)`，该组件会每秒自动触发 UI 刷新，导致整个列表视图周期性重绘抖动。AdvertiserListViewModel 在 `load()` 中通过 fire-and-forget Task 调用 `syncAll()`，syncAll 完成后不更新数据，但其异步副作用在某些情况下会触发 list 刷新（如通知机制）。

## Goals / Non-Goals

**Goals:**
- 彻底消除卡片相对时间组件带来的周期性重绘
- ID 截断展示，保留末 6 位，适配长 ID
- 移除 `hasSyncedOnce` + `syncAll()` 首次加载逻辑

**Non-Goals:**
- 不改变手动同步（右滑/contextMenu）功能
- 不改变同步状态 spinner（isSyncing）逻辑

## Decisions

### D1: 同步时间改为静态文案
不再展示 syncedAt 的相对时间，改为仅在 syncedAt 非 nil 时显示「已同步」固定文案（带时钟图标）。若需要具体时间可长按/tooltip，但本次不做。

### D2: ID 截断逻辑
`advertiserID.suffix(6)` 取末 6 位，前加 `…`，展示为 `…XXXXXX`。若 ID 长度 ≤ 6 则直接显示完整 ID。

### D3: 移除 syncAll 副作用
直接删除 `hasSyncedOnce` 属性和 `load()` 中的 `Task { try? await service.syncAll() }` 代码块。

## Risks / Trade-offs

- 去掉相对时间后用户无法知道同步了多久前 → 可接受，减少抖动体验更重要
- 移除自动 syncAll 后首次进入不会触发后台同步 → 数据仍来自上次本地同步，用户可手动同步，属预期行为
