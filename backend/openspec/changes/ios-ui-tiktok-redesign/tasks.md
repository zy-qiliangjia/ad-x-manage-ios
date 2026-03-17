## 1. 设计 Token & 通用组件

- [x] 1.1 新建 `Core/Theme/AppTheme.swift`，定义 Colors（primary、tiktokDark、tiktokRed、success、warning、danger、surface、background、border、textPrimary、textSecondary）、Spacing（xs/sm/md/lg/xl）、Radius（sm/md/lg/xl/pill）
- [x] 1.2 在 `AppTheme.swift` 中新增 `cardShadow()` ViewModifier 扩展
- [x] 1.3 新建 `Core/Theme/Components/PlatformBadgeView.swift`（TikTok/Kwai 平台标签小 badge）
- [x] 1.4 新建 `Core/Theme/Components/StatusBadgeView.swift`（活跃/暂停/异常状态 badge）
- [x] 1.5 新建 `Core/Theme/Components/ToastView.swift` + `ToastManager`（ObservableObject，MainTabView 注入）

## 2. Dashboard 重设计

- [x] 2.1 重写 `DashboardView.swift` 顶部 Header：Indigo→Purple 渐变背景，标题 + 设置图标
- [x] 2.2 在 Header 内添加平台筛选 Tab（全部 / TikTok），连接 `StatsService` platform 参数
- [x] 2.3 将 4 统计卡片改为 2×2 LazyVGrid，每卡片含图标、数值、标签，使用 AppTheme token
- [x] 2.4 集成 Swift Charts：新建 `DashboardChartView.swift`，BarMark 展示近 7 日消耗数据（mock 时序数据）
- [x] 2.5 在 `DashboardChartView` 中添加指标 tab 切换（消耗/展示/点击），动画过渡
- [x] 2.6 添加下拉刷新（`.refreshable`）重新请求 `/stats`

## 3. 账号列表重设计

- [x] 3.1 重写 `AdvertiserListView` 账号卡片（`AdvertiserCardView.swift`）：TikTok 头像（黑色渐变圆角+T）、账号名、ID、StatusBadge
- [x] 3.2 卡片底部三列数据行：本周消耗 / 推广系列数 / CTR，使用 AppTheme token
- [x] 3.3 将「添加账号」改为虚线边框按钮，点击弹出 Bottom Sheet（`.sheet` + `.presentationDetents([.height(280)])`）
- [x] 3.4 Bottom Sheet 内仅展示 TikTok 授权选项（图标+标题+描述），点击发起 OAuth
- [x] 3.5 左滑余额 sheet 改为 `.presentationDetents([.height(200)])` 样式

## 4. 广告管理重设计

- [x] 4.1 在 `AdsManageView.swift` 顶部添加横向滚动维度 Tab（账号/推广系列/广告组/广告），active 下划线指示器
- [x] 4.2 新建 `BreadcrumbView.swift`：显示当前钻取路径，节点可点击返回，current 节点不可点击
- [x] 4.3 将 BreadcrumbView 嵌入 AdsManageView 列表上方，钻取时自动追加
- [x] 4.4 新建 `AdsSummaryCardView.swift`：紫色渐变背景汇总卡片（消耗/点击/展示/转化/CPA）
- [x] 4.5 重写广告管理卡片（`AdsManageCardView.swift`）：PlatformBadge、名称、ID、Toggle 开关、五列数据、预算区
- [x] 4.6 预算 Bottom Sheet 改为 `.presentationDetents([.height(340)])`，含货币符号输入框 + 快捷金额按钮（500/1000/2000/5000 CNY）
- [x] 4.7 Toggle 开关添加确认 Alert（「确认[暂停/开启] X ？」），确认后调用 PATCH 接口
- [x] 4.8 卡片点击钻取区域与开关/预算按钮区域隔离（`.contentShape(Rectangle())` 仅在卡片主体，按钮单独处理 `onTapGesture` stopPropagation 等效）

## 5. 设置页重设计

- [x] 5.1 重写 `SettingsView.swift` 顶部：渐变圆角头像（首字母）、昵称、邮箱，居中排列
- [x] 5.2 用 `List` + `Section` 实现分组设置（「账号管理」/「其他」/「危险操作」）
- [x] 5.3 每个设置项：图标（`.background(AppTheme.Colors.background)` 圆角背景）+ 标题 + 描述 + 右箭头
- [x] 5.4 「退出登录」改为红色文字，点击弹出确认 Alert，确认后 `AppState.logout()`

## 6. MainTabView & 全局整合

- [x] 6.1 在 `MainTabView.swift` 顶层 ZStack 注入 `ToastView`，`EnvironmentObject` 传递 `ToastManager`
- [x] 6.2 将底部 Tab 图标替换为更贴合语义的 SF Symbols（chart.bar.xaxis / person.2 / rectangle.stack / gearshape）
- [x] 6.3 全局 `.tint` 从默认蓝色改为 `AppTheme.Colors.primary`（Indigo）
- [x] 6.4 Build & Run 验证 4 个 Tab 无编译错误，交互流程完整
