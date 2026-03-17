## ADDED Requirements

### Requirement: 渐变 Header + 平台筛选 tab
Dashboard 顶部 SHALL 展示从 Indigo → Purple 的线性渐变 Header，内含「全部 / TikTok」平台筛选 tab（本期只显示 TikTok，不展示 Kwai），选中 tab 为白色背景+主色文字，未选中为半透明白色。

#### Scenario: 默认显示全部平台
- **WHEN** 进入 Dashboard
- **THEN** 「全部」tab 高亮，统计数据显示全部广告主汇总

#### Scenario: 切换到 TikTok 筛选
- **WHEN** 用户点击「TikTok」tab
- **THEN** 统计卡片数据更新为仅 TikTok 平台数据

### Requirement: 4 统计卡片网格
Dashboard SHALL 在 Header 下方以 2×2 网格展示统计卡片：总消耗、活跃广告主、推广系列数、广告组数，每张卡片包含图标、数值、标签。

#### Scenario: 统计数据正常加载
- **WHEN** Dashboard 完成 API 请求
- **THEN** 4 张卡片显示实际数值，加载中显示 ProgressView

#### Scenario: 下拉刷新
- **WHEN** 用户下拉页面
- **THEN** 重新请求 `/stats` 并刷新卡片数值

### Requirement: Swift Charts 趋势图
Dashboard SHALL 展示近 7 日消耗趋势图（BarChart），含「消耗/展示/点击」指标 tab 切换，横轴为日期标签，纵轴为数值。

#### Scenario: 指标 tab 切换
- **WHEN** 用户点击「消耗」「展示」「点击」tab
- **THEN** 图表数据和 Y 轴单位随之更新，动画过渡

#### Scenario: 无趋势数据时
- **WHEN** 趋势接口不可用或返回空
- **THEN** 显示占位文案「暂无趋势数据」，不崩溃
