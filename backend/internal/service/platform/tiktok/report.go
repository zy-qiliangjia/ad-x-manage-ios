package tiktok

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"math/rand"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"sync"
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

// ── 逐广告主报表（per-advertiser）──────────────────────────────

const advReportCacheTTLBase = 5 * time.Minute

// advReportCacheKey 生成单广告主报表缓存 key。
// 格式：stats:report:adv:tiktok:{advertiser_id}:{start_date}:{end_date}
func advReportCacheKey(advertiserID, startDate, endDate string) string {
	return fmt.Sprintf("stats:report:adv:tiktok:%s:%s:%s", advertiserID, startDate, endDate)
}

// advReportCacheTTL 返回加随机抖动（±30s）的 TTL，分散缓存过期。
func advReportCacheTTL() time.Duration {
	jitter := time.Duration(rand.Intn(61)-30) * time.Second
	return advReportCacheTTLBase + jitter
}

// GetAdvertiserReport 返回 advertiserIDs 中每个广告主在 [startDate, endDate] 内的明细指标。
// 优先读 Redis 缓存（per-advertiser key），未命中的 ID 分批 ≤5 并发调用 TikTok API，
// 结果缓存后合并返回；原始列表中无数据的广告主以零值占位。
func (c *Client) GetAdvertiserReport(accessToken string, advertiserIDs []string, startDate, endDate string) ([]*platform.AdvertiserReportItem, error) {
	if len(advertiserIDs) == 0 {
		return nil, nil
	}

	ctx := context.Background()
	result := make(map[string]*platform.AdvertiserReportItem, len(advertiserIDs))
	var uncached []string

	// 1. 从缓存读取已有结果
	for _, id := range advertiserIDs {
		if c.rdb != nil {
			if raw, err := c.rdb.Get(ctx, advReportCacheKey(id, startDate, endDate)).Bytes(); err == nil {
				var item platform.AdvertiserReportItem
				if jsonErr := json.Unmarshal(raw, &item); jsonErr == nil {
					result[id] = &item
					continue
				}
			}
		}
		uncached = append(uncached, id)
	}

	// 2. 对未命中缓存的 ID 按批次 ≤5 并发请求
	if len(uncached) > 0 {
		batches := chunkIDs(uncached, batchSize)
		type batchResult struct {
			items []*platform.AdvertiserReportItem
			err   error
		}
		ch := make(chan batchResult, len(batches))

		var wg sync.WaitGroup
		for i, batch := range batches {
			wg.Add(1)
			go func(idx int, ids []string) {
				defer wg.Done()
				// 轻量限速：错开批次起始时间
				if idx > 0 {
					time.Sleep(time.Duration(idx) * rateLimitInterval)
				}
				items, err := c.fetchAdvBatch(ctx, accessToken, ids, startDate, endDate)
				ch <- batchResult{items: items, err: err}
			}(i, batch)
		}
		wg.Wait()
		close(ch)

		for br := range ch {
			if br.err != nil {
				// 批次失败时记录但不中断；失败广告主以零值占位
				continue
			}
			for _, item := range br.items {
				result[item.AdvertiserID] = item
				// 写入缓存
				if c.rdb != nil {
					if raw, err := json.Marshal(item); err == nil {
						_ = c.rdb.Set(ctx, advReportCacheKey(item.AdvertiserID, startDate, endDate), raw, advReportCacheTTL()).Err()
					}
				}
			}
		}
	}

	// 3. 按原始顺序输出，缺失的补零值
	out := make([]*platform.AdvertiserReportItem, 0, len(advertiserIDs))
	for _, id := range advertiserIDs {
		if item, ok := result[id]; ok {
			out = append(out, item)
		} else {
			out = append(out, &platform.AdvertiserReportItem{AdvertiserID: id})
		}
	}
	return out, nil
}

// advMetrics TikTok Report API 返回的单广告主 metrics 字段。
type advMetrics struct {
	Spend                          string `json:"spend"`
	Clicks                         string `json:"clicks"`
	Impressions                    string `json:"impressions"`
	Conversion                     string `json:"conversion"`
	CostPerConversion              string `json:"cost_per_conversion"`
	SkanClickTimeCostPerConversion string `json:"skan_click_time_cost_per_conversion"`
	Currency                       string `json:"currency"`
	AdvertiserID                   string `json:"advertiser_id"`
}

// fetchAdvBatch 调用 TikTok Integrated Report API 获取 ≤5 个广告主的明细数据。
func (c *Client) fetchAdvBatch(ctx context.Context, accessToken string, batchIDs []string, startDate, endDate string) ([]*platform.AdvertiserReportItem, error) {
	idsJSON, _ := json.Marshal(batchIDs)
	metricsJSON, _ := json.Marshal([]string{
		"spend", "clicks", "impressions", "conversion",
		"cost_per_conversion", "skan_click_time_cost_per_conversion", "currency",
	})
	dimensionsJSON, _ := json.Marshal([]string{"advertiser_id"})

	params := url.Values{}
	params.Set("page", "1")
	params.Set("page_size", "1000")
	params.Set("data_level", "AUCTION_ADVERTISER")
	params.Set("report_type", "BASIC")
	params.Set("dimensions", string(dimensionsJSON))
	params.Set("metrics", string(metricsJSON))
	params.Set("enable_total_metrics", "false")
	params.Set("start_date", startDate)
	params.Set("end_date", endDate)
	params.Set("advertiser_ids", string(idsJSON))

	var resp struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
		Data    struct {
			List []struct {
				Dimensions struct {
					AdvertiserID string `json:"advertiser_id"`
				} `json:"dimensions"`
				Metrics advMetrics `json:"metrics"`
			} `json:"list"`
		} `json:"data"`
	}

	if err := c.get("/open_api/"+apiVersion+"/report/integrated/get/", params, accessToken, &resp); err != nil {
		return nil, fmt.Errorf("tiktok adv report api: %w", err)
	}
	if resp.Code != 0 {
		return nil, fmt.Errorf("tiktok adv report api error %d: %s", resp.Code, resp.Message)
	}

	items := make([]*platform.AdvertiserReportItem, 0, len(resp.Data.List))
	for _, row := range resp.Data.List {
		items = append(items, parseAdvMetrics(row.Dimensions.AdvertiserID, row.Metrics))
	}
	return items, nil
}

func parseAdvMetrics(advertiserID string, m advMetrics) *platform.AdvertiserReportItem {
	spend, _ := strconv.ParseFloat(m.Spend, 64)
	clicks, _ := strconv.ParseInt(m.Clicks, 10, 64)
	impressions, _ := strconv.ParseInt(m.Impressions, 10, 64)
	conversion, _ := strconv.ParseInt(m.Conversion, 10, 64)
	cpc, _ := strconv.ParseFloat(m.CostPerConversion, 64)
	cpa, _ := strconv.ParseFloat(m.SkanClickTimeCostPerConversion, 64)
	return &platform.AdvertiserReportItem{
		AdvertiserID:      advertiserID,
		Spend:             spend,
		Clicks:            clicks,
		Impressions:       impressions,
		Conversion:        conversion,
		CostPerConversion: cpc,
		CPA:               cpa,
		Currency:          m.Currency,
	}
}

// ── 广告主日预算 ────────────────────────────────────────────────

// GetAdvertiserDailyBudget 查询广告主账户级日预算。
// 调用 /advertiser/info/ 接口，请求 budget 字段，返回 map[advertiser_id]budget。
func (c *Client) GetAdvertiserDailyBudget(accessToken string, advertiserIDs []string) (map[string]float64, error) {
	if len(advertiserIDs) == 0 {
		return nil, nil
	}
	idsJSON, _ := json.Marshal(advertiserIDs)
	fieldsJSON, _ := json.Marshal([]string{"advertiser_id", "budget"})
	params := url.Values{}
	params.Set("advertiser_ids", string(idsJSON))
	params.Set("fields", string(fieldsJSON))

	var resp struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
		Data    struct {
			List []struct {
				AdvertiserID string  `json:"advertiser_id"`
				Budget       float64 `json:"budget"`
			} `json:"list"`
		} `json:"data"`
	}
	if err := c.get("/open_api/"+apiVersion+"/advertiser/info/", params, accessToken, &resp); err != nil {
		return nil, fmt.Errorf("tiktok get advertiser daily budget: %w", err)
	}
	if resp.Code != 0 {
		return nil, fmt.Errorf("tiktok get advertiser daily budget error %d: %s", resp.Code, resp.Message)
	}
	result := make(map[string]float64, len(resp.Data.List))
	for _, item := range resp.Data.List {
		result[item.AdvertiserID] = item.Budget
	}
	return result, nil
}

// ── 逐广告组报表（per-adgroup）─────────────────────────────────

const adGroupReportCacheTTL = 5 * time.Minute

// adGroupReportCacheKey 生成单广告组报表缓存 key。
// 格式：stats:report:adgroup:tiktok:{advertiser_id}:{adgroup_id}:{start_date}:{end_date}
func adGroupReportCacheKey(advertiserID, adGroupID, startDate, endDate string) string {
	return fmt.Sprintf("stats:report:adgroup:tiktok:%s:%s:%s:%s", advertiserID, adGroupID, startDate, endDate)
}

// GetAdGroupReport 返回 adGroupIDs 中每个广告组在 [startDate, endDate] 内的明细指标。
// 优先读 Redis 缓存（per-adgroup key），未命中时调用 TikTok Integrated Report API。
func (c *Client) GetAdGroupReport(accessToken, advertiserID string, adGroupIDs []string, startDate, endDate string) ([]*platform.AdGroupReportItem, error) {
	if len(adGroupIDs) == 0 {
		return nil, nil
	}

	ctx := context.Background()
	result := make(map[string]*platform.AdGroupReportItem, len(adGroupIDs))
	var uncached []string

	// 1. 从缓存读取已有结果
	for _, id := range adGroupIDs {
		if c.rdb != nil {
			if raw, err := c.rdb.Get(ctx, adGroupReportCacheKey(advertiserID, id, startDate, endDate)).Bytes(); err == nil {
				var item platform.AdGroupReportItem
				if jsonErr := json.Unmarshal(raw, &item); jsonErr == nil {
					result[id] = &item
					continue
				}
			}
		}
		uncached = append(uncached, id)
	}

	// 2. 批量拉取未命中缓存的 ID
	if len(uncached) > 0 {
		items, err := c.fetchAdGroupBatch(ctx, accessToken, advertiserID, uncached, startDate, endDate)
		if err == nil {
			for _, item := range items {
				result[item.AdGroupID] = item
				if c.rdb != nil {
					if raw, err := json.Marshal(item); err == nil {
						_ = c.rdb.Set(ctx, adGroupReportCacheKey(advertiserID, item.AdGroupID, startDate, endDate), raw, adGroupReportCacheTTL).Err()
					}
				}
			}
		}
	}

	// 3. 按原始顺序输出，缺失的补零值
	out := make([]*platform.AdGroupReportItem, 0, len(adGroupIDs))
	for _, id := range adGroupIDs {
		if item, ok := result[id]; ok {
			out = append(out, item)
		} else {
			out = append(out, &platform.AdGroupReportItem{AdGroupID: id})
		}
	}
	return out, nil
}

// fetchAdGroupBatch 调用 TikTok Integrated Report API 拉取广告组明细数据。
func (c *Client) fetchAdGroupBatch(ctx context.Context, accessToken, advertiserID string, adGroupIDs []string, startDate, endDate string) ([]*platform.AdGroupReportItem, error) {
	idsJSON, _ := json.Marshal(adGroupIDs)
	body := map[string]any{
		"advertiser_id": advertiserID,
		"data_level":    "AUCTION_ADGROUP",
		"report_type":   "BASIC",
		"dimensions":    []string{"adgroup_id"},
		"metrics":       []string{"spend", "clicks", "impressions", "conversion", "cost_per_conversion"},
		"filtering": []map[string]any{
			{"field_name": "adgroup_ids", "filter_type": "IN", "filter_value": string(idsJSON)},
		},
		"start_date": startDate,
		"end_date":   endDate,
		"page":       1,
		"page_size":  1000,
	}

	var resp struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
		Data    struct {
			List []struct {
				Dimensions struct {
					AdGroupID string `json:"adgroup_id"`
				} `json:"dimensions"`
				Metrics struct {
					Spend             string `json:"spend"`
					Clicks            string `json:"clicks"`
					Impressions       string `json:"impressions"`
					Conversion        string `json:"conversion"`
					CostPerConversion string `json:"cost_per_conversion"`
				} `json:"metrics"`
			} `json:"list"`
		} `json:"data"`
	}

	b, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.base()+"/open_api/"+apiVersion+"/report/integrated/get/", bytes.NewReader(b))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Access-Token", accessToken)
	if err := c.do(req, &resp); err != nil {
		return nil, fmt.Errorf("tiktok adgroup report api: %w", err)
	}
	if resp.Code != 0 {
		return nil, fmt.Errorf("tiktok adgroup report api error %d: %s", resp.Code, resp.Message)
	}

	items := make([]*platform.AdGroupReportItem, 0, len(resp.Data.List))
	for _, row := range resp.Data.List {
		spend, _ := strconv.ParseFloat(row.Metrics.Spend, 64)
		clicks, _ := strconv.ParseInt(row.Metrics.Clicks, 10, 64)
		impressions, _ := strconv.ParseInt(row.Metrics.Impressions, 10, 64)
		conversion, _ := strconv.ParseInt(row.Metrics.Conversion, 10, 64)
		cpa, _ := strconv.ParseFloat(row.Metrics.CostPerConversion, 64)
		items = append(items, &platform.AdGroupReportItem{
			AdGroupID:   row.Dimensions.AdGroupID,
			Spend:       spend,
			Clicks:      clicks,
			Impressions: impressions,
			Conversion:  conversion,
			CPA:         cpa,
		})
	}
	return items, nil
}

// ── 逐广告报表（per-ad）────────────────────────────────────────

const adReportCacheTTL = 15 * time.Minute

// adReportCacheKey 生成单广告报表缓存 key。
// 格式：stats:report:ad:tiktok:{advertiser_id}:{ad_id}:{start_date}:{end_date}
func adReportCacheKey(advertiserID, adID, startDate, endDate string) string {
	return fmt.Sprintf("stats:report:ad:tiktok:%s:%s:%s:%s", advertiserID, adID, startDate, endDate)
}

// GetAdReport 返回 adIDs 中每个广告在 [startDate, endDate] 内的明细指标。
// 优先读 Redis 缓存（per-ad key），未命中时调用 TikTok Integrated Report API。
func (c *Client) GetAdReport(accessToken, advertiserID string, adIDs []string, startDate, endDate string) ([]*platform.AdReportItem, error) {
	if len(adIDs) == 0 {
		return nil, nil
	}

	ctx := context.Background()
	result := make(map[string]*platform.AdReportItem, len(adIDs))
	var uncached []string

	// 1. 从缓存读取已有结果
	for _, id := range adIDs {
		if c.rdb != nil {
			if raw, err := c.rdb.Get(ctx, adReportCacheKey(advertiserID, id, startDate, endDate)).Bytes(); err == nil {
				var item platform.AdReportItem
				if jsonErr := json.Unmarshal(raw, &item); jsonErr == nil {
					result[id] = &item
					continue
				}
			}
		}
		uncached = append(uncached, id)
	}

	// 2. 批量拉取未命中缓存的 ID
	if len(uncached) > 0 {
		items, err := c.fetchAdBatch(ctx, accessToken, advertiserID, uncached, startDate, endDate)
		if err == nil {
			for _, item := range items {
				result[item.AdID] = item
				if c.rdb != nil {
					if raw, err := json.Marshal(item); err == nil {
						_ = c.rdb.Set(ctx, adReportCacheKey(advertiserID, item.AdID, startDate, endDate), raw, adReportCacheTTL).Err()
					}
				}
			}
		}
	}

	// 3. 按原始顺序输出，缺失的补零值
	out := make([]*platform.AdReportItem, 0, len(adIDs))
	for _, id := range adIDs {
		if item, ok := result[id]; ok {
			out = append(out, item)
		} else {
			out = append(out, &platform.AdReportItem{AdID: id})
		}
	}
	return out, nil
}

// fetchAdBatch 调用 TikTok Integrated Report API 拉取广告明细数据。
func (c *Client) fetchAdBatch(ctx context.Context, accessToken, advertiserID string, adIDs []string, startDate, endDate string) ([]*platform.AdReportItem, error) {
	idsJSON, _ := json.Marshal(adIDs)
	body := map[string]any{
		"advertiser_id": advertiserID,
		"data_level":    "AUCTION_AD",
		"report_type":   "BASIC",
		"dimensions":    []string{"ad_id"},
		"metrics":       []string{"spend", "clicks", "impressions", "conversion", "cost_per_conversion"},
		"filtering": []map[string]any{
			{"field_name": "ad_ids", "filter_type": "IN", "filter_value": string(idsJSON)},
		},
		"start_date": startDate,
		"end_date":   endDate,
		"page":       1,
		"page_size":  1000,
	}

	var resp struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
		Data    struct {
			List []struct {
				Dimensions struct {
					AdID string `json:"ad_id"`
				} `json:"dimensions"`
				Metrics struct {
					Spend             string `json:"spend"`
					Clicks            string `json:"clicks"`
					Impressions       string `json:"impressions"`
					Conversion        string `json:"conversion"`
					CostPerConversion string `json:"cost_per_conversion"`
				} `json:"metrics"`
			} `json:"list"`
		} `json:"data"`
	}

	b, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.base()+"/open_api/"+apiVersion+"/report/integrated/get/", bytes.NewReader(b))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Access-Token", accessToken)
	if err := c.do(req, &resp); err != nil {
		return nil, fmt.Errorf("tiktok ad report api: %w", err)
	}
	if resp.Code != 0 {
		return nil, fmt.Errorf("tiktok ad report api error %d: %s", resp.Code, resp.Message)
	}

	items := make([]*platform.AdReportItem, 0, len(resp.Data.List))
	for _, row := range resp.Data.List {
		spend, _ := strconv.ParseFloat(row.Metrics.Spend, 64)
		clicks, _ := strconv.ParseInt(row.Metrics.Clicks, 10, 64)
		impressions, _ := strconv.ParseInt(row.Metrics.Impressions, 10, 64)
		conversion, _ := strconv.ParseInt(row.Metrics.Conversion, 10, 64)
		cpa, _ := strconv.ParseFloat(row.Metrics.CostPerConversion, 64)
		items = append(items, &platform.AdReportItem{
			AdID:        row.Dimensions.AdID,
			Spend:       spend,
			Clicks:      clicks,
			Impressions: impressions,
			Conversion:  conversion,
			CPA:         cpa,
		})
	}
	return items, nil
}

// sortedKey 返回 ID 排序后以逗号拼接的字符串（供缓存 key 使用）。
func sortedKey(ids []string) string {
	sorted := make([]string, len(ids))
	copy(sorted, ids)
	sort.Strings(sorted)
	return strings.Join(sorted, ",")
}

// ── 逐推广系列报表（per-campaign）──────────────────────────────

const campaignReportCacheTTL = 15 * time.Minute

// campaignReportCacheKey 生成单推广系列报表缓存 key。
// 格式：stats:report:campaign:tiktok:{advertiser_id}:{campaign_id}:{start_date}:{end_date}
func campaignReportCacheKey(advertiserID, campaignID, startDate, endDate string) string {
	return fmt.Sprintf("stats:report:campaign:tiktok:%s:%s:%s:%s", advertiserID, campaignID, startDate, endDate)
}

// GetCampaignReport 返回 campaignIDs 中每个推广系列在 [startDate, endDate] 内的明细指标。
// 优先读 Redis 缓存（per-campaign key），未命中时调用 TikTok Integrated Report API。
func (c *Client) GetCampaignReport(accessToken, advertiserID string, campaignIDs []string, startDate, endDate string) ([]*platform.CampaignReportItem, error) {
	if len(campaignIDs) == 0 {
		return nil, nil
	}

	ctx := context.Background()
	result := make(map[string]*platform.CampaignReportItem, len(campaignIDs))
	var uncached []string

	// 1. 从缓存读取已有结果
	for _, id := range campaignIDs {
		if c.rdb != nil {
			if raw, err := c.rdb.Get(ctx, campaignReportCacheKey(advertiserID, id, startDate, endDate)).Bytes(); err == nil {
				var item platform.CampaignReportItem
				if jsonErr := json.Unmarshal(raw, &item); jsonErr == nil {
					result[id] = &item
					continue
				}
			}
		}
		uncached = append(uncached, id)
	}

	// 2. 批量拉取未命中缓存的 ID
	if len(uncached) > 0 {
		items, err := c.fetchCampaignBatch(ctx, accessToken, advertiserID, uncached, startDate, endDate)
		if err == nil {
			for _, item := range items {
				result[item.CampaignID] = item
				if c.rdb != nil {
					if raw, err := json.Marshal(item); err == nil {
						_ = c.rdb.Set(ctx, campaignReportCacheKey(advertiserID, item.CampaignID, startDate, endDate), raw, campaignReportCacheTTL).Err()
					}
				}
			}
		}
	}

	// 3. 按原始顺序输出，缺失的补零值
	out := make([]*platform.CampaignReportItem, 0, len(campaignIDs))
	for _, id := range campaignIDs {
		if item, ok := result[id]; ok {
			out = append(out, item)
		} else {
			out = append(out, &platform.CampaignReportItem{CampaignID: id})
		}
	}
	return out, nil
}

// fetchCampaignBatch 调用 TikTok Integrated Report API 拉取推广系列明细数据。
// 直接按广告主拉取全量推广系列数据（AUCTION_CAMPAIGN 不支持 filtering.campaign_ids），
// 后续通过 campaign_id 维度做本地匹配过滤。
func (c *Client) fetchCampaignBatch(ctx context.Context, accessToken, advertiserID string, campaignIDs []string, startDate, endDate string) ([]*platform.CampaignReportItem, error) {
	// 构建仅筛选指定 campaign_ids 的 filtering 参数（使用 campaign_id 字段名而非 campaign_ids）
	campaignIDSet := make(map[string]bool, len(campaignIDs))
	for _, id := range campaignIDs {
		campaignIDSet[id] = true
	}

	body := map[string]any{
		"advertiser_id": advertiserID,
		"data_level":    "AUCTION_CAMPAIGN",
		"report_type":   "BASIC",
		"dimensions":    []string{"campaign_id"},
		"metrics":       []string{"spend", "clicks", "impressions", "conversion", "cost_per_conversion"},
		"start_date":    startDate,
		"end_date":      endDate,
		"page":          1,
		"page_size":     1000,
	}

	var resp struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
		Data    struct {
			List []struct {
				Dimensions struct {
					CampaignID string `json:"campaign_id"`
				} `json:"dimensions"`
				Metrics struct {
					Spend             string `json:"spend"`
					Clicks            string `json:"clicks"`
					Impressions       string `json:"impressions"`
					Conversion        string `json:"conversion"`
					CostPerConversion string `json:"cost_per_conversion"`
				} `json:"metrics"`
			} `json:"list"`
		} `json:"data"`
	}

	b, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.base()+"/open_api/"+apiVersion+"/report/integrated/get/", bytes.NewReader(b))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Access-Token", accessToken)
	if err := c.do(req, &resp); err != nil {
		return nil, fmt.Errorf("tiktok campaign report api: %w", err)
	}
	if resp.Code != 0 {
		return nil, fmt.Errorf("tiktok campaign report api error %d: %s", resp.Code, resp.Message)
	}

	items := make([]*platform.CampaignReportItem, 0, len(resp.Data.List))
	for _, row := range resp.Data.List {
		// 只返回请求列表中的推广系列
		if len(campaignIDSet) > 0 && !campaignIDSet[row.Dimensions.CampaignID] {
			continue
		}
		spend, _ := strconv.ParseFloat(row.Metrics.Spend, 64)
		clicks, _ := strconv.ParseInt(row.Metrics.Clicks, 10, 64)
		impressions, _ := strconv.ParseInt(row.Metrics.Impressions, 10, 64)
		conversion, _ := strconv.ParseInt(row.Metrics.Conversion, 10, 64)
		cpa, _ := strconv.ParseFloat(row.Metrics.CostPerConversion, 64)
		items = append(items, &platform.CampaignReportItem{
			CampaignID:  row.Dimensions.CampaignID,
			Spend:       spend,
			Clicks:      clicks,
			Impressions: impressions,
			Conversion:  conversion,
			CPA:         cpa,
		})
	}
	return items, nil
}
