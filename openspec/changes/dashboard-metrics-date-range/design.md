## Context

`dashboard-metrics-api-update` 在服务层将日期范围硬编码为 today-30 至 today，对用户不可见也不可调。本次变更在此基础上开放日期参数，同时限制最大跨度为 30 天（与平台 API 使用限制及性能预算对齐）。

现有架构：
- `/stats` handler 不接受日期参数，直接调用 service
- service 层固定计算 `today-30` / `today`
- Redis 缓存 key 已包含 `{start_date}:{end_date}`，支持变长日期区间

## Goals / Non-Goals

**Goals:**
- `/stats` 新增可选 `start_date` / `end_date` 查询参数，缺省时行为与现有完全一致
- 后端校验：日期格式合法（`YYYY-MM-DD`）、`start_date <= end_date`、跨度 ≤ 30 天、`end_date <= today`
- iOS DashboardView 提供日期区间选择入口，支持快捷选项（最近 7 天 / 14 天 / 30 天）和自定义日期范围
- iOS 端前置校验跨度 ≤ 30 天，不合规时展示提示，阻止请求发出
- 现有无参数调用行为不变（向后兼容）

**Non-Goals:**
- 不支持小时级粒度
- 不实现日期范围的持久化（每次打开 Dashboard 恢复默认近 30 天）
- 不对历史数据的可查询范围做额外限制（由平台 API 自身决定）

## Decisions

### 1. 后端参数为可选，缺省值在 handler 层填充

**选择**: handler 读取 `start_date` / `end_date`；若任一缺失，则以 `today-30` / `today` 填充，然后统一传入 service 层。Service 层不再有日期计算逻辑，只负责接收和使用。

**理由**: 保持 service 层纯粹（无隐式默认），handler 统一处理入参默认值；service 可独立测试任意日期范围。

**备选**: 在 service 内维持缺省判断 → service 逻辑耦合了默认值，不选。

### 2. 后端校验规则在 handler 层执行

**选择**: handler 在填充默认值之后、调用 service 之前完成校验：格式错误 / 跨度超 30 天 / end_date 超今日 → 返回 HTTP 422 / code 1002，body 带具体错误描述。

**理由**: 参数校验属于 handler 职责；service 只处理合法输入。

### 3. iOS 提供 3 个快捷选项 + 自定义日期选择

**选择**: 在 DashboardView 顶部增加一个横向滚动的快捷选项栏（最近 7 天 / 14 天 / 30 天）以及「自定义」入口（触发双 DatePicker Sheet）。默认选中「最近 30 天」。

**理由**: 快捷选项覆盖最常见场景，自定义满足特殊需求，UI 代价最小。

**备选**: 只提供双 DatePicker → 操作步骤多，日常使用体验差，不选。

### 4. iOS 前置校验：跨度 > 30 天时禁用确认按钮并展示 inline 提示

**选择**: 自定义日期选择 Sheet 中，实时计算跨度；若超过 30 天，确认按钮置灰并显示"日期范围不能超过 30 天"提示文字。不弹 alert，减少打断感。

**理由**: 即时反馈比提交后报错更友好；inline 提示不打断用户交互流。

## Risks / Trade-offs

- **[风险] end_date 传入未来日期** → 后端校验 `end_date <= today`，返回 1002
- **[风险] 平台 API 不支持过远的历史数据** → 本次不做限制，由平台 API 报错透传（code 1003）
- **[Trade-off] 快捷选项硬编码** → 灵活性低，但覆盖 90% 使用场景，可后续迭代
- **[风险] iOS 端日期时区处理** → 统一使用设备本地日期（与服务端 UTC 可能有 ±1 天偏差），与现有近 30 天默认行为一致，可接受

## Migration Plan

1. 后端先部署（新增可选参数，无参行为不变，完全向后兼容）
2. iOS 随后发布（新增日期选择 UI，默认仍为近 30 天）
3. 无数据库迁移，无 Redis key 格式变更

## Open Questions

- iOS 自定义日期 Sheet 是否需要"应用"后才触发请求，还是实时选择实时触发？（当前方案：Sheet 内有"确认"按钮，点击后关闭 Sheet 并触发请求）
