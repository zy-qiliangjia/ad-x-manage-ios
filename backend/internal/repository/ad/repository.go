package adrepo

import (
	"context"
	"errors"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"ad-x-manage/backend/internal/model/entity"
)

type Repository interface {
	Upsert(ctx context.Context, ads []*entity.Ad) error
	FindByAdvertiserID(ctx context.Context, advertiserID uint64, adgroupID uint64, keyword string, page, pageSize int) ([]*entity.Ad, int64, error)
	FindByAdvertiserIDs(ctx context.Context, advertiserIDs []uint64, keyword string, page, pageSize int) ([]*entity.Ad, int64, error)
	FindByID(ctx context.Context, id uint64) (*entity.Ad, error)
	UpdateStatus(ctx context.Context, id uint64, status string) error
}

type repo struct{ db *gorm.DB }

func New(db *gorm.DB) Repository { return &repo{db: db} }

// Upsert 批量插入或更新广告（以 advertiser_id + ad_id 为唯一键）。
func (r *repo) Upsert(ctx context.Context, ads []*entity.Ad) error {
	if len(ads) == 0 {
		return nil
	}
	return r.db.WithContext(ctx).
		Clauses(clause.OnConflict{
			Columns: []clause.Column{{Name: "advertiser_id"}, {Name: "ad_id"}},
			DoUpdates: clause.AssignmentColumns([]string{
				"ad_name", "adgroup_id", "status", "creative_type", "updated_at",
			}),
		}).
		CreateInBatches(ads, 200).Error
}

// FindByAdvertiserID 分页查询广告列表，支持按广告组过滤和关键词搜索（ID/名称）。
func (r *repo) FindByAdvertiserID(ctx context.Context, advertiserID uint64, adgroupID uint64, keyword string, page, pageSize int) ([]*entity.Ad, int64, error) {
	q := r.db.WithContext(ctx).Model(&entity.Ad{}).Where("advertiser_id = ?", advertiserID)
	if adgroupID > 0 {
		q = q.Where("adgroup_id = ?", adgroupID)
	}
	if keyword != "" {
		like := "%" + keyword + "%"
		q = q.Where("ad_name LIKE ? OR ad_id LIKE ?", like, like)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var list []*entity.Ad
	err := q.Order("id DESC").Offset((page - 1) * pageSize).Limit(pageSize).Find(&list).Error
	return list, total, err
}

func (r *repo) FindByID(ctx context.Context, id uint64) (*entity.Ad, error) {
	var a entity.Ad
	err := r.db.WithContext(ctx).First(&a, id).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &a, err
}

func (r *repo) UpdateStatus(ctx context.Context, id uint64, status string) error {
	return r.db.WithContext(ctx).Model(&entity.Ad{}).
		Where("id = ?", id).
		Update("status", status).Error
}

// FindByAdvertiserIDs 跨广告主分页查询广告列表，支持关键词搜索。
func (r *repo) FindByAdvertiserIDs(ctx context.Context, advertiserIDs []uint64, keyword string, page, pageSize int) ([]*entity.Ad, int64, error) {
	if len(advertiserIDs) == 0 {
		return nil, 0, nil
	}
	q := r.db.WithContext(ctx).Model(&entity.Ad{}).Where("advertiser_id IN ?", advertiserIDs)
	if keyword != "" {
		like := "%" + keyword + "%"
		q = q.Where("ad_name LIKE ? OR ad_id LIKE ?", like, like)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var list []*entity.Ad
	err := q.Order("id DESC").Offset((page - 1) * pageSize).Limit(pageSize).Find(&list).Error
	return list, total, err
}
