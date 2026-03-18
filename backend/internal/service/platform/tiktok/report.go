package tiktok

import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/redis/go-redis/v9"

	"ad-x-manage/backend/internal/service/platform"
)

// batchSize TikTok Report API 单次请求最多支持的广告主数量。
const batchSize = 5

// batchCacheTTL 批次中间结果缓存时长。
const batchCacheTTL = 15 * time.Minute

// rateLimitInterval 批次间最小间隔，确保调用频率 ≤10 次/秒。
const rateLimitInterval = 100 * time.Millisecond

// chunkIDs 将 ids 按 size 切分为二维切片。
func chunkIDs(ids []string, size int) [][]string {
	var chunks [][]string
	for size < len(ids) {
		ids, chunks = ids[size:], append(chunks, ids[0:size:size])
	}
	return append(chunks, ids)
}

// batchCacheKey 生成批次中间缓存 key。
// 格式：stats:report:batch:{platform}:{start_date}:{end_date}:{sorted_ids}
// sorted_ids 为该批次 advertiser_id 升序排列后以逗号拼接。
func batchCacheKey(platformName, startDate, endDate string, batchIDs []string) string {
	sorted := make([]string, len(batchIDs))
	copy(sorted, batchIDs)
	sort.Strings(sorted)
	return fmt.Sprintf("stats:report:batch:%s:%s:%s:%s",
		platformName, startDate, endDate, strings.Join(sorted, ","))
}

// batchTotalMetrics 批次 API 响应中 total_metrics 的原始字段。
type batchTotalMetrics struct {
	Spend       string `json:"spend"`
	Clicks      string `json:"clicks"`
	Impressions string `json:"impressions"`
	Conversion  string `json:"conversion"`
}

// GetReportStats 拉取 advertiserIDs 在 [startDate, endDate] 内的汇总指标。
// 内部将 ID 列表按每批 ≤5 个切分，顺序调用 TikTok Report API，批次间 sleep 100ms，
// 各批次结果逐字段累加后返回。每批结果独立写入 Redis 缓存（TTL 15 分钟）。
func (c *Client) GetReportStats(accessToken string, advertiserIDs []string, startDate, endDate string) (*platform.ReportStats, error) {
	if len(advertiserIDs) == 0 {
		return &platform.ReportStats{}, nil
	}

	ctx := context.Background()
	batches := chunkIDs(advertiserIDs, batchSize)
	accumulated := platform.ReportStats{}

	for i, batch := range batches {
		// 限速：第 2 批及后续批次等待 100ms
		if i > 0 {
			time.Sleep(rateLimitInterval)
		}

		batchStats, err := c.fetchBatch(ctx, accessToken, batch, startDate, endDate)
		if err != nil {
			return nil, err
		}

		accumulated.Spend += batchStats.Spend
		accumulated.Clicks += batchStats.Clicks
		accumulated.Impressions += batchStats.Impressions
		accumulated.Conversion += batchStats.Conversion
	}

	return &accumulated, nil
}

// fetchBatch 获取单批次的 ReportStats，优先读取 Redis 缓存；
// 缓存未命中时调用 TikTok API 并将结果写入缓存。
func (c *Client) fetchBatch(ctx context.Context, accessToken string, batchIDs []string, startDate, endDate string) (*platform.ReportStats, error) {
	cacheKey := batchCacheKey("tiktok", startDate, endDate, batchIDs)

	// 尝试读取批次缓存
	if c.rdb != nil {
		if cached, err := c.rdb.Get(ctx, cacheKey).Bytes(); err == nil {
			var stats platform.ReportStats
			if jsonErr := json.Unmarshal(cached, &stats); jsonErr == nil {
				return &stats, nil
			}
		}
	}

	// 缓存未命中，调用 TikTok Report API
	idsJSON, _ := json.Marshal(batchIDs)
	metricsJSON, _ := json.Marshal([]string{"spend", "clicks", "impressions", "conversion"})
	dimensionsJSON, _ := json.Marshal([]string{"advertiser_id"})

	params := url.Values{}
	params.Set("page", "1")
	params.Set("page_size", "1000")
	params.Set("data_level", "AUCTION_ADVERTISER")
	params.Set("report_type", "BASIC")
	params.Set("dimensions", string(dimensionsJSON))
	params.Set("metrics", string(metricsJSON))
	params.Set("enable_total_metrics", "true")
	params.Set("start_date", startDate)
	params.Set("end_date", endDate)
	params.Set("advertiser_ids", string(idsJSON))

	var resp struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
		Data    struct {
			TotalMetrics batchTotalMetrics `json:"total_metrics"`
		} `json:"data"`
	}
	if err := c.get("/open_api/"+apiVersion+"/report/integrated/get/", params, accessToken, &resp); err != nil {
		return nil, fmt.Errorf("tiktok report api error: %w", err)
	}
	if resp.Code != 0 {
		return nil, fmt.Errorf("tiktok report api error %d: %s", resp.Code, resp.Message)
	}

	stats := parseTotalMetrics(resp.Data.TotalMetrics)

	// 写入批次缓存
	if c.rdb != nil {
		if data, err := json.Marshal(stats); err == nil {
			_ = c.rdb.Set(ctx, cacheKey, data, batchCacheTTL).Err()
		}
	}

	return stats, nil
}

// parseTotalMetrics 将 API 返回的 string 字段转换为 ReportStats 数值类型。
func parseTotalMetrics(m batchTotalMetrics) *platform.ReportStats {
	spend, _ := strconv.ParseFloat(m.Spend, 64)
	clicks, _ := strconv.ParseInt(m.Clicks, 10, 64)
	impressions, _ := strconv.ParseInt(m.Impressions, 10, 64)
	conversion, _ := strconv.ParseInt(m.Conversion, 10, 64)
	return &platform.ReportStats{
		Spend:       spend,
		Clicks:      clicks,
		Impressions: impressions,
		Conversion:  conversion,
	}
}

// getCachedBatch 仅用于测试辅助：检查 Redis 中是否存在某批次缓存。
// 生产代码不调用此函数。
func getCachedBatch(ctx context.Context, rdb *redis.Client, key string) (*platform.ReportStats, bool) {
	data, err := rdb.Get(ctx, key).Bytes()
	if err != nil {
		return nil, false
	}
	var stats platform.ReportStats
	if err := json.Unmarshal(data, &stats); err != nil {
		return nil, false
	}
	return &stats, true
}
