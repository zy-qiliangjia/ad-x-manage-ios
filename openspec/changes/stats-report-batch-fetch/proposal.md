## Why

TikTok Report API 存在两个硬性限制：单次请求最多传入 5 个 `advertiser_id`，且调用频率上限为 10 次/秒。当前 `GetReportStats` 实现将所有广告主 ID 一次性传入，在广告主数量超过 5 个时会触发接口报错；高并发场景下亦可能超出频率限制导致请求失败。

## What Changes

- `GetReportStats` 内部实现改为将 advertiser ID 列表切分为每批最多 5 个，顺序逐批调用 Report API
- 批次间引入限速控制，确保调用频率不超过 10 次/秒
- 每批响应的 `total_metrics` 指标在客户端（服务层）累加，得到所有广告主的汇总值
- 每批的中间结果单独写入 Redis 缓存（key 含 advertiser_id 批次哈希），TTL 15 分钟，支持部分命中复用，避免重复拉取
- 最终聚合结果继续写入整体缓存 key（已有设计）

## Capabilities

### New Capabilities

- `report-stats-batch-rate-limit`: 将广告主 ID 分批（每批 ≤5）调用 Report API，限速 ≤10 req/s，逐批累加指标，中间结果缓存复用

### Modified Capabilities

- `platform-report-stats`: `GetReportStats` 调用行为变更——不再单次传入全部 ID，改为分批调用并汇总；批次限速和中间缓存属于新增规范

## Impact

- **后端**
  - `internal/service/platform/tiktok/`：重写 `GetReportStats`，加入分批逻辑和限速控制
  - `internal/service/stats/`：无需感知分批细节，接口签名不变
  - Redis：新增中间批次缓存 key 格式：`stats:report:batch:{user_id}:{platform}:{batch_hash}:{start_date}:{end_date}`，TTL 15 分钟
- **接口兼容性**：`/stats` 接口签名和响应结构不变，对调用方透明
