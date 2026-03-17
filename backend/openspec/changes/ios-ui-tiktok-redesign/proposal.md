## Why

当前 iOS 版本 UI 使用 SwiftUI 默认样式，无设计系统，颜色/间距散落各处，视觉层次薄弱。HTML 参考稿（ad-manager-mobile.html）已实现更完善的交互模式和视觉规范，iOS 版需对齐，提升使用体感和专业度。当前阶段聚焦 TikTok 平台。

## What Changes

- 新增 `AppTheme.swift` 设计 token 文件（品牌色、语义色、间距、圆角、阴影）
- Dashboard 重设计：渐变 Header + TikTok 平台 tab + 4 统计卡片（含涨跌幅）+ Swift Charts 趋势图
- 账号列表重设计：TikTok 风格头像、状态 badge（活跃/暂停/错误）、底部三列数据行
- 广告管理重设计：层级维度 tab + 面包屑导航 + 汇总卡片 + 卡片内预算编辑区
- 设置页重设计：头像 + 渐变 banner + 分组列表样式
- 通用组件：Toast、Bottom Sheet 动画、Toggle 开关、Platform Badge、Search Bar

## Capabilities

### New Capabilities

- `design-tokens`: 集中式设计 token（AppTheme），覆盖颜色、间距、圆角、阴影、排版
- `dashboard-ui`: 渐变 header + 平台筛选 tab + 统计卡片网格 + Swift Charts 趋势折线图
- `account-list-ui`: 账号卡片重设计，含平台头像、状态 badge、本周消耗/系列数/CTR 三列
- `ads-manage-ui`: 维度切换 tab + 面包屑 + 汇总摘要卡片 + 管理卡片（预算区、开关、钻取提示）
- `settings-ui`: 渐变头像 banner + 分组设置列表

### Modified Capabilities

（无 spec 级行为变更，仅 UI 层重设计）

## Impact

- **iOS 文件**：ContentView、MainTabView、DashboardView、AdvertiserListView、AdsManageView、SettingsView、AdGroupTab、AdTab、CampaignTab、以及各 Detail 子视图
- **新增文件**：`Core/Theme/AppTheme.swift`
- **后端**：无需改动（仅前端 UI 调整）
- **数据库**：无 schema 变更
- **平台范围**：本期只处理 TikTok 平台的样式和交互（Kwai 后续跟进）
