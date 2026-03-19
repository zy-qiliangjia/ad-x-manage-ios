package userrepo

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"

	"ad-x-manage/backend/internal/model/entity"
)

// Repository 定义用户数据访问接口。
type Repository interface {
	Create(ctx context.Context, user *entity.User) error
	FindByEmail(ctx context.Context, email string) (*entity.User, error)
	FindByID(ctx context.Context, id uint64) (*entity.User, error)
	FindByInviteCode(ctx context.Context, code string) (*entity.User, error)
	UpdateLastLoginAt(ctx context.Context, id uint64, t time.Time) error
	AddQuota(ctx context.Context, id uint64, delta int) error
}

type repo struct {
	db *gorm.DB
}

func New(db *gorm.DB) Repository {
	return &repo{db: db}
}

func (r *repo) Create(ctx context.Context, user *entity.User) error {
	return r.db.WithContext(ctx).Create(user).Error
}

func (r *repo) FindByEmail(ctx context.Context, email string) (*entity.User, error) {
	var u entity.User
	err := r.db.WithContext(ctx).Where("email = ?", email).First(&u).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &u, nil
}

func (r *repo) FindByID(ctx context.Context, id uint64) (*entity.User, error) {
	var u entity.User
	err := r.db.WithContext(ctx).First(&u, id).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &u, nil
}

func (r *repo) FindByInviteCode(ctx context.Context, code string) (*entity.User, error) {
	var u entity.User
	err := r.db.WithContext(ctx).Where("invite_code = ?", code).First(&u).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &u, nil
}

func (r *repo) UpdateLastLoginAt(ctx context.Context, id uint64, t time.Time) error {
	return r.db.WithContext(ctx).
		Model(&entity.User{}).
		Where("id = ?", id).
		Update("last_login_at", t).Error
}

// AddQuota 原子性增加（或减少）用户的账号额度。
func (r *repo) AddQuota(ctx context.Context, id uint64, delta int) error {
	return r.db.WithContext(ctx).
		Model(&entity.User{}).
		Where("id = ?", id).
		Update("quota", gorm.Expr("quota + ?", delta)).Error
}
