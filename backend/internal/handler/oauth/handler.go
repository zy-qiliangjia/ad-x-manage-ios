package oauthhandler

import (
	"errors"
	"fmt"

	"github.com/gin-gonic/gin"

	"ad-x-manage/backend/internal/middleware"
	"ad-x-manage/backend/internal/model/dto"
	"ad-x-manage/backend/internal/pkg/response"
	oauthsvc "ad-x-manage/backend/internal/service/oauth"
)

type Handler struct {
	svc oauthsvc.Service
}

func New(svc oauthsvc.Service) *Handler {
	return &Handler{svc: svc}
}

// GetURL 获取平台 OAuth 授权 URL（iOS 拿到 URL 后用 ASWebAuthenticationSession 打开）
// GET /api/v1/oauth/:platform/url
func (h *Handler) GetURL(c *gin.Context) {
	platformName := c.Param("platform")
	userID := middleware.GetUserID(c)

	res, err := h.svc.GetOAuthURL(c.Request.Context(), userID, platformName)
	if err != nil {
		switch {
		case errors.Is(err, oauthsvc.ErrPlatformUnknown):
			response.BadRequest(c, "不支持的平台: "+platformName)
		default:
			response.ServerError(c, "获取授权链接失败")
		}
		return
	}

	response.OK(c, res)
}

// Callback iOS 完成授权后携带 code + state 回传后端
// POST /api/v1/oauth/:platform/callback
func (h *Handler) Callback(c *gin.Context) {
	platformName := c.Param("platform")
	userID := middleware.GetUserID(c)

	var req dto.OAuthCallbackRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	res, err := h.svc.Callback(c.Request.Context(), userID, platformName, req.Code, req.State)
	if err != nil {
		switch {
		case errors.Is(err, oauthsvc.ErrInvalidState):
			response.BadRequest(c, "授权状态无效或已过期，请重新授权")
		case errors.Is(err, oauthsvc.ErrPlatformUnknown):
			response.BadRequest(c, "不支持的平台: "+platformName)
		default:
			response.PlatformError(c, "平台授权处理失败: "+err.Error())
		}
		return
	}

	response.OK(c, res)
}

// Redirect TikTok/Kwai 授权完成后回调此端点（需注册为平台 redirect_uri）
// GET /oauth/:platform/redirect?code=xxx&state=xxx
// 后端将参数透传到 iOS 自定义 scheme，由 ASWebAuthenticationSession 拦截
func (h *Handler) Redirect(c *gin.Context) {
	code := c.Query("code")
	state := c.Query("state")
	if code == "" || state == "" {
		c.String(400, "missing code or state")
		return
	}
	target := fmt.Sprintf("adxmanage://oauth/callback?code=%s&state=%s", code, state)
	c.Redirect(302, target)
}

// Revoke 解绑授权
// DELETE /api/v1/oauth/:platform/:token_id
func (h *Handler) Revoke(c *gin.Context) {
	userID := middleware.GetUserID(c)

	var tokenID uint64
	if _, err := fmt.Sscanf(c.Param("token_id"), "%d", &tokenID); err != nil || tokenID == 0 {
		response.BadRequest(c, "无效的 token_id")
		return
	}

	if err := h.svc.Revoke(c.Request.Context(), userID, tokenID); err != nil {
		switch {
		case errors.Is(err, oauthsvc.ErrTokenNotFound):
			response.BadRequest(c, "授权记录不存在")
		case errors.Is(err, oauthsvc.ErrForbidden):
			response.Forbidden(c, "无权限操作该授权")
		default:
			response.ServerError(c, "解绑失败")
		}
		return
	}

	response.OK(c, dto.RevokeResponse{Message: "解绑成功"})
}
