## Why

首页趋势图的横坐标目前显示的是中文星期名称（周一、周二…），无法让用户直观感知具体日期，在跨周查看时尤其容易产生歧义。将横坐标改为实际日期（如 3/11、3/12）可以提升数据可读性。

## What Changes

- `ChartDataPoint` 的 `label: String` 改为 `date: Date`，使图表直接绑定到日期值
- Mock 数据从固定星期名称改为动态生成最近 7 天的日期
- `BarMark` 的 X 轴绑定从字符串改为 `Date` 类型，使用 Swift Charts 原生日期格式化
- X 轴标签格式化为 `M/d`（如 3/11），简洁且无歧义

## Capabilities

### New Capabilities

无新能力（仅 UI 展示层调整）

### Modified Capabilities

- `dashboard-chart`: 横坐标数据类型由 `String`（星期名）改为 `Date`（具体日期）

## Impact

- 仅影响 `DashboardChartView.swift` 中的 `ChartDataPoint` 结构体和 mock 数据生成逻辑
- 不涉及后端接口、网络层、其他视图
