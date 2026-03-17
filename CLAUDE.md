# 广告聚合管理平台

## 项目概述

iOS 客户端 + Go 后端的广告聚合管理平台。广告主授权平台账号后，可在 App 内统一管理 TikTok For Business 和 Kwai（快手商业化）两个平台的广告投放、预算控制和账户数据。

---

## 技术栈

### iOS 客户端

| 层级 | 技术选型 |
|------|------|
| 开发框架 | SwiftUI |
| 最低版本 | iOS 16+ |
| 网络层 | URLSession + async/await |
| 本地持久化 | SwiftData |
| 状态管理 | MVVM + @Observable |
| 图表 | Swift Charts |
| OAuth 授权 | ASWebAuthenticationSession |
| 列表分页 | 下拉加载更多（cursor / page 分页） |

### 后端服务

| 层级 | 技术选型 |
|------|------|
| 语言框架 | Go + Gin |
| 主数据库 | MySQL 8.0+ |
| 缓存 | Redis 7+ |
| 配置管理 | .env（godotenv + envconfig） |
| ORM | GORM |
| 认证 | JWT（golang-jwt/jwt v5） |
| 日志 | Uber Zap |
| Token 加密存储 | AES-256-GCM |

---

## 完整用户流程

```
登录（邮箱+密码）
    │
    ▼
MainTabView（底部 4 Tab）
    │
    ├── Tab1: 数据概览
    │     · 平台筛选（全部 / TikTok / Kwai）
    │     · 总消耗 / 活跃广告主 / 推广系列数 / 广告组数
    │     · 下拉刷新
    │
    ├── Tab2: 账号管理
    │     · 广告主账号列表（搜索 + 平台筛选 + 分页）
    │     · 左滑查看余额 / 右滑手动同步
    │     · 点击进入账号详情（推广系列/广告组/广告/操作记录）
    │     · 右上角「+」→ OAuth 授权 → 自动全量同步
    │
    ├── Tab3: 广告管理（层级钻取）
    │     账号 → 推广系列 → 广告组 → 广告
    │     · 每层支持修改预算 / 开启暂停（推广系列、广告组）
    │     · 广告层支持搜索
    │
    └── Tab4: 设置
          · 用户信息 / 添加授权 / 退出登录
```

---

## iOS 页面结构

```
App
├── LoginView                      # 邮箱 + 密码登录
└── MainTabView                    # 登录后主容器（底部 4 Tab）
    ├── Tab1: 数据（DashboardView）
    │   ├── 平台筛选：全部 / TikTok / Kwai
    │   └── 4 统计卡片：总消耗 / 活跃广告主 / 推广系列数 / 广告组数
    │
    ├── Tab2: 账号（AdvertiserListView）
    │   ├── 搜索栏 + 平台筛选
    │   ├── 下拉加载更多
    │   ├── 余额查看 Sheet（左滑）
    │   ├── 手动同步（右滑）
    │   ├── 右上角「+」去授权
    │   └── 点击进入 AccountDetailView（3 Tab：推广系列/广告组/广告/操作记录）
    │
    ├── Tab3: 广告（AdsManageView）  # 层级钻取
    │   ├── 账号列表（平台筛选 + 搜索）
    │   ├── → 推广系列列表（可修改预算/状态）
    │   ├──── → 广告组列表（可修改预算/状态）
    │   └──────── → 广告列表（含搜索）
    │
    └── Tab4: 设置（SettingsView）
        ├── 用户信息（邮箱 + 头像）
        ├── 添加平台授权
        └── 退出登录
```

---

## 后端 API 接口设计

### 认证模块 `/api/v1/auth`

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/auth/login` | 邮箱密码登录，返回 JWT |
| POST | `/auth/logout` | 登出（加入 Token 黑名单） |
| POST | `/auth/refresh` | 刷新 JWT |

### OAuth 授权模块 `/api/v1/oauth`

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/oauth/:platform/url` | 获取 OAuth 授权跳转 URL |
| POST | `/oauth/:platform/callback` | 接收 code，换取 access_token |
| DELETE | `/oauth/:platform/:account_id` | 解除授权 |

### 广告主账号模块 `/api/v1/advertisers`

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/advertisers` | 获取账号列表（支持 platform/keyword/page） |
| GET | `/advertisers/:id/balance` | 实时查询账号余额（不走缓存） |
| POST | `/advertisers/:id/sync` | 手动触发数据同步 |

### 推广系列模块 `/api/v1/campaigns`

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/advertisers/:id/campaigns` | 推广系列列表（支持分页） |
| PATCH | `/campaigns/:id/budget` | 修改预算 |
| PATCH | `/campaigns/:id/status` | 开启 / 暂停 |

### 广告组模块 `/api/v1/adgroups`

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/advertisers/:id/adgroups` | 广告组列表（支持 campaign_id 筛选 + 分页） |
| PATCH | `/adgroups/:id/budget` | 修改预算 |
| PATCH | `/adgroups/:id/status` | 开启 / 暂停 |

### 广告模块 `/api/v1/ads`

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/advertisers/:id/ads` | 广告列表（支持 adgroup_id/keyword/page） |

### 统计概览模块 `/api/v1/stats`

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/stats` | 数据概览（总消耗/活跃广告主/推广系列数/广告组数，支持 platform 过滤） |

---

## 数据库表结构

```sql
-- 用户表
CREATE TABLE users (
    id            BIGINT       PRIMARY KEY AUTO_INCREMENT,
    email         VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    name          VARCHAR(100),
    created_at    DATETIME     DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 平台 OAuth Token（一个用户可绑定多个平台账号）
CREATE TABLE platform_tokens (
    id                BIGINT       PRIMARY KEY AUTO_INCREMENT,
    user_id           BIGINT       NOT NULL,
    platform          VARCHAR(20)  NOT NULL COMMENT 'tiktok | kwai',
    open_user_id      VARCHAR(100) NOT NULL COMMENT '平台用户 ID',
    access_token_enc  TEXT         NOT NULL COMMENT 'AES 加密存储',
    refresh_token_enc TEXT,
    expires_at        DATETIME,
    status            TINYINT      DEFAULT 1 COMMENT '1有效 0失效',
    created_at        DATETIME     DEFAULT CURRENT_TIMESTAMP,
    updated_at        DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_user_platform (user_id, platform, open_user_id)
);

-- 广告主账号
CREATE TABLE advertisers (
    id              BIGINT       PRIMARY KEY AUTO_INCREMENT,
    token_id        BIGINT       NOT NULL COMMENT '关联 platform_tokens.id',
    user_id         BIGINT       NOT NULL,
    platform        VARCHAR(20)  NOT NULL,
    advertiser_id   VARCHAR(100) NOT NULL COMMENT '平台广告主 ID',
    advertiser_name VARCHAR(255),
    currency        VARCHAR(10),
    timezone        VARCHAR(50),
    status          TINYINT      DEFAULT 1,
    synced_at       DATETIME     COMMENT '最后同步时间',
    created_at      DATETIME     DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_platform_adv (platform, advertiser_id)
);

-- 推广系列
CREATE TABLE campaigns (
    id              BIGINT       PRIMARY KEY AUTO_INCREMENT,
    advertiser_id   BIGINT       NOT NULL COMMENT '关联 advertisers.id',
    platform        VARCHAR(20)  NOT NULL,
    campaign_id     VARCHAR(100) NOT NULL COMMENT '平台 campaign ID',
    campaign_name   VARCHAR(255),
    status          VARCHAR(50)  COMMENT '平台原始状态值',
    budget          DECIMAL(18,2),
    budget_mode     VARCHAR(50),
    spend           DECIMAL(18,2) DEFAULT 0,
    created_at      DATETIME     DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_platform_camp (platform, campaign_id)
);

-- 广告组
CREATE TABLE ad_groups (
    id            BIGINT       PRIMARY KEY AUTO_INCREMENT,
    advertiser_id BIGINT       NOT NULL,
    campaign_id   BIGINT       NOT NULL COMMENT '关联 campaigns.id',
    platform      VARCHAR(20)  NOT NULL,
    adgroup_id    VARCHAR(100) NOT NULL,
    adgroup_name  VARCHAR(255),
    status        VARCHAR(50),
    budget        DECIMAL(18,2),
    budget_mode   VARCHAR(50),
    spend         DECIMAL(18,2) DEFAULT 0,
    created_at    DATETIME     DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_platform_adg (platform, adgroup_id)
);

-- 广告
CREATE TABLE ads (
    id            BIGINT       PRIMARY KEY AUTO_INCREMENT,
    advertiser_id BIGINT       NOT NULL,
    adgroup_id    BIGINT       NOT NULL COMMENT '关联 ad_groups.id',
    platform      VARCHAR(20)  NOT NULL,
    ad_id         VARCHAR(100) NOT NULL,
    ad_name       VARCHAR(255),
    status        VARCHAR(50),
    created_at    DATETIME     DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_platform_ad (platform, ad_id)
);

-- 操作日志
CREATE TABLE operation_logs (
    id            BIGINT       PRIMARY KEY AUTO_INCREMENT,
    user_id       BIGINT       NOT NULL,
    advertiser_id BIGINT       NOT NULL,
    platform      VARCHAR(20)  NOT NULL,
    action        VARCHAR(100) NOT NULL COMMENT 'budget_update | status_update',
    target_type   VARCHAR(50)  COMMENT 'campaign | adgroup | ad',
    target_id     VARCHAR(100),
    before_val    JSON,
    after_val     JSON,
    created_at    DATETIME     DEFAULT CURRENT_TIMESTAMP
);
```

---

## 数据同步策略

### 授权后自动全量同步

```
OAuth 成功
    │
    ▼
拉取该 open_user_id 下所有广告主账号
    │
    ▼
遍历每个广告主：
    ├── 拉取推广系列列表（全量）
    ├── 拉取广告组列表（全量）
    └── 拉取广告列表（全量）
        │
        ▼
    写入 / 更新本地数据库（UPSERT）
        │
        ▼
    返回同步完成通知给 iOS
```

### 数据时效策略

| 数据类型 | 策略 |
|------|------|
| 账号余额 | 不缓存，实时调用平台 API |
| 消耗/报表数据 | Redis 缓存 5 分钟 |
| 推广系列/广告组/广告列表 | 本地 DB 存储 + 手动刷新触发同步 |
| Token | DB 加密存储，到期前 30 分钟自动 refresh |

---

## 后端项目结构

```
backend/
├── cmd/
│   └── server/
│       └── main.go
├── internal/
│   ├── config/
│   │   └── config.go
│   ├── middleware/
│   │   ├── auth.go             # JWT 验证
│   │   ├── cors.go
│   │   └── logger.go
│   ├── router/
│   │   └── router.go
│   ├── handler/
│   │   ├── auth/
│   │   ├── oauth/
│   │   ├── advertiser/
│   │   ├── campaign/
│   │   ├── adgroup/
│   │   ├── ad/
│   │   └── stats/              # 数据概览接口
│   ├── service/
│   │   ├── auth/
│   │   ├── oauth/
│   │   ├── sync/               # 全量同步逻辑
│   │   ├── advertiser/
│   │   ├── campaign/
│   │   ├── adgroup/
│   │   ├── ad/
│   │   ├── stats/              # 统计聚合（从本地 DB 计算）
│   │   ├── platform/
│   │   │   ├── tiktok/         # TikTok API 封装（实现 Platform 接口）
│   │   │   └── kwai/           # Kwai API 封装（实现 Platform 接口）
│   │   └── platform_interface.go  # 统一平台接口定义
│   ├── repository/
│   │   ├── user/
│   │   ├── token/
│   │   ├── advertiser/
│   │   ├── campaign/
│   │   ├── adgroup/
│   │   └── ad/
│   ├── model/
│   │   ├── entity/             # DB 实体
│   │   └── dto/                # 请求/响应结构体
│   └── pkg/
│       ├── database/
│       ├── cache/
│       ├── response/
│       ├── jwtutil/
│       ├── encrypt/            # AES Token 加解密
│       └── logger/
├── migrations/
├── .env.example
├── .env
├── go.mod
└── Makefile
```

---

## 平台接口统一抽象

```go
// internal/service/platform_interface.go
type Platform interface {
    GetOAuthURL(state string) string
    ExchangeToken(code string) (*TokenResult, error)
    RefreshToken(refreshToken string) (*TokenResult, error)
    GetAdvertisers(accessToken string) ([]*Advertiser, error)
    GetBalance(accessToken, advertiserID string) (*Balance, error)
    GetCampaigns(accessToken, advertiserID string, page int) ([]*Campaign, error)
    GetAdGroups(accessToken, advertiserID, campaignID string, page int) ([]*AdGroup, error)
    GetAds(accessToken, advertiserID, adGroupID string, page int) ([]*Ad, error)
    UpdateBudget(accessToken, advertiserID, targetID, targetType string, budget float64) error
    UpdateStatus(accessToken, advertiserID, targetID, targetType, status string) error
}
```

---

## 统一响应结构

```json
{
    "code": 0,
    "message": "ok",
    "data": {},
    "pagination": {
        "page": 1,
        "page_size": 20,
        "total": 100,
        "has_more": true
    }
}
```

| code | HTTP 状态码 | 含义 |
|------|------|------|
| 0 | 200 | 成功 |
| 1001 | 401 | 未登录 / JWT 过期 |
| 1002 | 422 | 参数校验失败 |
| 1003 | 502 | 平台 API 调用失败 |
| 1004 | 403 | 无权限操作该账号 |
| 1005 | 401 | OAuth Token 失效，需重新授权 |
| 5000 | 500 | 服务器内部错误 |

---

## 环境变量配置（.env.example）

```env
# Server
APP_ENV=development
APP_PORT=8080
APP_SECRET=your-jwt-secret-here
APP_ENCRYPT_KEY=32-byte-aes-key-here

# MySQL
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=root
DB_PASSWORD=
DB_NAME=ad_manage
DB_MAX_OPEN_CONNS=20
DB_MAX_IDLE_CONNS=5

# Redis
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DB=0

# TikTok
TIKTOK_APP_ID=
TIKTOK_APP_SECRET=
TIKTOK_REDIRECT_URI=https://yourdomain.com/oauth/tiktok/callback
TIKTOK_SANDBOX=true

# Kwai
KWAI_APP_KEY=
KWAI_APP_SECRET=
KWAI_REDIRECT_URI=https://yourdomain.com/oauth/kwai/callback
```

---

## Go 核心依赖

```
github.com/gin-gonic/gin
github.com/joho/godotenv
github.com/kelseyhightower/envconfig
gorm.io/gorm
gorm.io/driver/mysql
github.com/redis/go-redis/v9
github.com/golang-jwt/jwt/v5
go.uber.org/zap
```

---

## 开发阶段规划

### 后端

| 阶段 | 内容 | 状态 |
|------|------|------|
| B1 | 项目初始化：目录结构 / go mod / MySQL 连接 / Redis 连接 / 健康检查 | ✅ |
| B2 | 用户系统：注册 / 登录 / JWT 签发 / 刷新 / 登出黑名单 | ✅ |
| B3 | OAuth 模块：TikTok & Kwai 授权 URL 生成 / Callback / Token 加密存储 / 自动刷新 | ✅ |
| B4 | 数据同步：授权后全量拉取广告主/系列/广告组/广告并写入 DB | ✅ |
| B5 | 广告主接口：列表查询（分页+搜索）/ 实时余额 | ✅ |
| B6 | 推广系列接口：列表 / 修改预算 / 修改状态 | ✅ |
| B7 | 广告组接口：列表 / 修改预算 / 修改状态 | ✅ |
| B8 | 广告接口：列表（含搜索）| ✅ |
| B9 | 操作日志记录 | ✅ |
| B10 | 统计概览接口：GET /stats（总消耗/广告主数/系列数/广告组数，支持平台过滤） | ✅ |

### iOS

| 阶段 | 内容 | 状态 |
|------|------|------|
| I1 | 项目初始化：SwiftUI / MVVM 结构 / 网络层封装 / JWT 本地存储 | ✅ |
| I2 | 登录页：邮箱密码 / Token 持久化 / 自动续签 | ✅ |
| I3 | 平台选择页 | ✅ |
| I4 | OAuth 授权：ASWebAuthenticationSession / 回调处理 / 同步进度提示 | ✅ |
| I5 | 广告主账号列表：搜索 / 分页 / 余额查看 Sheet | ✅ |
| I6 | 账号详情 3 Tab：推广系列 / 广告组 / 广告 / 操作记录 | ✅ |
| I7 | 推广系列操作：修改预算弹窗 / 状态切换确认 | ✅ |
| I8 | 广告组操作：同上 | ✅ |
| I9 | 广告搜索：ID / 名称 | ✅ |
| I10 | 底部 4 Tab 导航（数据/账号/广告/设置） | ✅ |
| I11 | 数据概览 Dashboard：平台筛选 + 4 统计卡片 | ✅ |
| I12 | 广告层级钻取（Tab3：账号→系列→广告组→广告） | ✅ |
| I13 | 设置页：用户信息 / 添加授权 / 退出登录 | ✅ |

---

## 安全注意事项

- `.env` 必须加入 `.gitignore`，禁止提交到版本库
- `access_token` / `refresh_token` 存入 DB 前必须 AES-256-GCM 加密
- 所有写操作（修改预算、修改状态）必须写入 `operation_logs`
- 操作接口需校验当前用户是否有权限操作目标广告主（防越权）
- 生产环境通过系统环境变量注入，不依赖 `.env` 文件
- JWT 黑名单使用 Redis 存储（key: `jwt:blacklist:{jti}`，TTL = Token 剩余有效期）
