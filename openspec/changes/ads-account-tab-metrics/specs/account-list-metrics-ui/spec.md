## ADDED Requirements

### Requirement: 账号列表指标卡片展示
iOS 账号列表（AdvertiserListView）中每个广告主 Cell SHALL 在基础信息下方展示6个指标：消耗（spend）、点击（clicks）、展示（impressions）、转化（conversion）、CPA（skan_click_time_cost_per_conversion）、日预算（daily_budget），采用2行×3列紧凑网格布局，字号为 caption。

#### Scenario: 数据已加载
- **WHEN** 报表数据成功返回并与广告主 ID 匹配
- **THEN** 对应 Cell 的指标网格显示真实数值，消耗/CPA/日预算保留2位小数并附带货币符号（如 USD）

#### Scenario: 数据未加载或请求中
- **WHEN** 报表请求尚未完成或该广告主无缓存数据
- **THEN** 指标网格显示 "—" 占位符或 skeleton loading 样式，不显示 0

#### Scenario: 广告主无投放数据
- **WHEN** 报表接口返回该广告主指标全为 "0"
- **THEN** 指标网格显示 "0"（消耗显示 "0.00"）

### Requirement: 自定义日期筛选器
账号列表顶部 SHALL 提供日期区间选择器，默认为近7天（today - 7 days 至 today - 1 day），允许用户自定义开始日期和结束日期，最大跨度30天。

#### Scenario: 选择合法日期区间
- **WHEN** 用户选择开始日期和结束日期，跨度 ≤ 30天
- **THEN** 列表触发重新拉取报表数据，指标展示更新为新日期区间的数据

#### Scenario: 选择超过30天跨度
- **WHEN** 用户尝试选择跨度超过30天的日期区间
- **THEN** 系统自动将结束日期截断至开始日期 + 30天，并弹出 Toast 提示"日期跨度最多30天"

#### Scenario: 切换平台筛选时
- **WHEN** 用户切换平台筛选（全部/TikTok/Kwai），当前日期区间保持不变
- **THEN** 列表重新拉取所筛选平台广告主的报表数据

### Requirement: 报表数据批次并发拉取
iOS 客户端 SHALL 在获取账号列表后，按每批最多5个广告主对 `/stats/report` 接口发起请求，多批次之间可并发执行，所有批次完成后合并结果，按广告主 ID 匹配填充指标。

#### Scenario: 广告主列表超过5个
- **WHEN** 当前列表有12个广告主
- **THEN** 客户端拆分为3批（5+5+2）并发请求，全部完成后统一更新 UI

#### Scenario: 某批次请求失败
- **WHEN** 其中一批请求返回错误
- **THEN** 该批次广告主指标显示 "0" 或错误占位，其他批次正常显示，不全局报错

### Requirement: 汇总行展示
账号列表底部（或顶部指标区域）SHALL 展示一个汇总行，显示当前筛选范围内所有广告主的指标合计（spend/clicks/impressions/conversion 求和，CPA 显示加权平均或"—"）。

#### Scenario: 汇总行正常显示
- **WHEN** 至少一个广告主有指标数据
- **THEN** 汇总行显示各指标累加值，消耗显示总和并注明"合计"标签

#### Scenario: 数据加载中
- **WHEN** 报表数据尚未全部返回
- **THEN** 汇总行显示 skeleton loading 或"加载中..."，不显示部分合计

#### Scenario: 所有广告主无数据
- **WHEN** 所有广告主在指定日期区间均无投放记录
- **THEN** 汇总行所有指标显示 "0.00"
