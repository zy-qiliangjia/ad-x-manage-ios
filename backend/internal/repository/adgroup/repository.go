package adgrouprepo

import (
	"context"
	"errors"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"ad-x-manage/backend/internal/model/entity"
)

type Repository interface {
	Upsert(ctx context.Context, groups []*entity.AdGroup) error
	FindAllByAdvertiserID(ctx context.Context, advertiserID uint64) ([]*entity.AdGroup, error)
	FindByAdvertiserID(ctx context.Context, advertiserID uint64, campaignID uint64, page, pageSize int) ([]*entity.AdGroup, int64, error)
	FindByAdvertiserIDs(ctx context.Context, advertiserIDs []uint64, keyword string, page, pageSize int) ([]*entity.AdGroup, int64, error)
	FindByID(ctx context.Context, id uint64) (*entity.AdGroup, error)
	UpdateBudget(ctx context.Context, id uint64, budget float64) error
	UpdateStatus(ctx context.Context, id uint64, status string) error
}

type repo struct{ db *gorm.DB }

func New(db *gorm.DB) Repository { return &repo{db: db} }

// Upsert 批量插入或更新广告组（以 advertiser_id + adgroup_id 为唯一键）。
func (r *repo) Upsert(ctx context.Context, groups []*entity.AdGroup) error {
	if len(groups) == 0 {
		return nil
	}
	return r.db.WithContext(ctx).
		Clauses(clause.OnConflict{
			Columns: []clause.Column{{Name: "advertiser_id"}, {Name: "adgroup_id"}},
			DoUpdates: clause.AssignmentColumns([]string{
				"adgroup_name", "campaign_id", "status", "budget_mode",
				"budget", "spend", "bid_type", "bid_price", "updated_at",
			}),
		}).
		CreateInBatches(groups, 200).Error
}

// FindAllByAdvertiserID 拉取该广告主下所有广告组（同步后构建 platform_id→internal_id 映射用）。
func (r *repo) FindAllByAdvertiserID(ctx context.Context, advertiserID uint64) ([]*entity.AdGroup, error) {
	var list []*entity.AdGroup
	err := r.db.WithContext(ctx).
		Where("advertiser_id = ?", advertiserID).
		Select("id, adgroup_id, adgroup_name, platform").
		Find(&list).Error
	return list, err
}

// FindByAdvertiserID 分页查询广告组列表，campaignID=0 时返回全部。
func (r *repo) FindByAdvertiserID(ctx context.Context, advertiserID uint64, campaignID uint64, page, pageSize int) ([]*entity.AdGroup, int64, error) {
	q := r.db.WithContext(ctx).Model(&entity.AdGroup{}).Where("advertiser_id = ?", advertiserID)
	if campaignID > 0 {
		q = q.Where("campaign_id = ?", campaignID)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var list []*entity.AdGroup
	err := q.Order("id DESC").Offset((page - 1) * pageSize).Limit(pageSize).Find(&list).Error
	return list, total, err
}

func (r *repo) FindByID(ctx context.Context, id uint64) (*entity.AdGroup, error) {
	var g entity.AdGroup
	err := r.db.WithContext(ctx).First(&g, id).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &g, err
}

func (r *repo) UpdateBudget(ctx context.Context, id uint64, budget float64) error {
	return r.db.WithContext(ctx).Model(&entity.AdGroup{}).
		Where("id = ?", id).Update("budget", budget).Error
}

func (r *repo) UpdateStatus(ctx context.Context, id uint64, status string) error {
	return r.db.WithContext(ctx).Model(&entity.AdGroup{}).
		Where("id = ?", id).Update("status", status).Error
}

// FindByAdvertiserIDs 跨广告主分页查询广告组，支持关键词搜索。
func (r *repo) FindByAdvertiserIDs(ctx context.Context, advertiserIDs []uint64, keyword string, page, pageSize int) ([]*entity.AdGroup, int64, error) {
	if len(advertiserIDs) == 0 {
		return nil, 0, nil
	}
	q := r.db.WithContext(ctx).Model(&entity.AdGroup{}).Where("advertiser_id IN ?", advertiserIDs)
	if keyword != "" {
		like := "%" + keyword + "%"
		q = q.Where("adgroup_name LIKE ? OR adgroup_id LIKE ?", like, like)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var list []*entity.AdGroup
	err := q.Order("id DESC").Offset((page - 1) * pageSize).Limit(pageSize).Find(&list).Error
	return list, total, err
}
