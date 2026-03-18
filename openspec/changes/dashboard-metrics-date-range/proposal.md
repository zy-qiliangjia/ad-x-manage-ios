## Why

`dashboard-metrics-api-update` 将 `/stats` 的日期范围固定为近 30 天，无法满足用户查看特定时间段（如最近一周、某次活动投放期间）广告数据的需求。需要在保持默认体验不变的前提下，允许用户自定义日期范围，并对范围上限做合理约束（不超过 30 天）。

## What Changes

- `/stats` 接口新增可选查询参数 `start_date` 和 `end_date`（`YYYY-MM-DD` 格式）
  - 不传时默认近 30 天（与现有行为一致）
  - 传入时校验：`end_date >= start_date`，且跨度不超过 30 天，否则返回 1002 参数校验失败
- Redis 缓存 key 已包含 date range，无需额外改动缓存策略
- iOS Dashboard 新增日期区间选择器（DatePicker 或预设快捷选项），支持传入自定义 start_date / end_date 调用 `/stats`
- iOS 客户端在请求前对日期区间做前置校验（≤30 天），避免无效请求

## Capabilities

### New Capabilities

（无新增独立能力）

### Modified Capabilities

- `platform-report-stats`: 日期范围由调用方传入（原为服务层固定计算），新增服务层校验逻辑（跨度不超过 30 天）
- `dashboard-stats`: `/stats` 接口新增 `start_date` / `end_date` 可选参数；iOS DashboardView 新增日期区间选择交互

## Impact

- **后端**
  - `internal/handler/stats/`: 读取并校验 `start_date` / `end_date` 查询参数，传入 service 层
  - `internal/service/stats/`: 接受 dateRange 参数，替代原有固定计算逻辑
  - 参数校验失败返回 HTTP 422 / code 1002
- **iOS**
  - `DashboardView`: 新增日期区间选择 UI 组件，绑定 ViewModel
  - `StatsViewModel`（或等效层）：维护 startDate / endDate 状态，传入 API 请求
  - 前置校验：若用户选择的区间超过 30 天，展示提示并阻止请求
- **API**：`/stats` 新增可选参数，向后兼容（不传参行为不变）
