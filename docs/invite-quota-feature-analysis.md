# 邀请码 & 广告主账号额度功能分析

> 日期：2026-03-19

---

## 一、需求概述

| 模块 | 说明 |
|------|------|
| 注册入口 | iOS 端不提供注册入口，用户联系客服，提供邮箱 + 邀请码，由客服通过后台添加账号 |
| 邀请码 | 每个用户拥有独立邀请码（格式：AP-XXXXXX）和独立邀请链接 |
| 邀请奖励 | 每成功邀请 1 位新用户注册，邀请人获得 +5 个广告主账号额度 |
| 账号额度 | 每个用户有独立的广告主账号额度上限，授权后只将在额度内的广告主入库，超出的不添加 |

---

## 二、核心逻辑说明

### 2.1 额度机制

```
新用户注册
  │
  ├── 初始额度：5 个（base_quota）
  │
  └── 通过邀请码注册时
        │
        ├── 邀请人额度 +5
        └── 新用户额度 +5（即初始仍为 5，当前阶段新用户无额外奖励；
                          如需双向奖励，可按业务调整）
```

- 额度为**全平台共享总额**（TikTok + Kwai 合计不超过该值）
- UI 层按平台分别显示已用数量，方便感知
- 示例：总额度 15 = 初始 5 + 2 位好友邀请 × 5

### 2.2 OAuth 授权后同步逻辑调整

```
OAuth 成功 → 拉取该 open_user_id 下所有广告主列表（平台返回 N 个）
  │
  ├── 查询当前用户已有广告主数量（已入库，跨所有平台）
  ├── 计算剩余可用额度 = total_quota - current_count
  │
  ├── 若剩余额度 > 0
  │     按平台返回顺序，取前 min(N, 剩余额度) 个广告主入库
  │
  └── 超出额度部分不入库，返回给 iOS 端提示：
        "已导入 X 个，Y 个因超出账号额度未导入，邀请好友可获得更多额度"
```

---

## 三、后端改动

### 3.1 数据库变更

#### `users` 表新增字段

```sql
ALTER TABLE users
  ADD COLUMN invite_code   VARCHAR(20)  UNIQUE  COMMENT '用户专属邀请码，格式 AP-XXXXXX',
  ADD COLUMN invited_by    BIGINT       NULL     COMMENT '邀请人 user_id，NULL 表示无邀请',
  ADD COLUMN base_quota    INT          NOT NULL DEFAULT 5 COMMENT '初始额度',
  ADD COLUMN bonus_quota   INT          NOT NULL DEFAULT 0 COMMENT '邀请奖励累计额度';
```

> `total_quota = base_quota + bonus_quota`，代码层计算，无需单独字段。

#### 索引

```sql
CREATE UNIQUE INDEX uk_invite_code ON users(invite_code);
CREATE INDEX idx_invited_by ON users(invited_by);
```

#### 迁移注意

- 存量用户迁移：`invite_code` 需在迁移脚本中批量生成，`bonus_quota` 默认为 0
- `GORM AutoMigrate` 只增不删索引，新索引由 AutoMigrate 创建，`UNIQUE` 索引需手动 `DROP` 旧索引后重建（如有同名索引冲突）

---

### 3.2 新增 / 改动 API

#### 3.2.1 管理员创建用户（供客服使用）

```
POST /api/v1/admin/users
Header: X-Admin-Token: <admin_secret>

Body:
{
  "email":       "user@example.com",
  "password":    "初始密码",
  "invite_code": "AP-XXXXXX"   // 可选，邀请人的邀请码
}

Response:
{
  "code": 0,
  "message": "ok",
  "data": {
    "user_id":     1,
    "email":       "user@example.com",
    "invite_code": "AP-V835PD"   // 新用户的邀请码
  }
}
```

**逻辑：**
1. 验证 `X-Admin-Token`（从 `.env` 读取 `ADMIN_SECRET`）
2. 若请求中携带 `invite_code`，查找邀请人，邀请人 `bonus_quota += 5`
3. 创建新用户，自动生成唯一 `invite_code`，`base_quota = 5`
4. 记录 `invited_by = 邀请人.id`

#### 3.2.2 获取当前用户邀请信息

```
GET /api/v1/users/invite
Header: Authorization: Bearer <jwt>

Response:
{
  "code": 0,
  "data": {
    "invite_code":    "AP-V835PD",
    "invite_link":    "https://apps.apple.com/app/adpilot?invite=AP-V835PD",
    "invited_count":  2,
    "earned_quota":   10,
    "total_quota":    15
  }
}
```

#### 3.2.3 获取账号额度信息

```
GET /api/v1/users/quota
Header: Authorization: Bearer <jwt>

Response:
{
  "code": 0,
  "data": {
    "total_quota": 15,
    "used_total":  3,
    "platforms": [
      { "platform": "tiktok", "used": 2 },
      { "platform": "kwai",   "used": 1 }
    ]
  }
}
```

#### 3.2.4 OAuth 同步接口返回调整

`POST /oauth/:platform/callback` 及 `POST /advertisers/:id/sync` 的响应中追加额度相关信息：

```json
{
  "code": 0,
  "data": {
    "imported_count": 3,
    "skipped_count":  2,
    "quota_exceeded": true,
    "total_quota":    5,
    "used_quota":     5
  }
}
```

---

### 3.3 新增文件 / 改动目录

```
backend/
├── internal/
│   ├── handler/
│   │   ├── admin/
│   │   │   └── user.go          # 新增：管理员创建用户
│   │   └── user/
│   │       └── invite.go        # 新增：邀请信息 & 额度查询
│   ├── service/
│   │   └── user/
│   │       ├── invite.go        # 新增：邀请码生成、奖励发放
│   │       └── quota.go         # 新增：额度计算
│   ├── middleware/
│   │   └── admin_auth.go        # 新增：X-Admin-Token 校验
│   └── model/
│       └── dto/
│           ├── invite.go        # 新增
│           └── quota.go         # 新增
```

**改动已有文件：**
- `internal/service/sync/sync.go` — 同步时加入额度校验，超出额度截断
- `internal/router/router.go` — 注册新路由
- `migrations/migrate.go` — 添加字段迁移
- `.env.example` — 新增 `ADMIN_SECRET`、`APP_INVITE_BASE_URL`

---

### 3.4 邀请码生成规则

- 格式：`AP-` + 6位大写字母数字（排除易混淆字符 O/0/I/1）
- 生成时检查唯一性，冲突则重新生成（碰撞概率极低）
- 示例：`AP-V835PD`

---

### 3.5 新增环境变量

```env
# 管理员接口鉴权密钥（客服后台调用）
ADMIN_SECRET=your-admin-secret-here

# App 邀请链接前缀
APP_INVITE_BASE_URL=https://apps.apple.com/app/adpilot
```

---

## 四、iOS 端改动

### 4.1 登录页调整

- 移除"注册"按钮（已在前序需求中处理，此处确认）
- 无需其他改动

### 4.2 新增页面

#### 4.2.1 广告账号管理页（AdvertiserAccountManageView）

**入口：** 设置 Tab → 广告账号管理

**内容：**
- 顶部额度卡片：显示总额度、已用总数
- 按平台分别显示进度条（已用 / 总额度）
- 下方"邀请好友，获得更多额度"入口（虚线按钮样式）
- 广告主账号列表（可在此页面统一查看所有平台账号）

**数据来源：** `GET /api/v1/users/quota`

#### 4.2.2 邀请好友页（InviteFriendsView）

**入口：** 设置 Tab → 邀请好友 / 广告账号管理页的邀请按钮

**内容：**
- 标题："邀请好友，扩展账号额度"
- 说明文案："每成功邀请1位新用户注册AdPilot，你和好友各获得+5个广告账号额度"
- 邀请码展示 + 复制按钮
- App 下载链接 + 复制按钮
- "生成邀请海报"按钮（一期可留空 / 占位）
- 底部统计：已邀请 N 人 / 获得额度 +N / 当前总额度 N

**数据来源：** `GET /api/v1/users/invite`

---

### 4.3 设置页（SettingsView）调整

新增两个操作行：

```
当前账号管理组
├── 广告账号管理   →  AdvertiserAccountManageView
└── 邀请好友       →  InviteFriendsView
```

额度简要信息可在设置页账号 Section 下展示（可选）：
> 账号额度：已用 3 / 共 15

---

### 4.4 账号授权后 OAuth 结果提示

当 `skipped_count > 0` 时，在授权成功的 Sheet / Alert 中追加提示：

> "已成功导入 3 个广告主账号，另有 2 个因超出账号额度未导入。
> 邀请好友可获得更多额度。[去邀请 →]"

---

### 4.5 新增 Model / ViewModel

```swift
// Models
struct UserQuota: Codable {
    let totalQuota: Int
    let usedTotal: Int
    let platforms: [PlatformQuota]
}

struct PlatformQuota: Codable {
    let platform: String
    let used: Int
}

struct InviteInfo: Codable {
    let inviteCode: String
    let inviteLink: String
    let invitedCount: Int
    let earnedQuota: Int
    let totalQuota: Int
}

struct SyncResult: Codable {
    let importedCount: Int
    let skippedCount: Int
    let quotaExceeded: Bool
    let totalQuota: Int
    let usedQuota: Int
}
```

---

### 4.6 新增 API 调用

```
APIService 新增：
  - fetchUserQuota()   → GET /api/v1/users/quota
  - fetchInviteInfo()  → GET /api/v1/users/invite
```

---

## 五、开发阶段规划（建议）

| 阶段 | 内容 | 端 |
|------|------|----|
| P1 | users 表加字段 + 迁移脚本 + 邀请码生成工具函数 | backend |
| P2 | 初始化 `admin-backend/` 项目结构（go mod / 路由 / 健康检查） | admin-backend |
| P3 | 管理后台创建用户接口 `POST /admin/api/v1/users`（含邀请奖励逻辑） | admin-backend |
| P4 | 管理后台用户列表 / 详情 / 调整额度接口 | admin-backend |
| P5 | 邀请信息接口 `GET /users/invite` + 额度接口 `GET /users/quota` | backend |
| P6 | OAuth 同步加入额度控制逻辑 | backend |
| P7 | iOS AdvertiserAccountManageView | iOS |
| P8 | iOS InviteFriendsView | iOS |
| P9 | iOS SettingsView 添加入口 | iOS |
| P10 | iOS OAuth 结果提示调整 | iOS |

---

## 六、管理后台（admin-backend）独立项目

### 6.1 项目定位

管理后台为独立 Go 项目，与 `backend/` 平级，不耦合主服务代码。

```
42-ad-x-manage-ios/
├── backend/          # 主服务（现有，面向 iOS 客户端）
├── admin-backend/    # 管理后台服务（新建，面向客服/运营人员）
├── ios/
├── docs/
└── ...
```

### 6.2 技术栈

与主服务保持一致，共享同一套 MySQL / Redis：

| 层级 | 选型 |
|------|------|
| 语言框架 | Go + Gin |
| 数据库 | MySQL 8.0+（同库，不同鉴权） |
| 缓存 | Redis 7+（同实例） |
| 配置 | .env（godotenv + envconfig） |
| ORM | GORM |
| 认证 | 独立 JWT 或固定 Admin Token（初期用 Token 即可） |
| 日志 | Uber Zap |

> 初期简单起见，管理后台使用 `X-Admin-Token` 静态 Token 鉴权，后期可升级为独立账号体系。

### 6.3 项目目录结构

```
admin-backend/
├── cmd/
│   └── server/
│       └── main.go
├── internal/
│   ├── config/
│   │   └── config.go
│   ├── middleware/
│   │   ├── auth.go         # X-Admin-Token 校验
│   │   ├── cors.go
│   │   └── logger.go
│   ├── router/
│   │   └── router.go
│   ├── handler/
│   │   ├── user/           # 用户管理
│   │   └── quota/          # 额度管理
│   ├── service/
│   │   ├── user/
│   │   └── quota/
│   ├── repository/         # 复用 / 复制主服务 repository 层
│   │   └── user/
│   ├── model/
│   │   ├── entity/         # 与主服务共用 DB 实体定义
│   │   └── dto/
│   └── pkg/
│       ├── database/
│       ├── response/
│       └── logger/
├── .env.example
├── .env
├── go.mod
└── Makefile
```

### 6.4 管理后台 API（一期范围）

#### 用户管理 `/admin/api/v1/users`

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/users` | 创建用户（邮箱+密码+可选邀请码） |
| GET | `/users` | 用户列表（支持邮箱搜索 + 分页） |
| GET | `/users/:id` | 用户详情（含邀请码、额度、授权账号数） |
| PATCH | `/users/:id/quota` | 手动调整用户额度 |
| DELETE | `/users/:id` | 禁用用户（软删除） |

#### 邀请管理 `/admin/api/v1/invites`

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/invites` | 邀请关系列表（谁邀请了谁、时间） |

#### 系统 `/admin/api/v1`

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/health` | 健康检查 |

### 6.5 创建用户接口详细说明

```
POST /admin/api/v1/users
Header: X-Admin-Token: <ADMIN_SECRET>

Body:
{
  "email":       "user@example.com",
  "password":    "初始密码（明文，服务端 bcrypt 加密）",
  "invite_code": "AP-V835PD"   // 可选，邀请人的邀请码
}

成功响应：
{
  "code": 0,
  "data": {
    "user_id":     10,
    "email":       "user@example.com",
    "invite_code": "AP-K3ZT8W",  // 新用户的邀请码（自动生成）
    "total_quota": 5
  }
}

若携带 invite_code：
- 找到邀请人 → 邀请人 bonus_quota += 5
- 新用户 base_quota = 5（可按需调整为双向奖励）
```

### 6.6 环境变量（.env.example）

```env
# Server
APP_ENV=development
APP_PORT=8081            # 与主服务不同端口

# MySQL（同主服务库）
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=root
DB_PASSWORD=
DB_NAME=ad_manage

# Redis（同实例）
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DB=0

# 管理后台鉴权
ADMIN_SECRET=your-admin-secret-here
```

### 6.7 主服务改动（backend/）

由于管理后台独立后，`backend/` 中**无需再保留** `POST /admin/users` 接口，相关逻辑迁移至 `admin-backend/`。

`backend/` 中只保留：
- `GET /api/v1/users/invite` — iOS 端查看邀请信息
- `GET /api/v1/users/quota` — iOS 端查看额度

---

## 七、暂不涉及（后期规划）

- 管理后台 Web UI（当前仅 HTTP API，客服通过 API 工具调用）
- 邀请海报生成
- 邀请排行榜
- 额度兑换 / 付费购买额度
- 新用户注册双向奖励（当前仅邀请人获得 +5）
- 管理后台独立账号体系（当前使用静态 Token）

---

## 八、SQL 变更记录

详见 `docs/db-migrations.md`（追加以下内容）：

```sql
-- 20260319: 新增邀请码 & 账号额度字段
ALTER TABLE users
  ADD COLUMN invite_code VARCHAR(20)  NULL    COMMENT '用户专属邀请码 AP-XXXXXX'  AFTER name,
  ADD COLUMN invited_by  BIGINT       NULL    COMMENT '邀请人 user_id'             AFTER invite_code,
  ADD COLUMN base_quota  INT NOT NULL DEFAULT 5 COMMENT '初始账号额度'             AFTER invited_by,
  ADD COLUMN bonus_quota INT NOT NULL DEFAULT 0 COMMENT '邀请奖励累计额度'          AFTER base_quota;

-- 唯一索引（邀请码全局唯一）
CREATE UNIQUE INDEX uk_invite_code ON users(invite_code);
CREATE INDEX idx_invited_by ON users(invited_by);
```
