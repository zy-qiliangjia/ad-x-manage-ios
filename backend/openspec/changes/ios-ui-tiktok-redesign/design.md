## Context

iOS 端当前使用 SwiftUI 原生默认样式，无设计系统，颜色/间距内联散落。HTML 参考稿（ad-manager-mobile.html）已定义完整的 design token 体系和交互规范（渐变 header、卡片阴影、bottom sheet、面包屑、趋势图）。本次设计目标是将参考稿的视觉层次和交互模式移植到 SwiftUI，不改变任何后端接口和业务逻辑。

## Goals / Non-Goals

**Goals:**
- 建立 `AppTheme.swift`，集中管理颜色、间距、圆角、阴影
- 按参考稿重设计 Dashboard、账号列表、广告管理、设置四个主要模块
- TikTok 平台专属品牌色（接近黑色 #010101 + 红 #FE2C55）贯穿全局
- Swift Charts 实现趋势图（折线/柱状）
- 所有交互使用 SwiftUI 原生动画（sheet slideUp、toggle、toast）

**Non-Goals:**
- 不改动后端 API 及数据模型
- 不新增 Kwai 平台 UI（本期跳过）
- 不做深色模式适配
- 不改动 OAuth 流程逻辑

## Decisions

### D1: 设计 Token 集中在 AppTheme.swift

**决策**：新建 `Core/Theme/AppTheme.swift`，用 `enum AppTheme` 作命名空间，所有颜色/间距以 `static let` 暴露。

**原因**：SwiftUI 无原生 CSS 变量机制，用 enum 命名空间可防止实例化，比 extension Color 更易维护。

**备选**：extension Color / extension View — 分散且难于集中更新。

---

### D2: 趋势图使用 Swift Charts（iOS 16+）

**决策**：Dashboard 趋势图用 `Charts` 框架 `BarMark` + `LineMark`，指标 tab 切换（消耗/展示/点击/CTR）。

**原因**：原生框架，无第三方依赖，动画流畅，与 SwiftUI 状态绑定一致。

**备选**：第三方 DGCharts — 引入依赖，包体积增大。

---

### D3: Bottom Sheet 使用 `.sheet` + 自定义 presentationDetents

**决策**：预算编辑、余额查看等弹窗用 `.presentationDetents([.height(320)])` + `.presentationDragIndicator(.visible)` 实现 iOS 16 原生 bottom sheet。

**原因**：参考稿 `slideUp` 动画效果，SwiftUI 原生方案零成本，且支持手势拖拽关闭。

---

### D4: Toast 用 ZStack overlay 实现

**决策**：在 `MainTabView` 顶层注入 `ToastView`，通过 `@Environment` 注入的 `ToastManager` 控制显隐。

**原因**：全局 toast 需浮在所有页面之上，ZStack overlay 是 SwiftUI 最简洁方案。

---

### D5: 面包屑导航保留现有 NavigationStack 架构

**决策**：AdsManageView 的层级钻取维持现有 NavigationStack + NavigationLink 方案，在顶部追加 `BreadcrumbView` 组件显示当前路径，不改为自定义状态机。

**原因**：当前 NavigationStack 已工作正常，只需在 toolbar/subheader 区域补充面包屑 UI，无需重构导航逻辑。

## Risks / Trade-offs

- [Swift Charts 图表数据] 当前后端 `/stats` 接口不返回每日时序数据 → **缓解**：趋势图数据可用本地 mock 或在 Dashboard 单独调用支持时序的 stats 接口（后续扩展）；本期用静态趋势数据展示 UI 效果，不影响主功能。
- [presentationDetents 版本兼容] iOS 16.4+ 才支持 `.fraction`，但 iOS 16 已支持 `.height` → **缓解**：只用 `.height(x)` 形式，与最低版本 iOS 16 兼容。
- [AppTheme 全局替换工作量] 存量 View 内联颜色较多 → **缓解**：分模块逐步替换，按 tasks 分任务，不强求一次完成全部 View 的 token 替换。

## Migration Plan

1. 先创建 `AppTheme.swift`（无副作用）
2. 从 Dashboard 开始，逐 Tab 替换
3. 通用组件（Toast、Badge、BreadcrumbView）单独提取，避免重复
4. 每个 Tab 独立可 build，不影响其他模块
5. 无后端变更，无需数据库迁移，无部署风险
