package entity

import "time"

// AdGroup 广告组。
type AdGroup struct {
	ID           uint64    `gorm:"primaryKey;autoIncrement"                                json:"id"`
	AdvertiserID uint64    `gorm:"not null;index:idx_advertiser_id"                         json:"advertiser_id"`
	CampaignID   uint64    `gorm:"not null;index:idx_campaign_id"                           json:"campaign_id"`
	Platform     string    `gorm:"size:20;not null;uniqueIndex:uk_platform_adgroup"         json:"platform"`
	AdgroupID    string    `gorm:"size:100;not null;uniqueIndex:uk_platform_adgroup"        json:"adgroup_id"`
	AdgroupName  string    `gorm:"size:255;not null;default:''"                            json:"adgroup_name"`
	Status       string    `gorm:"size:50;not null;default:'';index:idx_status"            json:"status"`
	BudgetMode   string    `gorm:"size:50;default:null"                                    json:"budget_mode"`
	Budget       float64   `gorm:"type:decimal(18,2);not null;default:0"                   json:"budget"`
	Spend        float64   `gorm:"type:decimal(18,2);not null;default:0"                   json:"spend"`
	Clicks       int64     `gorm:"not null;default:0"                                      json:"clicks"`
	Impressions  int64     `gorm:"not null;default:0"                                      json:"impressions"`
	Conversions  int64     `gorm:"not null;default:0"                                      json:"conversions"`
	BidType      string    `gorm:"size:50;default:null"                                    json:"bid_type"`
	BidPrice     float64   `gorm:"type:decimal(18,4);default:null"                         json:"bid_price"`
	CreatedAt    time.Time `                                                               json:"created_at"`
	UpdatedAt    time.Time `                                                               json:"updated_at"`
}
