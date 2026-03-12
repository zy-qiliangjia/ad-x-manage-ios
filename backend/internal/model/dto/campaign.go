package dto

// ── 推广系列列表 ───────────────────────────────────────────────

type CampaignListRequest struct {
	Page     int `form:"page,default=1"`
	PageSize int `form:"page_size,default=20"`
}

type CampaignItem struct {
	ID           uint64  `json:"id"`
	CampaignID   string  `json:"campaign_id"`
	CampaignName string  `json:"campaign_name"`
	Status       string  `json:"status"`
	BudgetMode   string  `json:"budget_mode"`
	Budget       float64 `json:"budget"`
	Spend        float64 `json:"spend"`
	Objective    string  `json:"objective"`
}

// ── 修改预算 ───────────────────────────────────────────────────

type UpdateBudgetRequest struct {
	Budget float64 `json:"budget" binding:"required,gt=0"`
}

// ── 修改状态（iOS 发送平台无关的 action）────────────────────────
// action: "enable" | "pause"

type UpdateStatusRequest struct {
	Action string `json:"action" binding:"required,oneof=enable pause"`
}
