package operationlogrepo

import (
	"context"
	"time"

	"gorm.io/gorm"

	"ad-x-manage/backend/internal/model/entity"
)

type Repository interface {
	Create(ctx context.Context, log *entity.OperationLog) error
	List(ctx context.Context, userID uint64, filter ListFilter) ([]*entity.OperationLog, int64, error)
}

// ListFilter 查询操作日志的过滤条件。
type ListFilter struct {
	AdvertiserID uint64
	Platform     string
	Action       string
	TargetType   string
	Result       *uint8
	StartTime    *time.Time
	EndTime      *time.Time
	Page         int
	PageSize     int
}

type repo struct{ db *gorm.DB }

func New(db *gorm.DB) Repository { return &repo{db: db} }

func (r *repo) Create(ctx context.Context, log *entity.OperationLog) error {
	return r.db.WithContext(ctx).Create(log).Error
}

// List 分页查询操作日志，userID 做安全隔离（只返回当前用户的日志）。
func (r *repo) List(ctx context.Context, userID uint64, f ListFilter) ([]*entity.OperationLog, int64, error) {
	q := r.db.WithContext(ctx).Model(&entity.OperationLog{}).Where("user_id = ?", userID)

	if f.AdvertiserID > 0 {
		q = q.Where("advertiser_id = ?", f.AdvertiserID)
	}
	if f.Platform != "" {
		q = q.Where("platform = ?", f.Platform)
	}
	if f.Action != "" {
		q = q.Where("action = ?", f.Action)
	}
	if f.TargetType != "" {
		q = q.Where("target_type = ?", f.TargetType)
	}
	if f.Result != nil {
		q = q.Where("result = ?", *f.Result)
	}
	if f.StartTime != nil {
		q = q.Where("created_at >= ?", *f.StartTime)
	}
	if f.EndTime != nil {
		q = q.Where("created_at < ?", *f.EndTime)
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	var list []*entity.OperationLog
	err := q.Order("id DESC").Offset((f.Page - 1) * f.PageSize).Limit(f.PageSize).Find(&list).Error
	return list, total, err
}
