package authhandler

import (
	"errors"
	"time"

	"github.com/gin-gonic/gin"

	"ad-x-manage/backend/internal/middleware"
	"ad-x-manage/backend/internal/model/dto"
	"ad-x-manage/backend/internal/pkg/jwtutil"
	"ad-x-manage/backend/internal/pkg/response"
	authsvc "ad-x-manage/backend/internal/service/auth"
)

type Handler struct {
	svc authsvc.Service
}

func New(svc authsvc.Service) *Handler {
	return &Handler{svc: svc}
}

// Register 注册
// POST /api/v1/auth/register
func (h *Handler) Register(c *gin.Context) {
	var req dto.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	if err := h.svc.Register(c.Request.Context(), &req); err != nil {
		switch {
		case errors.Is(err, authsvc.ErrEmailAlreadyExists):
			response.BadRequest(c, "邮箱已被注册")
		default:
			response.ServerError(c, "注册失败，请稍后重试")
		}
		return
	}

	response.OK(c, nil)
}

// Login 登录
// POST /api/v1/auth/login
func (h *Handler) Login(c *gin.Context) {
	var req dto.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	res, err := h.svc.Login(c.Request.Context(), &req)
	if err != nil {
		switch {
		case errors.Is(err, authsvc.ErrInvalidCredentials):
			response.Unauthorized(c, "邮箱或密码错误")
		case errors.Is(err, authsvc.ErrUserDisabled):
			response.Forbidden(c, "账号已被禁用，请联系管理员")
		default:
			response.ServerError(c, "登录失败，请稍后重试")
		}
		return
	}

	response.OK(c, res)
}

// Logout 登出（将当前 Token 加入黑名单）
// POST /api/v1/auth/logout  （需要登录）
func (h *Handler) Logout(c *gin.Context) {
	jtiVal, _ := c.Get(middleware.ContextKeyJTI)
	jti, _ := jtiVal.(string)

	// TTL 取 Token 完整有效期，保证黑名单覆盖剩余有效期
	if err := h.svc.Logout(c.Request.Context(), jti, jwtutil.AccessTokenTTL); err != nil {
		response.ServerError(c, "登出失败，请稍后重试")
		return
	}

	response.OK(c, nil)
}

// Refresh 刷新 Token
// POST /api/v1/auth/refresh  （需要登录）
func (h *Handler) Refresh(c *gin.Context) {
	userID := middleware.GetUserID(c)
	emailVal, _ := c.Get(middleware.ContextKeyEmail)
	email, _ := emailVal.(string)

	res, err := h.svc.Refresh(c.Request.Context(), userID, email)
	if err != nil {
		response.ServerError(c, "Token 刷新失败，请重新登录")
		return
	}

	// 将旧 Token 加入黑名单，强制客户端使用新 Token
	jtiVal, _ := c.Get(middleware.ContextKeyJTI)
	if jti, ok := jtiVal.(string); ok && jti != "" {
		_ = h.svc.Logout(c.Request.Context(), jti, time.Until(res.ExpiresAt)+time.Minute)
	}

	response.OK(c, res)
}
