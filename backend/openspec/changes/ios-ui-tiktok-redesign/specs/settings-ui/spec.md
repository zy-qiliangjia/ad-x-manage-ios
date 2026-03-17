## ADDED Requirements

### Requirement: 渐变头像 Banner
设置页顶部 SHALL 显示用户头像（取邮箱首字母大写，渐变圆角背景）、昵称、邮箱，居中排列，上方无导航标题。

#### Scenario: 头像首字母生成
- **WHEN** 用户已登录且有 name 字段
- **THEN** 头像显示 name 首字母大写，背景为 Indigo→Purple 渐变

#### Scenario: 无 name 时回退
- **WHEN** name 为空
- **THEN** 头像显示邮箱首字母

### Requirement: 分组设置列表
设置页 SHALL 用分组列表（group title + 圆角卡片组）展示：「账号管理」组（广告账号管理 → 进入账号列表）、「其他」组（关于、版本号）、「危险」组（退出登录，红色文字）。

#### Scenario: 设置列表渲染
- **WHEN** 进入设置页
- **THEN** 显示 3 个分组，每项含图标、标题、描述、右箭头

#### Scenario: 退出登录确认
- **WHEN** 用户点击「退出登录」
- **THEN** 弹出确认 Alert，确认后清除 Token、跳回登录页
