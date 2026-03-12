# 数据库设计方案

## 基本信息

| 项目 | 说明 |
|------|------|
| 数据库 | MySQL 8.0+ |
| 字符集 | utf8mb4 |
| 排序规则 | utf8mb4_unicode_ci |
| 存储引擎 | InnoDB |
| 建表文件 | `docs/schema.sql` |

---

## 表关系总览

```
users
 └── platform_tokens        (一用户多平台授权)
       └── advertisers      (一授权多广告主)
             └── campaigns  (一广告主多推广系列)
                   └── ad_groups  (一系列多广告组)
                         └── ads  (一广告组多广告)

users ──▶ operation_logs    (所有写操作记录)
```

### ER 关系图

```
┌──────────┐       ┌──────────────────┐       ┌─────────────┐
│  users   │ 1─── N│ platform_tokens  │ 1───N │ advertisers │
│----------│       │------------------│       │-------------│
│ id       │       │ id               │       │ id          │
│ email    │       │ user_id          │       │ token_id    │
│ password │       │ platform         │       │ user_id     │
│ name     │       │ open_user_id     │       │ platform    │
│ status   │       │ access_token_enc │       │ advertiser_id│
└──────────┘       │ refresh_token_enc│       │ advertiser_name│
                   │ expires_at       │       │ currency    │
                   │ status           │       │ timezone    │
                   └──────────────────┘       │ synced_at   │
                                              └──────┬──────┘
                                                     │ 1
                                                     │
                        ┌────────────────────────────┤
                        │                            │
                        ▼ N                          ▼ N
               ┌──────────────┐             ┌──────────────────┐
               │  campaigns   │             │  operation_logs  │
               │--------------│             │------------------│
               │ id           │             │ id               │
               │ advertiser_id│             │ user_id          │
               │ campaign_id  │             │ advertiser_id    │
               │ campaign_name│             │ action           │
               │ status       │             │ target_type      │
               │ budget       │             │ target_id        │
               │ spend        │             │ before_val (JSON)│
               └──────┬───────┘             │ after_val  (JSON)│
                      │ 1                   └──────────────────┘
                      │
                      ▼ N
               ┌──────────────┐
               │  ad_groups   │
               │--------------│
               │ id           │
               │ advertiser_id│
               │ campaign_id  │
               │ adgroup_id   │
               │ adgroup_name │
               │ status       │
               │ budget       │
               │ spend        │
               └──────┬───────┘
                      │ 1
                      │
                      ▼ N
               ┌──────────────┐
               │     ads      │
               │--------------│
               │ id           │
               │ advertiser_id│
               │ adgroup_id   │
               │ ad_id        │
               │ ad_name      │
               │ status       │
               └──────────────┘
```

---

## 表说明

### 1. users — 用户表

系统本身的用户账号，通过邮箱+密码登录。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | BIGINT UNSIGNED | 主键 |
| email | VARCHAR(255) | 登录邮箱，唯一索引 |
| password_hash | VARCHAR(255) | bcrypt 哈希，不存明文 |
| name | VARCHAR(100) | 用户昵称 |
| status | TINYINT | 1 正常 / 0 禁用 |
| last_login_at | DATETIME | 最后登录时间 |

**索引：**
- `uk_email`：唯一，登录查询

---

### 2. platform_tokens — 平台 OAuth Token 表

存储用户在各广告平台的授权凭证。一个用户可以对同一平台授权多个主体账号。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | BIGINT UNSIGNED | 主键 |
| user_id | BIGINT UNSIGNED | 关联 users.id |
| platform | VARCHAR(20) | `tiktok` \| `kwai` |
| open_user_id | VARCHAR(100) | 平台侧用户唯一 ID |
| access_token_enc | TEXT | AES-256-GCM 加密存储 |
| refresh_token_enc | TEXT | AES-256-GCM 加密存储 |
| expires_at | DATETIME | access_token 过期时间 |
| scope | VARCHAR(500) | 授权的权限范围 |
| status | TINYINT | 1 有效 / 0 失效或已解绑 |

**索引：**
- `uk_user_platform_openid`：唯一，防重复授权
- `idx_user_platform`：按用户+平台查询

**注意事项：**
- Token 过期前 30 分钟由后台定时任务自动 Refresh
- 解绑操作仅将 status 置 0，不物理删除（保留日志可追溯）
- access_token 和 refresh_token 必须加密后再入库

---

### 3. advertisers — 广告主账号表

OAuth 授权后从平台拉取的广告主列表。一个 OAuth 账号可以管理多个广告主。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | BIGINT UNSIGNED | 主键 |
| token_id | BIGINT UNSIGNED | 关联 platform_tokens.id |
| user_id | BIGINT UNSIGNED | 关联 users.id（冗余，便于查询） |
| platform | VARCHAR(20) | `tiktok` \| `kwai` |
| advertiser_id | VARCHAR(100) | 平台广告主 ID |
| advertiser_name | VARCHAR(255) | 广告主名称 |
| currency | VARCHAR(10) | 货币单位，如 USD / CNY |
| timezone | VARCHAR(50) | 账号时区，如 Asia/Shanghai |
| status | TINYINT | 1 正常 / 0 停用 |
| synced_at | DATETIME | 最后同步时间 |

**索引：**
- `uk_platform_advertiser`：唯一，防重复
- `idx_user_platform`：App 首页列表查询

---

### 4. campaigns — 推广系列表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | BIGINT UNSIGNED | 主键 |
| advertiser_id | BIGINT UNSIGNED | 关联 advertisers.id |
| platform | VARCHAR(20) | `tiktok` \| `kwai` |
| campaign_id | VARCHAR(100) | 平台 campaign ID |
| campaign_name | VARCHAR(255) | 推广系列名称 |
| status | VARCHAR(50) | 平台原始状态值（各平台不同） |
| budget_mode | VARCHAR(50) | 预算类型：日预算/总预算 |
| budget | DECIMAL(18,2) | 预算金额 |
| spend | DECIMAL(18,2) | 消耗金额（定期同步） |
| objective | VARCHAR(100) | 推广目标（流量/转化/应用等） |

**状态值参考：**

| 平台 | 投放中 | 暂停 | 未开始 |
|------|------|------|------|
| TikTok | `ENABLE` | `DISABLE` | `NOT_START` |
| Kwai | `ONLINE` | `OFFLINE` | `NOT_START` |

---

### 5. ad_groups — 广告组表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | BIGINT UNSIGNED | 主键 |
| advertiser_id | BIGINT UNSIGNED | 关联 advertisers.id |
| campaign_id | BIGINT UNSIGNED | 关联 campaigns.id |
| platform | VARCHAR(20) | `tiktok` \| `kwai` |
| adgroup_id | VARCHAR(100) | 平台广告组 ID |
| adgroup_name | VARCHAR(255) | 广告组名称 |
| status | VARCHAR(50) | 投放状态，平台原始值 |
| budget_mode | VARCHAR(50) | 预算类型 |
| budget | DECIMAL(18,2) | 预算金额 |
| spend | DECIMAL(18,2) | 消耗金额 |
| bid_type | VARCHAR(50) | 出价方式（CPM/CPC/oCPM 等） |
| bid_price | DECIMAL(18,4) | 出价金额 |

---

### 6. ads — 广告表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | BIGINT UNSIGNED | 主键 |
| advertiser_id | BIGINT UNSIGNED | 关联 advertisers.id |
| adgroup_id | BIGINT UNSIGNED | 关联 ad_groups.id |
| platform | VARCHAR(20) | `tiktok` \| `kwai` |
| ad_id | VARCHAR(100) | 平台广告 ID |
| ad_name | VARCHAR(255) | 广告名称 |
| status | VARCHAR(50) | 投放状态，平台原始值 |
| creative_type | VARCHAR(50) | 创意类型：视频/图片 |

**支持搜索字段：** `ad_id`、`ad_name`（已建前缀索引）

---

### 7. operation_logs — 操作日志表

记录所有写操作，不可修改，用于追溯和审计。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | BIGINT UNSIGNED | 主键 |
| user_id | BIGINT UNSIGNED | 操作人 |
| advertiser_id | BIGINT UNSIGNED | 广告主 |
| platform | VARCHAR(20) | 平台 |
| action | VARCHAR(50) | 操作类型（见下方枚举） |
| target_type | VARCHAR(20) | 操作对象类型 |
| target_id | VARCHAR(100) | 平台侧对象 ID |
| target_name | VARCHAR(255) | 对象名称（冗余，便于查阅） |
| before_val | JSON | 操作前的值 |
| after_val | JSON | 操作后的值 |
| result | TINYINT | 1 成功 / 0 失败 |
| fail_reason | VARCHAR(500) | 失败原因 |

**action 枚举值：**

| action | 说明 |
|------|------|
| `budget_update` | 修改预算 |
| `status_enable` | 开启投放 |
| `status_pause` | 暂停投放 |

**target_type 枚举值：** `campaign` / `adgroup` / `ad`

**before_val / after_val 示例：**
```json
// budget_update
{ "budget": 500.00, "budget_mode": "BUDGET_MODE_DAY" }

// status_enable / status_pause
{ "status": "DISABLE" }
```

---

## 数据同步策略

### 全量同步（OAuth 授权后触发）

```
POST /oauth/:platform/callback
    │
    ▼
换取 access_token → 加密存入 platform_tokens
    │
    ▼
GetAdvertisers → 批量 UPSERT advertisers
    │
    ▼
遍历每个 advertiser_id（并发控制，最多 3 个并发）
    ├── GetCampaigns（分页拉取全量）→ 批量 UPSERT campaigns
    ├── GetAdGroups（分页拉取全量） → 批量 UPSERT ad_groups
    └── GetAds（分页拉取全量）      → 批量 UPSERT ads
    │
    ▼
更新 advertisers.synced_at
    │
    ▼
返回同步结果给 iOS（成功数量 / 失败信息）
```

### 数据时效策略

| 数据 | 存储位置 | 更新策略 | 缓存 TTL |
|------|------|------|------|
| 账号余额 | 不存储 | 每次实时调用平台 API | — |
| 广告主列表 | MySQL | 手动刷新 / 授权后同步 | — |
| 推广系列 | MySQL | 手动刷新 / 授权后同步 | — |
| 广告组 | MySQL | 手动刷新 / 授权后同步 | — |
| 广告 | MySQL | 手动刷新 / 授权后同步 | — |
| 消耗数据（spend） | MySQL | 定期同步（每小时） | Redis 5 分钟 |
| access_token | MySQL（加密） | 到期前 30 分钟自动 refresh | — |

### UPSERT 策略

使用 `INSERT ... ON DUPLICATE KEY UPDATE` 处理数据同步，以平台唯一键（`platform` + 平台 ID）为基准：

```sql
-- 示例：campaigns 同步
INSERT INTO campaigns (advertiser_id, platform, campaign_id, campaign_name, status, budget, budget_mode, spend)
VALUES (?, ?, ?, ?, ?, ?, ?, ?)
ON DUPLICATE KEY UPDATE
    campaign_name = VALUES(campaign_name),
    status        = VALUES(status),
    budget        = VALUES(budget),
    budget_mode   = VALUES(budget_mode),
    spend         = VALUES(spend),
    updated_at    = CURRENT_TIMESTAMP;
```

---

## 索引设计说明

| 表 | 索引 | 用途 |
|------|------|------|
| users | uk_email | 登录查询 |
| platform_tokens | uk_user_platform_openid | 防重复授权 |
| platform_tokens | idx_user_platform | 查询用户的平台授权列表 |
| advertisers | uk_platform_advertiser | UPSERT 去重 |
| advertisers | idx_user_platform | App 首页账号列表 |
| campaigns | uk_platform_campaign | UPSERT 去重 |
| campaigns | idx_advertiser_id | 按广告主查系列 |
| ad_groups | uk_platform_adgroup | UPSERT 去重 |
| ad_groups | idx_campaign_id | 按系列查广告组 |
| ads | uk_platform_ad | UPSERT 去重 |
| ads | idx_adgroup_id | 按广告组查广告 |
| ads | idx_ad_name(50) | 广告名称前缀搜索 |
| operation_logs | idx_user_id | 查询用户操作历史 |
| operation_logs | idx_target | 查询某对象的操作记录 |
| operation_logs | idx_created_at | 按时间筛选日志 |

---

## 安全设计

| 项目 | 方案 |
|------|------|
| 密码存储 | bcrypt（cost=12），不存明文 |
| Token 存储 | AES-256-GCM 加密，密钥通过环境变量注入 |
| 防越权 | 所有接口校验 `advertiser.user_id = 当前登录用户 id` |
| 操作审计 | 所有写操作写入 operation_logs，不可删除 |
| Token 注销 | JWT jti 写入 Redis 黑名单，TTL = Token 剩余有效期 |

---

## 分页方案

列表接口统一使用 **页码分页**，支持下拉加载更多：

```json
// 请求参数
{
    "page": 1,
    "page_size": 20,
    "keyword": ""
}

// 响应
{
    "code": 0,
    "data": [...],
    "pagination": {
        "page": 1,
        "page_size": 20,
        "total": 100,
        "has_more": true
    }
}
```

广告表数据量较大时，可升级为 **cursor 分页**（基于 `id` 游标），避免深分页性能问题。
