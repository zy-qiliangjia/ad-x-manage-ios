## Context

当前账号管理列表（AdvertiserListView）仅展示广告主名称、平台标识和状态等基础字段，无任何投放指标。用户若需了解某账号的消耗/转化等数据，必须逐个进入账号详情页，操作路径长。

TikTok 平台提供报表接口 `GET /open_api/v1.3/report/integrated/get`，支持按广告主维度批量查询指标，但接口对单次请求的广告主数量有限制（最多5个），且有调用频率限制，需要在服务端批量拆分并缓存。

## Goals / Non-Goals

**Goals:**
- 后端新增 `GET /stats/report` 接口，接收广告主 ID 列表 + 日期区间，内部拆分为每批≤5个广告主，并行调用 TikTok 报表接口，结果合并后返回
- 接口结果 Redis 缓存5分钟，减少对平台 API 的调用压力
- iOS 账号列表新增指标卡片（消耗、点击、展示、转化、CPA、日预算）
- iOS 新增日期筛选器（默认近7天，最大跨度30天）
- iOS 展示汇总行（所有广告主指标合计）
- 数据未拉取到时指标显示0，不阻塞列表渲染

**Non-Goals:**
- 不实现 Kwai 平台报表（接口预留扩展点，Kwai 返回空数据）
- 不实现实时推送或 WebSocket 刷新
- 不修改账号详情页的现有指标展示逻辑

## Decisions

### 1. 服务端批量拆分 vs 客户端分批请求

**决策**：服务端做拆分，iOS 只请求一次，传入全量 advertiser_id 列表。

**理由**：
- 客户端分批会增加网络往返次数，且每次都需要合并缓存逻辑
- 服务端可利用 goroutine 并发执行多批请求，延迟更低
- 服务端统一做 Redis 缓存，避免多端重复拉取
- 缓存 key 设计：`stats:report:{platform}:{start_date}:{end_date}:{sorted_ids_hash}`

### 2. 缓存粒度：整批 vs 单个广告主

**决策**：以单个广告主为粒度缓存（key: `stats:report:{platform}:{advertiser_id}:{start_date}:{end_date}`），命中则跳过，未命中则收集到同一批次请求。

**理由**：
- 粗粒度缓存（整批）在广告主列表组合不一致时命中率极低
- 细粒度可有效复用单个广告主已缓存的数据，减少 API 调用次数
- 缓存 TTL 5分钟，日期区间固定时数据稳定

**备选方案**：整批缓存 → 命中率低，不采用

### 3. 日预算字段来源

**决策**：日预算（daily_budget）展示广告主级别预算，通过 TikTok `/open_api/v1.3/advertiser/info/` 接口获取并在 DB `advertisers` 表新增 `daily_budget` 字段存储；在 OAuth 全量同步和手动同步时更新，账号列表直接从 DB 读取，无需实时请求。

**理由**：
- 用户明确要求展示广告主级别（非 campaign 汇总）
- TikTok 报表接口（AUCTION_ADVERTISER 维度）不返回广告主预算字段，需额外调用 advertiser info 接口
- 存入 DB 可避免每次展示时调用平台接口，访问成本低
- 同步时顺带更新，数据新鲜度可接受（手动同步可强制刷新）

### 4. iOS 指标布局

**决策**：在每个账号 Cell 下方新增一行2列或3列指标网格（小字号），不改变现有 Cell 高度的主要结构，仅在展开状态下显示。考虑到屏幕空间，采用横向滚动的指标胶囊或固定2行3列网格。

**最终选择**：固定显示（无折叠），2行 × 3列指标网格，紧凑字号（caption）。

### 5. 日期筛选器交互

**决策**：使用 SwiftUI `DatePicker` 组合成自定义区间选择器，内嵌在列表顶部工具栏或筛选区域。超出30天时自动截断并提示。

## Risks / Trade-offs

- **平台 API 限速** → 批次间加入短暂延迟（如50ms）或基于错误码重试，服务端缓存减少实际调用频次
- **TikTok 接口字段变更** → 字段映射集中在 platform/tiktok 服务层，变更时只需修改一处
- **广告主列表很长时请求耗时** → 服务端并发执行多批，iOS 显示 loading skeleton，数据到达后逐步填充
- **Kwai 暂不实现** → 接口设计预留 platform 参数，Kwai 请求直接返回空指标（全0）
- **缓存击穿（大量广告主同时过期）** → TTL 加随机抖动（±30s）分散过期时间

## Migration Plan

1. 后端：新增 `/stats/report` 路由和 handler，不修改现有接口，向后兼容
2. iOS：`AdvertiserListView` 新增 ViewModel 字段和子视图，原有逻辑不变
3. 部署顺序：先发布后端，再发布 iOS 客户端（iOS 新版本依赖新接口）

## Open Questions

~~- TikTok 报表接口在沙盒环境（TIKTOK_SANDBOX=true）是否支持？~~
**已解决**：TikTok 无沙盒环境，App 已申请并通过正式审核，直接使用生产环境接口。`TIKTOK_SANDBOX` 配置项可移除或忽略，无需 mock 数据，测试使用真实账号。

~~- 日预算是否需要展示广告主级别还是账户级别？~~
**已解决**：展示广告主级别日预算。方案见 Decision 3：新增 `advertisers.daily_budget` 字段，通过 TikTok advertiser info 接口在同步时写入。
