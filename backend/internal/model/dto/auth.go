package dto

import "time"

// ── 注册 ──────────────────────────────────────────────────────

type RegisterRequest struct {
	Email      string `json:"email"       binding:"required,email"`
	Password   string `json:"password"    binding:"required,min=8,max=72"`
	Name       string `json:"name"        binding:"required,min=1,max=100"`
	InviteCode string `json:"invite_code"` // 可选：填写邀请码，双方各得 +5 额度
}

// ── 登录 ──────────────────────────────────────────────────────

type LoginRequest struct {
	Email    string `json:"email"    binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

type LoginResponse struct {
	Token     string    `json:"token"`
	ExpiresAt time.Time `json:"expires_at"`
	User      UserInfo  `json:"user"`
}

// ── 刷新 Token ────────────────────────────────────────────────

type RefreshResponse struct {
	Token     string    `json:"token"`
	ExpiresAt time.Time `json:"expires_at"`
}

// ── 通用 ──────────────────────────────────────────────────────

type UserInfo struct {
	ID    uint64 `json:"id"`
	Email string `json:"email"`
	Name  string `json:"name"`
}
