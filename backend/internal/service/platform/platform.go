package platform

import (
	"time"
)

// Client 广告平台统一接口，TikTok 和 Kwai 各自实现。
type Client interface {
	// Name 返回平台标识符（"tiktok" | "kwai"）
	Name() string

	// ── OAuth ──────────────────────────────────────────────
	// GetOAuthURL 生成带 state 的授权跳转 URL
	GetOAuthURL(state string) string
	// ExchangeToken 用 code 换取 access_token
	ExchangeToken(code string) (*TokenResult, error)
	// RefreshToken 用 refresh_token 换取新 access_token
	RefreshToken(refreshToken string) (*TokenResult, error)

	// ── 广告主 ─────────────────────────────────────────────
	// GetAdvertisers 拉取该 token 下所有广告主账号
	GetAdvertisers(accessToken string) ([]*AdvertiserInfo, error)
	// GetAdvertiserInfo 批量查询广告主详情（currency、timezone 等字段）
	GetAdvertiserInfo(accessToken string, advertiserIDs []string) ([]*AdvertiserInfo, error)
	// GetBalance 实时查询广告主账户余额
	GetBalance(accessToken, advertiserID string) (*BalanceInfo, error)
	// UpdateAdvertiserBudget 修改广告主账户日预算
	UpdateAdvertiserBudget(accessToken, advertiserID string, budget float64) error

	// ── 推广系列 ───────────────────────────────────────────
	GetCampaigns(accessToken, advertiserID string, page, pageSize int) ([]*CampaignInfo, int64, error)
	UpdateCampaignBudget(accessToken, advertiserID, campaignID string, budget float64) error
	UpdateCampaignStatus(accessToken, advertiserID, campaignID, status string) error

	// ── 广告组 ─────────────────────────────────────────────
	GetAdGroups(accessToken, advertiserID string, campaignID string, page, pageSize int) ([]*AdGroupInfo, int64, error)
	UpdateAdGroupBudget(accessToken, advertiserID, adGroupID string, budget float64) error
	UpdateAdGroupStatus(accessToken, advertiserID, adGroupID, status string) error

	// ── 广告 ───────────────────────────────────────────────
	GetAds(accessToken, advertiserID, adGroupID string, page, pageSize int) ([]*AdInfo, int64, error)

	// ── 报表统计 ───────────────────────────────────────────
	// GetReportStats 拉取指定广告主列表在给定日期范围内的汇总指标。
	// advertiserIDs 为空时直接返回零值。分批调用由实现层负责。
	GetReportStats(accessToken string, advertiserIDs []string, startDate, endDate string) (*ReportStats, error)

	// GetAdvertiserReport 拉取逐广告主报表明细（per-advertiser）。
	// 内部按 ≤5 个/批切分，优先读 Redis 缓存，未命中时调用平台 API 并缓存。
	// 请求列表中无数据的广告主以零值占位返回。
	GetAdvertiserReport(accessToken string, advertiserIDs []string, startDate, endDate string) ([]*AdvertiserReportItem, error)

	// GetAdvertiserDailyBudget 查询广告主账户级日预算。
	// 返回 map[platform_advertiser_id]daily_budget（float64）。
	GetAdvertiserDailyBudget(accessToken string, advertiserIDs []string) (map[string]float64, error)

	// GetAdGroupReport 拉取逐广告组报表明细（per-adgroup）。
	// adGroupIDs 为平台广告组 ID 列表，按 ≤5 个/批切分请求，返回各广告组明细。
	GetAdGroupReport(accessToken, advertiserID string, adGroupIDs []string, startDate, endDate string) ([]*AdGroupReportItem, error)

	// GetCampaignReport 拉取逐推广系列报表明细（per-campaign）。
	// campaignIDs 为平台推广系列 ID 列表，返回各推广系列指标明细。
	GetCampaignReport(accessToken, advertiserID string, campaignIDs []string, startDate, endDate string) ([]*CampaignReportItem, error)
}

// ── 共享数据结构 ───────────────────────────────────────────────

type TokenResult struct {
	OpenUserID          string
	AccessToken         string
	RefreshToken        string
	ExpiresAt           time.Time
	RefreshTokenExpires time.Time
	Scope               string
}

type AdvertiserInfo struct {
	AdvertiserID   string
	AdvertiserName string
	Currency       string
	Timezone       string
}

type BalanceInfo struct {
	AdvertiserID string
	Balance      float64
	Currency     string
}

type CampaignInfo struct {
	CampaignID   string
	CampaignName string
	Status       string
	BudgetMode   string
	Budget       float64
	Spend        float64
	Objective    string
}

type AdGroupInfo struct {
	AdGroupID   string
	AdGroupName string
	CampaignID  string
	Status      string
	BudgetMode  string
	Budget      float64
	Spend       float64
	BidType     string
	BidPrice    float64
}

type AdInfo struct {
	AdID         string
	AdName       string
	AdGroupID    string
	Status       string
	CreativeType string
}

// ReportStats 平台报表汇总指标（所有广告主合计）。
type ReportStats struct {
	Spend       float64
	Clicks      int64
	Impressions int64
	Conversion  int64
}

// ReportResult 单广告主报表汇总，字段均为 float64 便于逐行累加。
type ReportResult struct {
	Spend       float64
	Impressions float64
	Clicks      float64
	Conversions float64
}

// AdGroupReportItem 单广告组报表明细指标。
type AdGroupReportItem struct {
	AdGroupID   string
	Spend       float64
	Clicks      int64
	Impressions int64
	Conversion  int64
	CPA         float64
}

// CampaignReportItem 单推广系列报表明细指标。
type CampaignReportItem struct {
	CampaignID  string
	Spend       float64
	Clicks      int64
	Impressions int64
	Conversion  int64
	CPA         float64
}

// AdvertiserReportItem 单广告主报表明细指标。
type AdvertiserReportItem struct {
	AdvertiserID      string
	Spend             float64
	Clicks            int64
	Impressions       int64
	Conversion        int64
	CostPerConversion float64
	CPA               float64 // skan_click_time_cost_per_conversion
	Currency          string
}

