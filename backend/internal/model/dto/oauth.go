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

// OAuthCallbackResponse 回调响应：返回平台全量广告主列表（含已存库标记）+ 额度信息。
// 此阶段不保存广告主，等待 iOS 用户确认选择后调用 Confirm 接口。
type OAuthCallbackResponse struct {
	TokenID     uint64           `json:"token_id"`
	Platform    string           `json:"platform"`
	Advertisers []AdvertiserItem `json:"advertisers"`
	Quota       int              `json:"quota"`
	UsedQuota   int              `json:"used_quota"`
	Remaining   int              `json:"remaining"`
}

// ── 广告主列表项 ──────────────────────────────────────────────

type AdvertiserItem struct {
	ID             uint64    `json:"id,omitempty"` // 未入库时为 0，omitempty 避免干扰客户端
	AdvertiserID   string    `json:"advertiser_id"`
	AdvertiserName string    `json:"advertiser_name"`
	Currency       string    `json:"currency"`
	Timezone       string    `json:"timezone"`
	SyncedAt       time.Time `json:"synced_at"`
	IsExisting     bool      `json:"is_existing"` // true = 已存库，UI 需锁定
}

// ── 确认选择广告主 ────────────────────────────────────────────

type OAuthConfirmRequest struct {
	TokenID       uint64   `json:"token_id"       binding:"required"`
	AdvertiserIDs []string `json:"advertiser_ids"`
}

type OAuthConfirmResponse struct {
	TokenID     uint64           `json:"token_id"`
	Platform    string           `json:"platform"`
	Advertisers []AdvertiserItem `json:"advertisers"`
}

// ── 解绑授权 ──────────────────────────────────────────────────

type RevokeResponse struct {
	Message string `json:"message"`
}
