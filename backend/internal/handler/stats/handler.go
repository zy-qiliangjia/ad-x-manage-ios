package statshandler

import (
	"fmt"
	"strconv"
	"time"

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
// GET /api/v1/stats?platform=tiktok&start_date=2025-03-10&end_date=2025-03-16
func (h *Handler) Overview(c *gin.Context) {
	userID := middleware.GetUserID(c)
	platform := c.Query("platform")
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")

	// 默认近7天
	if startDate == "" || endDate == "" {
		now := time.Now()
		endDate = now.Format("2006-01-02")
		startDate = now.AddDate(0, 0, -6).Format("2006-01-02")
	}

	result, err := h.svc.Overview(c.Request.Context(), userID, platform, startDate, endDate)
	if err != nil {
		response.Fail(c, 500, response.CodeServerError, "获取统计数据失败")
		return
	}
	response.OK(c, result)
}

// Summary 按层级聚合广告指标（消耗/点击/展示/转化）。
// GET /api/v1/stats/summary?scope=advertiser&scope_id=1&date_from=2025-01-01&date_to=2025-01-07
func (h *Handler) Summary(c *gin.Context) {
	userID := middleware.GetUserID(c)
	scope := c.Query("scope")
	scopeIDStr := c.Query("scope_id")
	dateFrom := c.Query("date_from")
	dateTo := c.Query("date_to")

	if scope == "" || scopeIDStr == "" {
		response.BadRequest(c, "scope 和 scope_id 为必填参数")
		return
	}

	scopeID, err := parseUint64(scopeIDStr)
	if err != nil || scopeID == 0 {
		response.BadRequest(c, "无效的 scope_id")
		return
	}

	result, err := h.svc.Summary(c.Request.Context(), userID, scope, scopeID, dateFrom, dateTo)
	if err != nil {
		response.Fail(c, 500, response.CodeServerError, "获取统计数据失败")
		return
	}
	response.OK(c, result)
}

func parseUint64(s string) (uint64, error) {
	v, err := strconv.ParseUint(s, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("invalid uint64: %s", s)
	}
	return v, nil
}

