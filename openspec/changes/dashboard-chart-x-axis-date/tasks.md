## 1. 修改数据模型

- [x] 1.1 将 `ChartDataPoint` 的 `label: String` 字段替换为 `date: Date`

## 2. 更新 Mock 数据

- [x] 2.1 用 `Calendar.current` 动态生成最近 7 天日期，替换原有的硬编码星期名称 Mock 数据（三个指标均需更新）

## 3. 更新图表渲染

- [x] 3.1 将 `BarMark` 的 `x: .value("日期", point.label)` 改为 `x: .value("日期", point.date)`
- [x] 3.2 配置 `chartXAxis`，使用 `AxisMarks(values: .stride(by: .day, count: 1))` 固定每天一个刻度，并用 `.dateTime.month().day()` 格式化为 `M/d`
