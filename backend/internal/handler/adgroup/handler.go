package adgrouphandler

import (
	"errors"
	"fmt"
	"strconv"

	"github.com/gin-gonic/gin"

	"ad-x-manage/backend/internal/middleware"
	"ad-x-manage/backend/internal/model/dto"
	"ad-x-manage/backend/internal/pkg/response"
	adgroupsvc "ad-x-manage/backend/internal/service/adgroup"
)

type Handler struct {
	svc adgroupsvc.Service
}

func New(svc adgroupsvc.Service) *Handler {
	return &Handler{svc: svc}
}

// List 广告组分页列表
// GET /api/v1/advertisers/:id/adgroups?campaign_id=0&page=1&page_size=20
func (h *Handler) List(c *gin.Context) {
	advertiserID, err := parseID(c, "id")
	if err != nil {
		response.BadRequest(c, "无效的广告主 ID")
		return
	}
	var req dto.AdGroupListRequest
	if err := c.ShouldBindQuery(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	userID := middleware.GetUserID(c)

	list, total, err := h.svc.List(c.Request.Context(), userID, advertiserID, &req)
	if err != nil {
		switch {
		case errors.Is(err, adgroupsvc.ErrNotFound):
			response.BadRequest(c, "广告主不存在")
		case errors.Is(err, adgroupsvc.ErrForbidden):
			response.Forbidden(c, "无权限查看该广告主")
		default:
			response.ServerError(c, "获取广告组列表失败")
		}
		return
	}

	response.OKPage(c, list, response.Pagination{
		Page:     req.Page,
		PageSize: req.PageSize,
		Total:    total,
		HasMore:  int64(req.Page*req.PageSize) < total,
	})
}

// UpdateBudget 修改广告组预算
// PATCH /api/v1/adgroups/:id/budget
func (h *Handler) UpdateBudget(c *gin.Context) {
	adgroupID, err := parseID(c, "id")
	if err != nil {
		response.BadRequest(c, "无效的广告组 ID")
		return
	}
	var req dto.UpdateBudgetRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	userID := middleware.GetUserID(c)

	if err := h.svc.UpdateBudget(c.Request.Context(), userID, adgroupID, req.Budget); err != nil {
		handleWriteError(c, err, adgroupsvc.ErrNotFound, adgroupsvc.ErrForbidden, "修改预算失败")
		return
	}
	response.OK(c, gin.H{"adgroup_id": adgroupID, "budget": req.Budget})
}

// UpdateStatus 开启或暂停广告组
// PATCH /api/v1/adgroups/:id/status
func (h *Handler) UpdateStatus(c *gin.Context) {
	adgroupID, err := parseID(c, "id")
	if err != nil {
		response.BadRequest(c, "无效的广告组 ID")
		return
	}
	var req dto.UpdateStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	userID := middleware.GetUserID(c)

	if err := h.svc.UpdateStatus(c.Request.Context(), userID, adgroupID, req.Action); err != nil {
		handleWriteError(c, err, adgroupsvc.ErrNotFound, adgroupsvc.ErrForbidden, "修改状态失败")
		return
	}
	response.OK(c, gin.H{"adgroup_id": adgroupID, "action": req.Action})
}

func handleWriteError(c *gin.Context, err, errNotFound, errForbidden error, defaultMsg string) {
	switch {
	case errors.Is(err, errNotFound):
		response.BadRequest(c, "资源不存在")
	case errors.Is(err, errForbidden):
		response.Forbidden(c, "无权限操作")
	default:
		response.PlatformError(c, fmt.Sprintf("%s: %v", defaultMsg, err))
	}
}

func parseID(c *gin.Context, param string) (uint64, error) {
	id, err := strconv.ParseUint(c.Param(param), 10, 64)
	if err != nil || id == 0 {
		return 0, fmt.Errorf("invalid id")
	}
	return id, nil
}
