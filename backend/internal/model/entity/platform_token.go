package entity

import "time"

// PlatformToken 存储用户在各广告平台的 OAuth 授权凭证（Token 加密存储）。
type PlatformToken struct {
	ID              uint64     `gorm:"primaryKey;autoIncrement"                          json:"id"`
	UserID          uint64     `gorm:"not null;index:idx_user_platform"                  json:"user_id"`
	Platform        string     `gorm:"size:20;not null;index:idx_user_platform"          json:"platform"`
	OpenUserID      string     `gorm:"size:100;not null;uniqueIndex:uk_user_platform_openid" json:"open_user_id"`
	AccessToken  string     `gorm:"column:access_token;type:text;not null"   json:"-"`
	RefreshToken string     `gorm:"column:refresh_token;type:text;default:null" json:"-"`
	ExpiresAt       *time.Time `gorm:"default:null"                                      json:"expires_at"`
	Scope           string     `gorm:"size:500;default:null"                             json:"scope"`
	Status          uint8      `gorm:"not null;default:1"                                json:"status"`
	CreatedAt       time.Time  `                                                         json:"created_at"`
	UpdatedAt       time.Time  `                                                         json:"updated_at"`
}

// Platform 平台常量
const (
	PlatformTikTok = "tiktok"
	PlatformKwai   = "kwai"
)

// TokenStatus 状态常量
const (
	TokenStatusActive   = uint8(1)
	TokenStatusInactive = uint8(0)
)
