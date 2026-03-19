package advertiserrepo

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"ad-x-manage/backend/internal/model/entity"
)

type Repository interface {
	Upsert(ctx context.Context, advertisers []*entity.Advertiser) error
	FindByUserAndPlatform(ctx context.Context, userID uint64, platform, keyword string, page, pageSize int) ([]*entity.Advertiser, int64, error)
	FindAllActiveByUserID(ctx context.Context, userID uint64) ([]*entity.Advertiser, error)
	FindByID(ctx context.Context, id uint64) (*entity.Advertiser, error)
	FindByPlatformID(ctx context.Context, platform, advertiserID string) (*entity.Advertiser, error)
	FindByUserPlatformIDs(ctx context.Context, userID uint64, platform string, advertiserIDs []string) ([]*entity.Advertiser, error)
	UpdateSyncedAt(ctx context.Context, id uint64, t time.Time) error
	UpdateInfo(ctx context.Context, id uint64, currency, timezone string) error
	UpdateDailyBudget(ctx context.Context, id uint64, budget float64) error
	RevokeByTokenID(ctx context.Context, tokenID uint64) error
}

type repo struct {
	db *gorm.DB
}

func New(db *gorm.DB) Repository {
	return &repo{db: db}
}

// Upsert 批量插入或更新广告主（以 user_id + platform + advertiser_id 为唯一键）。
func (r *repo) Upsert(ctx context.Context, advertisers []*entity.Advertiser) error {
	if len(advertisers) == 0 {
		return nil
	}
	return r.db.WithContext(ctx).
		Clauses(clause.OnConflict{
			Columns: []clause.Column{{Name: "user_id"}, {Name: "platform"}, {Name: "advertiser_id"}},
			DoUpdates: clause.AssignmentColumns([]string{
				"token_id", "advertiser_name", "currency", "timezone", "daily_budget", "status", "synced_at", "updated_at",
			}),
		}).
		CreateInBatches(advertisers, 100).Error
}

// FindByUserAndPlatform 查询用户在指定平台的广告主列表（支持关键词搜索 + 分页）。
func (r *repo) FindByUserAndPlatform(ctx context.Context, userID uint64, platform, keyword string, page, pageSize int) ([]*entity.Advertiser, int64, error) {
	q := r.db.WithContext(ctx).
		Where("user_id = ? AND status = 1", userID)

	if platform != "" {
		q = q.Where("platform = ?", platform)
	}
	if keyword != "" {
		like := "%" + keyword + "%"
		q = q.Where("advertiser_name LIKE ? OR advertiser_id LIKE ?", like, like)
	}

	var total int64
	if err := q.Model(&entity.Advertiser{}).Count(&total).Error; err != nil {
		return nil, 0, err
	}

	var list []*entity.Advertiser
	offset := (page - 1) * pageSize
	err := q.Order("id DESC").Offset(offset).Limit(pageSize).Find(&list).Error
	return list, total, err
}

// FindAllActiveByUserID 查询该用户下所有有效广告主（不分页，用于触发全量同步）。
func (r *repo) FindAllActiveByUserID(ctx context.Context, userID uint64) ([]*entity.Advertiser, error) {
	var list []*entity.Advertiser
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND status = 1", userID).
		Find(&list).Error
	return list, err
}

func (r *repo) FindByID(ctx context.Context, id uint64) (*entity.Advertiser, error) {
	var a entity.Advertiser
	err := r.db.WithContext(ctx).First(&a, id).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &a, err
}

func (r *repo) FindByPlatformID(ctx context.Context, platform, advertiserID string) (*entity.Advertiser, error) {
	var a entity.Advertiser
	err := r.db.WithContext(ctx).
		Where("platform = ? AND advertiser_id = ?", platform, advertiserID).
		First(&a).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &a, err
}

func (r *repo) UpdateSyncedAt(ctx context.Context, id uint64, t time.Time) error {
	return r.db.WithContext(ctx).
		Model(&entity.Advertiser{}).
		Where("id = ?", id).
		Update("synced_at", t).Error
}

func (r *repo) UpdateInfo(ctx context.Context, id uint64, currency, timezone string) error {
	return r.db.WithContext(ctx).
		Model(&entity.Advertiser{}).
		Where("id = ?", id).
		Updates(map[string]any{
			"currency": currency,
			"timezone": timezone,
		}).Error
}

// FindByUserPlatformIDs 按 user_id + platform + 平台广告主 ID 列表批量查询。
func (r *repo) FindByUserPlatformIDs(ctx context.Context, userID uint64, platform string, advertiserIDs []string) ([]*entity.Advertiser, error) {
	var list []*entity.Advertiser
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND platform = ? AND advertiser_id IN ? AND status = 1", userID, platform, advertiserIDs).
		Find(&list).Error
	return list, err
}

func (r *repo) UpdateDailyBudget(ctx context.Context, id uint64, budget float64) error {
	return r.db.WithContext(ctx).
		Model(&entity.Advertiser{}).
		Where("id = ?", id).
		Update("daily_budget", budget).Error
}

// RevokeByTokenID 解绑时将该 token 下所有广告主标记为停用。
func (r *repo) RevokeByTokenID(ctx context.Context, tokenID uint64) error {
	return r.db.WithContext(ctx).
		Model(&entity.Advertiser{}).
		Where("token_id = ?", tokenID).
		Update("status", 0).Error
}
