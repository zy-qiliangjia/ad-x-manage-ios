package statssvc

import (
	"context"
	"fmt"
	"sort"
	"time"

	"go.uber.org/zap"
	"gorm.io/gorm"

	"ad-x-manage/backend/internal/model/dto"
	"ad-x-manage/backend/internal/model/entity"
	advertiserrepo "ad-x-manage/backend/internal/repository/advertiser"
	tokenrepo "ad-x-manage/backend/internal/repository/token"
	"ad-x-manage/backend/internal/service/platform"
)

// OverviewResult 数据概览聚合结果。
type OverviewResult struct {
	TotalSpend        float64 `json:"total_spend"`
	TotalClicks       float64 `json:"total_clicks"`
	TotalImpressions  float64 `json:"total_impressions"`
	TotalConversions  float64 `json:"total_conversions"`
	ActiveAdvertisers int64   `json:"active_advertisers"`
	CampaignCount     int64   `json:"campaign_count"`
	AdGroupCount      int64   `json:"adgroup_count"`
}

// SummaryResult 分层级汇总统计结果。
type SummaryResult struct {
	Spend         float64 `json:"spend"`
	Clicks        int64   `json:"clicks"`
	Impressions   int64   `json:"impressions"`
	Conversions   int64   `json:"conversions"`
	LastUpdatedAt *string `json:"last_updated_at"`
}

// Service 统计数据接口。
type Service interface {
	Overview(ctx context.Context, userID uint64, platformFilter, startDate, endDate string) (*OverviewResult, error)
	// Summary 按层级（advertiser/campaign/adgroup）聚合本地 DB 指标。
	Summary(ctx context.Context, userID uint64, scope string, scopeID uint64, dateFrom, dateTo string) (*SummaryResult, error)
	// GetAdvertiserReport 按广告主维度拉取报表明细，附带日预算。
	GetAdvertiserReport(ctx context.Context, userID uint64, platformName string, advertiserIDs []string, startDate, endDate string) (*dto.StatsReportResponse, error)
	// GetAdGroupReport 按广告组维度拉取报表明细（per-adgroup）。
	GetAdGroupReport(ctx context.Context, userID, advertiserDBID uint64, adGroupIDs []string, startDate, endDate string) (*dto.AdGroupReportResponse, error)
	// GetCampaignReport 按推广系列维度拉取报表明细（per-campaign）。
	GetCampaignReport(ctx context.Context, userID, advertiserDBID uint64, campaignIDs []string, startDate, endDate string) (*dto.CampaignReportResponse, error)
	// GetAdReport 按广告维度拉取报表明细（per-ad）。
	GetAdReport(ctx context.Context, userID, advertiserDBID uint64, adIDs []string, startDate, endDate string) (*dto.AdReportResponse, error)
	// GetTrendReport 拉取当前用户所有广告主近7天每日趋势数据，按平台过滤。
	GetTrendReport(ctx context.Context, userID uint64, platformFilter, startDate, endDate string) (*dto.TrendReportResponse, error)
}

type service struct {
	db        *gorm.DB
	log       *zap.Logger
	clients   map[string]platform.Client
	tokenRepo tokenrepo.Repository
	advRepo   advertiserrepo.Repository
}

// New 创建统计服务实例。
func New(db *gorm.DB, log *zap.Logger, clients map[string]platform.Client, tokenRepo tokenrepo.Repository, advRepo advertiserrepo.Repository) Service {
	return &service{
		db:        db,
		log:       log,
		clients:   clients,
		tokenRepo: tokenRepo,
		advRepo:   advRepo,
	}
}

// Overview 查询当前用户的广告数据概览。
// 消耗/点击/展示/转化通过平台 Report API 实时拉取（分批≤5，缓存15分钟），
// 系列数/广告组数来自本地 DB。
func (s *service) Overview(ctx context.Context, userID uint64, platformFilter, startDate, endDate string) (*OverviewResult, error) {
	// 默认近30天
	if startDate == "" || endDate == "" {
		now := time.Now()
		endDate = now.Format("2006-01-02")
		startDate = now.AddDate(0, 0, -29).Format("2006-01-02")
	}

	result := &OverviewResult{}

	// 1. 获取该用户下有效广告主列表
	q := s.db.WithContext(ctx).Table("advertisers").
		Where("user_id = ? AND status = 1", userID)
	if platformFilter != "" {
		q = q.Where("platform = ?", platformFilter)
	}

	var advs []entity.Advertiser
	if err := q.Find(&advs).Error; err != nil {
		return nil, err
	}
	result.ActiveAdvertisers = int64(len(advs))

	if len(advs) == 0 {
		return result, nil
	}

	advIDs := make([]uint64, len(advs))
	for i, a := range advs {
		advIDs[i] = a.ID
	}

	// 2. 推广系列数 / 广告组数（从本地 DB）
	if err := s.db.WithContext(ctx).Table("campaigns").
		Where("advertiser_id IN ?", advIDs).
		Count(&result.CampaignCount).Error; err != nil {
		return nil, err
	}
	if err := s.db.WithContext(ctx).Table("ad_groups").
		Where("advertiser_id IN ?", advIDs).
		Count(&result.AdGroupCount).Error; err != nil {
		return nil, err
	}

	// 3. 按平台分组，调用平台 Report API 获取消耗/点击/展示/转化
	type platformGroup struct {
		tokenID       uint64
		advertiserIDs []string
	}
	groups := make(map[string]*platformGroup)
	for _, adv := range advs {
		plt := adv.Platform
		if _, ok := groups[plt]; !ok {
			groups[plt] = &platformGroup{tokenID: adv.TokenID}
		}
		groups[plt].advertiserIDs = append(groups[plt].advertiserIDs, adv.AdvertiserID)
	}

	for plt, group := range groups {
		client, ok := s.clients[plt]
		if !ok {
			continue
		}
		tok, err := s.tokenRepo.FindByID(ctx, group.tokenID)
		if err != nil || tok == nil {
			s.log.Warn("Overview: token not found", zap.String("platform", plt), zap.Uint64("token_id", group.tokenID))
			continue
		}
		stats, err := client.GetReportStats(tok.AccessToken, group.advertiserIDs, startDate, endDate)
		if err != nil {
			s.log.Warn("Overview: GetReportStats failed", zap.String("platform", plt), zap.Error(err))
			continue
		}
		result.TotalSpend += stats.Spend
		result.TotalClicks += float64(stats.Clicks)
		result.TotalImpressions += float64(stats.Impressions)
		result.TotalConversions += float64(stats.Conversion)
	}

	return result, nil
}

// Summary 按层级（advertiser/campaign/adgroup）聚合本地 DB 中的广告指标。
// dateFrom/dateTo 为 YYYY-MM-DD 格式，按 updated_at 日期区间过滤。
func (s *service) Summary(ctx context.Context, userID uint64, scope string, scopeID uint64, dateFrom, dateTo string) (*SummaryResult, error) {
	switch scope {
	case "advertiser":
		// 验证广告主归属
		var cnt int64
		if err := s.db.WithContext(ctx).Table("advertisers").
			Where("id = ? AND user_id = ? AND status = 1", scopeID, userID).
			Count(&cnt).Error; err != nil || cnt == 0 {
			return &SummaryResult{}, nil
		}
		return s.aggregateCampaigns(ctx, "advertiser_id = ?", scopeID, dateFrom, dateTo)

	case "campaign":
		// 验证 campaign 归属
		var advID uint64
		if err := s.db.WithContext(ctx).Table("campaigns").
			Where("id = ?", scopeID).Pluck("advertiser_id", &advID).Error; err != nil || advID == 0 {
			return &SummaryResult{}, nil
		}
		var cnt int64
		if err := s.db.WithContext(ctx).Table("advertisers").
			Where("id = ? AND user_id = ?", advID, userID).Count(&cnt).Error; err != nil || cnt == 0 {
			return &SummaryResult{}, nil
		}
		return s.aggregateAdGroups(ctx, "campaign_id = ?", scopeID, dateFrom, dateTo)

	case "adgroup":
		// 验证 adgroup 归属
		var advID uint64
		if err := s.db.WithContext(ctx).Table("ad_groups").
			Where("id = ?", scopeID).Pluck("advertiser_id", &advID).Error; err != nil || advID == 0 {
			return &SummaryResult{}, nil
		}
		var cnt int64
		if err := s.db.WithContext(ctx).Table("advertisers").
			Where("id = ? AND user_id = ?", advID, userID).Count(&cnt).Error; err != nil || cnt == 0 {
			return &SummaryResult{}, nil
		}
		return s.singleAdGroup(ctx, scopeID)

	default:
		return &SummaryResult{}, nil
	}
}

// GetAdvertiserReport 从平台拉取逐广告主报表，附加本地 DB 的 daily_budget。
func (s *service) GetAdvertiserReport(ctx context.Context, userID uint64, platformName string, advertiserIDs []string, startDate, endDate string) (*dto.StatsReportResponse, error) {
	if len(advertiserIDs) == 0 {
		return &dto.StatsReportResponse{List: []*dto.AdvertiserReportItem{}, TotalMetrics: &dto.AdvertiserReportItem{}}, nil
	}

	// 1. 校验该用户拥有这些广告主，并获取 daily_budget + token_id
	advs, err := s.advRepo.FindByUserPlatformIDs(ctx, userID, platformName, advertiserIDs)
	if err != nil {
		return nil, fmt.Errorf("query advertisers: %w", err)
	}

	// 构建 advertiser_id → entity 映射
	advMap := make(map[string]*entity.Advertiser, len(advs))
	for _, a := range advs {
		advMap[a.AdvertiserID] = a
	}

	// 2. 获取 access token（取第一个广告主的 token，同一平台共享同一 token）
	var accessToken string
	if len(advs) > 0 {
		tok, err := s.tokenRepo.FindByID(ctx, advs[0].TokenID)
		if err != nil || tok == nil {
			return nil, fmt.Errorf("get access token: token not found")
		}
		accessToken = tok.AccessToken
	}

	// 3. 调用平台客户端获取逐广告主指标
	client, ok := s.clients[platformName]
	if !ok {
		return nil, fmt.Errorf("unsupported platform: %s", platformName)
	}

	var platformItems []*platform.AdvertiserReportItem
	if accessToken != "" {
		platformItems, err = client.GetAdvertiserReport(accessToken, advertiserIDs, startDate, endDate)
		if err != nil {
			s.log.Warn("GetAdvertiserReport platform error",
				zap.String("platform", platformName), zap.Error(err))
			// 平台调用失败时返回零值列表，不报错
			platformItems = nil
		}
	}

	// 4. 合并 daily_budget 并构建响应
	var totalSpend float64
	var totalClicks, totalImpressions, totalConversion int64

	list := make([]*dto.AdvertiserReportItem, 0, len(advertiserIDs))
	for _, id := range advertiserIDs {
		item := &dto.AdvertiserReportItem{AdvertiserID: id}

		// 附加平台指标
		if platformItems != nil {
			for _, pi := range platformItems {
				if pi.AdvertiserID == id {
					item.Spend = pi.Spend
					item.Clicks = pi.Clicks
					item.Impressions = pi.Impressions
					item.Conversion = pi.Conversion
					item.CostPerConversion = pi.CostPerConversion
					item.CPA = pi.CPA
					item.Currency = pi.Currency
					break
				}
			}
		}

		// 附加日预算（从 DB）
		if adv, ok := advMap[id]; ok && adv.DailyBudget != nil {
			item.DailyBudget = *adv.DailyBudget
		}

		// 累加汇总
		totalSpend += item.Spend
		totalClicks += item.Clicks
		totalImpressions += item.Impressions
		totalConversion += item.Conversion

		list = append(list, item)
	}

	total := &dto.AdvertiserReportItem{
		Spend:       totalSpend,
		Clicks:      totalClicks,
		Impressions: totalImpressions,
		Conversion:  totalConversion,
	}

	return &dto.StatsReportResponse{List: list, TotalMetrics: total}, nil
}

// ── 内部聚合方法 ────────────────────────────────────────────────

type aggregateRow struct {
	Spend       float64
	Clicks      int64
	Impressions int64
	Conversions int64
	LastUpdated *time.Time `gorm:"column:last_updated"`
}

func (s *service) aggregateCampaigns(ctx context.Context, where string, id uint64, dateFrom, dateTo string) (*SummaryResult, error) {
	var row aggregateRow
	q := s.db.WithContext(ctx).Table("campaigns").
		Select("COALESCE(SUM(spend),0) AS spend, COALESCE(SUM(clicks),0) AS clicks, COALESCE(SUM(impressions),0) AS impressions, COALESCE(SUM(conversions),0) AS conversions, MAX(updated_at) AS last_updated").
		Where(where, id)
	q = applyDateFilter(q, dateFrom, dateTo)
	if err := q.Scan(&row).Error; err != nil {
		return nil, err
	}
	return toSummaryResult(row), nil
}

func (s *service) aggregateAdGroups(ctx context.Context, where string, id uint64, dateFrom, dateTo string) (*SummaryResult, error) {
	var row aggregateRow
	q := s.db.WithContext(ctx).Table("ad_groups").
		Select("COALESCE(SUM(spend),0) AS spend, COALESCE(SUM(clicks),0) AS clicks, COALESCE(SUM(impressions),0) AS impressions, COALESCE(SUM(conversions),0) AS conversions, MAX(updated_at) AS last_updated").
		Where(where, id)
	q = applyDateFilter(q, dateFrom, dateTo)
	if err := q.Scan(&row).Error; err != nil {
		return nil, err
	}
	return toSummaryResult(row), nil
}

type adgRow struct {
	Spend       float64
	Clicks      int64
	Impressions int64
	Conversions int64
	UpdatedAt   *time.Time
}

func (s *service) singleAdGroup(ctx context.Context, id uint64) (*SummaryResult, error) {
	var row adgRow
	if err := s.db.WithContext(ctx).Table("ad_groups").
		Select("spend, clicks, impressions, conversions, updated_at").
		Where("id = ?", id).Scan(&row).Error; err != nil {
		return nil, err
	}
	result := &SummaryResult{
		Spend: row.Spend, Clicks: row.Clicks,
		Impressions: row.Impressions, Conversions: row.Conversions,
	}
	if row.UpdatedAt != nil {
		ts := row.UpdatedAt.UTC().Format(time.RFC3339)
		result.LastUpdatedAt = &ts
	}
	return result, nil
}

func toSummaryResult(row aggregateRow) *SummaryResult {
	result := &SummaryResult{
		Spend: row.Spend, Clicks: row.Clicks,
		Impressions: row.Impressions, Conversions: row.Conversions,
	}
	if row.LastUpdated != nil {
		ts := row.LastUpdated.UTC().Format(time.RFC3339)
		result.LastUpdatedAt = &ts
	}
	return result
}

// GetAdGroupReport 从平台拉取逐广告组报表，按 advertiserDBID 验证归属。
func (s *service) GetAdGroupReport(ctx context.Context, userID, advertiserDBID uint64, adGroupIDs []string, startDate, endDate string) (*dto.AdGroupReportResponse, error) {
	if len(adGroupIDs) == 0 {
		return &dto.AdGroupReportResponse{List: []*dto.AdGroupReportItem{}}, nil
	}

	// 1. 验证广告主归属
	adv, err := s.advRepo.FindByID(ctx, advertiserDBID)
	if err != nil || adv == nil {
		return nil, fmt.Errorf("advertiser not found")
	}
	if adv.UserID != userID {
		return nil, fmt.Errorf("forbidden")
	}

	// 2. 获取 access token
	tok, err := s.tokenRepo.FindByID(ctx, adv.TokenID)
	if err != nil || tok == nil {
		return nil, fmt.Errorf("token not found")
	}

	// 3. 调用平台客户端
	client, ok := s.clients[adv.Platform]
	if !ok {
		return nil, fmt.Errorf("unsupported platform: %s", adv.Platform)
	}

	platformItems, err := client.GetAdGroupReport(tok.AccessToken, adv.AdvertiserID, adGroupIDs, startDate, endDate)
	if err != nil {
		s.log.Warn("GetAdGroupReport platform error", zap.String("platform", adv.Platform), zap.Error(err))
		platformItems = nil
	}

	// 4. 构建响应
	itemMap := make(map[string]*platform.AdGroupReportItem, len(platformItems))
	for _, pi := range platformItems {
		itemMap[pi.AdGroupID] = pi
	}

	list := make([]*dto.AdGroupReportItem, 0, len(adGroupIDs))
	for _, id := range adGroupIDs {
		item := &dto.AdGroupReportItem{AdGroupID: id}
		if pi, ok := itemMap[id]; ok {
			item.Spend = pi.Spend
			item.Clicks = pi.Clicks
			item.Impressions = pi.Impressions
			item.Conversion = pi.Conversion
			item.CPA = pi.CPA
		}
		list = append(list, item)
	}

	return &dto.AdGroupReportResponse{List: list}, nil
}

// GetCampaignReport 从平台拉取逐推广系列报表，按 advertiserDBID 验证归属。
func (s *service) GetCampaignReport(ctx context.Context, userID, advertiserDBID uint64, campaignIDs []string, startDate, endDate string) (*dto.CampaignReportResponse, error) {
	if len(campaignIDs) == 0 {
		return &dto.CampaignReportResponse{List: []*dto.CampaignReportItem{}}, nil
	}

	// 1. 验证广告主归属
	adv, err := s.advRepo.FindByID(ctx, advertiserDBID)
	if err != nil || adv == nil {
		return nil, fmt.Errorf("advertiser not found")
	}
	if adv.UserID != userID {
		return nil, fmt.Errorf("forbidden")
	}

	// 2. 获取 access token
	tok, err := s.tokenRepo.FindByID(ctx, adv.TokenID)
	if err != nil || tok == nil {
		return nil, fmt.Errorf("token not found")
	}

	// 3. 调用平台客户端
	client, ok := s.clients[adv.Platform]
	if !ok {
		return nil, fmt.Errorf("unsupported platform: %s", adv.Platform)
	}

	platformItems, err := client.GetCampaignReport(tok.AccessToken, adv.AdvertiserID, campaignIDs, startDate, endDate)
	if err != nil {
		s.log.Warn("GetCampaignReport platform error", zap.String("platform", adv.Platform), zap.Error(err))
		return nil, fmt.Errorf("platform GetCampaignReport: %w", err)
	}

	// 4. 构建响应
	itemMap := make(map[string]*platform.CampaignReportItem, len(platformItems))
	for _, pi := range platformItems {
		itemMap[pi.CampaignID] = pi
	}

	list := make([]*dto.CampaignReportItem, 0, len(campaignIDs))
	for _, id := range campaignIDs {
		item := &dto.CampaignReportItem{CampaignID: id}
		if pi, ok := itemMap[id]; ok {
			item.Spend = pi.Spend
			item.Clicks = pi.Clicks
			item.Impressions = pi.Impressions
			item.Conversion = pi.Conversion
			item.CPA = pi.CPA
		}
		list = append(list, item)
	}

	// 5. 计算汇总指标
	total := &dto.CampaignReportItem{}
	for _, item := range list {
		total.Spend += item.Spend
		total.Clicks += item.Clicks
		total.Impressions += item.Impressions
		total.Conversion += item.Conversion
	}
	if total.Conversion > 0 {
		total.CPA = total.Spend / float64(total.Conversion)
	}

	return &dto.CampaignReportResponse{List: list, TotalMetrics: total}, nil
}

// GetAdReport 从平台拉取逐广告报表，按 advertiserDBID 验证归属。
func (s *service) GetAdReport(ctx context.Context, userID, advertiserDBID uint64, adIDs []string, startDate, endDate string) (*dto.AdReportResponse, error) {
	if len(adIDs) == 0 {
		return &dto.AdReportResponse{List: []*dto.AdReportItem{}}, nil
	}

	// 1. 验证广告主归属
	adv, err := s.advRepo.FindByID(ctx, advertiserDBID)
	if err != nil || adv == nil {
		return nil, fmt.Errorf("advertiser not found")
	}
	if adv.UserID != userID {
		return nil, fmt.Errorf("forbidden")
	}

	// 2. 获取 access token
	tok, err := s.tokenRepo.FindByID(ctx, adv.TokenID)
	if err != nil || tok == nil {
		return nil, fmt.Errorf("token not found")
	}

	// 3. 调用平台客户端
	client, ok := s.clients[adv.Platform]
	if !ok {
		return nil, fmt.Errorf("unsupported platform: %s", adv.Platform)
	}

	platformItems, err := client.GetAdReport(tok.AccessToken, adv.AdvertiserID, adIDs, startDate, endDate)
	if err != nil {
		s.log.Warn("GetAdReport platform error", zap.String("platform", adv.Platform), zap.Error(err))
		platformItems = nil
	}

	// 4. 构建响应
	itemMap := make(map[string]*platform.AdReportItem, len(platformItems))
	for _, pi := range platformItems {
		itemMap[pi.AdID] = pi
	}

	list := make([]*dto.AdReportItem, 0, len(adIDs))
	for _, id := range adIDs {
		item := &dto.AdReportItem{AdID: id}
		if pi, ok := itemMap[id]; ok {
			item.Spend = pi.Spend
			item.Clicks = pi.Clicks
			item.Impressions = pi.Impressions
			item.Conversion = pi.Conversion
			item.CPA = pi.CPA
		}
		list = append(list, item)
	}

	return &dto.AdReportResponse{List: list}, nil
}

// GetTrendReport 拉取当前用户所有广告主在 [startDate, endDate] 内的每日趋势数据。
// 按平台过滤，各平台结果按日期聚合后返回，日期升序。
func (s *service) GetTrendReport(ctx context.Context, userID uint64, platformFilter, startDate, endDate string) (*dto.TrendReportResponse, error) {
	// 1. 获取该用户下有效广告主列表
	q := s.db.WithContext(ctx).Table("advertisers").
		Where("user_id = ? AND status = 1", userID)
	if platformFilter != "" {
		q = q.Where("platform = ?", platformFilter)
	}

	var advs []entity.Advertiser
	if err := q.Find(&advs).Error; err != nil {
		return nil, err
	}
	if len(advs) == 0 {
		return &dto.TrendReportResponse{Items: []*dto.TrendDataPoint{}}, nil
	}

	// 2. 按平台分组
	type platformGroup struct {
		tokenID       uint64
		advertiserIDs []string
	}
	groups := make(map[string]*platformGroup)
	for _, adv := range advs {
		plt := adv.Platform
		if _, ok := groups[plt]; !ok {
			groups[plt] = &platformGroup{tokenID: adv.TokenID}
		}
		groups[plt].advertiserIDs = append(groups[plt].advertiserIDs, adv.AdvertiserID)
	}

	// 3. 按日期聚合各平台结果
	byDate := make(map[string]*dto.TrendDataPoint)

	for plt, group := range groups {
		client, ok := s.clients[plt]
		if !ok {
			continue
		}
		tok, err := s.tokenRepo.FindByID(ctx, group.tokenID)
		if err != nil || tok == nil {
			s.log.Warn("GetTrendReport: token not found", zap.String("platform", plt))
			continue
		}
		items, err := client.GetTrendReport(tok.AccessToken, group.advertiserIDs, startDate, endDate)
		if err != nil {
			s.log.Warn("GetTrendReport: platform error", zap.String("platform", plt), zap.Error(err))
			continue
		}
		for _, item := range items {
			if existing, ok := byDate[item.Date]; ok {
				existing.Spend += item.Spend
				existing.Clicks += item.Clicks
				existing.Impressions += item.Impressions
				existing.Conversion += item.Conversion
			} else {
				byDate[item.Date] = &dto.TrendDataPoint{
					Date:        item.Date,
					Spend:       item.Spend,
					Clicks:      item.Clicks,
					Impressions: item.Impressions,
					Conversion:  item.Conversion,
				}
			}
		}
	}

	// 4. 按日期排序输出
	dates := make([]string, 0, len(byDate))
	for d := range byDate {
		dates = append(dates, d)
	}
	sort.Strings(dates)

	result := make([]*dto.TrendDataPoint, 0, len(dates))
	for _, d := range dates {
		result = append(result, byDate[d])
	}

	return &dto.TrendReportResponse{Items: result}, nil
}

func applyDateFilter(q *gorm.DB, dateFrom, dateTo string) *gorm.DB {
	if dateFrom != "" {
		q = q.Where("DATE(updated_at) >= ?", dateFrom)
	}
	if dateTo != "" {
		q = q.Where("DATE(updated_at) <= ?", dateTo)
	}
	return q
}
