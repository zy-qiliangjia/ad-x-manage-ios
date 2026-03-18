package dto

// StatsReportRequest 广告主报表批量查询请求参数。
type StatsReportRequest struct {
	Platform      string   `form:"platform"       binding:"required"`
	AdvertiserIDs []string `form:"advertiser_ids" binding:"required,min=1"`
	StartDate     string   `form:"start_date"     binding:"required"`
	EndDate       string   `form:"end_date"       binding:"required"`
}

// AdvertiserReportItem 单广告主报表明细。
type AdvertiserReportItem struct {
	AdvertiserID      string  `json:"advertiser_id"`
	Spend             float64 `json:"spend"`
	Clicks            int64   `json:"clicks"`
	Impressions       int64   `json:"impressions"`
	Conversion        int64   `json:"conversion"`
	CostPerConversion float64 `json:"cost_per_conversion"`
	CPA               float64 `json:"cpa"`
	Currency          string  `json:"currency"`
	DailyBudget       float64 `json:"daily_budget"`
}

// StatsReportResponse 广告主报表批量查询响应。
type StatsReportResponse struct {
	List         []*AdvertiserReportItem `json:"list"`
	TotalMetrics *AdvertiserReportItem   `json:"total_metrics"`
}
