## MODIFIED Requirements

### Requirement: Chart X-axis displays actual dates
首页趋势图的横坐标 SHALL 显示具体日期，而非星期名称。

`ChartDataPoint` MUST 使用 `date: Date` 字段替换原有的 `label: String` 字段。

Mock 数据 MUST 通过 `Calendar.current` 动态生成最近 7 天的日期（含今天），而非硬编码星期名称。

X 轴标签 MUST 以 `M/d` 格式（月/日）展示，例如 `3/11`、`3/12`。

#### Scenario: Chart renders with date X-axis
- **WHEN** 用户进入首页 Dashboard
- **THEN** 趋势图 X 轴显示最近 7 天的日期（如 3/11、3/12 … 3/17），而非周一至周日

#### Scenario: Each day has exactly one bar
- **WHEN** 趋势图渲染完成
- **THEN** X 轴恰好包含 7 个刻度，每个对应一天，不省略任何刻度

#### Scenario: Today is the rightmost data point
- **WHEN** Mock 数据生成
- **THEN** 最后一个数据点的日期等于当天（`Calendar.current.startOfDay(for: Date())`）
