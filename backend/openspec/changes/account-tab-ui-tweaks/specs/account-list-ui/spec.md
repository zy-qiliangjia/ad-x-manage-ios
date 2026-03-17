## MODIFIED Requirements

### Requirement: 账号卡片同步时间显示
卡片右上角 SHALL 在 syncedAt 非 nil 时仅显示固定文案「已同步」（带时钟图标），不使用 `Text(date, style: .relative)` 相对倒计时组件。同步中状态（isSyncing）仍显示 ProgressView。

#### Scenario: 有同步时间时显示静态文案
- **WHEN** advertiser.syncedAt 非 nil 且未在同步中
- **THEN** 右上角显示时钟图标 + 「已同步」文案，不随时间跳动刷新

#### Scenario: 同步中显示 spinner
- **WHEN** isSyncing 为 true
- **THEN** 显示 ProgressView，不显示同步文案

#### Scenario: 从未同步
- **WHEN** syncedAt 为 nil 且 isSyncing 为 false
- **THEN** 右上角不显示任何内容（或显示「未同步」）

### Requirement: 广告主 ID 截断展示
卡片中的广告主 ID SHALL 只显示末 6 位，格式为 `…XXXXXX`；若 ID 长度 ≤ 6 则完整显示。

#### Scenario: 长 ID 截断
- **WHEN** advertiserID 长度 > 6
- **THEN** 显示 `…` + 末 6 位字符

#### Scenario: 短 ID 完整显示
- **WHEN** advertiserID 长度 ≤ 6
- **THEN** 完整显示 advertiserID

### Requirement: 不自动触发后台全量同步
ViewModel 首次加载 SHALL 不再自动调用 `syncAll()`，避免异步副作用导致列表刷新抖动。

#### Scenario: 进入账号列表
- **WHEN** AdvertiserListView 首次出现，触发 load()
- **THEN** 仅请求广告主列表，不触发后台 syncAll
