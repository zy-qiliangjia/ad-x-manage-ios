package platform

import (
	"context"
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

	// ── 报表 ───────────────────────────────────────────────
	// GetReport 查询指定广告主在日期范围内的核心指标汇总
	GetReport(ctx context.Context, accessToken, advertiserID, startDate, endDate string) (*ReportResult, error)
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

type ReportResult struct {
	Spend       float64
	Clicks      float64
	Impressions float64
	Conversions float64
}
