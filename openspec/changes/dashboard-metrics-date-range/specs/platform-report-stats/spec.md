## MODIFIED Requirements

### Requirement: Report API date range defaults to last 30 days
服务层 SHALL 接受调用方传入的 startDate / endDate 参数（`YYYY-MM-DD` 格式字符串）来调用 `GetReportStats`。若调用方未提供日期，Handler 层 SHALL 以当前 UTC 日期为 end_date，往前 30 天为 start_date 作为默认值传入，服务层不再自行计算日期。

#### Scenario: Caller-provided date range used
- **WHEN** Handler 传入明确的 startDate = "2026-03-01"、endDate = "2026-03-10"
- **THEN** 服务层使用该日期范围调用 `GetReportStats`，不覆盖为默认值

#### Scenario: Default date range applied when not provided
- **WHEN** 请求未传 start_date / end_date 参数
- **THEN** Handler 填充 end_date = today(UTC)，start_date = end_date - 30 days，服务层使用填充后的值

## ADDED Requirements

### Requirement: Date range validation enforces max 30-day span
Handler 层 SHALL 在调用 service 之前校验 start_date / end_date 参数，不合法时返回 code 1002（HTTP 422）。

校验规则：
1. 日期格式必须为 `YYYY-MM-DD`
2. `start_date <= end_date`
3. 跨度（`end_date - start_date`）不超过 30 天
4. `end_date <= today(UTC)`

#### Scenario: Date range within 30 days passes validation
- **WHEN** start_date = "2026-03-01"，end_date = "2026-03-20"（跨度 19 天）
- **THEN** 校验通过，继续调用 service

#### Scenario: Date range exceeds 30 days rejected
- **WHEN** start_date = "2026-01-01"，end_date = "2026-03-01"（跨度 59 天）
- **THEN** 返回 HTTP 422 / code 1002，message 说明"日期范围不能超过 30 天"

#### Scenario: start_date after end_date rejected
- **WHEN** start_date = "2026-03-20"，end_date = "2026-03-01"
- **THEN** 返回 HTTP 422 / code 1002

#### Scenario: Future end_date rejected
- **WHEN** end_date 晚于 today(UTC)
- **THEN** 返回 HTTP 422 / code 1002，message 说明"结束日期不能晚于今天"

#### Scenario: Invalid date format rejected
- **WHEN** start_date = "2026/03/01"（非 YYYY-MM-DD 格式）
- **THEN** 返回 HTTP 422 / code 1002
