# 客服管理后台 — 前端代码说明

## 一、技术方案

单文件 HTML（admin-cs-backend.html），CSS/JS 全部内联，无外部依赖。Demo 阶段数据硬编码在 JS 中，正式开发时对接 API。

## 二、页面结构

```
body
├── #loginScreen          — 飞书登录页（初始显示）
├── #mainNavbar           — 顶部导航栏（登录后显示）
├── #mainContainer        — 主容器（登录后显示）
│   ├── .sidebar          — 左侧导航
│   │   ├── 数据概览
│   │   ├── 账号管理
│   │   └── 操作日志
│   └── .main-content     — 右侧内容区
│       ├── #dashboard    — 数据概览页
│       ├── #accounts     — 账号管理页
│       └── #logs         — 操作日志页
├── #accountModal         — 创建/编辑账号弹窗
└── #confirmModal         — 确认对话框（复用为用量详情弹窗）
```

## 三、数据结构

### 账号对象

```javascript
{
  id: 1,                          // 唯一ID
  email: 'user@example.com',      // 邮箱（登录凭证）
  product: '掌上AD',               // 产品名（掌上AD / AD搭子 / AD晴雨表）
  status: 'active',               // 状态（active / disabled）
  created: '2024-03-10',          // 创建日期
  myCode: 'ZS-X8K2M1',           // 该用户的唯一邀请码
  usedCode: 'ZS-VIP001',         // 该用户使用的别人的邀请码
  remarks: '',                    // 备注
  usage: {
    used: 3,                      // 已用量
    limit: 5,                     // 上限
    lastActive: '2024-03-19'      // 最后活跃日期
  }
}
```

### 操作日志对象

```javascript
{
  time: '2024-03-19 14:32',       // 操作时间
  user: '张三',                    // 操作人
  action: '创建账号',              // 操作类型
  detail: 'user@example.com - 掌上AD'  // 详情
}
```

## 四、核心函数清单

### 登录相关

| 函数 | 说明 |
|------|------|
| `feishuLogin()` | 飞书登录，隐藏登录页，显示主界面，调用 `init()` |
| `feishuLogout()` | 退出登录，隐藏主界面，显示登录页 |

### 页面导航

| 函数 | 说明 |
|------|------|
| `switchPage(page)` | 切换左侧导航高亮和右侧内容区，参数：dashboard / accounts / logs |

### 账号管理

| 函数 | 说明 |
|------|------|
| `renderAccountTable()` | 渲染账号列表表格（当前页数据） |
| `filterTable()` | 按搜索词、产品、状态筛选账号，重置到第1页 |
| `openCreateModal()` | 打开创建账号弹窗，清空表单，自动生成密码 |
| `openEditModal(id)` | 打开编辑账号弹窗，加载已有数据 |
| `saveAccount()` | 保存账号（创建或编辑），校验必填项 |
| `closeModal()` | 关闭弹窗，清空表单 |
| `resetPassword(id)` | 重置密码，二次确认 |
| `toggleStatus(id)` | 切换禁用/启用状态，二次确认 |

### 用量相关

| 函数 | 说明 |
|------|------|
| `getUsageLabel(product)` | 根据产品返回用量名称和单位 |
| `renderUsageBrief(account)` | 渲染表格中的用量进度条 |
| `showUsage(id)` | 弹出用量详情面板 |
| `toggleUsageEdit()` | 切换用量详情中的编辑/显示模式 |
| `saveUsageEdit()` | 保存用量编辑，更新表格 |

### 邀请码

| 函数 | 说明 |
|------|------|
| `generateInviteCode(product)` | 自动生成邀请码（产品前缀 + 6位随机码） |

### 分页

| 函数 | 说明 |
|------|------|
| `updatePagination()` | 更新账号列表分页状态 |
| `prevPage()` / `nextPage()` / `setPage(n)` | 账号列表翻页 |
| `renderLogTable()` | 渲染操作日志表格（当前页数据） |
| `logPrevPage()` / `logNextPage()` / `logSetPage(n)` | 日志翻页 |

### 通用

| 函数 | 说明 |
|------|------|
| `generatePassword()` | 生成12位随机密码 |
| `copyPassword()` | 复制密码到剪贴板 |
| `showToast(message, type)` | 右下角 toast 提示，type: success / error / info |
| `showConfirm(message, onConfirm)` | 二次确认弹窗 |
| `getProductBadgeClass(product)` | 返回产品标签的 CSS class |

## 五、CSS 设计规范

| 元素 | 规范 |
|------|------|
| 主色 | `#5b4fd4`（紫色） |
| 背景 | `#f8f8fa` |
| 卡片 | 白底 + `1px solid #e8e8ec` + `border-radius: 8px` |
| 按钮 | 主按钮紫色 `#5b4fd4`，次按钮白底灰边 |
| 表格 | 表头 `#f8f8fa`，hover 行 `#fafafa` |
| 弹窗 | 居中，`max-width: 500px`，`max-height: 90vh`，带 slideIn 动画 |
| 侧边栏 | 220px 宽，选中项紫色左边框 + 紫色背景 |
| 响应式 | `@media (max-width: 768px)` 适配移动端 |

### 产品标签颜色

| 产品 | class | 颜色 |
|------|-------|------|
| 掌上AD | badge-indigo | 紫色 `#5b4fd4` |
| AD搭子 | badge-blue | 蓝色 `#1976d2` |
| AD晴雨表 | badge-green | 绿色 `#388e3c` |

### 用量进度条颜色

| 使用率 | 颜色 |
|--------|------|
| <60% | 绿色 `#52c41a` |
| 60-90% | 黄色 `#faad14` |
| ≥90% | 红色 `#ff4d4f` |

## 六、正式开发对接要点

Demo 中所有数据硬编码在 JS 变量中。正式开发时需替换为 API 调用：

| Demo 写法 | 正式对接 |
|-----------|---------|
| `let accounts = [...]` | `GET /api/admin/v1/accounts` |
| `let logs = [...]` | `GET /api/admin/v1/logs` |
| `accounts.push({...})` | `POST /api/admin/v1/accounts` |
| `account.status = 'disabled'` | `PATCH /api/admin/v1/accounts/:id/status` |
| `account.usage = {...}` | `PATCH /api/admin/v1/accounts/:id/usage` |
| `feishuLogin()` 模拟 | `POST /api/admin/v1/auth/feishu` + 飞书 OAuth 流程 |
| 统计卡片硬编码 | `GET /api/admin/v1/dashboard/stats` |

## 七、文件清单

| 文件 | 说明 |
|------|------|
| `admin-cs-backend.html` | 完整前端 Demo（单文件 HTML，可直接浏览器打开预览） |
| `admin-PRD.md` | 产品需求文档 |
| `admin-API.md` | API 需求文档 |
| `admin-frontend.md` | 本文档（前端代码说明） |
