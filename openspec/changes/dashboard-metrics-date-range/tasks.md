## 1. 后端：移除服务层固定日期计算

- [ ] 1.1 修改 `internal/service/stats/` 的服务方法签名，新增 `startDate string`、`endDate string` 参数，移除内部的 today-30 日期计算逻辑
- [ ] 1.2 同步更新 `GetReportStats` 调用处，将 startDate / endDate 直接传入，不在 service 内计算

## 2. 后端：Handler 参数解析与默认值填充

- [ ] 2.1 在 `internal/handler/stats/` 中读取查询参数 `start_date` 和 `end_date`
- [ ] 2.2 当任一参数缺失时，在 handler 层填充默认值：`end_date = today(UTC)`，`start_date = end_date - 30 days`（格式 `YYYY-MM-DD`）

## 3. 后端：日期参数校验

- [ ] 3.1 实现日期格式校验（`YYYY-MM-DD`），格式错误返回 HTTP 422 / code 1002
- [ ] 3.2 实现 `start_date <= end_date` 校验，不满足返回 1002
- [ ] 3.3 实现跨度 ≤ 30 天校验，超出返回 1002，message 说明"日期范围不能超过 30 天"
- [ ] 3.4 实现 `end_date <= today(UTC)` 校验，未来日期返回 1002，message 说明"结束日期不能晚于今天"

## 4. iOS：ViewModel 日期状态管理

- [ ] 4.1 在 DashboardViewModel（或等效的 @Observable 对象）新增 `startDate: Date` 和 `endDate: Date` 状态属性，默认值为近 30 天
- [ ] 4.2 新增枚举 `DateRangePreset`（case last7Days / last14Days / last30Days / custom），新增 `selectedPreset` 状态属性，默认 `.last30Days`
- [ ] 4.3 当 `startDate` 或 `endDate` 变化时，触发 `/stats` 重新请求（将日期格式化为 `YYYY-MM-DD` 后作为查询参数传入）

## 5. iOS：快捷日期选项 UI

- [ ] 5.1 在 DashboardView 的平台筛选器下方添加横向滚动的快捷选项栏，包含"最近 7 天"、"最近 14 天"、"最近 30 天"、"自定义"四个胶囊按钮
- [ ] 5.2 点击快捷选项时，计算对应 start_date / end_date，更新 ViewModel 状态，并高亮当前选中项
- [ ] 5.3 点击"自定义"时，设置 `selectedPreset = .custom`，展示自定义日期 Sheet

## 6. iOS：自定义日期 Sheet

- [ ] 6.1 新建 `DateRangePickerSheet` View，包含"开始日期"和"结束日期"两个 DatePicker（`datePickerStyle: .compact`），限制最大可选日期为今日
- [ ] 6.2 实现实时跨度计算：当用户调整任一 DatePicker 时，计算当前跨度天数
- [ ] 6.3 跨度 > 30 天时，禁用"确认"按钮并在按钮上方显示 inline 提示文字"日期范围不能超过 30 天"；跨度合法时移除提示并启用按钮
- [ ] 6.4 点击"确认"时，将 Sheet 内的日期写入 ViewModel 的 `startDate` / `endDate`，关闭 Sheet（ViewModel 的日期变化触发 stats 请求）
- [ ] 6.5 点击"取消"时，关闭 Sheet，ViewModel 状态不变
