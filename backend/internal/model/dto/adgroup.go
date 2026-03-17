package dto

// ── 广告组列表 ─────────────────────────────────────────────────

type AdGroupListRequest struct {
	CampaignID uint64 `form:"campaign_id"` // 0 = 不过滤，返回全部
	Page       int    `form:"page,default=1"`
	PageSize   int    `form:"page_size,default=20"`
}

type AdGroupItem struct {
	ID             uint64  `json:"id"`
	AdgroupID      string  `json:"adgroup_id"`
	AdgroupName    string  `json:"adgroup_name"`
	CampaignID     uint64  `json:"campaign_id"`
	Status         string  `json:"status"`
	BudgetMode     string  `json:"budget_mode"`
	Budget         float64 `json:"budget"`
	Spend          float64 `json:"spend"`
	Clicks         int64   `json:"clicks"`
	Impressions    int64   `json:"impressions"`
	Conversions    int64   `json:"conversions"`
	BidType        string  `json:"bid_type"`
	BidPrice       float64 `json:"bid_price"`
	AdvertiserID   uint64  `json:"advertiser_id"`
	AdvertiserName string  `json:"advertiser_name"`
	Platform       string  `json:"platform"`
}

// ── 全量广告组列表请求 ───────────────────────────────────────────
type AllAdGroupListRequest struct {
	Platform string `form:"platform"`
	Keyword  string `form:"keyword"`
	Page     int    `form:"page,default=1"`
	PageSize int    `form:"page_size,default=20"`
}
