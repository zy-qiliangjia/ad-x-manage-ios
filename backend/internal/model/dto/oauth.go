package dto

import "time"

// ── 获取授权 URL ──────────────────────────────────────────────

type OAuthURLResponse struct {
	URL   string `json:"url"`
	State string `json:"state"`
}

// ── 授权回调（iOS 携带 code 发回后端）────────────────────────

type OAuthCallbackRequest struct {
	Code  string `json:"code"  binding:"required"`
	State string `json:"state" binding:"required"`
}

type OAuthCallbackResponse struct {
	TokenID     uint64           `json:"token_id"`
	Platform    string           `json:"platform"`
	Advertisers []AdvertiserItem `json:"advertisers"`
}

// ── 广告主列表项 ──────────────────────────────────────────────

type AdvertiserItem struct {
	ID             uint64    `json:"id"`
	AdvertiserID   string    `json:"advertiser_id"`
	AdvertiserName string    `json:"advertiser_name"`
	Currency       string    `json:"currency"`
	Timezone       string    `json:"timezone"`
	SyncedAt       time.Time `json:"synced_at"`
}

// ── 解绑授权 ──────────────────────────────────────────────────

type RevokeResponse struct {
	Message string `json:"message"`
}
