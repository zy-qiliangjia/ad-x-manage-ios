package operationloghandler

import (
	"errors"

	"github.com/gin-gonic/gin"

	"ad-x-manage/backend/internal/middleware"
	"ad-x-manage/backend/internal/model/dto"
	"ad-x-manage/backend/internal/pkg/response"
	operationlogsvc "ad-x-manage/backend/internal/service/operationlog"
)

type Handler struct {
	svc operationlogsvc.Service
}

func New(svc operationlogsvc.Service) *Handler {
	return &Handler{svc: svc}
}

// List 操作日志分页列表
// GET /api/v1/operation-logs?advertiser_id=&platform=&action=&target_type=&result=&start_date=&end_date=&page=1&page_size=20
func (h *Handler) List(c *gin.Context) {
	var req dto.OperationLogListRequest
	if err := c.ShouldBindQuery(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	userID := middleware.GetUserID(c)

	list, total, err := h.svc.List(c.Request.Context(), userID, &req)
	if err != nil {
		if errors.Is(err, operationlogsvc.ErrForbidden) {
			response.Forbidden(c, "无权限查看该广告主的操作日志")
			return
		}
		response.ServerError(c, "获取操作日志失败")
		return
	}

	response.OKPage(c, list, response.Pagination{
		Page:     req.Page,
		PageSize: req.PageSize,
		Total:    total,
		HasMore:  int64(req.Page*req.PageSize) < total,
	})
}
