package inviterepo

import (
	"context"

	"gorm.io/gorm"

	"ad-x-manage/backend/internal/model/entity"
)

type Repository interface {
	CountByInviterID(ctx context.Context, inviterID uint64) (int64, error)
	CreateRecord(ctx context.Context, record *entity.InviteRecord) error
	ExistsByInviteeID(ctx context.Context, inviteeID uint64) (bool, error)
}

type repo struct {
	db *gorm.DB
}

func New(db *gorm.DB) Repository {
	return &repo{db: db}
}

func (r *repo) CountByInviterID(ctx context.Context, inviterID uint64) (int64, error) {
	var count int64
	err := r.db.WithContext(ctx).
		Model(&entity.InviteRecord{}).
		Where("inviter_id = ?", inviterID).
		Count(&count).Error
	return count, err
}

func (r *repo) CreateRecord(ctx context.Context, record *entity.InviteRecord) error {
	return r.db.WithContext(ctx).Create(record).Error
}

func (r *repo) ExistsByInviteeID(ctx context.Context, inviteeID uint64) (bool, error) {
	var count int64
	err := r.db.WithContext(ctx).
		Model(&entity.InviteRecord{}).
		Where("invitee_id = ?", inviteeID).
		Count(&count).Error
	return count > 0, err
}
