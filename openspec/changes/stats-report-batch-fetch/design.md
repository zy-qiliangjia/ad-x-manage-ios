## Context

TikTok Report API 的两个硬性约束：
1. 单次请求 `advertiser_ids` 最多传入 **5 个**
2. 调用频率上限 **10 次/秒**（即每次请求间隔 ≥ 100ms）

当前 `GetReportStats` 将所有广告主 ID 一次性传入，超过 5 个时平台直接返回错误，导致统计接口不可用。修复的核心是将 ID 列表分批并控制调用节奏。

服务已有整体 Redis 缓存（key 含 user_id + platform + date range），但批次级别没有缓存，重复请求会重复拉取所有批次。

## Goals / Non-Goals

**Goals:**
- 将 advertiser ID 列表切分为每批 ≤ 5 个，顺序逐批调用 Report API
- 批次间 sleep 100ms，确保调用频率 ≤ 10 req/s
- 各批次的 `total_metrics` 在服务层手动累加，返回全量汇总值
- 每批结果单独写入 Redis 中间缓存（TTL 15 分钟），命中时跳过该批次的 API 调用

**Non-Goals:**
- 不并行发送多个批次（并行会突破速率限制）
- 不将批次结果持久化到 MySQL（统计数据无需入库，Redis 缓存已足够）
- 不修改 `/stats` 接口签名或响应结构，对调用方完全透明
- 不处理 Kwai 分批（Kwai 当前返回零值占位，不受影响）

## Decisions

### 1. 顺序执行 + `time.Sleep(100ms)` 限速

**选择**: 每批请求发出后 sleep 100ms，再发下一批（首批无需 sleep）。

**理由**: 最简单可靠，无额外依赖。广告主数量通常 ≤ 20 个（即 ≤ 4 批），顺序耗时 ≤ 400ms，对于 15 分钟缓存命中率而言完全可接受。

**备选**: token bucket（`golang.org/x/time/rate`）→ 引入外部依赖，对此场景过度设计，不选。

### 2. 批次大小常量 = 5

**选择**: 常量 `batchSize = 5`，定义在 tiktok 平台实现文件内。

**理由**: 与平台限制对应，集中定义便于未来调整。

### 3. 中间批次缓存 key 不含 user_id，以广告主 ID 排序拼接为 key 的一部分

**选择**: 缓存 key 格式：
```
stats:report:batch:{platform}:{start_date}:{end_date}:{sorted_ids}
```
其中 `sorted_ids` = 该批次 advertiser_id 排序后逗号拼接（如 `111,222,333`）。

**理由**: 同一组广告主 ID 在相同日期范围的数据是确定的，不依赖 user_id（不同用户可能共享广告主）。避免相同批次被多用户重复拉取，提高缓存利用率。

**备选**: 含 user_id → 不同用户即便有相同广告主也不能共享缓存，浪费平台配额，不选。

### 4. 批次出错策略：fail fast，不返回部分结果

**选择**: 任一批次 API 返回错误时，立即返回 error，不返回已累加的部分数据。

**理由**: 部分数据会误导用户（数值偏低但看起来正常）；fail fast 触发 `/stats` handler 层降级到整体缓存（若有），或返回 1003。

**备选**: 跳过失败批次、返回部分结果 → 数据不一致风险高，不选。

### 5. 累加方式：各批次 total_metrics 逐字段求和

**选择**: 服务层在 `GetReportStats` 内部维护 `accumulated ReportStats`，每批响应的 `total_metrics` 对应字段累加：
- `Spend` (float64) += 该批 `total_metrics.spend`（string→float64）
- `Clicks` / `Conversion` / `Impressions` (int64) += 对应字段（string→int64）

**理由**: TikTok 的 `total_metrics` 是该请求内所有广告主的汇总，多个批次的汇总求和即为全量汇总。

## Risks / Trade-offs

- **[风险] sleep(100ms) 在批次较多时延迟较高** → 15 分钟缓存覆盖大多数请求，实际冷启动调用较少；可接受
- **[风险] 中间批次缓存 key 过长（含多个 advertiser_id）** → 实测 Redis key 无长度性能问题，5 个 20 位 ID 约 100 字符，可接受
- **[Trade-off] fail fast 导致整体失败** → 极个别批次失败时无法返回其他批次数据；由整体缓存兜底，降低影响
- **[风险] TikTok API 限额（日/月次数上限）** → 中间批次缓存复用能显著降低实际 API 调用次数，15 分钟 TTL 对高频访问有保护

## Migration Plan

只修改 tiktok 平台实现层，接口不变，直接替换部署无需迁移。

## Open Questions

- 若未来广告主数量急剧增加（如 >100 个），顺序拉取耗时过长，是否考虑引入异步预取？（当前不在范围内）
