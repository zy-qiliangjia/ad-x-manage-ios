package campaignrepo

import (
	"context"
	"errors"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"ad-x-manage/backend/internal/model/entity"
)

type Repository interface {
	Upsert(ctx context.Context, campaigns []*entity.Campaign) error
	FindAllByAdvertiserID(ctx context.Context, advertiserID uint64) ([]*entity.Campaign, error)
	FindByAdvertiserID(ctx context.Context, advertiserID uint64, page, pageSize int) ([]*entity.Campaign, int64, error)
	FindByAdvertiserIDs(ctx context.Context, advertiserIDs []uint64, keyword string, page, pageSize int) ([]*entity.Campaign, int64, error)
	FindByID(ctx context.Context, id uint64) (*entity.Campaign, error)
	UpdateBudget(ctx context.Context, id uint64, budget float64) error
	UpdateStatus(ctx context.Context, id uint64, status string) error
}

type repo struct{ db *gorm.DB }

func New(db *gorm.DB) Repository { return &repo{db: db} }

// Upsert 批量插入或更新推广系列（以 advertiser_id + campaign_id 为唯一键）。
func (r *repo) Upsert(ctx context.Context, campaigns []*entity.Campaign) error {
	if len(campaigns) == 0 {
		return nil
	}
	return r.db.WithContext(ctx).
		Clauses(clause.OnConflict{
			Columns: []clause.Column{{Name: "advertiser_id"}, {Name: "campaign_id"}},
			DoUpdates: clause.AssignmentColumns([]string{
				"campaign_name", "status", "budget_mode", "budget", "spend", "objective", "updated_at",
			}),
		}).
		CreateInBatches(campaigns, 200).Error
}

// FindAllByAdvertiserID 拉取该广告主下所有推广系列（用于同步后构建 platform_id→internal_id 映射）。
func (r *repo) FindAllByAdvertiserID(ctx context.Context, advertiserID uint64) ([]*entity.Campaign, error) {
	var list []*entity.Campaign
	err := r.db.WithContext(ctx).
		Where("advertiser_id = ?", advertiserID).
		Select("id, campaign_id, platform").
		Find(&list).Error
	return list, err
}

// FindByAdvertiserID 分页查询推广系列列表。
func (r *repo) FindByAdvertiserID(ctx context.Context, advertiserID uint64, page, pageSize int) ([]*entity.Campaign, int64, error) {
	var total int64
	q := r.db.WithContext(ctx).Model(&entity.Campaign{}).Where("advertiser_id = ?", advertiserID)
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var list []*entity.Campaign
	err := q.Order("id DESC").Offset((page - 1) * pageSize).Limit(pageSize).Find(&list).Error
	return list, total, err
}

func (r *repo) FindByID(ctx context.Context, id uint64) (*entity.Campaign, error) {
	var c entity.Campaign
	err := r.db.WithContext(ctx).First(&c, id).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &c, err
}

func (r *repo) UpdateBudget(ctx context.Context, id uint64, budget float64) error {
	return r.db.WithContext(ctx).Model(&entity.Campaign{}).
		Where("id = ?", id).Update("budget", budget).Error
}

func (r *repo) UpdateStatus(ctx context.Context, id uint64, status string) error {
	return r.db.WithContext(ctx).Model(&entity.Campaign{}).
		Where("id = ?", id).Update("status", status).Error
}

// FindByAdvertiserIDs 跨广告主分页查询推广系列，支持关键词搜索。
func (r *repo) FindByAdvertiserIDs(ctx context.Context, advertiserIDs []uint64, keyword string, page, pageSize int) ([]*entity.Campaign, int64, error) {
	if len(advertiserIDs) == 0 {
		return nil, 0, nil
	}
	q := r.db.WithContext(ctx).Model(&entity.Campaign{}).Where("advertiser_id IN ?", advertiserIDs)
	if keyword != "" {
		like := "%" + keyword + "%"
		q = q.Where("campaign_name LIKE ? OR campaign_id LIKE ?", like, like)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var list []*entity.Campaign
	err := q.Order("id DESC").Offset((page - 1) * pageSize).Limit(pageSize).Find(&list).Error
	return list, total, err
}
