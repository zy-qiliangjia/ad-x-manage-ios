package campaignhandler

import (
	"errors"
	"fmt"
	"strconv"

	"github.com/gin-gonic/gin"

	"ad-x-manage/backend/internal/middleware"
	"ad-x-manage/backend/internal/model/dto"
	"ad-x-manage/backend/internal/pkg/response"
	campaignsvc "ad-x-manage/backend/internal/service/campaign"
)

type Handler struct {
	svc campaignsvc.Service
}

func New(svc campaignsvc.Service) *Handler {
	return &Handler{svc: svc}
}

// List 推广系列分页列表
// GET /api/v1/advertisers/:id/campaigns?page=1&page_size=20
func (h *Handler) List(c *gin.Context) {
	advertiserID, err := parseID(c, "id")
	if err != nil {
		response.BadRequest(c, "无效的广告主 ID")
		return
	}
	var req dto.CampaignListRequest
	if err := c.ShouldBindQuery(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	userID := middleware.GetUserID(c)

	list, total, err := h.svc.List(c.Request.Context(), userID, advertiserID, &req)
	if err != nil {
		switch {
		case errors.Is(err, campaignsvc.ErrNotFound):
			response.BadRequest(c, "广告主不存在")
		case errors.Is(err, campaignsvc.ErrForbidden):
			response.Forbidden(c, "无权限查看该广告主")
		default:
			response.ServerError(c, "获取推广系列列表失败")
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

// ListAll 全量推广系列分页列表（跨广告主）
// GET /api/v1/campaigns?platform=tiktok&keyword=xxx&page=1&page_size=20
func (h *Handler) ListAll(c *gin.Context) {
	var req dto.AllCampaignListRequest
	if err := c.ShouldBindQuery(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	userID := middleware.GetUserID(c)

	list, total, err := h.svc.ListAll(c.Request.Context(), userID, &req)
	if err != nil {
		response.ServerError(c, "获取推广系列列表失败")
		return
	}

	response.OKPage(c, list, response.Pagination{
		Page:     req.Page,
		PageSize: req.PageSize,
		Total:    total,
		HasMore:  int64(req.Page*req.PageSize) < total,
	})
}

// UpdateBudget 修改推广系列预算
// PATCH /api/v1/campaigns/:id/budget
func (h *Handler) UpdateBudget(c *gin.Context) {
	campaignID, err := parseID(c, "id")
	if err != nil {
		response.BadRequest(c, "无效的推广系列 ID")
		return
	}
	var req dto.UpdateBudgetRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	userID := middleware.GetUserID(c)

	if err := h.svc.UpdateBudget(c.Request.Context(), userID, campaignID, req.Budget); err != nil {
		handleWriteError(c, err, campaignsvc.ErrNotFound, campaignsvc.ErrForbidden, "修改预算失败")
		return
	}
	response.OK(c, gin.H{"campaign_id": campaignID, "budget": req.Budget})
}

// UpdateStatus 开启或暂停推广系列
// PATCH /api/v1/campaigns/:id/status
func (h *Handler) UpdateStatus(c *gin.Context) {
	campaignID, err := parseID(c, "id")
	if err != nil {
		response.BadRequest(c, "无效的推广系列 ID")
		return
	}
	var req dto.UpdateStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	userID := middleware.GetUserID(c)

	if err := h.svc.UpdateStatus(c.Request.Context(), userID, campaignID, req.Action); err != nil {
		handleWriteError(c, err, campaignsvc.ErrNotFound, campaignsvc.ErrForbidden, "修改状态失败")
		return
	}
	response.OK(c, gin.H{"campaign_id": campaignID, "action": req.Action})
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
