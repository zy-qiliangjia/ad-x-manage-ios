# 客服管理后台 — API 需求文档

Base URL: `/api/admin/v1`

所有接口需要飞书 OAuth Token 鉴权，通过 `Authorization: Bearer {token}` 传递。

---

## 1. 认证

### 1.1 飞书登录

```
POST /auth/feishu
```

**请求体**

```json
{
  "code": "飞书OAuth授权码"
}
```

**响应**

```json
{
  "token": "jwt_token",
  "user": {
    "name": "张三",
    "avatar": "https://...",
    "feishuId": "xxx"
  }
}
```

### 1.2 获取当前用户

```
GET /auth/me
```

**响应**

```json
{
  "name": "张三",
  "avatar": "https://...",
  "feishuId": "xxx"
}
```

### 1.3 退出登录

```
POST /auth/logout
```

---

## 2. 数据概览

### 2.1 获取统计数据

```
GET /dashboard/stats
```

**响应**

```json
{
  "totalAccounts": 156,
  "todayNew": 8,
  "pending": 3
}
```

### 2.2 获取最近操作

```
GET /dashboard/recent-activities?limit=5
```

**响应**

```json
{
  "items": [
    {
      "action": "创建账号",
      "detail": "user@example.com - 掌上AD",
      "operator": "张三",
      "timeAgo": "2分钟前"
    }
  ]
}
```

---

## 3. 账号管理

### 3.1 获取账号列表

```
GET /accounts?page=1&pageSize=10&search=&product=&status=
```

**Query 参数**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| page | int | 否 | 页码，默认 1 |
| pageSize | int | 否 | 每页条数，默认 10 |
| search | string | 否 | 按邮箱模糊搜索 |
| product | string | 否 | 筛选产品：掌上AD / AD搭子 / AD晴雨表 |
| status | string | 否 | 筛选状态：active / disabled |

**响应**

```json
{
  "total": 156,
  "page": 1,
  "pageSize": 10,
  "items": [
    {
      "id": 1,
      "email": "user@example.com",
      "product": "掌上AD",
      "status": "active",
      "created": "2024-03-10",
      "myCode": "ZS-X8K2M1",
      "usedCode": "ZS-VIP001",
      "remarks": "",
      "usage": {
        "used": 3,
        "limit": 5,
        "lastActive": "2024-03-19"
      }
    }
  ]
}
```

### 3.2 创建账号

```
POST /accounts
```

**请求体**

```json
{
  "email": "user@example.com",
  "password": "随机密码或手动输入",
  "product": "掌上AD",
  "myCode": "ZS-ABC123",
  "usedCode": "ZS-VIP001",
  "usageLimit": 5,
  "remarks": "备注"
}
```

- `myCode` 留空时后端自动生成（按产品前缀 + 6位随机码）
- `usedCode` 可选，校验该邀请码是否存在
- 同一邮箱+同一产品不允许重复创建

**响应**

```json
{
  "id": 11,
  "email": "user@example.com",
  "product": "掌上AD",
  "myCode": "ZS-ABC123",
  "status": "active",
  "created": "2024-03-19"
}
```

### 3.3 编辑账号

```
PUT /accounts/:id
```

**请求体**（所有字段可选，只传需要修改的）

```json
{
  "product": "掌上AD",
  "password": "新密码（留空不修改）",
  "myCode": "ZS-ABC123",
  "usedCode": "ZS-VIP001",
  "usageUsed": 3,
  "usageLimit": 10,
  "remarks": "备注"
}
```

**响应**

```json
{
  "id": 1,
  "email": "user@example.com",
  "product": "掌上AD",
  "myCode": "ZS-ABC123",
  "usedCode": "ZS-VIP001",
  "usage": { "used": 3, "limit": 10, "lastActive": "2024-03-19" },
  "remarks": "备注"
}
```

### 3.4 获取账号用量详情

```
GET /accounts/:id/usage
```

**响应**

```json
{
  "id": 1,
  "email": "user@example.com",
  "product": "掌上AD",
  "usageLabel": "广告账号数",
  "usageUnit": "个",
  "used": 3,
  "limit": 5,
  "percentage": 60,
  "lastActive": "2024-03-19",
  "myCode": "ZS-X8K2M1",
  "usedCode": "ZS-VIP001",
  "status": "active",
  "created": "2024-03-10",
  "remarks": ""
}
```

### 3.5 更新账号用量

```
PATCH /accounts/:id/usage
```

**请求体**

```json
{
  "used": 5,
  "limit": 10
}
```

**响应**

```json
{
  "id": 1,
  "used": 5,
  "limit": 10
}
```

### 3.6 重置密码

```
POST /accounts/:id/reset-password
```

**响应**

```json
{
  "newPassword": "自动生成的新密码"
}
```

### 3.7 禁用/启用账号

```
PATCH /accounts/:id/status
```

**请求体**

```json
{
  "status": "disabled"
}
```

`status` 取值：`active` / `disabled`

**响应**

```json
{
  "id": 1,
  "status": "disabled"
}
```

---

## 4. 操作日志

### 4.1 获取操作日志列表

```
GET /logs?page=1&pageSize=10
```

**Query 参数**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| page | int | 否 | 页码，默认 1 |
| pageSize | int | 否 | 每页条数，默认 10 |

日志按时间倒序返回。

**响应**

```json
{
  "total": 22,
  "page": 1,
  "pageSize": 10,
  "items": [
    {
      "id": 1,
      "time": "2024-03-19 14:32",
      "operator": "张三",
      "action": "创建账号",
      "detail": "user@example.com - 掌上AD"
    }
  ]
}
```

---

## 5. 邀请码

### 5.1 校验邀请码

```
GET /invite-codes/validate?code=ZS-VIP001
```

**响应**

```json
{
  "valid": true,
  "ownerEmail": "admin@test.com",
  "ownerProduct": "掌上AD"
}
```

---

## 6. 数据模型

### accounts 表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | int | 主键，自增 |
| email | varchar(255) | 用户邮箱 |
| password_hash | varchar(255) | 密码哈希 |
| product | enum | 掌上AD / AD搭子 / AD晴雨表 |
| status | enum | active / disabled |
| my_code | varchar(20) | 该用户的唯一邀请码 |
| used_code | varchar(20) | 该用户使用的邀请码（nullable） |
| usage_used | int | 已用量 |
| usage_limit | int | 用量上限 |
| last_active | datetime | 最后活跃时间 |
| remarks | text | 备注 |
| created_at | datetime | 创建时间 |
| updated_at | datetime | 更新时间 |

唯一约束：`(email, product)` — 同一邮箱同一产品只能有一条记录。

### operation_logs 表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | int | 主键，自增 |
| operator | varchar(100) | 操作人姓名 |
| operator_feishu_id | varchar(100) | 操作人飞书ID |
| action | enum | create_account / reset_password / disable / enable / edit_info |
| detail | text | 操作详情 |
| target_account_id | int | 目标账号ID |
| created_at | datetime | 操作时间 |

### admin_users 表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | int | 主键，自增 |
| feishu_id | varchar(100) | 飞书用户ID |
| name | varchar(100) | 姓名 |
| avatar | varchar(500) | 头像URL |
| created_at | datetime | 首次登录时间 |
| last_login | datetime | 最后登录时间 |

---

## 7. 错误码

| HTTP 状态码 | code | 说明 |
|-------------|------|------|
| 401 | UNAUTHORIZED | 未登录或 token 过期 |
| 400 | INVALID_PARAMS | 参数校验失败 |
| 400 | DUPLICATE_ACCOUNT | 同一邮箱+产品已存在 |
| 400 | INVALID_INVITE_CODE | 邀请码不存在 |
| 404 | ACCOUNT_NOT_FOUND | 账号不存在 |
| 500 | INTERNAL_ERROR | 服务端异常 |
