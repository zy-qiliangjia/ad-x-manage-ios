package oauthsvc

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"

	"ad-x-manage/backend/internal/model/dto"
	"ad-x-manage/backend/internal/model/entity"
	advertiserrepo "ad-x-manage/backend/internal/repository/advertiser"
	tokenrepo "ad-x-manage/backend/internal/repository/token"
	"ad-x-manage/backend/internal/service/platform"
	syncsvc "ad-x-manage/backend/internal/service/sync"
)

var (
	ErrInvalidState    = errors.New("invalid or expired state")
	ErrPlatformUnknown = errors.New("unsupported platform")
	ErrTokenNotFound   = errors.New("token not found")
	ErrForbidden       = errors.New("no permission")
)

const stateKeyPrefix = "oauth:state:"
const stateTTL = 10 * time.Minute

// Service OAuth 授权业务接口。
type Service interface {
	GetOAuthURL(ctx context.Context, userID uint64, platformName string) (*dto.OAuthURLResponse, error)
	Callback(ctx context.Context, userID uint64, platformName, code, state string) (*dto.OAuthCallbackResponse, error)
	Revoke(ctx context.Context, userID, tokenID uint64) error
}

type service struct {
	clients   map[string]platform.Client
	tokenRepo tokenrepo.Repository
	advRepo   advertiserrepo.Repository
	syncSvc   syncsvc.Service
	rdb       *redis.Client
	log       *zap.Logger
}

func New(
	clients map[string]platform.Client,
	tokenRepo tokenrepo.Repository,
	advRepo advertiserrepo.Repository,
	syncSvc syncsvc.Service,
	rdb *redis.Client,
	log *zap.Logger,
) Service {
	return &service{
		clients:   clients,
		tokenRepo: tokenRepo,
		advRepo:   advRepo,
		syncSvc:   syncSvc,
		rdb:       rdb,
		log:       log,
	}
}

// GetOAuthURL 生成带 CSRF state 的平台授权 URL。
// state 存入 Redis，TTL 10 分钟。
func (s *service) GetOAuthURL(ctx context.Context, userID uint64, platformName string) (*dto.OAuthURLResponse, error) {
	client, err := s.getClient(platformName)
	if err != nil {
		return nil, err
	}

	state, err := generateState()
	if err != nil {
		return nil, err
	}

	// 存 state → user_id，供 callback 时校验
	key := stateKeyPrefix + state
	if err := s.rdb.Set(ctx, key, userID, stateTTL).Err(); err != nil {
		return nil, fmt.Errorf("store oauth state: %w", err)
	}

	return &dto.OAuthURLResponse{
		URL:   client.GetOAuthURL(state),
		State: state,
	}, nil
}

// Callback 处理授权回调：校验 state → 换 token → 存库 → 同步广告主。
func (s *service) Callback(ctx context.Context, userID uint64, platformName, code, state string) (*dto.OAuthCallbackResponse, error) {
	// 1. 验证 state 防 CSRF
	if err := s.validateState(ctx, state, userID); err != nil {
		return nil, err
	}

	client, err := s.getClient(platformName)
	if err != nil {
		return nil, err
	}

	// 2. 换取 access_token
	tokenResult, err := client.ExchangeToken(code)
	if err != nil {
		return nil, fmt.Errorf("exchange token: %w", err)
	}

	// 3. 存储 token（明文）
	platformToken := &entity.PlatformToken{
		UserID:       userID,
		Platform:     platformName,
		OpenUserID:   tokenResult.OpenUserID,
		AccessToken:  tokenResult.AccessToken,
		RefreshToken: tokenResult.RefreshToken,
		ExpiresAt:    &tokenResult.ExpiresAt,
		Scope:        tokenResult.Scope,
		Status:       entity.TokenStatusActive,
	}
	if err := s.tokenRepo.Upsert(ctx, platformToken); err != nil {
		return nil, fmt.Errorf("save token: %w", err)
	}
	// MySQL ON DUPLICATE KEY UPDATE 不返回已有行的 ID，需要重新查询确保 ID 正确
	if platformToken.ID == 0 {
		existing, err := s.tokenRepo.FindByUniqueKey(ctx, userID, platformName, tokenResult.OpenUserID)
		if err != nil {
			return nil, fmt.Errorf("reload token: %w", err)
		}
		if existing != nil {
			platformToken.ID = existing.ID
		}
	}

	// 4. 拉取广告主并同步入库
	advertisers, err := client.GetAdvertisers(tokenResult.AccessToken)
	if err != nil {
		return nil, fmt.Errorf("get advertisers: %w", err)
	}

	now := time.Now()
	entities := make([]*entity.Advertiser, 0, len(advertisers))
	for _, adv := range advertisers {
		entities = append(entities, &entity.Advertiser{
			TokenID:        platformToken.ID,
			UserID:         userID,
			Platform:       platformName,
			AdvertiserID:   adv.AdvertiserID,
			AdvertiserName: adv.AdvertiserName,
			Currency:       adv.Currency,
			Timezone:       adv.Timezone,
			Status:         1,
			SyncedAt:       &now,
		})
	}
	if err := s.advRepo.Upsert(ctx, entities); err != nil {
		return nil, fmt.Errorf("save advertisers: %w", err)
	}

	// 5. 查询已存入 DB 的广告主（带 ID），触发后台同步
	savedAdvs, _, _ := s.advRepo.FindByUserAndPlatform(ctx, userID, platformName, "", 1, 1000)
	s.triggerBackgroundSync(savedAdvs)

	// 6. 组装响应
	items := make([]dto.AdvertiserItem, 0, len(savedAdvs))
	for _, a := range savedAdvs {
		items = append(items, dto.AdvertiserItem{
			ID:             a.ID,
			AdvertiserID:   a.AdvertiserID,
			AdvertiserName: a.AdvertiserName,
			Currency:       a.Currency,
			Timezone:       a.Timezone,
			SyncedAt:       now,
		})
	}

	return &dto.OAuthCallbackResponse{
		TokenID:     platformToken.ID,
		Platform:    platformName,
		Advertisers: items,
	}, nil
}

// triggerBackgroundSync 在后台 goroutine 中对每个广告主触发全量数据同步。
func (s *service) triggerBackgroundSync(advertisers []*entity.Advertiser) {
	for _, adv := range advertisers {
		adv := adv // capture loop var
		go func() {
			ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
			defer cancel()
			if _, err := s.syncSvc.SyncAdvertiser(ctx, adv); err != nil {
				s.log.Warn("background sync failed",
					zap.Uint64("advertiser_id", adv.ID),
					zap.String("platform", adv.Platform),
					zap.Error(err),
				)
			}
		}()
	}
}

// Revoke 解绑授权：将 token 和对应广告主标记为停用。
func (s *service) Revoke(ctx context.Context, userID, tokenID uint64) error {
	token, err := s.tokenRepo.FindByID(ctx, tokenID)
	if err != nil {
		return err
	}
	if token == nil {
		return ErrTokenNotFound
	}
	// 鉴权：只能解绑自己的 token
	if token.UserID != userID {
		return ErrForbidden
	}

	if err := s.tokenRepo.Revoke(ctx, tokenID); err != nil {
		return err
	}
	return s.advRepo.RevokeByTokenID(ctx, tokenID)
}

// ── 工具方法 ───────────────────────────────────────────────────

func (s *service) getClient(platformName string) (platform.Client, error) {
	c, ok := s.clients[platformName]
	if !ok {
		return nil, fmt.Errorf("%w: %s", ErrPlatformUnknown, platformName)
	}
	return c, nil
}

func (s *service) validateState(ctx context.Context, state string, userID uint64) error {
	key := stateKeyPrefix + state
	val, err := s.rdb.GetDel(ctx, key).Result()
	if err != nil {
		return ErrInvalidState
	}
	// 验证 state 对应的 user_id 与当前登录用户一致
	if fmt.Sprintf("%d", userID) != val {
		return ErrInvalidState
	}
	return nil
}

func generateState() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}
