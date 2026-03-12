package entity

import "time"

// Campaign 推广系列。
type Campaign struct {
	ID           uint64    `gorm:"primaryKey;autoIncrement"                                  json:"id"`
	AdvertiserID uint64    `gorm:"not null;index:idx_advertiser_id"                           json:"advertiser_id"`
	Platform     string    `gorm:"size:20;not null;uniqueIndex:uk_platform_campaign"          json:"platform"`
	CampaignID   string    `gorm:"size:100;not null;uniqueIndex:uk_platform_campaign"         json:"campaign_id"`
	CampaignName string    `gorm:"size:255;not null;default:''"                              json:"campaign_name"`
	Status       string    `gorm:"size:50;not null;default:'';index:idx_status"              json:"status"`
	BudgetMode   string    `gorm:"size:50;default:null"                                      json:"budget_mode"`
	Budget       float64   `gorm:"type:decimal(18,2);not null;default:0"                     json:"budget"`
	Spend        float64   `gorm:"type:decimal(18,2);not null;default:0"                     json:"spend"`
	Objective    string    `gorm:"size:100;default:null"                                     json:"objective"`
	CreatedAt    time.Time `                                                                 json:"created_at"`
	UpdatedAt    time.Time `                                                                 json:"updated_at"`
}

// 各平台投放状态值
const (
	// TikTok
	TikTokStatusEnable   = "ENABLE"
	TikTokStatusDisable  = "DISABLE"
	TikTokStatusNotStart = "NOT_START"

	// Kwai
	KwaiStatusOnline   = "ONLINE"
	KwaiStatusOffline  = "OFFLINE"
	KwaiStatusNotStart = "NOT_START"
)
