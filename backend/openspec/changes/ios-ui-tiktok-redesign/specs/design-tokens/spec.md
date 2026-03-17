## ADDED Requirements

### Requirement: AppTheme 设计 token 文件
系统 SHALL 在 `Core/Theme/AppTheme.swift` 中以 `enum AppTheme` 提供全局设计 token，无需实例化即可访问。

#### Scenario: 颜色 token 可访问
- **WHEN** 任意 View 引用 `AppTheme.Colors.primary`
- **THEN** 返回品牌主色（Indigo #4F46E5）

#### Scenario: TikTok 品牌色可访问
- **WHEN** 引用 `AppTheme.Colors.tiktokDark` 和 `AppTheme.Colors.tiktokRed`
- **THEN** 分别返回 #010101（接近黑）和 #FE2C55（TikTok 红）

#### Scenario: 语义色涵盖状态
- **WHEN** 引用 `AppTheme.Colors.success / warning / danger`
- **THEN** 分别返回绿 #10B981、琥珀 #F59E0B、红 #EF4444

#### Scenario: 间距 token 可用
- **WHEN** 引用 `AppTheme.Spacing.sm / md / lg / xl`
- **THEN** 分别返回 8 / 12 / 16 / 20 pt

#### Scenario: 圆角 token 可用
- **WHEN** 引用 `AppTheme.Radius.sm / md / lg / xl / pill`
- **THEN** 分别返回 8 / 12 / 14 / 16 / 20 pt

### Requirement: 卡片阴影样式
系统 SHALL 提供统一的卡片阴影 ViewModifier `cardShadow()`，应用 `color: .black.opacity(0.06), radius: 8, x: 0, y: 2`。

#### Scenario: 卡片应用阴影
- **WHEN** 任意 View 调用 `.cardShadow()`
- **THEN** 渲染结果一致，无需各处手写 shadow 参数
