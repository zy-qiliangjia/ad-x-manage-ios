package statssvc

import (
	"context"

	"gorm.io/gorm"
)

// OverviewResult 数据概览聚合结果。
type OverviewResult struct {
	TotalSpend        float64 `json:"total_spend"`
	ActiveAdvertisers int64   `json:"active_advertisers"`
	CampaignCount     int64   `json:"campaign_count"`
	AdGroupCount      int64   `json:"adgroup_count"`
}

// Service 统计数据接口。
type Service interface {
	Overview(ctx context.Context, userID uint64, platform string) (*OverviewResult, error)
}

type service struct {
	db *gorm.DB
}

// New 创建统计服务实例。
func New(db *gorm.DB) Service {
	return &service{db: db}
}

// Overview 查询当前用户的广告数据概览（消耗总额、活跃广告主数、推广系列数、广告组数）。
func (s *service) Overview(ctx context.Context, userID uint64, platform string) (*OverviewResult, error) {
	result := &OverviewResult{}

	// 1. 获取该用户下有效广告主 ID 列表
	q := s.db.WithContext(ctx).Table("advertisers").
		Where("user_id = ? AND status = 1", userID)
	if platform != "" {
		q = q.Where("platform = ?", platform)
	}

	var advIDs []uint64
	if err := q.Pluck("id", &advIDs).Error; err != nil {
		return nil, err
	}
	result.ActiveAdvertisers = int64(len(advIDs))

	if len(advIDs) == 0 {
		return result, nil
	}

	// 2. 推广系列总消耗 + 系列数
	type spendRow struct {
		TotalSpend    float64
		CampaignCount int64
	}
	var sr spendRow
	if err := s.db.WithContext(ctx).Table("campaigns").
		Select("COALESCE(SUM(spend), 0) AS total_spend, COUNT(*) AS campaign_count").
		Where("advertiser_id IN ?", advIDs).
		Scan(&sr).Error; err != nil {
		return nil, err
	}
	result.TotalSpend = sr.TotalSpend
	result.CampaignCount = sr.CampaignCount

	// 3. 广告组数
	if err := s.db.WithContext(ctx).Table("ad_groups").
		Where("advertiser_id IN ?", advIDs).
		Count(&result.AdGroupCount).Error; err != nil {
		return nil, err
	}

	return result, nil
}
