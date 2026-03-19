package invitehandler

import (
	"github.com/gin-gonic/gin"

	"ad-x-manage/backend/internal/middleware"
	"ad-x-manage/backend/internal/pkg/response"
	invitesvc "ad-x-manage/backend/internal/service/invite"
)

type Handler struct {
	svc invitesvc.Service
}

func New(svc invitesvc.Service) *Handler {
	return &Handler{svc: svc}
}

// GetInviteInfo GET /api/v1/users/invite
func (h *Handler) GetInviteInfo(c *gin.Context) {
	userID := middleware.GetUserID(c)
	info, err := h.svc.GetInviteInfo(c.Request.Context(), userID)
	if err != nil {
		response.ServerError(c, "获取邀请信息失败")
		return
	}
	response.OK(c, info)
}

// GetQuota GET /api/v1/users/quota
func (h *Handler) GetQuota(c *gin.Context) {
	userID := middleware.GetUserID(c)
	quota, err := h.svc.GetQuota(c.Request.Context(), userID)
	if err != nil {
		response.ServerError(c, "获取额度信息失败")
		return
	}
	response.OK(c, quota)
}
