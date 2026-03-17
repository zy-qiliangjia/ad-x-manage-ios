## Context

`DashboardChartView` 目前使用 `ChartDataPoint { label: String, value: Double }` 存储趋势图数据，并以中文星期名（周一…周日）作为 X 轴标签。这种方式固定了时间语义，在跨周场景下无法判断具体日期。

## Goals / Non-Goals

**Goals:**
- 将图表 X 轴标签改为实际日期（格式 `M/d`，如 `3/11`）
- Mock 数据动态生成为最近 7 天，而非固定星期名

**Non-Goals:**
- 接入真实后端时序接口（仍保留 Mock 数据）
- 修改图表类型、颜色、Y 轴、指标切换逻辑

## Decisions

### 决策 1：使用 `Date` 替换 `String` 作为 X 轴数据类型

`BarMark(x: .value("日期", point.date))` 配合 `.chartXAxis { AxisMarks(values: .stride(by: .day)) }` 可以让 Swift Charts 原生处理日期刻度，无需手动格式化每个标签。

替代方案：保留 `String`，将其改为日期字符串（如 "3/11"）。但这会丢失 `Date` 类型带来的原生刻度对齐能力，且排序依赖字符串顺序，不可靠。

### 决策 2：Mock 数据使用 `Calendar.current` 动态计算最近 7 天

```swift
let today = Calendar.current.startOfDay(for: Date())
// 生成 today-6 ... today 共 7 个 Date
```

这样每次启动 App 都能看到正确的最近 7 天日期，无需手动维护。

### 决策 3：X 轴标签格式 `M/d`

使用 `AxisMarks(format: .dateTime.month().day())` 输出如 `3/11`，简洁且与用户常见日期习惯一致。

## Risks / Trade-offs

- [风险] Swift Charts 日期轴在 7 个数据点时可能自动省略部分刻度 → 通过 `AxisMarks(values: .stride(by: .day, count: 1))` 固定每天显示一个刻度来缓解
- [取舍] 使用 `Date` 而非 `String` 后，未来接入真实接口时，接口返回的数据需要解析为 `Date`，但这是更正确的方向
