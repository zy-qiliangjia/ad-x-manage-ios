package entity

import "time"

// Ad 广告。
type Ad struct {
	ID           uint64    `gorm:"primaryKey;autoIncrement"                          json:"id"`
	AdvertiserID uint64    `gorm:"not null;index:idx_advertiser_id;uniqueIndex:uk_advertiser_ad"  json:"advertiser_id"`
	AdgroupID    uint64    `gorm:"not null;index:idx_adgroup_id"                                 json:"adgroup_id"`
	Platform     string    `gorm:"size:20;not null"                                              json:"platform"`
	AdID         string    `gorm:"size:100;not null;uniqueIndex:uk_advertiser_ad"               json:"ad_id"`
	AdName       string    `gorm:"size:255;not null;default:'';index:idx_ad_name"     json:"ad_name"`
	Status       string    `gorm:"size:50;not null;default:'';index:idx_status"       json:"status"`
	CreativeType string    `gorm:"size:50;default:null"                               json:"creative_type"`
	CreatedAt    time.Time `                                                         json:"created_at"`
	UpdatedAt    time.Time `                                                         json:"updated_at"`
}
