package advertiserhandler

import (
	"errors"
	"fmt"
	"strconv"

	"github.com/gin-gonic/gin"

	"ad-x-manage/backend/internal/middleware"
	"ad-x-manage/backend/internal/model/dto"
	"ad-x-manage/backend/internal/pkg/response"
	advertisersvc "ad-x-manage/backend/internal/service/advertiser"
)

type Handler struct {
	svc advertisersvc.Service
}

func New(svc advertisersvc.Service) *Handler {
	return &Handler{svc: svc}
}

// List 广告主账号列表（支持平台过滤 / 关键词搜索 / 分页）
// GET /api/v1/advertisers?platform=tiktok&keyword=xxx&page=1&page_size=20
func (h *Handler) List(c *gin.Context) {
	var req dto.AdvertiserListRequest
	if err := c.ShouldBindQuery(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	userID := middleware.GetUserID(c)

	list, total, err := h.svc.List(c.Request.Context(), userID, &req)
	if err != nil {
		response.ServerError(c, "获取广告主列表失败")
		return
	}

	response.OKPage(c, list, response.Pagination{
		Page:     req.Page,
		PageSize: req.PageSize,
		Total:    total,
		HasMore:  int64(req.Page*req.PageSize) < total,
	})
}

// Balance 实时查询广告主余额（不缓存，直接调用平台 API）
// GET /api/v1/advertisers/:id/balance
func (h *Handler) Balance(c *gin.Context) {
	id, err := parseID(c, "id")
	if err != nil {
		response.BadRequest(c, "无效的广告主 ID")
		return
	}
	userID := middleware.GetUserID(c)

	res, err := h.svc.GetBalance(c.Request.Context(), userID, id)
	if err != nil {
		switch {
		case errors.Is(err, advertisersvc.ErrNotFound):
			response.BadRequest(c, "广告主不存在")
		case errors.Is(err, advertisersvc.ErrForbidden):
			response.Forbidden(c, "无权限查看该广告主")
		default:
			response.PlatformError(c, fmt.Sprintf("余额查询失败: %v", err))
		}
		return
	}

	response.OK(c, res)
}

// Sync 手动触发全量数据同步
// POST /api/v1/advertisers/:id/sync
func (h *Handler) Sync(c *gin.Context) {
	id, err := parseID(c, "id")
	if err != nil {
		response.BadRequest(c, "无效的广告主 ID")
		return
	}
	userID := middleware.GetUserID(c)

	res, err := h.svc.Sync(c.Request.Context(), userID, id)
	if err != nil {
		switch {
		case errors.Is(err, advertisersvc.ErrNotFound):
			response.BadRequest(c, "广告主不存在")
		case errors.Is(err, advertisersvc.ErrForbidden):
			response.Forbidden(c, "无权限操作该广告主")
		default:
			response.ServerError(c, fmt.Sprintf("同步失败: %v", err))
		}
		return
	}

	response.OK(c, res)
}

func parseID(c *gin.Context, param string) (uint64, error) {
	id, err := strconv.ParseUint(c.Param(param), 10, 64)
	if err != nil || id == 0 {
		return 0, fmt.Errorf("invalid id")
	}
	return id, nil
}
