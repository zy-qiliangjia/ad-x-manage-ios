package tokenrepo

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"ad-x-manage/backend/internal/model/entity"
)

type Repository interface {
	Upsert(ctx context.Context, token *entity.PlatformToken) error
	FindByID(ctx context.Context, id uint64) (*entity.PlatformToken, error)
	FindByUserAndPlatform(ctx context.Context, userID uint64, platform string) ([]*entity.PlatformToken, error)
	FindActiveByUserAndPlatform(ctx context.Context, userID uint64, platform string) ([]*entity.PlatformToken, error)
	UpdateToken(ctx context.Context, id uint64, accessTokenEnc, refreshTokenEnc string, expiresAt time.Time) error
	Revoke(ctx context.Context, id uint64) error
	// FindExpiringSoon 查找 30 分钟内即将过期的 token（用于定时刷新）
	FindExpiringSoon(ctx context.Context, within time.Duration) ([]*entity.PlatformToken, error)
}

type repo struct {
	db *gorm.DB
}

func New(db *gorm.DB) Repository {
	return &repo{db: db}
}

func (r *repo) Upsert(ctx context.Context, token *entity.PlatformToken) error {
	return r.db.WithContext(ctx).
		Clauses(clause.OnConflict{
			Columns: []clause.Column{
				{Name: "user_id"}, {Name: "platform"}, {Name: "open_user_id"},
			},
			DoUpdates: clause.AssignmentColumns([]string{
				"access_token_enc", "refresh_token_enc", "expires_at", "scope", "status", "updated_at",
			}),
		}).
		Create(token).Error
}

func (r *repo) FindByID(ctx context.Context, id uint64) (*entity.PlatformToken, error) {
	var t entity.PlatformToken
	err := r.db.WithContext(ctx).First(&t, id).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &t, err
}

func (r *repo) FindByUserAndPlatform(ctx context.Context, userID uint64, platform string) ([]*entity.PlatformToken, error) {
	var tokens []*entity.PlatformToken
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND platform = ?", userID, platform).
		Find(&tokens).Error
	return tokens, err
}

func (r *repo) FindActiveByUserAndPlatform(ctx context.Context, userID uint64, platform string) ([]*entity.PlatformToken, error) {
	var tokens []*entity.PlatformToken
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND platform = ? AND status = ?", userID, platform, entity.TokenStatusActive).
		Find(&tokens).Error
	return tokens, err
}

func (r *repo) UpdateToken(ctx context.Context, id uint64, accessTokenEnc, refreshTokenEnc string, expiresAt time.Time) error {
	return r.db.WithContext(ctx).
		Model(&entity.PlatformToken{}).
		Where("id = ?", id).
		Updates(map[string]any{
			"access_token_enc":  accessTokenEnc,
			"refresh_token_enc": refreshTokenEnc,
			"expires_at":        expiresAt,
		}).Error
}

func (r *repo) Revoke(ctx context.Context, id uint64) error {
	return r.db.WithContext(ctx).
		Model(&entity.PlatformToken{}).
		Where("id = ?", id).
		Update("status", entity.TokenStatusInactive).Error
}

func (r *repo) FindExpiringSoon(ctx context.Context, within time.Duration) ([]*entity.PlatformToken, error) {
	deadline := time.Now().Add(within)
	var tokens []*entity.PlatformToken
	err := r.db.WithContext(ctx).
		Where("status = ? AND expires_at IS NOT NULL AND expires_at <= ?", entity.TokenStatusActive, deadline).
		Find(&tokens).Error
	return tokens, err
}
