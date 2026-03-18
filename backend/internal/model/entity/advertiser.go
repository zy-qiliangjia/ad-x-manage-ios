package entity

import "time"

// Advertiser 广告主账号，通过 OAuth 授权后从平台拉取。
type Advertiser struct {
	ID             uint64     `gorm:"primaryKey;autoIncrement"                                json:"id"`
	TokenID        uint64     `gorm:"not null;index:idx_token_id"                             json:"token_id"`
	UserID         uint64     `gorm:"not null;index:idx_user_platform"                        json:"user_id"`
	Platform       string     `gorm:"size:20;not null;index:idx_user_platform;uniqueIndex:uk_platform_advertiser" json:"platform"`
	AdvertiserID   string     `gorm:"size:100;not null;uniqueIndex:uk_platform_advertiser"    json:"advertiser_id"`
	AdvertiserName string     `gorm:"size:255;not null;default:''"                            json:"advertiser_name"`
	Currency       string     `gorm:"size:10;default:null"                                    json:"currency"`
	Timezone       string     `gorm:"size:50;default:null"                                    json:"timezone"`
	DailyBudget    *float64   `gorm:"type:decimal(18,2);default:null"                         json:"daily_budget"`
	Status         uint8      `gorm:"not null;default:1"                                      json:"status"`
	SyncedAt       *time.Time `gorm:"default:null"                                            json:"synced_at"`
	CreatedAt      time.Time  `                                                               json:"created_at"`
	UpdatedAt      time.Time  `                                                               json:"updated_at"`
}
