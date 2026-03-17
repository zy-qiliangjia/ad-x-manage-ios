package statshandler

import (
	"github.com/gin-gonic/gin"

	"ad-x-manage/backend/internal/middleware"
	"ad-x-manage/backend/internal/pkg/response"
	statssvc "ad-x-manage/backend/internal/service/stats"
)

// Handler 统计数据 HTTP 处理器。
type Handler struct {
	svc statssvc.Service
}

// New 创建统计处理器。
func New(svc statssvc.Service) *Handler {
	return &Handler{svc: svc}
}

// Overview 查询当前用户的广告数据概览。
// GET /api/v1/stats?platform=tiktok
func (h *Handler) Overview(c *gin.Context) {
	userID := middleware.GetUserID(c)
	platform := c.Query("platform")

	result, err := h.svc.Overview(c.Request.Context(), userID, platform)
	if err != nil {
		response.Fail(c, 500, response.CodeServerError, "获取统计数据失败")
		return
	}
	response.OK(c, result)
}
