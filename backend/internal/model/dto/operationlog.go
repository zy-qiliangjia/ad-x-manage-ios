package dto

import "time"

// ── 操作日志列表 ───────────────────────────────────────────────

type OperationLogListRequest struct {
	AdvertiserID uint64 `form:"advertiser_id"` // 0 = 不过滤
	Platform     string `form:"platform"`      // "" = 不过滤
	Action       string `form:"action"`        // "" = 不过滤
	TargetType   string `form:"target_type"`   // "" = 不过滤
	Result       *uint8 `form:"result"`        // nil = 不过滤；0=失败 1=成功
	StartDate    string `form:"start_date"`    // YYYY-MM-DD，含
	EndDate      string `form:"end_date"`      // YYYY-MM-DD，含
	Page         int    `form:"page,default=1"`
	PageSize     int    `form:"page_size,default=20"`
}

type OperationLogItem struct {
	ID           uint64         `json:"id"`
	AdvertiserID uint64         `json:"advertiser_id"`
	Platform     string         `json:"platform"`
	Action       string         `json:"action"`
	TargetType   string         `json:"target_type"`
	TargetID     string         `json:"target_id"`
	TargetName   string         `json:"target_name"`
	BeforeVal    map[string]any `json:"before_val"`
	AfterVal     map[string]any `json:"after_val"`
	Result       uint8          `json:"result"`
	FailReason   string         `json:"fail_reason,omitempty"`
	CreatedAt    time.Time      `json:"created_at"`
}
