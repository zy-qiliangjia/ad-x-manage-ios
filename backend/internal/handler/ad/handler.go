package adhandler

import (
	"errors"
	"fmt"
	"strconv"

	"github.com/gin-gonic/gin"

	"ad-x-manage/backend/internal/middleware"
	"ad-x-manage/backend/internal/model/dto"
	"ad-x-manage/backend/internal/pkg/response"
	adsvc "ad-x-manage/backend/internal/service/ad"
)

type Handler struct {
	svc adsvc.Service
}

func New(svc adsvc.Service) *Handler {
	return &Handler{svc: svc}
}

// List 广告分页列表，支持按广告组过滤和关键词搜索
// GET /api/v1/advertisers/:id/ads?adgroup_id=0&keyword=xxx&page=1&page_size=20
func (h *Handler) List(c *gin.Context) {
	advertiserID, err := parseID(c, "id")
	if err != nil {
		response.BadRequest(c, "无效的广告主 ID")
		return
	}
	var req dto.AdListRequest
	if err := c.ShouldBindQuery(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	userID := middleware.GetUserID(c)

	list, total, err := h.svc.List(c.Request.Context(), userID, advertiserID, &req)
	if err != nil {
		switch {
		case errors.Is(err, adsvc.ErrNotFound):
			response.BadRequest(c, "广告主不存在")
		case errors.Is(err, adsvc.ErrForbidden):
			response.Forbidden(c, "无权限查看该广告主")
		default:
			response.ServerError(c, "获取广告列表失败")
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

// ListAll 全量广告分页列表（跨广告主）
// GET /api/v1/ads?platform=tiktok&keyword=xxx&page=1&page_size=20
func (h *Handler) ListAll(c *gin.Context) {
	var req dto.AllAdListRequest
	if err := c.ShouldBindQuery(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	userID := middleware.GetUserID(c)

	list, total, err := h.svc.ListAll(c.Request.Context(), userID, &req)
	if err != nil {
		response.ServerError(c, "获取广告列表失败")
		return
	}

	response.OKPage(c, list, response.Pagination{
		Page:     req.Page,
		PageSize: req.PageSize,
		Total:    total,
		HasMore:  int64(req.Page*req.PageSize) < total,
	})
}

func parseID(c *gin.Context, param string) (uint64, error) {
	id, err := strconv.ParseUint(c.Param(param), 10, 64)
	if err != nil || id == 0 {
		return 0, fmt.Errorf("invalid id")
	}
	return id, nil
}
