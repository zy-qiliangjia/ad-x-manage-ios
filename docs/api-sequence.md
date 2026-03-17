# API 调用顺序

## 全局约定

- 所有接口（除登录/注册/OAuth平台回调）均需在请求头携带 JWT：
  ```
  Authorization: Bearer <token>
  ```
- 统一响应结构：
  ```json
  { "code": 0, "message": "ok", "data": {} }
  ```
- 分页接口额外包含：
  ```json
  {
    "pagination": {
      "page": 1,
      "page_size": 20,
      "total": 100,
      "has_more": true
    }
  }
  ```

| code | HTTP | 含义 |
|------|------|------|
| 0 | 200 | 成功 |
| 1001 | 401 | 未登录 / JWT 过期 |
| 1002 | 422 | 参数校验失败 |
| 1003 | 502 | 平台 API 调用失败 |
| 1004 | 403 | 无权限操作该账号 |
| 1005 | 401 | OAuth Token 失效，需重新授权 |
| 5000 | 500 | 服务器内部错误 |

---

## 一、注册 / 登录

```
POST /api/v1/auth/register
```
请求体：
```json
{ "email": "user@example.com", "password": "123456", "name": "张三" }
```

```
POST /api/v1/auth/login
```
请求体：
```json
{ "email": "user@example.com", "password": "123456" }
```
响应 `data`：
```json
{
  "token": "<jwt>",
  "expires_at": "2026-04-01T00:00:00Z",
  "user": { "id": 1, "email": "user@example.com", "name": "张三" }
}
```

---

## 二、登录后 — 触发全量后台同步

登录成功后立即调用，对当前用户所有有效广告主在后台触发全量数据同步（异步，立即返回）。

```
POST /api/v1/advertisers/sync
```
响应 `data`：
```json
{ "triggered": 3 }
```

---

## 三、广告主列表

```
GET /api/v1/advertisers?platform=tiktok&keyword=xxx&page=1&page_size=20
```

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| platform | string | 否 | `tiktok` \| `kwai`，不传则全部 |
| keyword | string | 否 | 按账号名称或 ID 模糊搜索 |
| page | int | 否 | 默认 1 |
| page_size | int | 否 | 默认 20，最大 100 |

响应 `data` 数组元素：
```json
{
  "id": 1,
  "platform": "tiktok",
  "advertiser_id": "7123456789",
  "advertiser_name": "品牌旗舰店",
  "currency": "CNY",
  "timezone": "Asia/Shanghai",
  "status": 1,
  "synced_at": "2026-03-13T10:00:00Z"
}
```

---

## 四、添加新平台账号（OAuth 授权）

### 4.1 获取授权 URL
```
GET /api/v1/oauth/:platform/url
```
响应 `data`：
```json
{ "url": "https://ads.tiktok.com/marketing_api/auth?...", "state": "abc123" }
```

### 4.2 用户在浏览器完成授权后，iOS 提取 code + state 发起回调
```
POST /api/v1/oauth/:platform/callback
```
请求体：
```json
{ "code": "AUTH_CODE", "state": "abc123" }
```
响应 `data`：
```json
{
  "token_id": 5,
  "platform": "tiktok",
  "advertisers": [
    {
      "id": 1,
      "advertiser_id": "7123456789",
      "advertiser_name": "品牌旗舰店",
      "currency": "CNY",
      "timezone": "Asia/Shanghai",
      "synced_at": "2026-03-13T10:00:00Z"
    }
  ]
}
```
> 后端在 Callback 处理完成后会自动在后台触发广告数据全量同步。

---

## 五、账号详情 — 进入某广告主后依次加载

### 5.1 推广系列列表（Tab1）
```
GET /api/v1/advertisers/:id/campaigns?page=1&page_size=20
```
响应 `data` 数组元素：
```json
{
  "id": 10,
  "campaign_id": "1800123456",
  "campaign_name": "春节大促",
  "status": "CAMPAIGN_STATUS_ENABLE",
  "budget": 5000.00,
  "budget_mode": "BUDGET_MODE_DAY",
  "spend": 1200.50
}
```

### 5.2 广告组列表（Tab2）
```
GET /api/v1/advertisers/:id/adgroups?campaign_id=10&page=1&page_size=20
```

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| campaign_id | int | 否 | 按推广系列 ID 筛选 |
| page | int | 否 | 默认 1 |
| page_size | int | 否 | 默认 20 |

响应 `data` 数组元素：
```json
{
  "id": 20,
  "campaign_id": 10,
  "adgroup_id": "1900123456",
  "adgroup_name": "人群包A",
  "status": "ADGROUP_STATUS_ENABLE",
  "budget": 1000.00,
  "budget_mode": "BUDGET_MODE_DAY",
  "spend": 300.00
}
```

### 5.3 广告列表（Tab3）
```
GET /api/v1/advertisers/:id/ads?adgroup_id=20&keyword=xxx&page=1&page_size=20
```

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| adgroup_id | int | 否 | 按广告组 ID 筛选 |
| keyword | string | 否 | 按广告名称或 ID 搜索 |
| page | int | 否 | 默认 1 |
| page_size | int | 否 | 默认 20 |

响应 `data` 数组元素：
```json
{
  "id": 30,
  "adgroup_id": 20,
  "ad_id": "2000123456",
  "ad_name": "素材_竖版_15s",
  "status": "AD_STATUS_ENABLE"
}
```

### 5.4 操作日志
```
GET /api/v1/operation-logs?advertiser_id=1&page=1&page_size=20
```
响应 `data` 数组元素：
```json
{
  "id": 100,
  "platform": "tiktok",
  "action": "budget_update",
  "target_type": "campaign",
  "target_id": "1800123456",
  "before_val": { "budget": 3000 },
  "after_val": { "budget": 5000 },
  "created_at": "2026-03-13T10:30:00Z"
}
```

---

## 六、写操作

### 6.1 修改推广系列预算
```
PATCH /api/v1/campaigns/:id/budget
```
请求体：
```json
{ "budget": 8000.00 }
```

### 6.2 修改推广系列状态
```
PATCH /api/v1/campaigns/:id/status
```
请求体：
```json
{ "status": "CAMPAIGN_STATUS_ENABLE" }
```
> status 可选值：`CAMPAIGN_STATUS_ENABLE`（开启）| `CAMPAIGN_STATUS_DISABLE`（暂停）

### 6.3 修改广告组预算
```
PATCH /api/v1/adgroups/:id/budget
```
请求体：
```json
{ "budget": 2000.00 }
```

### 6.4 修改广告组状态
```
PATCH /api/v1/adgroups/:id/status
```
请求体：
```json
{ "status": "ADGROUP_STATUS_ENABLE" }
```
> status 可选值：`ADGROUP_STATUS_ENABLE`（开启）| `ADGROUP_STATUS_DISABLE`（暂停）

---

## 七、实时余额 / 手动同步

### 7.1 实时查询账户余额（不走缓存，直接调平台 API）
```
GET /api/v1/advertisers/:id/balance
```
响应 `data`：
```json
{
  "advertiser_id": "7123456789",
  "balance": 3800.00,
  "currency": "CNY"
}
```

### 7.2 手动触发单个广告主全量同步（同步执行，等待结果）
```
POST /api/v1/advertisers/:id/sync
```
响应 `data`：
```json
{
  "advertiser_id": 1,
  "campaign_count": 5,
  "adgroup_count": 12,
  "ad_count": 38,
  "duration": "4.231s",
  "errors": []
}
```

---

## 八、Token 管理

### 8.1 JWT 即将过期时自动续签
```
POST /api/v1/auth/refresh
```
响应 `data`：
```json
{ "token": "<new_jwt>", "expires_at": "2026-04-14T00:00:00Z" }
```

### 8.2 登出（Token 加入黑名单）
```
POST /api/v1/auth/logout
```

### 8.3 解除平台授权
```
DELETE /api/v1/oauth/:platform/:token_id
```
> 解绑后该 token 下所有广告主会被标记为停用。
