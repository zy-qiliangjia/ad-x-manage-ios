# 本地运行指南

> 适用环境：macOS + Xcode 16.0 + Go 1.22+

---

## 一、环境前置检查

| 工具 | 版本要求 | 检查命令 |
|------|------|------|
| Go | 1.22+ | `go version` |
| MySQL | 8.0+ | `mysql --version` |
| Redis | 7.0+ | `redis-server --version` |
| Xcode | 16.0 | Xcode → About |

### 安装缺失工具（已安装可跳过）

```bash
# 安装 Homebrew（如未安装）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 安装 Go
brew install go

# 安装 MySQL
brew install mysql

# 安装 Redis
brew install redis
```

---

## 二、启动后端

### 2.1 启动 MySQL 和 Redis

```bash
brew services start mysql
brew services start redis

# 确认运行中
brew services list | grep -E "mysql|redis"
# 应看到两行 started
```

### 2.2 创建数据库

```bash
mysql -u root -e "CREATE DATABASE IF NOT EXISTS ad_manage_x \
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

> 若 root 有密码：`mysql -u root -p -e "CREATE DATABASE ..."`

### 2.3 配置 .env

```bash
cd /Users/edy/data/project/42-ad-x-manage-ios/backend

# 首次初始化（已存在则跳过）
cp .env.example .env
```

用编辑器打开 `.env`，填写以下关键字段：

```env
APP_ENV=development
APP_PORT=8080

# 至少 32 字符的随机字符串
APP_SECRET=your-jwt-secret-min-32-chars-here!!
# 必须恰好 32 字节
APP_ENCRYPT_KEY=your-32-byte-aes-key-here!!!!!!

# MySQL（按实际密码修改）
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=root
DB_PASSWORD=
DB_NAME=ad_manage_x

# Redis（本地默认无密码）
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DB=0

# TikTok（沙箱测试阶段，生产前替换）
TIKTOK_APP_ID=
TIKTOK_APP_SECRET=
TIKTOK_REDIRECT_URI=adxmanage://oauth/callback
TIKTOK_SANDBOX=true

# Kwai
KWAI_APP_KEY=
KWAI_APP_SECRET=
KWAI_REDIRECT_URI=adxmanage://oauth/callback
```

> `APP_ENCRYPT_KEY` 必须恰好 32 个字节，否则 AES-256-GCM 初始化会 panic。
> 快速生成：`openssl rand -hex 16`（输出 32 个十六进制字符）

### 2.4 执行数据库迁移

```bash
cd /Users/edy/data/project/42-ad-x-manage-ios/backend
make migrate
```

成功后控制台输出 `migration done`，数据库会生成所有表。

### 2.5 启动服务器

```bash
cd /Users/edy/data/project/42-ad-x-manage-ios/backend
make run
# 或直接：go run cmd/server/main.go
```

控制台看到类似以下输出说明启动成功：

```
[GIN-debug] Listening and serving HTTP on :8080
```

### 2.6 验证接口可访问

```bash
curl http://localhost:8080/health
# 期望返回：{"code":0,"message":"ok"}
```

---

## 三、创建并运行 iOS 项目

> iOS 源代码已在 `ios/AdXManage/` 目录中，但尚未创建 Xcode 工程文件，需手动新建并导入。

### 3.1 新建 Xcode 工程

1. 打开 **Xcode 16.0**
2. 菜单 **File → New → Project**
3. 选择模板：**iOS → App** → Next
4. 填写项目信息：

   | 字段 | 值 |
   |------|------|
   | Product Name | `AdXManage` |
   | Team | 选择开发者账号（或 None 仅跑模拟器） |
   | Organization Identifier | `com.yourname`（自定义） |
   | Interface | **SwiftUI** |
   | Language | **Swift** |
   | Use Core Data | 不勾选 |

5. 保存位置选择 `/Users/edy/data/project/42-ad-x-manage-ios/ios/`
6. 点击 **Create**

### 3.2 替换 / 导入源文件

Xcode 默认生成了 `ContentView.swift` 和 `AdXManageApp.swift`，需要替换为仓库中的版本：

1. 在 Xcode **Project Navigator** 中删除默认生成的所有 `.swift` 文件（右键 → Delete → Move to Trash）
2. 右键项目根 Group → **Add Files to "AdXManage"**
3. 选择以下目录，勾选 **"Create groups"**，点击 Add：
   - `ios/AdXManage/App/`
   - `ios/AdXManage/Core/`
   - `ios/AdXManage/Features/`
   - `ios/AdXManage/Models/`

添加后工程树应与 `ios/AdXManage/` 目录结构一致。

### 3.3 配置 Info.plist

在 Xcode 工程 **Info** 标签（或 `Info.plist` 文件）中添加两项配置：

#### ① API_BASE_URL

| Key | Type | Value |
|-----|------|-------|
| `API_BASE_URL` | String | `http://localhost:8080/api/v1` |

> 对应 `APIClient.swift` 中的读取逻辑：
> `Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL")`

#### ② OAuth 回调 URL Scheme

在 Info.plist 添加 `URL types`：

| 字段 | 值 |
|------|------|
| URL identifier | `com.yourname.AdXManage` |
| URL Schemes | `adxmanage` |

> 此 scheme 对应 `OAuthService.swift` 中的 `callbackURLScheme: "adxmanage"`，
> 也需与 `.env` 中 `TIKTOK_REDIRECT_URI` / `KWAI_REDIRECT_URI` 的 scheme 保持一致。

### 3.4 配置 App Transport Security（允许 HTTP 本地访问）

本地后端使用 HTTP，需在 Info.plist 添加：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

或在 Xcode Info 编辑器中：
- 添加 `App Transport Security Settings` → 添加子项 `Allow Local Networking` = `YES`

### 3.5 选择模拟器并运行

1. 顶部设备选择器选择 **iPhone 15 Pro（或任意 iOS 17+ 模拟器）**
2. 按 `⌘R` 构建运行
3. 首次构建约需 1-2 分钟编译 SwiftUI 预览

---

## 四、首次使用流程

```
1. 模拟器中打开 App
2. 注册账号：填写邮箱 + 密码
3. 登录
4. 点击右上角「+」选择平台（TikTok / Kwai）
5. 进入 OAuth 授权页（需要已在平台注册开发者应用，.env 中填写 APP_ID/SECRET）
6. 授权完成后自动同步数据，进入广告主列表
```

> **无平台账号时测试**：可直接通过 API 工具（如 curl / Postman）向后端写入测试数据，
> 跳过 OAuth 流程验证列表展示、预算修改等功能。

---

## 五、常用命令速查

```bash
# ── 后端 ──────────────────────────────────────
cd backend

make run          # 启动后端
make build        # 编译为二进制 bin/server
make migrate      # 执行数据库迁移
make tidy         # 整理 Go 依赖
make test         # 运行单元测试

# ── MySQL ─────────────────────────────────────
brew services start mysql     # 启动
brew services stop mysql      # 停止
mysql -u root ad_manage_x     # 连接数据库

# ── Redis ─────────────────────────────────────
brew services start redis     # 启动
brew services stop redis      # 停止
redis-cli ping                # 测试连接（返回 PONG）

# ── 查看后端日志 ──────────────────────────────
# make run 已直接输出到终端，Ctrl+C 停止
```

---

## 六、常见问题

| 问题 | 原因 | 解决 |
|------|------|------|
| `panic: invalid key size` | `APP_ENCRYPT_KEY` 不是 32 字节 | 重新生成：`openssl rand -hex 16` |
| `Error 1049: Unknown database` | 数据库未创建 | 执行 §2.2 创建数据库 |
| `dial tcp 127.0.0.1:3306: connect: connection refused` | MySQL 未启动 | `brew services start mysql` |
| iOS 构建报 `No such module` | 源文件未正确 Add 到工程 | 重新按 §3.2 步骤 Add Files |
| `Cannot connect to the server` | 后端未启动 / ATS 限制 | 检查 `make run` + §3.4 ATS 配置 |
| OAuth 回调无响应 | URL Scheme 未配置 | 检查 Info.plist 中 `adxmanage` scheme |
