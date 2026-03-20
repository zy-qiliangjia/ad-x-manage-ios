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

// AdGroupReportItem 单广告组报表明细。
type AdGroupReportItem struct {
	AdGroupID   string  `json:"adgroup_id"`
	Spend       float64 `json:"spend"`
	Clicks      int64   `json:"clicks"`
	Impressions int64   `json:"impressions"`
	Conversion  int64   `json:"conversion"`
	CPA         float64 `json:"cpa"`
}

// AdGroupReportResponse 广告组报表批量查询响应。
type AdGroupReportResponse struct {
	List []*AdGroupReportItem `json:"list"`
}

// CampaignReportItem 单推广系列报表明细。
type CampaignReportItem struct {
	CampaignID  string  `json:"campaign_id"`
	Spend       float64 `json:"spend"`
	Clicks      int64   `json:"clicks"`
	Impressions int64   `json:"impressions"`
	Conversion  int64   `json:"conversion"`
	CPA         float64 `json:"cpa"`
}

// CampaignReportResponse 推广系列报表批量查询响应。
type CampaignReportResponse struct {
	List         []*CampaignReportItem `json:"list"`
	TotalMetrics *CampaignReportItem   `json:"total_metrics,omitempty"`
}

// AdReportItem 单广告报表明细。
type AdReportItem struct {
	AdID        string  `json:"ad_id"`
	Spend       float64 `json:"spend"`
	Clicks      int64   `json:"clicks"`
	Impressions int64   `json:"impressions"`
	Conversion  int64   `json:"conversion"`
	CPA         float64 `json:"cpa"`
}

// AdReportResponse 广告报表批量查询响应。
type AdReportResponse struct {
	List []*AdReportItem `json:"list"`
}

// TrendDataPoint 单日趋势数据点。
type TrendDataPoint struct {
	Date        string  `json:"date"`
	Spend       float64 `json:"spend"`
	Clicks      int64   `json:"clicks"`
	Impressions int64   `json:"impressions"`
	Conversion  int64   `json:"conversion"`
}

// TrendReportResponse 近7天趋势报表响应。
type TrendReportResponse struct {
	Items []*TrendDataPoint `json:"items"`
}
