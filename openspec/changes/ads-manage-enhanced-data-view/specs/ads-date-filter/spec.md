## ADDED Requirements

### Requirement: 广告管理页日期快捷筛选
广告管理页（Tab3）各层级（账号/推广系列/广告组/广告组）的汇总卡片区域 SHALL 提供日期快捷选项：今天 / 昨天 / 近7天 / 近30天。

选中日期选项后，系统 SHALL 以对应日期区间请求 `GET /api/v1/stats/summary`，刷新汇总卡片数据（消耗、点击、展示、转化）。列表本身（campaign/adgroup 列表）不受日期筛选影响。

默认选中"近7天"。

#### Scenario: 默认加载
- **WHEN** 用户进入任意层级的广告管理页
- **THEN** 日期选项默认选中"近7天"，汇总卡片以近7天数据展示

#### Scenario: 切换日期选项
- **WHEN** 用户点击日期快捷选项中的"今天"
- **THEN** 系统以 `date_from = date_to = today` 请求 summary 接口，汇总卡片数据刷新；列表不刷新

#### Scenario: 日期选项在维度切换后保持
- **WHEN** 用户在推广系列层级选择了"昨天"，再切换维度到广告组层级
- **THEN** 广告组层级进入时沿用"昨天"作为初始日期选项

#### Scenario: 日期筛选参数传递
- **WHEN** 用户选择"近30天"
- **THEN** iOS 以 `date_from = today-29天, date_to = today` 格式传参请求后端 summary 接口

---

### Requirement: Dashboard 日期快捷筛选
Dashboard（Tab1）的统计卡片区域 SHALL 同样提供日期快捷选项（今天/昨天/近7天/近30天），作用于 `GET /api/v1/stats` 接口的 `date_from`/`date_to` 参数。

#### Scenario: Dashboard 切换日期
- **WHEN** 用户在 Dashboard 点击"近30天"
- **THEN** 四个统计卡片（总消耗/活跃广告主/推广系列数/广告组数）以近30天数据刷新
