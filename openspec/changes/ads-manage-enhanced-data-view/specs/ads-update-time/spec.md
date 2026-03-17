## ADDED Requirements

### Requirement: 导航栏右上角展示数据更新时间
广告管理页（Tab3）各层级页面和 Dashboard（Tab1）的导航栏 SHALL 在右上角展示数据最后更新时间，格式为"更新于 HH:mm"（仅展示时分）。

更新时间来源于 stats/summary 接口返回的 `last_updated_at` 字段（取该范围内最近一条记录的 `MAX(updated_at)`）。

未加载完成时显示"加载中..."；若 `last_updated_at` 为 null，显示"暂无数据"。

#### Scenario: 数据加载完成后展示更新时间
- **WHEN** summary 接口返回 `last_updated_at: "2025-01-15T14:30:00Z"`
- **THEN** 导航栏右上角展示"更新于 14:30"（按设备本地时区转换）

#### Scenario: 加载中状态
- **WHEN** summary 接口请求尚未返回
- **THEN** 导航栏右上角显示旋转加载指示器或"加载中..."文字

#### Scenario: 无数据时
- **WHEN** summary 接口返回 `last_updated_at: null`
- **THEN** 导航栏右上角显示"暂无数据"

#### Scenario: 切换日期选项时更新
- **WHEN** 用户切换日期快捷选项，summary 接口重新请求并返回新的 `last_updated_at`
- **THEN** 导航栏右上角时间同步更新为新值
