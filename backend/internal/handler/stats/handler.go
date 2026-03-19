package statshandler

import (
	"fmt"
	"strconv"
	"strings"
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

	// 默认近30天
	if startDate == "" || endDate == "" {
		now := time.Now()
		endDate = now.Format("2006-01-02")
		startDate = now.AddDate(0, 0, -29).Format("2006-01-02")
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

// GetReport 广告主报表批量查询接口。
// GET /api/v1/stats/report?platform=tiktok&advertiser_ids=id1,id2&start_date=2026-01-01&end_date=2026-01-07
func (h *Handler) GetReport(c *gin.Context) {
	userID := middleware.GetUserID(c)
	platformName := c.Query("platform")
	advertiserIDsStr := c.Query("advertiser_ids")
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")

	if platformName == "" || advertiserIDsStr == "" || startDate == "" || endDate == "" {
		response.BadRequest(c, "platform、advertiser_ids、start_date、end_date 均为必填参数")
		return
	}

	// 解析日期跨度（最多30天）
	start, err1 := time.Parse("2006-01-02", startDate)
	end, err2 := time.Parse("2006-01-02", endDate)
	if err1 != nil || err2 != nil {
		response.BadRequest(c, "日期格式无效，请使用 YYYY-MM-DD")
		return
	}
	if end.Sub(start) > 30*24*time.Hour {
		response.Fail(c, 422, response.CodeInvalidParam, "日期跨度最多30天")
		return
	}

	advertiserIDs := strings.Split(advertiserIDsStr, ",")
	for i, id := range advertiserIDs {
		advertiserIDs[i] = strings.TrimSpace(id)
	}

	result, err := h.svc.GetAdvertiserReport(c.Request.Context(), userID, platformName, advertiserIDs, startDate, endDate)
	if err != nil {
		response.Fail(c, 500, response.CodeServerError, "获取报表数据失败")
		return
	}
	response.OK(c, result)
}

// GetAdGroupReport 广告组报表批量查询接口。
// GET /api/v1/stats/adgroup-report?advertiser_id=123&adgroup_ids=id1,id2&start_date=2026-01-01&end_date=2026-01-07
func (h *Handler) GetAdGroupReport(c *gin.Context) {
	userID := middleware.GetUserID(c)
	advertiserIDStr := c.Query("advertiser_id")
	adGroupIDsStr := c.Query("adgroup_ids")
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")

	if advertiserIDStr == "" || adGroupIDsStr == "" || startDate == "" || endDate == "" {
		response.BadRequest(c, "advertiser_id、adgroup_ids、start_date、end_date 均为必填参数")
		return
	}

	advertiserID, err := parseUint64(advertiserIDStr)
	if err != nil || advertiserID == 0 {
		response.BadRequest(c, "无效的 advertiser_id")
		return
	}

	start, err1 := time.Parse("2006-01-02", startDate)
	end, err2 := time.Parse("2006-01-02", endDate)
	if err1 != nil || err2 != nil {
		response.BadRequest(c, "日期格式无效，请使用 YYYY-MM-DD")
		return
	}
	if end.Sub(start) > 30*24*time.Hour {
		response.Fail(c, 422, response.CodeInvalidParam, "日期跨度最多30天")
		return
	}

	adGroupIDs := strings.Split(adGroupIDsStr, ",")
	for i, id := range adGroupIDs {
		adGroupIDs[i] = strings.TrimSpace(id)
	}

	result, err := h.svc.GetAdGroupReport(c.Request.Context(), userID, advertiserID, adGroupIDs, startDate, endDate)
	if err != nil {
		response.Fail(c, 500, response.CodeServerError, "获取报表数据失败")
		return
	}
	response.OK(c, result)
}

// GetCampaignReport 推广系列报表批量查询接口。
// GET /api/v1/stats/campaign-report?advertiser_id=123&campaign_ids=id1,id2&start_date=2026-01-01&end_date=2026-01-07
func (h *Handler) GetCampaignReport(c *gin.Context) {
	userID := middleware.GetUserID(c)
	advertiserIDStr := c.Query("advertiser_id")
	campaignIDsStr := c.Query("campaign_ids")
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")

	if advertiserIDStr == "" || campaignIDsStr == "" || startDate == "" || endDate == "" {
		response.BadRequest(c, "advertiser_id、campaign_ids、start_date、end_date 均为必填参数")
		return
	}

	advertiserID, err := parseUint64(advertiserIDStr)
	if err != nil || advertiserID == 0 {
		response.BadRequest(c, "无效的 advertiser_id")
		return
	}

	start, err1 := time.Parse("2006-01-02", startDate)
	end, err2 := time.Parse("2006-01-02", endDate)
	if err1 != nil || err2 != nil {
		response.BadRequest(c, "日期格式无效，请使用 YYYY-MM-DD")
		return
	}
	if end.Sub(start) > 30*24*time.Hour {
		response.Fail(c, 422, response.CodeInvalidParam, "日期跨度最多30天")
		return
	}

	campaignIDs := strings.Split(campaignIDsStr, ",")
	for i, id := range campaignIDs {
		campaignIDs[i] = strings.TrimSpace(id)
	}

	result, err := h.svc.GetCampaignReport(c.Request.Context(), userID, advertiserID, campaignIDs, startDate, endDate)
	if err != nil {
		response.Fail(c, 500, response.CodeServerError, "获取报表数据失败")
		return
	}
	response.OK(c, result)
}

// GetAdReport 广告报表批量查询接口。
// GET /api/v1/stats/ad-report?advertiser_id=123&ad_ids=id1,id2&start_date=2026-01-01&end_date=2026-01-07
func (h *Handler) GetAdReport(c *gin.Context) {
	userID := middleware.GetUserID(c)
	advertiserIDStr := c.Query("advertiser_id")
	adIDsStr := c.Query("ad_ids")
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")

	if advertiserIDStr == "" || adIDsStr == "" || startDate == "" || endDate == "" {
		response.BadRequest(c, "advertiser_id、ad_ids、start_date、end_date 均为必填参数")
		return
	}

	advertiserID, err := parseUint64(advertiserIDStr)
	if err != nil || advertiserID == 0 {
		response.BadRequest(c, "无效的 advertiser_id")
		return
	}

	start, err1 := time.Parse("2006-01-02", startDate)
	end, err2 := time.Parse("2006-01-02", endDate)
	if err1 != nil || err2 != nil {
		response.BadRequest(c, "日期格式无效，请使用 YYYY-MM-DD")
		return
	}
	if end.Sub(start) > 30*24*time.Hour {
		response.Fail(c, 422, response.CodeInvalidParam, "日期跨度最多30天")
		return
	}

	adIDs := strings.Split(adIDsStr, ",")
	for i, id := range adIDs {
		adIDs[i] = strings.TrimSpace(id)
	}

	result, err := h.svc.GetAdReport(c.Request.Context(), userID, advertiserID, adIDs, startDate, endDate)
	if err != nil {
		response.Fail(c, 500, response.CodeServerError, "获取报表数据失败")
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

