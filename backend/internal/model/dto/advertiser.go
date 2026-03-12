package dto

import "time"

// ── 广告主列表 ─────────────────────────────────────────────────

type AdvertiserListRequest struct {
	Platform string `form:"platform"` // tiktok | kwai | 空=全部
	Keyword  string `form:"keyword"`
	Page     int    `form:"page,default=1"`
	PageSize int    `form:"page_size,default=20"`
}

type AdvertiserListItem struct {
	ID             uint64     `json:"id"`
	Platform       string     `json:"platform"`
	AdvertiserID   string     `json:"advertiser_id"`
	AdvertiserName string     `json:"advertiser_name"`
	Currency       string     `json:"currency"`
	Timezone       string     `json:"timezone"`
	Status         uint8      `json:"status"`
	SyncedAt       *time.Time `json:"synced_at"`
}

// ── 余额 ───────────────────────────────────────────────────────

type BalanceResponse struct {
	AdvertiserID string  `json:"advertiser_id"`
	Balance      float64 `json:"balance"`
	Currency     string  `json:"currency"`
}

// ── 同步结果 ───────────────────────────────────────────────────

type SyncResponse struct {
	AdvertiserID  uint64   `json:"advertiser_id"`
	CampaignCount int      `json:"campaign_count"`
	AdGroupCount  int      `json:"adgroup_count"`
	AdCount       int      `json:"ad_count"`
	Duration      string   `json:"duration"`
	Errors        []string `json:"errors,omitempty"`
}
