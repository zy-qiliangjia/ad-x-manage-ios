## 1. TikTok 平台层：分批工具函数

- [x] 1.1 在 `internal/service/platform/tiktok/` 定义常量 `batchSize = 5`
- [x] 1.2 实现辅助函数 `chunkIDs(ids []string, size int) [][]string`，将 ID 列表按 size 切分为二维切片

## 2. TikTok 平台层：批次中间缓存

- [x] 2.1 实现 `batchCacheKey(platform, startDate, endDate string, batchIDs []string) string`：对 batchIDs 排序后逗号拼接，拼装为 `stats:report:batch:{platform}:{start_date}:{end_date}:{sorted_ids}` 格式的 Redis key
- [x] 2.2 实现批次缓存读取逻辑：调用 TikTok API 前先查 Redis，命中则直接返回缓存的 `ReportStats` 部分值，跳过 API 调用
- [x] 2.3 实现批次缓存写入逻辑：API 调用成功后，将该批次的 `total_metrics` 序列化为 JSON 写入 Redis，TTL 15 分钟

## 3. TikTok 平台层：分批调用与限速

- [x] 3.1 重写 `GetReportStats` 主体：调用 `chunkIDs` 切分 advertiserIDs，遍历批次列表
- [x] 3.2 在每个批次循环内：先查批次缓存；未命中则调用 TikTok Report API（`advertiser_ids` 限制为该批次 ≤5 个 ID），写缓存
- [x] 3.3 在第 2 批及后续批次开始前插入 `time.Sleep(100 * time.Millisecond)`（首批不等待）
- [x] 3.4 任一批次 API 返回非 0 code 或 error 时，立即返回 error（fail fast），不返回已累加数据

## 4. TikTok 平台层：跨批次指标累加

- [x] 4.1 在批次循环外初始化累加器 `accumulated ReportStats{}`
- [x] 4.2 每批成功获取（缓存命中或 API 返回）后，将该批次 `total_metrics` 的 spend（string→float64）、clicks / conversion / impressions（string→int64）分别累加到 `accumulated`
- [x] 4.3 所有批次处理完成后，返回 `&accumulated, nil`

## 5. 边界与回归验证

- [x] 5.1 验证 advertiserIDs 为空时，直接返回 `ReportStats{}` 零值，不进入批次循环
- [x] 5.2 验证 advertiserIDs ≤ 5 时，仅发起 1 次请求，无 sleep
- [x] 5.3 验证 advertiserIDs = 13 时，发起 3 次请求（5+5+3），有 2 次 sleep
- [x] 5.4 验证批次缓存命中时不调用平台 API（可通过观察 Redis key 和日志确认）
