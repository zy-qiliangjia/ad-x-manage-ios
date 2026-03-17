package statssvc

import (
	"context"
	"time"

	"go.uber.org/zap"
	"gorm.io/gorm"

	"ad-x-manage/backend/internal/model/entity"
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
}

type service struct {
	db  *gorm.DB
	log *zap.Logger
}

// New 创建统计服务实例。
func New(db *gorm.DB, log *zap.Logger) Service {
	return &service{db: db, log: log}
}

// Overview 查询当前用户的广告数据概览。
// 消耗/点击/展示/转化聚合自本地 campaigns 表，系列数/广告组数同样来自本地 DB。
func (s *service) Overview(ctx context.Context, userID uint64, platformFilter, startDate, endDate string) (*OverviewResult, error) {
	// 默认近7天
	if startDate == "" || endDate == "" {
		now := time.Now()
		endDate = now.Format("2006-01-02")
		startDate = now.AddDate(0, 0, -6).Format("2006-01-02")
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

	// 3. 从本地 campaigns 表聚合消耗/点击/展示/转化
	var metrics struct {
		Spend       float64
		Clicks      float64
		Impressions float64
		Conversions float64
	}
	if err := s.db.WithContext(ctx).Table("campaigns").
		Select("COALESCE(SUM(spend),0) AS spend, COALESCE(SUM(clicks),0) AS clicks, COALESCE(SUM(impressions),0) AS impressions, COALESCE(SUM(conversions),0) AS conversions").
		Where("advertiser_id IN ?", advIDs).
		Scan(&metrics).Error; err != nil {
		return nil, err
	}
	result.TotalSpend = metrics.Spend
	result.TotalClicks = metrics.Clicks
	result.TotalImpressions = metrics.Impressions
	result.TotalConversions = metrics.Conversions

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

func applyDateFilter(q *gorm.DB, dateFrom, dateTo string) *gorm.DB {
	if dateFrom != "" {
		q = q.Where("DATE(updated_at) >= ?", dateFrom)
	}
	if dateTo != "" {
		q = q.Where("DATE(updated_at) <= ?", dateTo)
	}
	return q
}

