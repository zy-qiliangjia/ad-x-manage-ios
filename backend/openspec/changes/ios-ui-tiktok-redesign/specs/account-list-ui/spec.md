## ADDED Requirements

### Requirement: 账号卡片重设计
账号列表每张卡片 SHALL 包含：平台头像（TikTok 黑色渐变圆角正方形 + T 字母）、账号名称、平台 ID、状态 badge（活跃绿/暂停黄/异常红）、底部三列数据行（本周消耗 / 推广系列数 / CTR）。

#### Scenario: TikTok 卡片渲染
- **WHEN** 账号列表加载 TikTok 广告主
- **THEN** 头像为黑色渐变背景+白色「T」，状态 badge 颜色对应后端 status 字段

#### Scenario: 状态 badge 映射
- **WHEN** status 为 `ENABLE` 或 `ACTIVE`
- **THEN** badge 显示绿色「活跃」；`DISABLE` 显示黄色「暂停」；其他显示红色「异常」

### Requirement: 授权添加按钮样式
账号列表底部 SHALL 有虚线边框的「＋ 授权添加新广告账号」按钮，点击后弹出平台选择 Bottom Sheet。

#### Scenario: 点击添加按钮
- **WHEN** 用户点击添加按钮
- **THEN** 从底部滑出 Bottom Sheet，展示 TikTok 选项（Kwai 置灰/不显示）

### Requirement: 左滑查看余额
账号卡片 SHALL 支持左滑手势，滑出「余额」操作按钮，点击后弹出余额查看 Bottom Sheet。

#### Scenario: 左滑触发余额
- **WHEN** 用户左滑账号卡片
- **THEN** 出现蓝色「余额」按钮；点击后 Bottom Sheet 展示实时余额和货币单位
